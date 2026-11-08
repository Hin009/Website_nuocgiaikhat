package vn.drinkstore.auth;

import java.security.SecureRandom;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.annotation.*;
import org.springframework.core.task.TaskExecutor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.*;
import vn.drinkstore.common.*;
import vn.drinkstore.security.*;

@Service
public class PasswordResetService {
    private static final SecureRandom RANDOM=new SecureRandom();
    private static final org.slf4j.Logger LOG=org.slf4j.LoggerFactory.getLogger(PasswordResetService.class);
    private static final String GENERIC="Nếu email thuộc tài khoản khách hàng được phép khôi phục, mã OTP sẽ được gửi. Vui lòng kiểm tra hộp thư và thư rác.";
    private final Db db; private final PasswordEncoder encoder; private final PasswordResetMail mail;
    private final TaskExecutor delivery; private final Clock clock;
    @Autowired public PasswordResetService(Db db,PasswordEncoder encoder,PasswordResetMail mail,
        @Qualifier("passwordResetMailExecutor") TaskExecutor delivery) { this(db,encoder,mail,delivery,Clock.systemUTC()); }
    PasswordResetService(Db db,PasswordEncoder encoder,PasswordResetMail mail,TaskExecutor delivery,Clock clock) {
        this.db=db; this.encoder=encoder; this.mail=mail; this.delivery=delivery; this.clock=clock;
    }
    private boolean eligible(long account) {
        return db.number("""
            select count(*) from tai_khoan a where a.id=?
              and (a.trang_thai='ACTIVE' or (a.trang_thai='LOCKED' and a.so_lan_dang_nhap_sai>=5))
              and exists(select 1 from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=a.id and r.ma_vai_tro='KHACH_HANG')
              and not exists(select 1 from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=a.id and r.ma_vai_tro in ('NHAN_VIEN','QUAN_TRI_VIEN'))
            """,account)>0;
    }
    private Map<String,Object> accepted(UUID challenge) {
        return Map.of("challengeId",challenge,"expiresInSeconds",300,"retryAfterSeconds",60,"message",GENERIC);
    }
    public void requireDeliveryConfigured() { mail.requireConfigured(); }
    @Transactional public Object request(String email) {
        requireDeliveryConfigured();
        String normalized=email.trim().toLowerCase(Locale.ROOT);
        UUID challenge=UUID.randomUUID();
        String code=String.format(Locale.ROOT,"%06d",RANDOM.nextInt(1_000_000));
        // Perform the same expensive hashing for unknown addresses as for existing accounts.
        String hash=encoder.encode(code);
        var accounts=db.rows("select id,email from tai_khoan where lower(email)=? for update",normalized);
        if(accounts.isEmpty()) return accepted(challenge);
        long account=Db.n(accounts.getFirst(),"id");
        if(!eligible(account)) return accepted(challenge);
        Instant now=clock.instant();
        var recent=db.rows("select tao_luc from password_reset_challenge where tai_khoan_id=? order by tao_luc desc limit 1",account);
        if(!recent.isEmpty() && instant(recent.getFirst().get("tao_luc")).plusSeconds(60).isAfter(now)) return accepted(challenge);
        db.jdbc().update("delete from password_reset_challenge where tai_khoan_id=? and tao_luc<?",account,Timestamp.from(now.minus(Duration.ofDays(1))));
        invalidate(account);
        db.jdbc().update("insert into password_reset_challenge(id,tai_khoan_id,otp_hash,het_han,tao_luc) values (?,?,?,?,?)",challenge,account,hash,Timestamp.from(now.plusSeconds(300)),Timestamp.from(now));
        Runnable send=()-> {
            try { delivery.execute(()-> {
                try { mail.send(normalized,code); }
                catch(RuntimeException failure) { deliveryFailed(challenge); }
            }); } catch(RuntimeException failure) { deliveryFailed(challenge); }
        };
        if(TransactionSynchronizationManager.isSynchronizationActive())
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() { @Override public void afterCommit() { send.run(); } });
        else send.run();
        return accepted(challenge);
    }
    private void deliveryFailed(UUID challenge) {
        LOG.warn("Không gửi được email OTP (yêu cầu {}). Kiểm tra cấu hình SMTP.",challenge);
        try { db.jdbc().update("update password_reset_challenge set gui_that_bai=true,da_dung=true,otp_hash=null where id=?",challenge); }
        catch(RuntimeException ignored) { LOG.warn("Không cập nhật được trạng thái gửi email OTP."); }
    }
    private Map<String,Object> lock(UUID challenge) {
        var rows=db.rows("select tai_khoan_id from password_reset_challenge where id=?",challenge);
        if(rows.isEmpty()) throw invalid();
        long account=Db.n(rows.getFirst(),"tai_khoan_id");
        db.one("select id from tai_khoan where id=? for update",account);
        var row=db.one("select * from password_reset_challenge where id=? for update",challenge);
        if(!eligible(account) || Boolean.TRUE.equals(row.get("da_dung"))) throw invalid();
        return row;
    }
    // A wrong OTP must consume an attempt even though the endpoint returns a validation error.
    @Transactional(noRollbackFor=ApiException.class) public Object verify(UUID challenge,String code) {
        var row=lock(challenge);
        if(row.get("otp_hash")==null || row.get("reset_token_hash")!=null || Db.n(row,"so_lan_sai")>=5 || !clock.instant().isBefore(instant(row.get("het_han")))) throw invalid();
        if(!encoder.matches(code,row.get("otp_hash").toString())) {
            db.jdbc().update("update password_reset_challenge set so_lan_sai=least(so_lan_sai+1,5) where id=?",challenge);
            throw invalid();
        }
        String token=Tokens.generate();
        db.jdbc().update("update password_reset_challenge set otp_hash=null,reset_token_hash=?,reset_het_han=? where id=?",Tokens.hash(token),Timestamp.from(clock.instant().plusSeconds(300)),challenge);
        return Map.of("resetToken",token,"expiresInSeconds",300);
    }
    @Transactional public void complete(UUID challenge,String token,String password) {
        Passwords.validate(password);
        var row=lock(challenge);
        if(row.get("reset_token_hash")==null || row.get("reset_het_han")==null || !clock.instant().isBefore(instant(row.get("reset_het_han")))) throw invalid();
        if(!MessageDigest.isEqual(Tokens.hash(token).getBytes(StandardCharsets.US_ASCII),row.get("reset_token_hash").toString().getBytes(StandardCharsets.US_ASCII))) throw invalid();
        long account=Db.n(row,"tai_khoan_id");
        db.jdbc().update("update tai_khoan set mat_khau_hash=?,so_lan_dang_nhap_sai=0,trang_thai='ACTIVE' where id=?",encoder.encode(password),account);
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",account);
        invalidate(account);
        db.audit(account,"PASSWORD_RESET_OTP","tai_khoan",account);
    }
    private void invalidate(long account) {
        db.jdbc().update("update password_reset_challenge set da_dung=true,otp_hash=null,reset_token_hash=null,reset_het_han=null where tai_khoan_id=? and not da_dung",account);
    }
    static Instant instant(Object value) {
        if(value instanceof Timestamp timestamp) return timestamp.toInstant();
        if(value instanceof OffsetDateTime time) return time.toInstant();
        return (Instant)value;
    }
    private ApiException invalid() { return ApiException.bad("Mã xác minh không hợp lệ, đã dùng hoặc hết hạn. Vui lòng kiểm tra hoặc gửi lại OTP."); }
}

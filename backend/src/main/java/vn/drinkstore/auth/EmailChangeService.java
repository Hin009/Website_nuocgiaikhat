package vn.drinkstore.auth;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.*;
import java.util.*;
import org.springframework.beans.factory.annotation.*;
import org.springframework.core.task.TaskExecutor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.*;
import vn.drinkstore.common.*;

@Service
public class EmailChangeService {
    private static final SecureRandom RANDOM=new SecureRandom();
    private static final org.slf4j.Logger LOG=org.slf4j.LoggerFactory.getLogger(EmailChangeService.class);
    private final Db db;
    private final PasswordEncoder encoder;
    private final PasswordResetMail mail;
    private final EmailChangeRateLimit limits;
    private final TaskExecutor delivery;
    private final Clock clock;
    @Autowired public EmailChangeService(Db db,PasswordEncoder encoder,PasswordResetMail mail,EmailChangeRateLimit limits,
        @Qualifier("passwordResetMailExecutor") TaskExecutor delivery) {
        this(db,encoder,mail,limits,delivery,Clock.systemUTC());
    }
    EmailChangeService(Db db,PasswordEncoder encoder,PasswordResetMail mail,EmailChangeRateLimit limits,TaskExecutor delivery,Clock clock) {
        this.db=db; this.encoder=encoder; this.mail=mail; this.limits=limits; this.delivery=delivery; this.clock=clock;
    }
    private String normalized(String email) { return email.trim().toLowerCase(Locale.ROOT); }
    private Map<String,Object> account(long id) {
        var row=db.one("select id,email,trang_thai from tai_khoan where id=? and deleted_at is null for update",id);
        if(!"ACTIVE".equals(row.get("trang_thai"))) throw invalid();
        return row;
    }
    private Map<String,Object> lock(long account,String session,UUID challenge) {
        var user=account(account);
        var rows=db.rows("select * from email_change_challenge where id=? and tai_khoan_id=? and session_hash=? for update",challenge,account,session);
        if(rows.isEmpty()) throw invalid();
        var row=rows.getFirst();
        if(!normalized(user.get("email").toString()).equals(row.get("old_email")) || Set.of("CANCELLED","COMPLETED").contains(row.get("stage"))
            || !clock.instant().isBefore(instant(row.get("created_at")).plusSeconds(1800))) throw invalid();
        return row;
    }
    private void grant(Map<String,Object> row) {
        if(row.get("verified_until")==null || !clock.instant().isBefore(instant(row.get("verified_until")))) throw invalid();
    }
    private String code() { return String.format(Locale.ROOT,"%06d",RANDOM.nextInt(1_000_000)); }
    private Map<String,Object> accepted(UUID id,String email,Instant expires) {
        return Map.of("challengeId",id,"email",email,"expiresInSeconds",Math.max(0,Duration.between(clock.instant(),expires).toSeconds()),"retryAfterSeconds",60,"message","Mã OTP gồm 6 chữ số đã được yêu cầu gửi. Vui lòng kiểm tra email và thư rác.");
    }
    private void send(UUID id,String email,String code,boolean newEmail,String hash) {
        Runnable dispatch=() -> {
            try { delivery.execute(() -> {
                try { mail.sendEmailChange(email,code,newEmail); }
                catch(RuntimeException failure) { failed(id,hash); }
            }); } catch(RuntimeException failure) { failed(id,hash); }
        };
        if(TransactionSynchronizationManager.isSynchronizationActive())
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() { @Override public void afterCommit() { dispatch.run(); } });
        else dispatch.run();
    }
    private void failed(UUID id,String hash) {
        LOG.warn("Không gửi được OTP đổi email (yêu cầu {}). Kiểm tra SMTP.",id);
        try { db.jdbc().update("update email_change_challenge set delivery_failed=true,otp_hash=null where id=? and otp_hash=?",id,hash); }
        catch(RuntimeException ignored) { LOG.warn("Không cập nhật được trạng thái gửi OTP đổi email."); }
    }
    @Transactional public Object requestCurrent(long id,String session,String ip) {
        mail.requireConfigured();
        String current=normalized(account(id).get("email").toString());
        var recent=db.rows("select last_sent_at from email_change_challenge where tai_khoan_id=? order by last_sent_at desc limit 1",id);
        if(!recent.isEmpty()) cooldown(recent.getFirst());
        limits.request(id,ip,current);
        db.jdbc().update("delete from email_change_challenge where tai_khoan_id=? and created_at<?",id,Timestamp.from(clock.instant().minus(Duration.ofDays(1))));
        invalidate(id);
        UUID challenge=UUID.randomUUID(); String code=code(),hash=encoder.encode(code);
        Instant expires=clock.instant().plusSeconds(300);
        db.jdbc().update("insert into email_change_challenge(id,tai_khoan_id,session_hash,old_email,stage,otp_hash,expires_at,last_sent_at,created_at) values (?,?,?,?,'CURRENT_OTP',?,?,?,?)",
            challenge,id,session,current,hash,Timestamp.from(expires),Timestamp.from(clock.instant()),Timestamp.from(clock.instant()));
        send(challenge,current,code,false,hash);
        return accepted(challenge,current,expires);
    }
    @Transactional(noRollbackFor=WrongCode.class) public Object verifyCurrent(long id,String session,UUID challenge,String code,String ip) {
        limits.verify(ip); var row=lock(id,session,challenge);
        if(!"CURRENT_OTP".equals(row.get("stage"))) throw invalid();
        verifyCode(challenge,row,code);
        db.jdbc().update("update email_change_challenge set stage='CURRENT_VERIFIED',otp_hash=null,verified_until=? where id=?",Timestamp.from(clock.instant().plusSeconds(600)),challenge);
        return Map.of("message","Đã xác minh email hiện tại. Vui lòng nhập email mới.","expiresInSeconds",600);
    }
    public static class WrongCode extends ApiException {
        WrongCode() { super(HttpStatus.BAD_REQUEST,"Mã OTP không đúng. Mỗi mã chỉ được nhập sai tối đa 5 lần."); }
    }
    private void verifyCode(UUID id,Map<String,Object> row,String code) {
        if(row.get("otp_hash")==null || Boolean.TRUE.equals(row.get("delivery_failed")) || Db.n(row,"attempts")>=5 || !clock.instant().isBefore(instant(row.get("expires_at"))))
            throw ApiException.bad("Mã OTP đã hết hạn hoặc hết lượt xác minh. Vui lòng gửi lại OTP.");
        if(!encoder.matches(code,row.get("otp_hash").toString())) {
            db.jdbc().update("update email_change_challenge set attempts=least(attempts+1,5) where id=?",id);
            throw new WrongCode();
        }
    }
    private void available(long id,String email) {
        if(db.number("select count(*) from tai_khoan where lower(email)=? and id<>?",email,id)>0)
            throw new ApiException(HttpStatus.CONFLICT,"Email mới không khả dụng. Vui lòng chọn địa chỉ email khác.");
    }
    @Transactional public Object requestNew(long id,String session,UUID challenge,String email,String ip) {
        mail.requireConfigured();
        if(challenge==null) throw invalid();
        var row=lock(id,session,challenge); grant(row);
        if(!Set.of("CURRENT_VERIFIED","NEW_OTP").contains(row.get("stage"))) throw invalid();
        String next=normalized(email);
        if(next.equals(row.get("old_email"))) throw ApiException.bad("Email mới phải khác email hiện tại.");
        available(id,next);
        return issueNew(id,challenge,row,next,ip);
    }
    private Object issueNew(long id,UUID challenge,Map<String,Object> row,String email,String ip) {
        if("NEW_OTP".equals(row.get("stage"))) cooldown(row);
        limits.request(id,ip,email);
        Instant expires=clock.instant().plusSeconds(300);
        if(expires.isAfter(instant(row.get("verified_until")))) expires=instant(row.get("verified_until"));
        String code=code(),hash=encoder.encode(code);
        db.jdbc().update("update email_change_challenge set stage='NEW_OTP',new_email=?,otp_hash=?,expires_at=?,attempts=0,last_sent_at=?,delivery_failed=false where id=?",
            email,hash,Timestamp.from(expires),Timestamp.from(clock.instant()),challenge);
        send(challenge,email,code,true,hash);
        return accepted(challenge,email,expires);
    }
    private void cooldown(Map<String,Object> row) {
        long milliseconds=Duration.between(clock.instant(),instant(row.get("last_sent_at")).plusSeconds(60)).toMillis();
        if(milliseconds>0) throw new ApiException(HttpStatus.TOO_MANY_REQUESTS,"Vui lòng chờ "+((milliseconds+999)/1000)+" giây để gửi lại OTP.");
    }
    @Transactional public Object resend(long id,String session,UUID challenge,String ip) {
        mail.requireConfigured(); var row=lock(id,session,challenge);
        if("NEW_OTP".equals(row.get("stage"))) {
            grant(row); available(id,row.get("new_email").toString());
            return issueNew(id,challenge,row,row.get("new_email").toString(),ip);
        }
        if(!"CURRENT_OTP".equals(row.get("stage"))) throw invalid();
        cooldown(row); limits.request(id,ip,row.get("old_email").toString());
        String code=code(),hash=encoder.encode(code); Instant expires=clock.instant().plusSeconds(300);
        db.jdbc().update("update email_change_challenge set otp_hash=?,expires_at=?,attempts=0,last_sent_at=?,delivery_failed=false where id=?",hash,Timestamp.from(expires),Timestamp.from(clock.instant()),challenge);
        send(challenge,row.get("old_email").toString(),code,false,hash);
        return accepted(challenge,row.get("old_email").toString(),expires);
    }
    @Transactional(noRollbackFor=WrongCode.class) public Object verifyNew(long id,String session,UUID challenge,String code,String ip) {
        limits.verify(ip); var row=lock(id,session,challenge); grant(row);
        if(!"NEW_OTP".equals(row.get("stage"))) throw invalid();
        verifyCode(challenge,row,code);
        String next=row.get("new_email").toString(); available(id,next);
        try { db.jdbc().update("update tai_khoan set email=?,email_da_xac_thuc=true where id=?",next,id); }
        catch(DuplicateKeyException e) { throw new ApiException(HttpStatus.CONFLICT,"Email mới không khả dụng. Vui lòng chọn địa chỉ email khác."); }
        db.jdbc().update("update email_change_challenge set stage='COMPLETED',otp_hash=null where id=?",challenge);
        db.jdbc().update("update email_change_challenge set stage='CANCELLED',otp_hash=null where tai_khoan_id=? and id<>? and stage not in ('COMPLETED','CANCELLED')",id,challenge);
        db.jdbc().update("update password_reset_challenge set da_dung=true,otp_hash=null,reset_token_hash=null,reset_het_han=null where tai_khoan_id=?",id);
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=? and token_hash<>?",id,session);
        db.audit(id,"EMAIL_CHANGE_OTP","tai_khoan",id);
        return Map.of("email",next,"message","Email được thay đổi thành công.");
    }
    @Transactional public void cancel(long id,String session,UUID challenge) {
        account(id);
        db.jdbc().update("update email_change_challenge set stage='CANCELLED',otp_hash=null where id=? and tai_khoan_id=? and session_hash=? and stage not in ('COMPLETED','CANCELLED')",challenge,id,session);
    }
    private void invalidate(long id) { db.jdbc().update("update email_change_challenge set stage='CANCELLED',otp_hash=null where tai_khoan_id=? and stage not in ('COMPLETED','CANCELLED')",id); }
    private static Instant instant(Object value) { return PasswordResetService.instant(value); }
    private ApiException invalid() { return ApiException.bad("Yêu cầu đổi email không hợp lệ hoặc đã hết hạn. Vui lòng bắt đầu lại."); }
}

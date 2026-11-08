package vn.drinkstore.auth;

import java.time.*;
import java.sql.Timestamp;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Tokens;
import vn.drinkstore.security.Passwords;

@Service
public class AuthService {
    private final Db db; private final PasswordEncoder encoder; private final int hours;
    public AuthService(Db db, PasswordEncoder encoder,@Value("${app.token-hours}") int hours) { this.db=db; this.encoder=encoder; this.hours=hours; }
    @Transactional
    public Map<String,Object> register(String email,String password,String name) { return register(email,password,name,null); }
    @Transactional
    public Map<String,Object> register(String email,String password,String name,String phone) {
        PhoneNumbers.validate(phone,false);
        long id=createAccount(email,password,"KHACH_HANG");
        db.jdbc().update("insert into khach_hang(tai_khoan_id,ho_ten,dien_thoai) values (?,?,?)",id,name,phone);
        db.audit(id,"REGISTER","tai_khoan",id);
        return Map.of("id",id,"email",email);
    }
    public long createAccount(String email,String password,String role) {
        Passwords.validate(password);
        long roleId=db.id("select id from vai_tro where ma_vai_tro=?",role);
        long id=db.id("insert into tai_khoan(email,mat_khau_hash) values (?,?) returning id",email.toLowerCase(java.util.Locale.ROOT),encoder.encode(password));
        db.jdbc().update("insert into tai_khoan_vai_tro(tai_khoan_id,vai_tro_id) values (?,?)",id,roleId);
        return id;
    }
    // Commit failed-attempt counter even when reporting invalid credentials.
    @Transactional(noRollbackFor=ApiException.class)
    public Map<String,Object> login(String email,String password) {
        if(!Passwords.fitsBcrypt(password)) throw unauthorized();
        var rows=db.jdbc().queryForList("select * from tai_khoan where lower(email)=lower(?) for update",email);
        if(rows.isEmpty()) { encoder.matches(password,"$2a$12$wJqA1jDijVW5eM8bS8AdoOU0vMAM6asrY5oAJrdEUaS4hI4Azt9aa"); throw unauthorized(); }
        var a=rows.getFirst(); long id=Db.n(a,"id");
        if(!"ACTIVE".equals(a.get("trang_thai"))) throw unauthorized();
        if(!encoder.matches(password,a.get("mat_khau_hash").toString())) {
            db.jdbc().update("update tai_khoan set so_lan_dang_nhap_sai=so_lan_dang_nhap_sai+1, trang_thai=case when so_lan_dang_nhap_sai>=4 then 'LOCKED' else trang_thai end where id=?",id);
            throw unauthorized();
        }
        db.jdbc().update("update tai_khoan set so_lan_dang_nhap_sai=0 where id=?",id);
        String token=Tokens.generate(); Instant expires=Instant.now().plus(Duration.ofHours(hours));
        db.jdbc().update("insert into phien_xac_thuc(tai_khoan_id,token_hash,het_han) values (?,?,?)",id,Tokens.hash(token),Timestamp.from(expires));
        db.audit(id,"LOGIN","tai_khoan",id);
        return Map.of("accessToken",token,"tokenType","Bearer","expiresAt",expires,"user",profile(id));
    }
    private ApiException unauthorized() { return new ApiException(HttpStatus.UNAUTHORIZED,"Sai tài khoản, mật khẩu hoặc tài khoản đã bị khóa"); }
    public Map<String,Object> profile(long account) {
        return Map.of("account",db.one("select id,email,trang_thai,email_da_xac_thuc from tai_khoan where id=?",account),
            "roles",db.jdbc().queryForList("select r.ma_vai_tro from vai_tro r join tai_khoan_vai_tro ar on ar.vai_tro_id=r.id where ar.tai_khoan_id=? order by r.id",String.class,account),
            "permissions",db.jdbc().queryForList("select distinct q.ma_quyen from quyen q join vai_tro_quyen rq on rq.quyen_id=q.id join tai_khoan_vai_tro ar on ar.vai_tro_id=rq.vai_tro_id where ar.tai_khoan_id=? order by q.ma_quyen",String.class,account));
    }
    @Transactional public void changePassword(long id,String oldPassword,String password) {
        Passwords.validate(password);
        if(!Passwords.fitsBcrypt(oldPassword)) throw ApiException.bad("Mật khẩu cũ không đúng");
        var a=db.one("select * from tai_khoan where id=? for update",id);
        if(!encoder.matches(oldPassword,a.get("mat_khau_hash").toString())) throw ApiException.bad("Mật khẩu cũ không đúng");
        db.jdbc().update("update tai_khoan set mat_khau_hash=? where id=?",encoder.encode(password),id);
        db.jdbc().update("update password_reset_challenge set da_dung=true,otp_hash=null,reset_token_hash=null,reset_het_han=null where tai_khoan_id=?",id);
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",id);
    }
}

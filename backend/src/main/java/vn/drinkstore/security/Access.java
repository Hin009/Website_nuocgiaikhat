package vn.drinkstore.security;

import org.springframework.stereotype.Component;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.access.AccessDeniedException;
import vn.drinkstore.common.Db;

@Component("access")
public class Access {
    private final Db db;
    public Access(Db db) { this.db=db; }
    public long account() {
        var a=SecurityContextHolder.getContext().getAuthentication();
        if(a==null || !(a.getPrincipal() instanceof Long)) throw new AccessDeniedException("Login required");
        return (Long)a.getPrincipal();
    }
    public boolean role(String role) {
        return db.number("select count(*) from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=? and r.ma_vai_tro=?",account(),role)>0;
    }
    public boolean admin() { return role("QUAN_TRI_VIEN"); }
    public boolean has(String permission) { return admin() || Boolean.TRUE.equals(db.jdbc().queryForObject("select exists(select 1 from tai_khoan_vai_tro ar join vai_tro_quyen rq on rq.vai_tro_id=ar.vai_tro_id join quyen q on q.id=rq.quyen_id where ar.tai_khoan_id=? and q.ma_quyen=?)",Boolean.class,account(),permission)); }
    public long customer() { return db.id("select id from khach_hang where tai_khoan_id=?",account()); }
    public long employee() { return db.id("select id from nhan_vien where tai_khoan_id=? and trang_thai='ACTIVE'",account()); }
}

package vn.drinkstore.administration;

import java.util.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.auth.AuthService;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;
import vn.drinkstore.security.Passwords;

@Service
public class AdminService {
    private final Db db; private final Access access; private final AuthService auth; private final PasswordEncoder passwords;
    public AdminService(Db db,Access access,AuthService auth,PasswordEncoder passwords) { this.db=db; this.access=access; this.auth=auth; this.passwords=passwords; }
    @Transactional public Object createStaff(AdminController.NewStaff r) {
        PhoneNumbers.validate(r.phone(),false);
        long account=auth.createAccount(r.email(),r.password(),"NHAN_VIEN");
        long id=db.id("insert into nhan_vien(tai_khoan_id,ma_nhan_vien,ho_ten,dien_thoai,chuc_vu,ngay_vao_lam) values (?,'NV-'||?::text,?,?,?,current_date) returning id",account,account,r.fullName(),r.phone(),r.position());
        db.audit(access.account(),"STAFF_CREATE","nhan_vien",id); return db.one("select * from nhan_vien where id=?",id);
    }
    @Transactional public Object updateStaff(long id,AdminController.StaffProfile r) {
        PhoneNumbers.validate(r.phone(),false);
        db.one("select id from nhan_vien where id=? for update",id);
        db.jdbc().update("update nhan_vien set ho_ten=?,ngay_sinh=?,gioi_tinh=?,dien_thoai=?,dia_chi=? where id=?",r.fullName(),r.birthDate(),r.gender(),r.phone(),r.address(),id);
        db.audit(access.account(),"STAFF_PROFILE","nhan_vien",id); return db.one("select * from nhan_vien where id=?",id);
    }
    @Transactional public Object employment(long id,AdminController.Employment r) {
        var staff=db.one("select * from nhan_vien where id=? for update",id);
        if(Db.n(staff,"tai_khoan_id")==access.account()) throw ApiException.bad("Không tự thay đổi trạng thái làm việc");
        db.jdbc().update("update nhan_vien set trang_thai=?,chuc_vu=? where id=?",r.status(),r.position(),id);
        db.jdbc().update("update tai_khoan set trang_thai=?,so_lan_dang_nhap_sai=0 where id=?","ACTIVE".equals(r.status())?"ACTIVE":"DISABLED",staff.get("tai_khoan_id"));
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",staff.get("tai_khoan_id"));
        db.audit(access.account(),"STAFF_"+r.status(),"nhan_vien",id); return db.one("select * from nhan_vien where id=?",id);
    }
    @Transactional public Object accountStatus(long id,String status) {
        if(id==access.account()) throw ApiException.bad("Không tự khóa tài khoản quản trị đang dùng");
        db.one("select id from tai_khoan where id=? for update",id);
        if(status.equals("ACTIVE") && db.number("select count(*) from nhan_vien where tai_khoan_id=? and trang_thai<>'ACTIVE'",id)>0) throw ApiException.bad("Khôi phục nhân viên trước khi mở tài khoản");
        db.jdbc().update("update tai_khoan set trang_thai=?,so_lan_dang_nhap_sai=0 where id=?",status,id);
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",id);
        db.audit(access.account(),"ACCOUNT_"+status,"tai_khoan",id); return Map.of("id",id,"status",status);
    }
    @Transactional public void reset(long id,String password) {
        Passwords.validate(password);
        db.one("select id from tai_khoan where id=? for update",id);
        rejectCustomerPasswordChange(id);
        db.jdbc().update("update tai_khoan set mat_khau_hash=? where id=?",passwords.encode(password),id);
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",id);
        db.audit(access.account(),"PASSWORD_RESET","tai_khoan",id);
    }
    private void rejectCustomerPasswordChange(long id) {
        if(db.number("select count(*) from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=? and r.ma_vai_tro='KHACH_HANG'",id)>0)
            throw ApiException.bad("Không đặt mật khẩu mới cho khách hàng trong quản lý tài khoản.");
    }
    @Transactional public Object role(Long id,AdminController.Role r) {
        if(id==null) throw ApiException.bad("Schema defines three fixed role codes; update an existing role");
        db.one("select id from vai_tro where id=? for update",id);
        db.jdbc().update("update vai_tro set ten_vai_tro=?,mo_ta=? where id=?",r.name(),r.description(),id);
        db.audit(access.account(),"ROLE_SAVE","vai_tro",id); return db.one("select * from vai_tro where id=?",id);
    }
    @Transactional public void assign(long account,long role,boolean add) {
        if(account==access.account()) throw ApiException.bad("Cannot change own roles");
        db.one("select id from tai_khoan where id=? for update",account);
        var r=db.one("select * from vai_tro where id=?",role);
        if(add && Set.of("QUAN_TRI_VIEN","NHAN_VIEN").contains(r.get("ma_vai_tro")) && db.number("select count(*) from nhan_vien where tai_khoan_id=? and trang_thai='ACTIVE'",account)==0) throw ApiException.bad("Active employee profile required");
        if(add) db.jdbc().update("insert into tai_khoan_vai_tro(tai_khoan_id,vai_tro_id) values (?,?) on conflict do nothing",account,role);
        else {
            if(db.number("select count(*) from tai_khoan_vai_tro where tai_khoan_id=? and vai_tro_id<>?",account,role)==0) throw ApiException.bad("Account must retain at least one role");
            db.jdbc().update("delete from tai_khoan_vai_tro where tai_khoan_id=? and vai_tro_id=?",account,role);
        }
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",account);
        db.audit(access.account(),add?"ROLE_ASSIGN":"ROLE_REVOKE","tai_khoan",account);
    }
    @Transactional public void permissions(long role,List<Long> ids) {
        db.one("select id from vai_tro where id=? for update",role);
        for(Long id:new HashSet<>(ids)) db.one("select id from quyen where id=?",id);
        db.jdbc().update("delete from vai_tro_quyen where vai_tro_id=?",role);
        for(Long id:new HashSet<>(ids)) db.jdbc().update("insert into vai_tro_quyen(vai_tro_id,quyen_id) values (?,?)",role,id);
        db.audit(access.account(),"ROLE_PERMISSIONS","vai_tro",role);
    }
    @Transactional public void deleteRole(long id) {
        db.one("select id from vai_tro where id=?",id);
        throw ApiException.bad("Cannot delete one of the three system roles");
    }
    @Transactional public Object accountEditor(Long id,AdminController.AccountEditor r) {
        PhoneNumbers.validate(r.phone(),false);
        long role=db.id("select id from vai_tro where ma_vai_tro=?",r.role());
        boolean created=id==null;
        if(created) { if(r.password()==null || r.password().isBlank()) throw ApiException.bad("Cần mật khẩu cho tài khoản mới"); id=auth.createAccount(r.email(),r.password(),r.role()); }
        var account=db.one("select * from tai_khoan where id=? for update",id);
        if(!created && r.password()!=null && !r.password().isBlank()) {
            if("KHACH_HANG".equals(r.role())) throw ApiException.bad("Không đặt mật khẩu mới cho khách hàng trong quản lý tài khoản.");
            rejectCustomerPasswordChange(id);
        }
        if(!account.get("email").toString().equalsIgnoreCase(r.email())) throw ApiException.bad("Không đổi email của tài khoản đã tạo");
        var roles=db.jdbc().queryForList("select r.ma_vai_tro from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=?",String.class,id);
        String primary=roles.contains("QUAN_TRI_VIEN")?"QUAN_TRI_VIEN":roles.contains("NHAN_VIEN")?"NHAN_VIEN":"KHACH_HANG";
        boolean roleChanged=!primary.equals(r.role());
        if(id==access.account() && (!r.active() || roleChanged)) throw ApiException.bad("Không khóa hoặc hạ quyền tài khoản đang dùng");
        if("KHACH_HANG".equals(r.role())) {
            db.jdbc().update("insert into khach_hang(tai_khoan_id,ho_ten,dien_thoai) values (?,?,?) on conflict(tai_khoan_id) do update set ho_ten=excluded.ho_ten,dien_thoai=excluded.dien_thoai",id,r.fullName(),r.phone());
        } else {
            if(r.active() && db.number("select count(*) from nhan_vien where tai_khoan_id=? and trang_thai<>'ACTIVE'",id)>0) throw ApiException.bad("Khôi phục trạng thái nhân viên trước khi mở tài khoản");
            db.jdbc().update("insert into nhan_vien(tai_khoan_id,ma_nhan_vien,ho_ten,dien_thoai) values (?,'NV-'||?::text,?,?) on conflict(tai_khoan_id) do update set ho_ten=excluded.ho_ten,dien_thoai=excluded.dien_thoai",id,id,r.fullName(),r.phone());
        }
        if(roleChanged) {
            db.jdbc().update("delete from tai_khoan_vai_tro where tai_khoan_id=?",id);
            db.jdbc().update("insert into tai_khoan_vai_tro(tai_khoan_id,vai_tro_id) values (?,?)",id,role);
        }
        String state=r.active()?"ACTIVE":"LOCKED";
        boolean statusChanged=!state.equals(account.get("trang_thai"));
        db.jdbc().update("update tai_khoan set trang_thai=?,so_lan_dang_nhap_sai=case when ? then 0 else so_lan_dang_nhap_sai end where id=?",state,statusChanged,id);
        boolean passwordChanged=!created && r.password()!=null && !r.password().isBlank();
        if(passwordChanged) { Passwords.validate(r.password()); db.jdbc().update("update tai_khoan set mat_khau_hash=? where id=?",passwords.encode(r.password()),id); }
        if(roleChanged || statusChanged || passwordChanged) db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=?",id);
        db.audit(access.account(),created?"ACCOUNT_CREATE":"ACCOUNT_EDIT","tai_khoan",id);
        return db.one("select a.id,a.email,a.trang_thai,coalesce(n.ho_ten,k.ho_ten) as ho_ten,coalesce(n.dien_thoai,k.dien_thoai) as dien_thoai,n.id as nhan_vien_id,k.id as khach_hang_id,array(select r.ma_vai_tro from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=a.id) as roles from tai_khoan a left join nhan_vien n on n.tai_khoan_id=a.id left join khach_hang k on k.tai_khoan_id=a.id where a.id=?",id);
    }
}

package vn.drinkstore.administration;

import java.time.LocalDate;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class AdminController {
    private final Db db; private final AdminService service; private final Access access;
    public AdminController(Db db,AdminService service,Access access) { this.db=db; this.service=service; this.access=access; }
    public record NewStaff(@NotBlank @Email @Size(max=255) String email,@NotBlank @Size(min=8,max=72) String password,@NotBlank @Size(max=160) String fullName,@Pattern(regexp=vn.drinkstore.common.PhoneNumbers.OPTIONAL_PATTERN,message=vn.drinkstore.common.PhoneNumbers.MESSAGE) String phone,@Size(max=120) String position) {}
    public record AccountEditor(@NotBlank @Email @Size(max=255) String email,@NotBlank @Size(max=150) String fullName,@Pattern(regexp=vn.drinkstore.common.PhoneNumbers.OPTIONAL_PATTERN,message=vn.drinkstore.common.PhoneNumbers.MESSAGE) String phone,@NotNull @Pattern(regexp="KHACH_HANG|NHAN_VIEN|QUAN_TRI_VIEN") String role,boolean active,@Size(max=72) String password) {}
    @PostMapping("/management/account-editor") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')")
    public Object editAccount(@Valid @RequestBody AccountEditor r) { return service.accountEditor(null,r); }
    @PutMapping("/management/account-editor/{id}") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')")
    public Object editAccount(@PathVariable long id,@Valid @RequestBody AccountEditor r) { return service.accountEditor(id,r); }
    public record StaffProfile(@NotBlank @Size(max=160) String fullName,@Past LocalDate birthDate,@Size(max=20) String gender,@Pattern(regexp=vn.drinkstore.common.PhoneNumbers.OPTIONAL_PATTERN,message=vn.drinkstore.common.PhoneNumbers.MESSAGE) String phone,@Size(max=1000) String address) {}
    public record Employment(@NotNull @Pattern(regexp="ACTIVE|ON_LEAVE|RESIGNED") String status,@Size(max=120) String position) {}
    public record AccountStatus(@NotNull @Pattern(regexp="ACTIVE|LOCKED|DISABLED") String status) {}
    public record Password(@NotBlank @Size(min=8,max=72) String password) {}
    public record Role(@NotNull @NotBlank @Size(max=100) String name,@Size(max=2000) String description) {}
    public record Permissions(@NotNull @Size(max=200) List<@NotNull @Positive Long> permissionIds) {}
    @GetMapping("/staff/profile") public Object mine() { return db.one("select * from nhan_vien where id=?",access.employee()); }
    @PutMapping("/staff/profile") public Object mine(@Valid @RequestBody StaffProfile r) { return service.updateStaff(access.employee(),r); }
    @GetMapping("/management/employees") @PreAuthorize("@access.admin() and @access.has('STAFF_MANAGE')")
    public Object employees(@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select n.*,a.email from nhan_vien n join tai_khoan a on a.id=n.tai_khoan_id where n.ho_ten ilike ? order by n.id desc","select count(*) from nhan_vien where ho_ten ilike ?",List.of("%"+q+"%"),page,size);
    }
    @PostMapping("/management/employees") @PreAuthorize("@access.admin() and @access.has('STAFF_MANAGE')") public Object create(@Valid @RequestBody NewStaff r) { return service.createStaff(r); }
    @PutMapping("/management/employees/{id}") @PreAuthorize("@access.admin() and @access.has('STAFF_MANAGE')") public Object update(@PathVariable long id,@Valid @RequestBody StaffProfile r) { return service.updateStaff(id,r); }
    @PatchMapping("/management/employees/{id}/employment") @PreAuthorize("@access.admin() and @access.has('STAFF_MANAGE')") public Object employment(@PathVariable long id,@Valid @RequestBody Employment r) { return service.employment(id,r); }
    @GetMapping("/management/accounts") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object accounts(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select a.id,a.email,a.trang_thai,a.email_da_xac_thuc,a.ngay_tao,coalesce(n.ho_ten,k.ho_ten,a.email) as ho_ten,coalesce(n.dien_thoai,k.dien_thoai) as dien_thoai,n.id as nhan_vien_id,k.id as khach_hang_id,coalesce(n.dia_chi,(select concat_ws(', ',nullif(d.dia_chi,''),nullif(d.phuong_xa,''),nullif(d.quan_huyen,''),nullif(d.tinh_thanh,'')) from dia_chi_giao_hang d where d.khach_hang_id=k.id order by d.mac_dinh desc,d.id limit 1)) as dia_chi,array(select r.ma_vai_tro from tai_khoan_vai_tro ar join vai_tro r on r.id=ar.vai_tro_id where ar.tai_khoan_id=a.id order by r.id) as roles from tai_khoan a left join nhan_vien n on n.tai_khoan_id=a.id left join khach_hang k on k.tai_khoan_id=a.id order by a.id desc","select count(*) from tai_khoan",List.of(),page,size);
    }
    @PatchMapping("/management/accounts/{id}/status") @PreAuthorize("@access.admin()") public Object status(@PathVariable long id,@Valid @RequestBody AccountStatus r) { return service.accountStatus(id,r.status()); }
    @PutMapping("/management/accounts/{id}/password") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object password(@PathVariable long id,@Valid @RequestBody Password r) { service.reset(id,r.password()); return Map.of("message","Đã đặt lại mật khẩu"); }
    @GetMapping("/management/roles") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object roles() {
        return Map.of("roles",db.rows("select * from vai_tro order by id"),"grants",db.rows("select * from vai_tro_quyen order by vai_tro_id,quyen_id"),"permissions",db.jdbc().queryForList("select * from quyen order by id"));
    }
    @PostMapping("/management/roles") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object role(@Valid @RequestBody Role r) { return service.role(null,r); }
    @PutMapping("/management/roles/{id}") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object role(@PathVariable long id,@Valid @RequestBody Role r) { return service.role(id,r); }
    @DeleteMapping("/management/roles/{id}") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT) public void deleteRole(@PathVariable long id) { service.deleteRole(id); }
    @PutMapping("/management/roles/{id}/permissions") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object permissions(@PathVariable long id,@Valid @RequestBody Permissions r) { service.permissions(id,r.permissionIds()); return Map.of("id",id); }
    @PutMapping("/management/accounts/{account}/roles/{role}") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") public Object assign(@PathVariable long account,@PathVariable long role) { service.assign(account,role,true); return Map.of("message","Đã gán vai trò"); }
    @DeleteMapping("/management/accounts/{account}/roles/{role}") @PreAuthorize("@access.admin() and @access.has('ROLE_MANAGE')") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT) public void revoke(@PathVariable long account,@PathVariable long role) { service.assign(account,role,false); }
    @GetMapping("/management/audit") @PreAuthorize("@access.admin()") public Object audit(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return db.page("select * from nhat_ky_hoat_dong order by id desc","select count(*) from nhat_ky_hoat_dong",List.of(),page,size); }
}

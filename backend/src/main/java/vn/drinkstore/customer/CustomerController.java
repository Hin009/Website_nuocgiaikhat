package vn.drinkstore.customer;

import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class CustomerController {
    private final Db db; private final Access access; private final CustomerService service;
    public CustomerController(Db db,Access access,CustomerService service) { this.db=db; this.access=access; this.service=service; }
    public record Profile(@NotBlank @Size(max=160) String fullName,@Size(max=25) String phone,@Size(max=2000) String avatar) {}
    public record Address(@NotBlank @Size(max=160) String recipient,@NotBlank @Size(max=25) String phone,@NotBlank @Size(max=120) String province,@Size(max=120) String district,@Size(max=120) String ward,@NotBlank @Size(max=1000) String street,boolean isDefault) {}
    public record Review(@Positive long orderLineId,@Min(1) @Max(5) int rating,@Size(max=4000) String comment) {}
    public record Text(@NotBlank @Size(max=4000) String content) {}
    public record Visibility(boolean visible) {}
    @GetMapping("/me/profile") public Object profile() { return db.one("select * from khach_hang where id=?",access.customer()); }
    @PutMapping("/me/profile") public Object update(@Valid @RequestBody Profile r) { return service.profile(r); }
    @GetMapping("/me/addresses") public Object addresses() { return db.jdbc().queryForList("select * from dia_chi_giao_hang where khach_hang_id=? order by mac_dinh desc,id",access.customer()); }
    @PostMapping("/me/addresses") public Object address(@Valid @RequestBody Address r) { return service.address(null,r); }
    @PutMapping("/me/addresses/{id}") public Object address(@PathVariable long id,@Valid @RequestBody Address r) { return service.address(id,r); }
    @DeleteMapping("/me/addresses/{id}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void deleteAddress(@PathVariable long id) { db.jdbc().update("delete from dia_chi_giao_hang where id=? and khach_hang_id=?",id,access.customer()); }
    @GetMapping("/me/favorites") public Object favorites(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        long c=access.customer(); return db.page("select s.id,s.sku,s.ten,s.trang_thai from san_pham_yeu_thich f join san_pham s on s.id=f.san_pham_id where f.khach_hang_id=? and s.trang_thai='DANG_BAN' and s.hien_thi order by f.ngay_them desc,s.id","select count(*) from san_pham_yeu_thich f join san_pham s on s.id=f.san_pham_id where f.khach_hang_id=? and s.trang_thai='DANG_BAN' and s.hien_thi",List.of(c),page,size);
    }
    @PutMapping("/me/favorites/{id}") public Object favorite(@PathVariable long id) {
        db.one("select id from san_pham where id=? and trang_thai='DANG_BAN' and hien_thi",id);
        db.jdbc().update("insert into san_pham_yeu_thich(khach_hang_id,san_pham_id) values (?,?) on conflict do nothing",access.customer(),id); return Map.of("message","Đã thêm yêu thích");
    }
    @DeleteMapping("/me/favorites/{id}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void unfavorite(@PathVariable long id) { db.jdbc().update("delete from san_pham_yeu_thich where khach_hang_id=? and san_pham_id=?",access.customer(),id); }
    @PostMapping("/me/reviews") public Object review(@Valid @RequestBody Review r) { return service.review(r); }
    @GetMapping("/staff/customers") @PreAuthorize("@access.has('CUSTOMER_READ')")
    public Object customers(@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select k.*,a.email,a.trang_thai,(select concat_ws(', ',nullif(d.dia_chi,''),nullif(d.phuong_xa,''),nullif(d.quan_huyen,''),nullif(d.tinh_thanh,'')) from dia_chi_giao_hang d where d.khach_hang_id=k.id order by d.mac_dinh desc,d.id limit 1) as dia_chi from khach_hang k join tai_khoan a on a.id=k.tai_khoan_id where k.ho_ten ilike ? order by k.id desc","select count(*) from khach_hang where ho_ten ilike ?",List.of("%"+q+"%"),page,size);
    }
    @GetMapping("/staff/customers/{id}/orders") @PreAuthorize("@access.has('CUSTOMER_READ')")
    public Object history(@PathVariable long id,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return db.page("select * from don_hang where khach_hang_id=? order by id desc","select count(*) from don_hang where khach_hang_id=?",List.of(id),page,size); }
    @PatchMapping("/staff/reviews/{id}") @PreAuthorize("@access.has('CUSTOMER_READ')") public Object moderate(@PathVariable long id,@RequestBody Visibility r) {
        db.one("select id from danh_gia_san_pham where id=?",id); db.jdbc().update("update danh_gia_san_pham set trang_thai=? where id=?",r.visible()?"APPROVED":"HIDDEN",id); db.audit(access.account(),"REVIEW_MODERATE","danh_gia_san_pham",id); return Map.of("id",id);
    }
}

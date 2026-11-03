package vn.drinkstore.customer;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@Service
public class CustomerService {
    private final Db db; private final Access access;
    public CustomerService(Db db,Access access) { this.db=db; this.access=access; }
    @Transactional public Object profile(CustomerController.Profile r) {
        long id=access.customer();
        db.jdbc().update("update khach_hang set ho_ten=?,dien_thoai=?,anh_dai_dien=? where id=?",r.fullName(),r.phone(),r.avatar(),id);
        return db.one("select * from khach_hang where id=?",id);
    }
    @Transactional public Object address(Long id,CustomerController.Address r) {
        long customer=access.customer();
        // Serializes changes to the partial unique default-address index.
        db.one("select id from khach_hang where id=? for update",customer);
        if(id!=null) db.one("select id from dia_chi_giao_hang where id=? and khach_hang_id=?",id,customer);
        if(r.isDefault()) db.jdbc().update("update dia_chi_giao_hang set mac_dinh=false where khach_hang_id=?",customer);
        if(id==null) id=db.id("insert into dia_chi_giao_hang(khach_hang_id,ten_nguoi_nhan,so_dien_thoai,tinh_thanh,quan_huyen,phuong_xa,dia_chi,mac_dinh) values (?,?,?,?,?,?,?,?) returning id",customer,r.recipient(),r.phone(),r.province(),r.district(),r.ward(),r.street(),r.isDefault());
        else db.jdbc().update("update dia_chi_giao_hang set ten_nguoi_nhan=?,so_dien_thoai=?,tinh_thanh=?,quan_huyen=?,phuong_xa=?,dia_chi=?,mac_dinh=? where id=?",r.recipient(),r.phone(),r.province(),r.district(),r.ward(),r.street(),r.isDefault(),id);
        return db.one("select * from dia_chi_giao_hang where id=?",id);
    }
    @Transactional public Object review(CustomerController.Review r) {
        long customer=access.customer();
        var line=db.one("select d.id from chi_tiet_don_hang d join don_hang o on o.id=d.don_hang_id where d.id=? and o.khach_hang_id=? and o.trang_thai='DA_GIAO'",r.orderLineId(),customer);
        long id=db.id("insert into danh_gia_san_pham(khach_hang_id,chi_tiet_don_hang_id,so_sao,noi_dung) values (?,?,?,?) returning id",customer,r.orderLineId(),r.rating(),r.comment()); return Map.of("id",id);
    }
}

package vn.drinkstore.sales;

import java.util.*;
import java.math.BigDecimal;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@Service
public class OrderService {
    private final Db db; private final CartService carts; private final PromotionService promotions; private final Access access; private final BigDecimal shipping;
    public OrderService(Db db,CartService carts,PromotionService promotions,Access access,@Value("${app.shipping-fee}") BigDecimal shipping) {
        this.db=db; this.carts=carts; this.promotions=promotions; this.access=access; this.shipping=shipping;
    }
    @Transactional public Object checkout(long customer,long address,String note,String method,String coupon) {
        return checkout(customer,address,note,method,coupon,null);
    }
    @Transactional public Map<String,Object> quote(long customer,List<Long> packages,String coupon) {
        var lines=carts.selectedLines(customer,packages);
        if(lines.isEmpty()) throw ApiException.bad("Giỏ hàng trống");
        CartService.validateStock(lines);
        var discount=promotions.calculate(coupon,customer,lines,false);
        BigDecimal subtotal=lines.stream().map(l->Db.money(l,"gia_ban").multiply(BigDecimal.valueOf(Db.n(l,"so_luong")))).reduce(BigDecimal.ZERO,BigDecimal::add);
        return Map.of("subtotal",subtotal,"discount",discount.amount(),"shippingFee",shipping,"total",subtotal.subtract(discount.amount()).add(shipping));
    }
    @Transactional public Object checkout(long customer,long address,String note,String method,String coupon,List<Long> packages) {
        if(!Set.of("COD","BANK_TRANSFER").contains(method)) throw ApiException.bad("Chỉ COD và chuyển khoản thủ công được cấu hình. Cổng thanh toán chưa tích hợp");
        long cart=carts.cart(customer);
        var lines=carts.selectedLines(customer,packages);
        if(lines.isEmpty()) throw ApiException.bad("Giỏ hàng trống");
        CartService.validateStock(lines);
        // Require explicit acceptance of current prices before checkout.
        if(lines.stream().anyMatch(l->Boolean.TRUE.equals(l.get("price_changed")))) throw ApiException.bad("Giá đã thay đổi. Cập nhật lại giỏ hàng trước khi đặt");
        var addr=db.one("select * from dia_chi_giao_hang where id=? and khach_hang_id=?",address,customer);
        PhoneNumbers.validate(addr.get("so_dien_thoai"),true);
        String snapshot=addr.get("ten_nguoi_nhan")+" | "+addr.get("so_dien_thoai")+" | "+addr.get("dia_chi")+", "+Objects.toString(addr.get("phuong_xa"),"")+", "+Objects.toString(addr.get("quan_huyen"),"")+", "+addr.get("tinh_thanh");
        var discount=promotions.calculate(coupon,customer,lines,true);
        BigDecimal subtotal=lines.stream().map(l->Db.money(l,"gia_ban").multiply(BigDecimal.valueOf(Db.n(l,"so_luong")))).reduce(BigDecimal.ZERO,BigDecimal::add);
        BigDecimal total=subtotal.subtract(discount.amount()).add(shipping);
        long id=db.id("insert into don_hang(kenh_ban,trang_thai,ma_don,khach_hang_id,dia_chi_nhan,ghi_chu,phi_van_chuyen,giam_gia,tong_tien) values ('ONLINE','CHO_XAC_NHAN',?,?,?,?,?,?,?) returning id","DH-"+UUID.randomUUID(),customer,snapshot,note,shipping,discount.amount(),total);
        for(var l:lines) db.jdbc().update("insert into chi_tiet_don_hang(don_hang_id,quy_cach_id,ten_san_pham,ten_quy_cach,he_so_quy_doi,so_luong,don_gia,gia_von_don_vi) values (?,?,?,?,?,?,?,?)",id,l.get("quy_cach_id"),l.get("ten"),l.get("ten_quy_cach"),l.get("he_so_quy_doi"),l.get("so_luong"),l.get("gia_ban"),l.get("gia_von"));
        if(discount.promotionId()!=null) db.jdbc().update("update don_hang set khuyen_mai_id=? where id=?",discount.promotionId(),id);
        db.jdbc().update("update don_hang set ten_nguoi_nhan=?,sdt_nguoi_nhan=? where id=?",addr.get("ten_nguoi_nhan"),addr.get("so_dien_thoai"),id);
        if(total.signum()>0) db.jdbc().update("insert into thanh_toan(don_hang_id,phuong_thuc,so_tien) values (?,?,?)",id,method,total);
        for(var l:lines) db.jdbc().update("delete from chi_tiet_gio_hang where gio_hang_id=? and id=?",cart,l.get("id"));
        db.audit(access.account(),"CHECKOUT","don_hang",id);
        return detail(id,customer);
    }
    public Object detail(long id,Long customer) {
        var order=customer==null?db.one("select * from don_hang where id=?",id):db.one("select * from don_hang where id=? and khach_hang_id=?",id,customer);
        if(order.get("khach_hang_id")!=null) order.put("tai_khoan_khach_id",db.number("select tai_khoan_id from khach_hang where id=?",order.get("khach_hang_id")));
        var items=db.jdbc().queryForList("select c.*,q.san_pham_id from chi_tiet_don_hang c join quy_cach_san_pham q on q.id=c.quy_cach_id where c.don_hang_id=? order by c.id",id);
        if(customer!=null) items.forEach(l->l.remove("gia_von_don_vi"));
        order.put("items",items);
        order.put("history",db.jdbc().queryForList("select * from lich_su_trang_thai_don where don_hang_id=? order by id",id));
        order.put("payments",db.jdbc().queryForList("select id,phuong_thuc,so_tien,trang_thai,thoi_gian from thanh_toan where don_hang_id=?",id)); return order;
    }
    @Transactional public Object transition(long id,String status,Long customer) { return transition(id,status,customer,null); }
    @Transactional public Object transition(long id,String status,Long customer,String note) {
        var order=db.one("select * from don_hang where id=? for update",id);
        if(customer!=null) {
            if(Db.n(order,"khach_hang_id")!=customer) throw ApiException.missing();
            if(!"DA_HUY".equals(status) || !"CHO_XAC_NHAN".equals(order.get("trang_thai"))) throw ApiException.bad("Khách hàng chỉ được hủy đơn chờ xác nhận");
        }
        if(status.equals(order.get("trang_thai"))) return detail(id,customer);
        if(!"ONLINE".equals(order.get("kenh_ban"))) throw ApiException.bad("This endpoint processes online orders only");
        String old=order.get("trang_thai").toString();
        boolean valid=(old.equals("CHO_XAC_NHAN") && Set.of("DANG_CHUAN_BI","DA_HUY","TU_CHOI").contains(status))
            || (old.equals("DANG_CHUAN_BI") && Set.of("DANG_GIAO","DA_HUY").contains(status))
            || (old.equals("DANG_GIAO") && Set.of("DA_GIAO","DA_HUY").contains(status));
        if(!valid) throw ApiException.bad("Invalid online order transition");
        if("DANG_CHUAN_BI".equals(status)) {
            confirmCoupon(order);
            // Snapshot weighted cost at stock issue, while the lines are still editable.
            for(var p:db.rows("select distinct q.san_pham_id from chi_tiet_don_hang c join quy_cach_san_pham q on q.id=c.quy_cach_id where c.don_hang_id=? order by q.san_pham_id",id))
                db.one("select san_pham_id from so_luong_san_pham where san_pham_id=? for update",p.get("san_pham_id"));
            db.jdbc().update("update chi_tiet_don_hang c set gia_von_don_vi=q.gia_von from quy_cach_san_pham q where q.id=c.quy_cach_id and c.don_hang_id=?",id);
        }
        // Database trigger is the ONLY writer of stock and cancellation rollback.
        db.jdbc().update("update don_hang set trang_thai=?,nhan_vien_xu_ly_id=coalesce(nhan_vien_xu_ly_id,?) where id=?",status,customer==null?access.employee():null,id);
        db.jdbc().update("update lich_su_trang_thai_don set tai_khoan_thuc_hien_id=?,ghi_chu=? where id=(select max(id) from lich_su_trang_thai_don where don_hang_id=?)",access.account(),note,id);
        if("DANG_CHUAN_BI".equals(status)) invoice(id);
        db.audit(access.account(),"ORDER_"+status,"don_hang",id);
        return detail(id,customer);
    }
    private void confirmCoupon(Map<String,Object> order) {
        long id=Db.n(order,"id");
        var selected=db.jdbc().queryForList("select p.ma_code from don_hang d join khuyen_mai p on p.id=d.khuyen_mai_id where d.id=?",id);
        if(selected.isEmpty()) return;
        var lines=db.jdbc().queryForList("select d.quy_cach_id,d.so_luong,d.don_gia as gia_ban,s.id as san_pham_id,s.loai_san_pham_id,s.thuong_hieu_id from chi_tiet_don_hang d join quy_cach_san_pham q on q.id=d.quy_cach_id join san_pham s on s.id=q.san_pham_id where d.don_hang_id=?",id);
        var discount=promotions.calculate(selected.getFirst().get("ma_code").toString(),Db.n(order,"khach_hang_id"),lines,true);
        if(discount.amount().compareTo(Db.money(order,"giam_gia"))!=0) throw ApiException.bad("Khuyến mãi thay đổi; cần hủy và đặt lại đơn");
        db.jdbc().update("insert into su_dung_khuyen_mai(khuyen_mai_id,don_hang_id,khach_hang_id,so_tien_giam) values (?,?,?,?)",discount.promotionId(),id,order.get("khach_hang_id"),discount.amount());
    }
    private void invoice(long id) {
        db.jdbc().queryForObject("select lap_hoa_don_tu_don(?,?)",Long.class,id,access.employee());
        db.jdbc().update("update hoa_don set trang_thai='PAID' where don_hang_id=? and exists(select 1 from thanh_toan where don_hang_id=? and trang_thai='SUCCESS')",id,id);
    }
}

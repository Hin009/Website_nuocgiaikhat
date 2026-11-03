package vn.drinkstore.billing;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@Service
public class BillingService {
    private final Db db; private final Access access;
    public BillingService(Db db,Access access) { this.db=db; this.access=access; }
    public Object invoice(long order,Long customer) {
        var o=customer==null?db.one("select * from don_hang where id=?",order):db.one("select * from don_hang where id=? and khach_hang_id=?",order,customer);
        var invoice=db.one("select * from hoa_don where don_hang_id=?",order);
        invoice.put("discount",o.get("giam_gia")); invoice.put("shippingFee",o.get("phi_van_chuyen"));
        invoice.put("items",db.jdbc().queryForList("select * from chi_tiet_hoa_don where hoa_don_id=? order by id",invoice.get("id")));
        invoice.put("history",db.jdbc().queryForList("select * from lich_su_hoa_don where hoa_don_id=? order by id",invoice.get("id"))); return invoice;
    }
    @Transactional public Object received(long payment,String reference) {
        // Lock order before payment; cancellation and collection cannot race.
        var initial=db.one("select don_hang_id from thanh_toan where id=?",payment);
        var order=db.one("select * from don_hang where id=? for update",initial.get("don_hang_id"));
        var p=db.one("select * from thanh_toan where id=? for update",payment);
        if("SUCCESS".equals(p.get("trang_thai"))) return p;
        if(!"PENDING".equals(p.get("trang_thai"))) throw ApiException.bad("Giao dịch không còn chờ thanh toán");
        if(Set.of("DA_HUY","TU_CHOI").contains(order.get("trang_thai"))) throw ApiException.bad("Đơn hàng đã hủy");
        if("COD".equals(p.get("phuong_thuc")) && !"DA_GIAO".equals(order.get("trang_thai"))) throw ApiException.bad("Chỉ thu COD khi đơn đã giao");
        if(!Set.of("COD","BANK_TRANSFER").contains(p.get("phuong_thuc"))) throw ApiException.bad("Giao dịch cổng thanh toán cần callback được xác thực");
        if("BANK_TRANSFER".equals(p.get("phuong_thuc")) && (reference==null || reference.isBlank())) throw ApiException.bad("Cần mã đối soát chuyển khoản");
        db.jdbc().update("update thanh_toan set trang_thai='SUCCESS',ma_giao_dich=? where id=?",reference,payment);
        db.audit(access.account(),"PAYMENT_RECEIVED","thanh_toan",payment); return db.one("select * from thanh_toan where id=?",payment);
    }
    @Transactional public Object refund(long payment,String reason) {
        var initial=db.one("select don_hang_id from thanh_toan where id=?",payment);
        var order=db.one("select * from don_hang where id=? for update",initial.get("don_hang_id"));
        var p=db.one("select * from thanh_toan where id=? for update",payment);
        if(!Set.of("DA_HUY","TU_CHOI").contains(order.get("trang_thai")) || !"SUCCESS".equals(p.get("trang_thai"))) throw ApiException.bad("Chỉ hoàn tiền đơn đã hủy và đã thanh toán");
        if(!Set.of("COD","BANK_TRANSFER").contains(p.get("phuong_thuc"))) throw ApiException.bad("Cần tích hợp hoàn tiền của cổng thanh toán");
        long id=db.id("insert into hoan_tien(thanh_toan_id,so_tien,ly_do,nguoi_xu_ly_id,trang_thai,ngay_hoan) values (?,?,?,?,'COMPLETED',now()) returning id",payment,p.get("so_tien"),reason,access.employee());
        db.jdbc().update("update thanh_toan set trang_thai='REFUNDED' where id=?",payment);
        db.audit(access.account(),"MANUAL_REFUND_RECORDED","hoan_tien",id); return db.one("select * from hoan_tien where id=?",id);
    }
}

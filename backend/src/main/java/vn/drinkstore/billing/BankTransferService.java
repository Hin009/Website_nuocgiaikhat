package vn.drinkstore.billing;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@Service
@org.springframework.context.annotation.DependsOn("bankTransferSchema")
public class BankTransferService {
    private final Db db; private final Access access; private final BankTransferConfig config;
    public BankTransferService(Db db,Access access,BankTransferConfig config) { this.db=db; this.access=access; this.config=config; }
    public Object details(long orderId,long customer) {
        var order=db.one("select * from don_hang where id=? and khach_hang_id=?",orderId,customer);
        var payment=db.one("select * from thanh_toan where don_hang_id=? and phuong_thuc='BANK_TRANSFER'",orderId);
        var result=new LinkedHashMap<String,Object>();
        result.put("orderId",orderId); result.put("orderCode",order.get("ma_don"));
        result.put("amount",payment.get("so_tien")); result.put("reference","WB"+orderId);
        result.put("bank",config.details()); result.put("status",payment.get("trang_thai"));
        result.put("orderStatus",order.get("trang_thai"));
        result.put("customerConfirmedAt",payment.get("customer_confirmed_at"));
        return result;
    }
    @Transactional public Object confirm(long orderId,long customer) {
        // Same lock order as cancellation, staff collection and order confirmation.
        var order=db.one("select * from don_hang where id=? and khach_hang_id=? for update",orderId,customer);
        var payment=db.one("select * from thanh_toan where don_hang_id=? and phuong_thuc='BANK_TRANSFER' for update",orderId);
        if(Set.of("DA_HUY","TU_CHOI").contains(order.get("trang_thai"))) throw ApiException.bad("Đơn hàng đã hủy");
        if(payment.get("customer_confirmed_at")!=null) return details(orderId,customer);
        if(!"CHO_XAC_NHAN".equals(order.get("trang_thai")) || !"PENDING".equals(payment.get("trang_thai")))
            throw ApiException.bad("Đơn hàng không còn chờ xác nhận thanh toán");
        db.jdbc().update("update thanh_toan set customer_confirmed_at=now() where id=?",payment.get("id"));
        db.jdbc().update("insert into payment_notification(payment_id,order_id,message) values (?,?,?) on conflict(payment_id) do nothing",
            payment.get("id"),orderId,"Khách hàng đã xác nhận chuyển khoản đơn "+order.get("ma_don")+". Vui lòng kiểm tra tiền trước khi xác nhận đơn.");
        db.audit(access.account(),"CUSTOMER_TRANSFER_CONFIRMED","thanh_toan",Db.n(payment,"id"));
        return details(orderId,customer);
    }
}

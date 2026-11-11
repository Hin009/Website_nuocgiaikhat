package vn.drinkstore.billing;

import java.util.*;
import java.math.BigDecimal;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import com.fasterxml.jackson.databind.ObjectMapper;
import vn.drinkstore.common.*;

@Service
public class MomoService {
    private final Db db;
    private final MomoProperties config;
    private final MomoClient client;
    private final TransactionTemplate tx;
    private final ObjectMapper json;
    public MomoService(Db db,MomoProperties config,MomoClient client,org.springframework.transaction.PlatformTransactionManager manager,ObjectMapper json) {
        this.db=db; this.config=config; this.client=client; this.tx=new TransactionTemplate(manager); this.json=json;
    }
    public Object start(long orderId,long customer) {
        config.requireReady();
        // Persist identifiers before network I/O: IPN can arrive before create returns.
        var attempt=tx.execute(s->{
            var order=db.one("select * from don_hang where id=? and khach_hang_id=? for update",orderId,customer);
            if(Set.of("DA_HUY","TU_CHOI").contains(order.get("trang_thai"))) throw ApiException.bad("Đơn đã hủy, không thể thanh toán");
            var payment=db.one("select * from thanh_toan where don_hang_id=? and phuong_thuc='MOMO' for update",orderId);
            if("SUCCESS".equals(payment.get("trang_thai"))) return (Map<String,Object>)null;
            var active=db.rows("select * from momo_payment_attempt where payment_id=? and status in ('CREATED','PENDING')",payment.get("id"));
            if(!active.isEmpty()) return active.getFirst();
            long amount=Db.money(payment,"so_tien").longValueExact();
            if(amount<1000 || amount>50000000) throw ApiException.bad("MoMo hỗ trợ số tiền từ 1.000 đến 50.000.000đ");
            long id=db.id("insert into momo_payment_attempt(payment_id,momo_order_id,request_id,amount,order_info,redirect_url,ipn_url) values (?,?,?,?,?,?,?) returning id",
                payment.get("id"),"WB-"+UUID.randomUUID(),UUID.randomUUID().toString(),amount,"WATERBUS "+order.get("ma_don"),config.redirectUrl,config.ipnUrl);
            db.jdbc().update("update thanh_toan set trang_thai='PENDING' where id=?",payment.get("id"));
            return db.one("select * from momo_payment_attempt where id=?",id);
        });
        if(attempt==null || attempt.get("pay_url")!=null || attempt.get("qr_code_data")!=null) return status(orderId,customer);
        Map<String,Object> response;
        try { response=client.create(attempt); }
        catch(IllegalStateException e) {
            // Ambiguous outcome: never create a new attempt or assert failure.
            tx.executeWithoutResult(s->db.jdbc().update("update momo_payment_attempt set message=? where id=? and status='CREATED'", "Chưa nhận được phản hồi MoMo; thử tải lại cùng giao dịch.",attempt.get("id")));
            return status(orderId,customer);
        }
        tx.executeWithoutResult(s->{
            db.one("select id from don_hang where id=? for update",orderId);
            db.one("select id from thanh_toan where id=? for update",attempt.get("payment_id"));
            var current=db.one("select * from momo_payment_attempt where id=? for update",attempt.get("id"));
            if(!"CREATED".equals(current.get("status"))) return;
            int code=new BigDecimal(response.get("resultCode").toString()).intValueExact();
            // Duplicate request codes are ambiguous; retain identifiers for a later IPN.
            boolean rejected=code!=0 && code!=40 && code!=41 && code!=1000 && code!=7000 && code!=7002 && code!=9000;
            String payUrl=Objects.toString(response.get("payUrl"),"");
            if(!payUrl.isBlank() && !payUrl.startsWith("https://test-payment.momo.vn/")) throw ApiException.bad("MoMo trả về URL ngoài Sandbox");
            db.jdbc().update("update momo_payment_attempt set status=?,pay_url=nullif(?,''),qr_code_data=?,result_code=?,message=? where id=?",
                rejected?"FAILED":"PENDING",payUrl,response.get("qrCodeUrl"),code,response.get("message"),attempt.get("id"));
            if(rejected) db.jdbc().update("update thanh_toan set trang_thai='FAILED' where id=?",attempt.get("payment_id"));
        });
        return status(orderId,customer);
    }
    public Map<String,Object> status(long orderId,Long customer) {
        var order=customer==null?db.one("select id,ma_don,trang_thai from don_hang where id=?",orderId)
            :db.one("select id,ma_don,trang_thai from don_hang where id=? and khach_hang_id=?",orderId,customer);
        var payment=db.one("select id,phuong_thuc,so_tien,trang_thai,ma_giao_dich from thanh_toan where don_hang_id=? order by id desc limit 1",orderId);
        payment.put("orderId",orderId); payment.put("orderCode",order.get("ma_don")); payment.put("orderStatus",order.get("trang_thai"));
        var attempts=db.rows("select id,momo_order_id,request_id,environment,status,pay_url,qr_code_data,result_code,message,trans_id,paid_at,created_at from momo_payment_attempt where payment_id=? order by (status='SUCCESS') desc,id desc limit 1",payment.get("id"));
        payment.put("attempt",attempts.isEmpty()?null:attempts.getFirst());
        return payment;
    }
    @Transactional public void ipn(Map<String,Object> payload) {
        client.verify(payload);
        var initial=db.one("select a.id,p.don_hang_id from momo_payment_attempt a join thanh_toan p on p.id=a.payment_id where a.momo_order_id=?",payload.get("orderId"));
        var order=db.one("select * from don_hang where id=? for update",initial.get("don_hang_id"));
        var payment=db.one("select * from thanh_toan where don_hang_id=? and phuong_thuc='MOMO' for update",order.get("id"));
        var attempt=db.one("select * from momo_payment_attempt where id=? for update",initial.get("id"));
        if(!attempt.get("request_id").equals(payload.get("requestId")) || !attempt.get("order_info").equals(payload.get("orderInfo"))
            || !"".equals(payload.get("extraData")) || !"momo_wallet".equals(payload.get("orderType"))
            || new BigDecimal(payload.get("amount").toString()).compareTo(Db.money(payment,"so_tien"))!=0
            || new BigDecimal(payload.get("amount").toString()).compareTo(Db.money(attempt,"amount"))!=0) throw ApiException.bad("IPN không khớp giao dịch");
        int code=new BigDecimal(payload.get("resultCode").toString()).intValueExact();
        String transId=payload.get("transId").toString();
        if(code==0 && new BigDecimal(transId).signum()<=0) throw ApiException.bad("Mã giao dịch không hợp lệ");
        if("SUCCESS".equals(attempt.get("status")) && code==0 && !transId.equals(attempt.get("trans_id"))) throw ApiException.bad("Mã giao dịch thay đổi");
        try { db.jdbc().update("insert into momo_ipn_history(attempt_id,payload) values (?,?::jsonb)",attempt.get("id"),json.writeValueAsString(payload)); }
        catch(com.fasterxml.jackson.core.JsonProcessingException e) { throw ApiException.bad("IPN không hợp lệ"); }
        if("SUCCESS".equals(attempt.get("status"))) return;
        if(code==0) {
            // Payment truth is independent of fulfillment. Late payment of a cancelled order is recorded for review/refund.
            db.jdbc().update("update momo_payment_attempt set status='SUCCESS',trans_id=?,result_code=0,message=?,paid_at=now() where id=?",transId,payload.get("message"),attempt.get("id"));
            if("SUCCESS".equals(payment.get("trang_thai"))) {
                db.jdbc().update("update payment_notification set message=message || ? where payment_id=?", " · Phát hiện thêm khoản thanh toán MoMo "+transId+": cần đối soát/hoàn tiền.",payment.get("id"));
                return;
            }
            db.jdbc().update("update thanh_toan set trang_thai='SUCCESS',ma_giao_dich=? where id=?",transId,payment.get("id"));
            String warning=Set.of("DA_HUY","TU_CHOI").contains(order.get("trang_thai"))?" (đơn đã hủy: cần đối soát/hoàn tiền qua MoMo)":"";
            db.jdbc().update("insert into payment_notification(payment_id,order_id,message) values (?,?,?) on conflict(payment_id) do nothing",payment.get("id"),order.get("id"),"Đơn hàng "+order.get("ma_don")+" đã thanh toán qua MoMo"+warning);
        } else if(!Set.of(1000,7000,7002,9000).contains(code)) {
            db.jdbc().update("update momo_payment_attempt set status='FAILED',result_code=?,message=? where id=?",code,payload.get("message"),attempt.get("id"));
            // A stale failed attempt must not overwrite a newer attempt's state.
            db.jdbc().update("update thanh_toan set trang_thai='FAILED' where id=? and trang_thai<>'SUCCESS' and not exists(select 1 from momo_payment_attempt where payment_id=? and id>? )",payment.get("id"),payment.get("id"),attempt.get("id"));
        }
    }
}

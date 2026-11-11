package vn.drinkstore.billing;

import java.util.Map;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.http.HttpStatus;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class MomoController {
    private final MomoService service; private final Access access; private final Db db;
    public MomoController(MomoService service,Access access,Db db) { this.service=service; this.access=access; this.db=db; }
    @PostMapping("/payments/momo/ipn") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void ipn(@RequestBody Map<String,Object> payload) { service.ipn(payload); }
    @PostMapping("/payments/orders/{id}/momo")
    public Object start(@PathVariable long id) { return service.start(id,access.customer()); }
    @GetMapping("/payments/orders/{id}/status")
    public Object status(@PathVariable long id) { return service.status(id,access.customer()); }
    @GetMapping("/payments/momo/return")
    public Object returned(@RequestParam String orderId) {
        long customer=access.customer();
        var row=db.one("select d.id from don_hang d join thanh_toan p on p.don_hang_id=d.id join momo_payment_attempt a on a.payment_id=p.id where a.momo_order_id=? and d.khach_hang_id=?",orderId,customer);
        return service.status(Db.n(row,"id"),customer);
    }
    @GetMapping("/staff/payment-notifications") @PreAuthorize("@access.has('ORDER_UPDATE')")
    public Object notifications(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select * from payment_notification order by id desc","select count(*) from payment_notification",java.util.List.of(),page,size);
    }
}

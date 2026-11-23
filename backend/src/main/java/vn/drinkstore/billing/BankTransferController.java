package vn.drinkstore.billing;

import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class BankTransferController {
    private final BankTransferService service; private final Access access; private final Db db; private final PaymentEvents events;
    public BankTransferController(BankTransferService service,Access access,Db db,PaymentEvents events) {
        this.service=service; this.access=access; this.db=db; this.events=events;
    }
    @GetMapping("/orders/{id}/bank-transfer") public Object details(@PathVariable long id) { return service.details(id,access.customer()); }
    @PostMapping("/orders/{id}/bank-transfer/confirm") public Object confirm(@PathVariable long id) { return service.confirm(id,access.customer()); }
    @GetMapping("/payments/notifications") @PreAuthorize("@access.has('ORDER_UPDATE')")
    public Object notifications() { return db.rows("select id,order_id,message,created_at from payment_notification order by id desc limit 20"); }
    @GetMapping(value="/payments/events",produces=org.springframework.http.MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("@access.has('ORDER_UPDATE')")
    public SseEmitter events(@RequestParam(defaultValue="0") long after,jakarta.servlet.http.HttpServletResponse response) {
        response.setHeader("Cache-Control","no-cache, no-transform"); response.setHeader("X-Accel-Buffering","no");
        return events.subscribe(after);
    }
}

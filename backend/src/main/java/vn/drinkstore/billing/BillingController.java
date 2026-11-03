package vn.drinkstore.billing;

import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class BillingController {
    private final Db db; private final Access access; private final BillingService service;
    public BillingController(Db db,Access access,BillingService service) { this.db=db; this.access=access; this.service=service; }
    public record Receipt(@Size(max=200) String reference) {}
    public record Refund(@NotBlank @Size(max=2000) String reason) {}
    @GetMapping("/orders/{id}/invoice") public Object invoice(@PathVariable long id) { return service.invoice(id,access.customer()); }
    @GetMapping("/staff/orders/{id}/invoice") @PreAuthorize("@access.has('INVOICE_READ')") public Object staffInvoice(@PathVariable long id) { return service.invoice(id,null); }
    @GetMapping("/staff/invoices") @PreAuthorize("@access.has('INVOICE_READ')") public Object invoices(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return db.page("select * from hoa_don order by id desc","select count(*) from hoa_don",List.of(),page,size); }
    @GetMapping("/staff/payments") @PreAuthorize("@access.has('PAYMENT_READ')") public Object payments(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return db.page("select * from thanh_toan order by id desc","select count(*) from thanh_toan",List.of(),page,size); }
    @PostMapping("/staff/payments/{id}/received") @PreAuthorize("@access.has('PAYMENT_READ')") public Object received(@PathVariable long id,@Valid @RequestBody Receipt r) { return service.received(id,r.reference()); }
    @PostMapping("/management/payments/{id}/manual-refund") @PreAuthorize("@access.admin() and @access.has('REFUND_MANAGE')") public Object refund(@PathVariable long id,@Valid @RequestBody Refund r) { return service.refund(id,r.reason()); }
}

package vn.drinkstore.sales;

import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;

@RestController
@RequestMapping("/api/v1")
public class SalesController {
    private final Db db; private final Access access; private final CartService carts; private final OrderService orders;
    public SalesController(Db db,Access access,CartService carts,OrderService orders) { this.db=db; this.access=access; this.carts=carts; this.orders=orders; }
    public record CartItem(@Min(1) @Max(1000000) int quantity) {}
    public record Checkout(@Positive long addressId,@Size(max=2000) String note,@NotBlank String paymentMethod,@Size(max=70) String couponCode,@Size(max=100) List<@NotNull @Positive Long> packageIds,@NotNull UUID requestKey) {}
    public record Quote(@Size(max=100) List<@NotNull @Positive Long> packageIds,@Size(max=70) String couponCode) {}
    @PostMapping("/orders/quote") public Object quote(@Valid @RequestBody Quote r) { return orders.quote(access.customer(),r.packageIds(),r.couponCode()); }
    public record Status(@Pattern(regexp="DANG_CHUAN_BI|DANG_GIAO|DA_GIAO|DA_HUY|TU_CHOI") @NotNull String status,@Size(max=2000) String note) {}
    @GetMapping("/cart") public Object cart(@RequestParam(required=false) String couponCode) { return carts.view(access.customer(),couponCode); }
    @PutMapping("/cart/items/{packageId}") public Object put(@PathVariable long packageId,@Valid @RequestBody CartItem r) { return carts.put(access.customer(),packageId,r.quantity()); }
    @DeleteMapping("/cart/items/{packageId}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void remove(@PathVariable long packageId) { carts.remove(access.customer(),packageId); }
    @PostMapping("/orders") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Object checkout(@Valid @RequestBody Checkout r) { return orders.checkoutOnce(access.customer(),r.addressId(),r.note(),r.paymentMethod(),r.couponCode(),r.packageIds(),r.requestKey(),r.toString()); }
    @GetMapping("/orders") public Object mine(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        long customer=access.customer(); return db.page("select * from don_hang where khach_hang_id=? order by id desc","select count(*) from don_hang where khach_hang_id=?",List.of(customer),page,size);
    }
    @GetMapping("/orders/{id}") public Object order(@PathVariable long id) { return orders.detail(id,access.customer()); }
    public record Note(@Size(max=2000) String note) {}
    @PostMapping("/orders/{id}/cancel") public Object cancel(@PathVariable long id,@Valid @RequestBody(required=false) Note r) { return orders.transition(id,"DA_HUY",access.customer(),r==null?null:r.note()); }
    @PostMapping("/orders/{id}/reorder") public Object reorder(@PathVariable long id) { return carts.reorder(access.customer(),id); }
    @GetMapping("/staff/orders") @PreAuthorize("@access.has('ORDER_UPDATE')")
    public Object all(@RequestParam(required=false) String status,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        String where=status==null?"":" where trang_thai=?";
        return db.page("select * from don_hang"+where+" order by id desc","select count(*) from don_hang"+where,status==null?List.of():List.of(status),page,size);
    }
    @GetMapping("/staff/orders/{id}") @PreAuthorize("@access.has('ORDER_UPDATE')") public Object staffOrder(@PathVariable long id) { return orders.detail(id,null); }
    @PatchMapping("/staff/orders/{id}/status") @PreAuthorize("@access.has('ORDER_UPDATE')")
    public Object transition(@PathVariable long id,@Valid @RequestBody Status r) { return orders.transition(id,r.status(),null,r.note()); }
}

package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.Db;

@RestController
@RequestMapping("/api/v1")
public class PurchaseController {
    private final Db db; private final PurchaseService service;
    public PurchaseController(Db db,PurchaseService service) { this.db=db; this.service=service; }
    public record Line(@Positive Long packageId,@Min(1) @Max(1000000) int quantity,@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal unitCost,@Positive Long productId,@Pattern(regexp="LOC|THUNG") String packaging,@Min(2) @Max(1000000) Integer unitsPerPackage) {
        public Line(long packageId,int quantity,BigDecimal unitCost) { this(packageId,quantity,unitCost,null,null,null); }
    }
    public record Create(@Positive long supplierId,@FutureOrPresent(message="Ngày giao dự kiến phải từ hôm nay trở đi") LocalDate expectedDate,@NotEmpty @Size(max=100) List<@Valid Line> items) {}
    public record Decision(@NotNull @Pattern(regexp="DA_DUYET|TU_CHOI|DANG_GIAO|DA_HUY") String status,@Size(max=2000) String reason) {}
    public record ReceiptLine(@Positive long purchaseLineId,@Min(0) @Max(1000000) int quantity,@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal actualCost,@Min(0) @Max(1000000) int rejectedQuantity,@Size(max=2000) String rejectionReason,@NotNull @PastOrPresent LocalDate manufacturedOn,@NotNull LocalDate expiresOn) {
        public ReceiptLine(long purchaseLineId,int quantity,BigDecimal actualCost,int rejectedQuantity,String rejectionReason) { this(purchaseLineId,quantity,actualCost,rejectedQuantity,rejectionReason,null,null); }
        public ReceiptLine(long purchaseLineId,int quantity,BigDecimal actualCost) { this(purchaseLineId,quantity,actualCost,0,null); }
    }
    public record Receive(@NotEmpty @Size(max=100) List<@Valid ReceiptLine> items) {}
    public record ReceiptDates(@NotNull @PastOrPresent LocalDate manufacturedOn,@NotNull LocalDate expiresOn) {}
    @PatchMapping("/receipts/{id}/lines/{lineId}/dates") @PreAuthorize("@access.has('IMPORT_RECEIVE')")
    public Object receiptDates(@PathVariable long id,@PathVariable long lineId,@Valid @RequestBody ReceiptDates r) { return service.updateReceiptDates(id,lineId,r); }
    public record DebtPayment(@NotNull @DecimalMin(value="0",inclusive=false) BigDecimal amount,@NotBlank @Size(max=80) String method,@Size(max=150) String reference) {}
    @PostMapping("/purchases") @PreAuthorize("@access.has('IMPORT_CREATE')") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Object create(@Valid @RequestBody Create r) { return service.create(r); }
    @GetMapping("/purchases") @PreAuthorize("@access.has('IMPORT_READ')") public Object list(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select * from don_dat_hang_ncc order by id desc","select count(*) from don_dat_hang_ncc",List.of(),page,size);
    }
    @GetMapping("/purchases/{id}") @PreAuthorize("@access.has('IMPORT_READ')") public Object detail(@PathVariable long id) { return service.detail(id); }
    @PatchMapping("/purchases/{id}/status") @PreAuthorize("@access.admin() and @access.has('IMPORT_APPROVE')") public Object decide(@PathVariable long id,@Valid @RequestBody Decision r) { return service.decide(id,r); }
    @PostMapping("/purchases/{id}/receipts") @PreAuthorize("@access.has('IMPORT_RECEIVE')") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Object receipt(@PathVariable long id,@Valid @RequestBody Receive r) { return service.receipt(id,r); }
    @GetMapping("/receipts") @PreAuthorize("@access.has('IMPORT_READ')")
    public Object receipts(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.receipts(page,size); }
    @GetMapping("/receipts/{id}") @PreAuthorize("@access.has('IMPORT_RECEIVE')") public Object receiptDetail(@PathVariable long id) { return service.receiptDetail(id); }
    @PostMapping("/receipts/{id}/confirm") @PreAuthorize("@access.has('IMPORT_RECEIVE')") public Object confirm(@PathVariable long id) { return service.confirm(id); }
    @GetMapping("/debts") @PreAuthorize("@access.admin()") public Object debts(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        return db.page("select * from cong_no_ncc order by id desc","select count(*) from cong_no_ncc",List.of(),page,size);
    }
    @PostMapping("/debts/{id}/payments") @PreAuthorize("@access.admin()") public Object payDebt(@PathVariable long id,@Valid @RequestBody DebtPayment r) { return service.payDebt(id,r); }
}

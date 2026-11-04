package vn.drinkstore.management;

import java.util.Map;
import java.math.BigDecimal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/management")
@PreAuthorize("@access.admin()")
public class ManagementController {
    private final ManagementService service;
    public ManagementController(ManagementService service) { this.service=service; }
    public record ProductEditor(@NotBlank @Size(max=255) String fullName,@NotBlank @Size(max=150) String brand,@Positive long categoryId,@Size(max=80) String volume,@Size(max=3000) String description,@NotNull @DecimalMin("0") BigDecimal price,boolean active,@Positive Long packageId,@NotNull @Pattern(regexp="LON|CHAI|HOP") String packaging,@Size(max=2000) String imageUrl,@Min(0) @Max(1000000000) Long stock,@Min(0) Long expectedStock,@Size(max=1000) String stockReason) {}
    @PostMapping("/product-editor") @PreAuthorize("@access.admin() and @access.has('PRODUCT_MANAGE')")
    public Object editor(@Valid @RequestBody ProductEditor r) { return service.productEditor(null,r); }
    @PutMapping("/product-editor/{id}") @PreAuthorize("@access.admin() and @access.has('PRODUCT_MANAGE')")
    public Object editor(@PathVariable long id,@Valid @RequestBody ProductEditor r) { return service.productEditor(id,r); }
    public record StockUpdate(@NotNull @Min(0) @Max(1000000000) Long stock,@NotNull @Min(0) Long expectedStock,@NotBlank @Size(max=1000) String reason) {}
    @PatchMapping("/products/{id}/stock") @PreAuthorize("@access.admin() and @access.has('PRODUCT_MANAGE')")
    public Object stock(@PathVariable long id,@Valid @RequestBody StockUpdate r) { return service.updateStock(id,r); }
    public record SupplierEditor(@NotBlank @Size(max=255) String fullName,@Size(max=30) String taxCode,@Size(max=150) String contactName,@Pattern(regexp=vn.drinkstore.common.PhoneNumbers.OPTIONAL_PATTERN,message=vn.drinkstore.common.PhoneNumbers.MESSAGE) String phone,@Email @Size(max=255) String email,@Size(max=2000) String address,@NotNull @Pattern(regexp="HOP_TAC|NGUNG_HOP_TAC") String status,@NotNull @Pattern(regexp="DOANH_NGHIEP|HO_KINH_DOANH|CA_NHAN") String supplierType,@NotNull @Pattern(regexp="CHUA_XAC_MINH|DA_XAC_MINH|CAN_KIEM_TRA_LAI") String verificationStatus,@Size(max=2000) String verificationNotes,boolean verificationConfirmed,@Size(max=5000) java.util.List<@NotNull @Positive Long> productIds) {}
    public record PromotionEditor(@NotBlank @Size(max=60) @Pattern(regexp="[A-Za-z0-9_-]+") String code,@NotBlank @Size(max=150) String fullName,@Size(max=3000) String description,@NotNull @Pattern(regexp="PERCENT|FIXED") String discountType,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=16,fraction=2) BigDecimal value,@DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal maxDiscount,@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal minimumOrder,@NotNull java.time.OffsetDateTime startsAt,@NotNull java.time.OffsetDateTime endsAt,@Min(0) Integer totalLimit,@Min(0) Integer customerLimit,@NotNull @Pattern(regexp="CATEGORY|BRAND") String scope,@NotNull @Size(max=500) java.util.List<@NotNull @Positive Long> scopeIds,@NotNull @Pattern(regexp="ACTIVE|INACTIVE") String status) {}
    @PostMapping("/supplier-editor") @PreAuthorize("@access.admin() and @access.has('SUPPLIER_MANAGE')")
    public Object supplier(@Valid @RequestBody SupplierEditor r) { return service.supplierEditor(null,r); }
    @GetMapping("/supplier-editor") @PreAuthorize("@access.admin() and @access.has('SUPPLIER_MANAGE')")
    public Object suppliers(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.suppliers(page,size); }
    @GetMapping("/supplier-editor/{id}/products")
    public Object supplierProducts(@PathVariable long id) { return service.supplierProductIds(id); }
    public record SupplierTaxCheck(@Positive Long supplierId,@NotNull @Pattern(regexp="DOANH_NGHIEP|HO_KINH_DOANH|CA_NHAN") String supplierType,@NotBlank @Size(max=30) String taxCode) {}
    @PostMapping("/supplier-tax-check") @PreAuthorize("@access.admin() and @access.has('SUPPLIER_MANAGE')")
    public Object checkTax(@Valid @RequestBody SupplierTaxCheck r) { return service.checkSupplierTax(r.supplierId(),r.supplierType(),r.taxCode()); }
    @PutMapping("/supplier-editor/{id}") @PreAuthorize("@access.admin() and @access.has('SUPPLIER_MANAGE')")
    public Object supplier(@PathVariable long id,@Valid @RequestBody SupplierEditor r) { return service.supplierEditor(id,r); }
    @GetMapping("/promotion-editor") @PreAuthorize("@access.admin() and @access.has('PROMOTION_MANAGE')")
    public Object promotions(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.promotions(page,size); }
    @PostMapping("/promotion-editor") @PreAuthorize("@access.admin() and @access.has('PROMOTION_MANAGE')")
    public Object promotion(@Valid @RequestBody PromotionEditor r) { return service.promotionEditor(null,r); }
    @PutMapping("/promotion-editor/{id}") @PreAuthorize("@access.admin() and @access.has('PROMOTION_MANAGE')")
    public Object promotion(@PathVariable long id,@Valid @RequestBody PromotionEditor r) { return service.promotionEditor(id,r); }
    public record SupplierStatus(@NotNull @Pattern(regexp="HOP_TAC|NGUNG_HOP_TAC") String status) {}
    public record PromotionStatus(@NotNull @Pattern(regexp="ACTIVE|INACTIVE") String status) {}
    @PatchMapping("/supplier-editor/{id}/status") @PreAuthorize("@access.admin() and @access.has('SUPPLIER_MANAGE')")
    public Object supplierStatus(@PathVariable long id,@Valid @RequestBody SupplierStatus r) { return service.save("suppliers",id,Map.of("trang_thai",r.status())); }
    @PatchMapping("/promotion-editor/{id}/status") @PreAuthorize("@access.admin() and @access.has('PROMOTION_MANAGE')")
    public Object promotionStatus(@PathVariable long id,@Valid @RequestBody PromotionStatus r) { return service.save("promotions",id,Map.of("trang_thai",r.status())); }
    @GetMapping("/{resource}") public Object list(@PathVariable String resource,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.list(resource,page,size); }
    @GetMapping("/{resource}/{id}") public Object detail(@PathVariable String resource,@PathVariable long id) { return service.detail(resource,id); }
    @PostMapping("/{resource}") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Object create(@PathVariable String resource,@RequestBody Map<String,Object> body) { return service.save(resource,null,body); }
    @PatchMapping("/{resource}/{id}") public Object update(@PathVariable String resource,@PathVariable long id,@RequestBody Map<String,Object> body) { return service.save(resource,id,body); }
    @DeleteMapping("/{resource}/{id}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String resource,@PathVariable long id) { service.delete(resource,id); }
    @GetMapping("/supplier-products/{supplierId}/{productId}")
    public Object supplierProduct(@PathVariable long supplierId,@PathVariable long productId) { return service.supplierProduct(supplierId,productId); }
    @DeleteMapping("/supplier-products/{supplierId}/{productId}") @ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
    public void deleteSupplierProduct(@PathVariable long supplierId,@PathVariable long productId) { service.deleteSupplierProduct(supplierId,productId); }
}

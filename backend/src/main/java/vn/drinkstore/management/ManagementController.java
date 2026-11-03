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

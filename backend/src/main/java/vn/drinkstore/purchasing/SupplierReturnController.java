package vn.drinkstore.purchasing;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/supplier-returns")
public class SupplierReturnController {
    private final SupplierReturnService service;
    public SupplierReturnController(SupplierReturnService service) { this.service=service; }
    @GetMapping @PreAuthorize("@access.has('IMPORT_READ')")
    public Object list(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.list(page,size); }
}

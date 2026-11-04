package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.common.Db;
import static org.junit.jupiter.api.Assertions.*;

class PurchaseSupplierScopeTest {
    private final Db db=new Db(null) {
        @Override public Map<String,Object> one(String sql,Object... args) {
            return sql.contains("quy_cach_san_pham")?Map.of("san_pham_id",2L):Map.of("id",1L);
        }
        @Override public long number(String sql,Object... args) {
            return sql.contains("nha_cung_cap_san_pham")?0:1;
        }
        @Override public long id(String sql,Object... args) {
            throw new AssertionError("Unassigned products must be rejected before any insert");
        }
    };
    private void rejected(PurchaseController.Line line) {
        var service=new PurchaseService(db,null);
        assertThrows(ApiException.class,()->service.create(new PurchaseController.Create(1,null,List.of(line))));
    }
    @Test void rejectsExistingPackageFromUnassignedProduct() {
        rejected(new PurchaseController.Line(10,1,new BigDecimal("10000")));
    }
    @Test void rejectsCustomCaseBeforeCreatingAnyPackage() {
        rejected(new PurchaseController.Line(null,2,new BigDecimal("240000"),2L,"THUNG",24));
    }
}

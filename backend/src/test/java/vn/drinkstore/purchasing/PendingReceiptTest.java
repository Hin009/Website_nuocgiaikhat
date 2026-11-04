package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.common.Db;
import static org.junit.jupiter.api.Assertions.*;

class PendingReceiptTest {
    @Test void blocksDuplicateDraftBeforeInsertingAndWhileHoldingPurchaseLock() {
        Db db=new Db(null) {
            boolean locked;
            @Override public Map<String,Object> one(String sql,Object... args) {
                assertTrue(sql.endsWith("for update")); locked=true;
                return Map.of("trang_thai","DA_DUYET");
            }
            @Override public long number(String sql,Object... args) {
                assertTrue(locked); assertTrue(sql.contains("trang_thai='DRAFT'")); return 1;
            }
            @Override public long id(String sql,Object... args) { throw new AssertionError("Must not create a second draft"); }
        };
        var service=new PurchaseService(db,null);
        assertThrows(ApiException.class,()->service.receipt(1,new PurchaseController.Receive(List.of(new PurchaseController.ReceiptLine(1,2,BigDecimal.TEN)))));
    }
}

package vn.drinkstore.management;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;
import static org.junit.jupiter.api.Assertions.*;

class ProductStockTest {
    static class InventoryDb extends Db {
        int adjustments=0, audits=0;
        Object[] saved;
        InventoryDb() { super(null); }
        @Override public Map<String,Object> one(String sql,Object... args) { return Map.of("id",1L); }
        @Override public long number(String sql,Object... args) { return 20; }
        @Override public long id(String sql,Object... args) {
            if(sql.startsWith("insert into dieu_chinh_so_luong")) { adjustments++; saved=args; }
            return 1;
        }
        @Override public void audit(long account,String action,String target,long id) { audits++; }
    }
    private ManagementService service(InventoryDb db,boolean admin) {
        return new ManagementService(db,new Access(null) {
            @Override public boolean admin() { return admin; }
            @Override public long employee() { return 1; }
            @Override public long account() { return 1; }
        });
    }
    @Test void recordsAdjustmentWithPreviousStockNewStockAndReason() {
        var db=new InventoryDb();
        service(db,true).updateStock(1,new ManagementController.StockUpdate(25L,20L,"Kiểm kê"));
        assertEquals(1,db.adjustments); assertEquals(1,db.audits);
        assertEquals(20L,db.saved[3]); assertEquals(25L,db.saved[4]); assertEquals("Kiểm kê",db.saved[5]);
    }
    @Test void rejectsStaleChangesWithoutRecordingAdjustment() {
        var db=new InventoryDb();
        assertThrows(ApiException.class,()->service(db,true).updateStock(1,new ManagementController.StockUpdate(25L,19L,"Kiểm kê")));
        assertEquals(0,db.adjustments); assertEquals(0,db.audits);
    }
    @Test void staffCannotChangeStock() {
        var db=new InventoryDb();
        assertThrows(AccessDeniedException.class,()->service(db,false).updateStock(1,new ManagementController.StockUpdate(25L,20L,"Kiểm kê")));
        assertEquals(0,db.adjustments);
    }
}

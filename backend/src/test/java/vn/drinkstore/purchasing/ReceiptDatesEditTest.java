package vn.drinkstore.purchasing;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.Access;
import static org.junit.jupiter.api.Assertions.*;

class ReceiptDatesEditTest {
    static class RecordingJdbc extends JdbcTemplate {
        int writes;
        Object[] arguments;
        @Override public int update(String sql,Object... args) { writes++; arguments=args; assertTrue(sql.startsWith("update chi_tiet_lan_nhap set ngay_san_xuat")); return 1; }
    }
    private PurchaseService service(RecordingJdbc jdbc,String state) {
        var db=new Db(jdbc) {
            @Override public Map<String,Object> one(String sql,Object... args) {
                if(sql.contains("from chi_tiet_lan_nhap")) return Map.of("so_luong_thuc_nhan",2);
                return new java.util.HashMap<>(Map.of("id",1L,"don_ncc_id",1L,"trang_thai",state));
            }
            @Override public List<Map<String,Object>> rows(String sql,Object... args) { return List.of(); }
            @Override public void audit(long account,String action,String target,long id) { assertEquals("RECEIPT_DATES",action); }
        };
        return new PurchaseService(db,new Access(null) { @Override public long account() { return 1; } });
    }
    @Test void editsOnlyDatesOfDraftLine() {
        var jdbc=new RecordingJdbc();
        var dates=new PurchaseController.ReceiptDates(LocalDate.of(2000,1,1),LocalDate.of(2099,1,1));
        service(jdbc,"DRAFT").updateReceiptDates(1,2,dates);
        assertEquals(1,jdbc.writes); assertArrayEquals(new Object[]{dates.manufacturedOn(),dates.expiresOn(),2L,1L},jdbc.arguments);
    }
    @Test void refusesDateChangesOnConfirmedOrCancelledReceipts() {
        for(String state:List.of("CONFIRMED","CANCELLED")) {
            var jdbc=new RecordingJdbc();
            assertThrows(ApiException.class,()->service(jdbc,state).updateReceiptDates(1,2,new PurchaseController.ReceiptDates(LocalDate.of(2000,1,1),LocalDate.of(2099,1,1))));
            assertEquals(0,jdbc.writes);
        }
    }
}

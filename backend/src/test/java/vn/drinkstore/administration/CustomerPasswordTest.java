package vn.drinkstore.administration;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.common.Db;
import static org.junit.jupiter.api.Assertions.*;

class CustomerPasswordTest {
    static class RecordingJdbc extends JdbcTemplate {
        int writes;
        @Override public int update(String sql,Object... args) { writes++; return 1; }
    }
    private AdminService service(RecordingJdbc jdbc,boolean customer) {
        var db=new Db(jdbc) {
            @Override public Map<String,Object> one(String sql,Object... args) { return Map.of("id",2L,"email","customer@test.invalid"); }
            @Override public long id(String sql,Object... args) { return 1; }
            @Override public long number(String sql,Object... args) { return customer?1:0; }
            @Override public void audit(long account,String action,String target,long id) {}
        };
        return new AdminService(db,null,null,new BCryptPasswordEncoder());
    }
    @Test void dedicatedResetCannotChangeCustomerPassword() {
        var jdbc=new RecordingJdbc();
        assertThrows(ApiException.class,()->service(jdbc,true).reset(2,"NewPassword123!"));
        assertEquals(0,jdbc.writes);
    }
    @Test void editorCannotChangeCustomerPasswordEvenWhenPromotingToStaff() {
        var jdbc=new RecordingJdbc();
        var request=new AdminController.AccountEditor("customer@test.invalid","Khách hàng","0901234567","NHAN_VIEN",true,"NewPassword123!");
        assertThrows(ApiException.class,()->service(jdbc,true).accountEditor(2L,request));
        assertEquals(0,jdbc.writes);
    }
    @Test void editorCannotResetPasswordWhileConvertingStaffToCustomer() {
        var jdbc=new RecordingJdbc();
        var request=new AdminController.AccountEditor("customer@test.invalid","Khách hàng","0901234567","KHACH_HANG",true,"NewPassword123!");
        assertThrows(ApiException.class,()->service(jdbc,false).accountEditor(2L,request));
        assertEquals(0,jdbc.writes);
    }
}

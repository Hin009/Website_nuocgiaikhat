package vn.drinkstore.administration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import vn.drinkstore.common.Db;
import static org.junit.jupiter.api.Assertions.*;
class CustomerPasswordTest {
    static class RecordingJdbc extends JdbcTemplate {
        int writes;
        @Override public int update(String sql,Object... args) { writes++; return 1; }
    }
    @Test void dedicatedManagementResetCannotChangeAnyPassword() {
        var jdbc=new RecordingJdbc();
        var service=new AdminService(new Db(jdbc),null,null);
        assertThrows(AccessDeniedException.class,()->service.reset(2,"NewPassword123!"));
        assertEquals(0,jdbc.writes);
    }
    @ParameterizedTest @ValueSource(strings={"KHACH_HANG","NHAN_VIEN","QUAN_TRI_VIEN"})
    void existingAccountPasswordCannotBeChangedEvenWhenRoleIsChanged(String role) {
        var jdbc=new RecordingJdbc();
        var service=new AdminService(new Db(jdbc),null,null);
        var request=new AdminController.AccountEditor("user@test.invalid","Test User","0901234567",role,true,"NewPassword123!");
        assertThrows(AccessDeniedException.class,()->service.accountEditor(2L,request));
        assertEquals(0,jdbc.writes);
    }
}

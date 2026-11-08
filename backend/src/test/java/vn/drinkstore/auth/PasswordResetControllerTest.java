package vn.drinkstore.auth;

import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PasswordResetControllerTest {
    @Test void unconfiguredDeliveryDoesNotSpendRateLimit() {
        var service=mock(PasswordResetService.class);
        var limits=mock(PasswordResetRateLimit.class);
        var controller=new PasswordResetController(service,limits);
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"Not configured")).when(service).requireDeliveryConfigured();
        for(int i=0;i<10;i++) assertThrows(ApiException.class,()->controller.request(new PasswordResetController.Request("customer@test.invalid"),mock(HttpServletRequest.class)));
        verifyNoInteractions(limits);
        verify(service,never()).request(anyString());
    }
}

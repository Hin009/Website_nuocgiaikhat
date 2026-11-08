package vn.drinkstore.auth;

import org.junit.jupiter.api.Test;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PasswordResetMailTest {
    @Test void placeholderPasswordIsRejectedBeforeAttemptingDelivery() {
        var sender=mock(JavaMailSender.class);
        var mail=new PasswordResetMail(sender,true,"store@test.invalid","store@test.invalid","YOUR_NEW_APP_PASSWORD");
        var failure=assertThrows(ApiException.class,mail::requireConfigured);
        assertTrue(failure.getMessage().contains("giá trị mẫu"));
        verifyNoInteractions(sender);
    }
    @Test void disabledDeliveryFailsWithoutSending() {
        var sender=mock(JavaMailSender.class);
        var mail=new PasswordResetMail(sender,false,"","","");
        assertThrows(ApiException.class,mail::requireConfigured); verifyNoInteractions(sender);
    }
    @Test void emailIsSentOnlyToRequestedAddress() {
        var sender=mock(JavaMailSender.class);
        var mail=new PasswordResetMail(sender,true,"store@test.invalid","store@test.invalid","test-only");
        mail.requireConfigured(); mail.send("customer@test.invalid","012345");
        var capture=org.mockito.ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(sender).send(capture.capture());
        assertArrayEquals(new String[]{"customer@test.invalid"},capture.getValue().getTo());
        assertEquals("store@test.invalid",capture.getValue().getFrom());
        assertTrue(capture.getValue().getText().contains("012345"));
    }
}

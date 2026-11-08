package vn.drinkstore.auth;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;
import vn.drinkstore.common.ApiException;
import org.springframework.http.HttpStatus;

@Component
public class PasswordResetMail {
    private final JavaMailSender sender;
    private final boolean enabled;
    private final String from,username,password;
    public PasswordResetMail(JavaMailSender sender,@Value("${app.password-reset.mail-enabled:false}") boolean enabled,
        @Value("${app.password-reset.mail-from:}") String from,@Value("${spring.mail.username:}") String username,
        @Value("${spring.mail.password:}") String password) {
        this.sender=sender; this.enabled=enabled; this.from=from; this.username=username; this.password=password;
    }
    public void requireConfigured() {
        if(!enabled || from.isBlank() || username.isBlank() || password.isBlank())
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"Chức năng gửi OTP chưa được cấu hình. Vui lòng liên hệ cửa hàng.");
        if(password.trim().equals("YOUR_NEW_APP_PASSWORD") || password.trim().equals("mat-khau-ung-dung"))
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"Gửi OTP chưa sẵn sàng: MAIL_PASSWORD vẫn là giá trị mẫu. Cần cấu hình mật khẩu ứng dụng Gmail và cập nhật lại API.");
    }
    public void send(String recipient,String code) {
        var message=new SimpleMailMessage();
        message.setFrom(from); message.setTo(recipient);
        message.setSubject("WaterBus - Mã OTP khôi phục mật khẩu");
        message.setText("Mã OTP của bạn là: "+code+"\n\nMã có hiệu lực trong 5 phút và chỉ được dùng một lần. Không chia sẻ mã này với bất kỳ ai.\n\nNếu bạn không yêu cầu đổi mật khẩu, hãy bỏ qua email này.\nWaterBus");
        sender.send(message);
    }
    @Configuration
    public static class DeliveryConfiguration {
        @Bean(name="passwordResetMailExecutor") public ThreadPoolTaskExecutor executor() {
            var executor=new ThreadPoolTaskExecutor();
            executor.setCorePoolSize(1); executor.setMaxPoolSize(2); executor.setQueueCapacity(20);
            executor.setThreadNamePrefix("password-reset-mail-"); executor.setWaitForTasksToCompleteOnShutdown(false);
            return executor;
        }
    }
}

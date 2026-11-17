package vn.drinkstore.auth;

import java.time.Duration;
import org.springframework.stereotype.Component;

@Component
public class EmailChangeRateLimit {
    private final PasswordResetRateLimit limits=new PasswordResetRateLimit();
    public void request(long account,String ip,String email) {
        limits.check("account:"+account,10,Duration.ofHours(1));
        limits.request(ip,email);
    }
    public void verify(String ip) { limits.verify(ip); }
}

package vn.drinkstore.auth;

import java.util.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth/password-reset")
public class PasswordResetController {
    private final PasswordResetService service;
    private final PasswordResetRateLimit limits;
    public PasswordResetController(PasswordResetService service,PasswordResetRateLimit limits) { this.service=service; this.limits=limits; }
    public record Request(@NotBlank @Email @Size(max=255) String email) {}
    public record Verify(@NotNull UUID challengeId,@NotBlank @Pattern(regexp="[0-9]{6}") String code) {}
    public record Complete(@NotNull UUID challengeId,@NotBlank @Pattern(regexp="[A-Za-z0-9_-]{43}") String resetToken,@NotBlank @Size(min=8,max=72) String newPassword) {}
    @PostMapping("/request") public Object request(@Valid @RequestBody Request request,HttpServletRequest http) {
        service.requireDeliveryConfigured();
        limits.request(http.getRemoteAddr(),request.email()); return service.request(request.email());
    }
    @PostMapping("/verify") public Object verify(@Valid @RequestBody Verify request,HttpServletRequest http) {
        limits.verify(http.getRemoteAddr()); return service.verify(request.challengeId(),request.code());
    }
    @PostMapping("/complete") public Object complete(@Valid @RequestBody Complete request,HttpServletRequest http) {
        limits.complete(http.getRemoteAddr()); service.complete(request.challengeId(),request.resetToken(),request.newPassword());
        return Map.of("message","Đã đổi mật khẩu. Vui lòng đăng nhập lại bằng mật khẩu mới.");
    }
}

package vn.drinkstore.auth;

import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.security.Access;
import vn.drinkstore.security.Tokens;

@RestController
@RequestMapping("/api/v1/auth/email-change")
public class EmailChangeController {
    private final EmailChangeService service;
    private final Access access;
    public EmailChangeController(EmailChangeService service,Access access) { this.service=service; this.access=access; }
    public record Verification(@NotNull UUID challengeId,@NotBlank @Pattern(regexp="[0-9]{6}") String code) {}
    public record NewEmail(@NotNull UUID challengeId,@NotBlank @Email @Size(max=255) String email) {}
    public record Challenge(@NotNull UUID challengeId) {}
    private String session(HttpServletRequest http) { return Tokens.hash(http.getHeader("Authorization").substring(7)); }
    @PostMapping("/request-current") public Object current(HttpServletRequest http) {
        return service.requestCurrent(access.account(),session(http),http.getRemoteAddr());
    }
    @PostMapping("/verify-current") public Object verifyCurrent(@Valid @RequestBody Verification r,HttpServletRequest http) {
        return service.verifyCurrent(access.account(),session(http),r.challengeId(),r.code(),http.getRemoteAddr());
    }
    @PostMapping("/request-new") public Object newEmail(@Valid @RequestBody NewEmail r,HttpServletRequest http) {
        return service.requestNew(access.account(),session(http),r.challengeId(),r.email(),http.getRemoteAddr());
    }
    @PostMapping("/verify-new") public Object verifyNew(@Valid @RequestBody Verification r,HttpServletRequest http) {
        return service.verifyNew(access.account(),session(http),r.challengeId(),r.code(),http.getRemoteAddr());
    }
    @PostMapping("/resend") public Object resend(@Valid @RequestBody Challenge r,HttpServletRequest http) {
        return service.resend(access.account(),session(http),r.challengeId(),http.getRemoteAddr());
    }
    @PostMapping("/cancel") public Object cancel(@Valid @RequestBody Challenge r,HttpServletRequest http) {
        service.cancel(access.account(),session(http),r.challengeId()); return java.util.Map.of("message","Đã hủy yêu cầu đổi email.");
    }
}

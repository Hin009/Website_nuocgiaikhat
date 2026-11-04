package vn.drinkstore.auth;

import java.util.Map;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.Db;
import vn.drinkstore.security.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService service; private final Access access; private final Db db;
    public AuthController(AuthService service,Access access,Db db) { this.service=service; this.access=access; this.db=db; }
    public record Register(@NotBlank @Email @Size(max=255) String email,
        @NotBlank @Size(min=8,max=72) String password,@NotBlank @Size(max=150) String fullName,@Pattern(regexp=vn.drinkstore.common.PhoneNumbers.OPTIONAL_PATTERN,message=vn.drinkstore.common.PhoneNumbers.MESSAGE) String phone) {}
    public record Login(@NotBlank @Email @Size(max=255) String email,@NotBlank @Size(max=72) String password) {}
    public record ChangePassword(@NotBlank String oldPassword,@NotBlank @Size(min=8,max=72) String newPassword) {}
    @PostMapping("/register") @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public Object register(@Valid @RequestBody Register r) { return service.register(r.email(),r.password(),r.fullName(),r.phone()); }
    @PostMapping("/login") public Object login(@Valid @RequestBody Login r) { return service.login(r.email(),r.password()); }
    @GetMapping("/me") public Object me() { return service.profile(access.account()); }
    @PostMapping("/logout") public Object logout(@RequestHeader("Authorization") String header) {
        db.jdbc().update("update phien_xac_thuc set da_thu_hoi=true where tai_khoan_id=? and token_hash=?",access.account(),Tokens.hash(header.substring(7)));
        return Map.of("message","Đã đăng xuất");
    }
    @PutMapping("/password") public Object password(@Valid @RequestBody ChangePassword r) {
        service.changePassword(access.account(),r.oldPassword(),r.newPassword()); return Map.of("message","Đã đổi mật khẩu, vui lòng đăng nhập lại");
    }
}

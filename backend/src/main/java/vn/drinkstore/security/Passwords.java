package vn.drinkstore.security;

import java.nio.charset.StandardCharsets;
import vn.drinkstore.common.ApiException;

public final class Passwords {
    private Passwords() {}
    public static boolean fitsBcrypt(String password) { return password!=null && password.getBytes(StandardCharsets.UTF_8).length<=72; }
    public static void validate(String password) {
        if(password==null || password.length()<8 || !fitsBcrypt(password)) throw ApiException.bad("Mật khẩu cần ít nhất 8 ký tự và tối đa 72 byte UTF-8");
    }
}

package vn.drinkstore.management;

import java.util.Set;
import vn.drinkstore.common.ApiException;

public final class SupplierLegalRules {
    private SupplierLegalRules() {}
    public static String taxCode(String type, String code) {
        if (!Set.of("DOANH_NGHIEP", "HO_KINH_DOANH", "CA_NHAN").contains(type))
            throw ApiException.bad("Loại nhà cung cấp không hợp lệ.");
        if (code == null || code.isBlank()) return null;
        code = code.trim();
        if (!code.matches("[0-9]{10}")) throw ApiException.bad("Mã số thuế phải gồm đúng 10 chữ số.");
        return code;
    }
}

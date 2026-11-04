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
        boolean tax = code.matches("[0-9]{10}(?:-?[0-9]{3})?");
        boolean personal = !type.equals("DOANH_NGHIEP") && code.matches("[0-9]{12}");
        if (!tax && !personal) throw ApiException.bad(type.equals("DOANH_NGHIEP")
            ? "Mã số thuế doanh nghiệp gồm 10 số hoặc 10 số-3 số đơn vị phụ thuộc."
            : "Nhập số định danh cá nhân 12 số hoặc mã số thuế 10/13 số theo hồ sơ pháp lý.");
        String digits = code.replace("-", "");
        return digits.length() == 13 ? digits.substring(0,10) + "-" + digits.substring(10) : digits;
    }
}

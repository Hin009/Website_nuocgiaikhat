package vn.drinkstore.purchasing;

import vn.drinkstore.common.ApiException;

public final class ReceiptRules {
    private ReceiptRules() {}
    public static void validate(PurchaseController.ReceiptLine line) {
        if(line.quantity()<0 || line.rejectedQuantity()<0 || (long)line.quantity()+line.rejectedQuantity()==0)
            throw ApiException.bad("Nhập số lượng hàng đạt hoặc hàng lỗi lớn hơn 0.");
        if(line.rejectedQuantity()>0 && (line.rejectionReason()==null || line.rejectionReason().isBlank()))
            throw ApiException.bad("Ghi lý do từ chối hàng lỗi.");
        if(line.actualCost()==null || line.actualCost().signum()<0) throw ApiException.bad("Giá nhập không hợp lệ.");
    }
}

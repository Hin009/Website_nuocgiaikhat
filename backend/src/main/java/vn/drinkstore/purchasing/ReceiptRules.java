package vn.drinkstore.purchasing;

import vn.drinkstore.common.ApiException;

public final class ReceiptRules {
    private ReceiptRules() {}
    public static void validateDates(java.time.LocalDate manufacturedOn,java.time.LocalDate expiresOn,int acceptedQuantity) {
        if(manufacturedOn==null && expiresOn==null) return; // Older posted receipts have no date data.
        if(manufacturedOn==null || expiresOn==null) throw ApiException.bad("Nhập đủ ngày sản xuất và ngày hết hạn.");
        var today=java.time.LocalDate.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
        if(manufacturedOn.isAfter(today)) throw ApiException.bad("Ngày sản xuất không được sau hôm nay.");
        if(expiresOn.isBefore(manufacturedOn)) throw ApiException.bad("Ngày hết hạn không được trước ngày sản xuất.");
        if(acceptedQuantity>0 && expiresOn.isBefore(today)) throw ApiException.bad("Hàng hết hạn phải ghi vào số lượng hàng lỗi trả NCC, không nhập kho.");
    }
    public static void validate(PurchaseController.ReceiptLine line) {
        validateDates(line.manufacturedOn(),line.expiresOn(),line.quantity());
        if(line.quantity()<0 || line.rejectedQuantity()<0 || (long)line.quantity()+line.rejectedQuantity()==0)
            throw ApiException.bad("Nhập số lượng hàng đạt hoặc hàng lỗi lớn hơn 0.");
        if(line.rejectedQuantity()>0 && (line.rejectionReason()==null || line.rejectionReason().isBlank()))
            throw ApiException.bad("Ghi lý do từ chối hàng lỗi.");
        if(line.actualCost()==null || line.actualCost().signum()<0) throw ApiException.bad("Giá nhập không hợp lệ.");
    }
}

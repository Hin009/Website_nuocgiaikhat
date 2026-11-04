package vn.drinkstore.purchasing;

import java.util.Set;
import vn.drinkstore.common.ApiException;

public final class ImportPackaging {
    private ImportPackaging() {}
    public static void validate(PurchaseController.Line line) {
        if(line.packageId()!=null) {
            if(line.packageId()<=0 || line.productId()!=null || line.packaging()!=null || line.unitsPerPackage()!=null)
                throw ApiException.bad("Chọn quy cách đã có hoặc khai báo lốc/thùng; không gửi đồng thời hai cách.");
        } else if(line.productId()==null || line.productId()<=0 || line.packaging()==null || !Set.of("LOC","THUNG").contains(line.packaging()) || line.unitsPerPackage()==null || line.unitsPerPackage()<2 || line.unitsPerPackage()>1000000)
            throw ApiException.bad("Chọn sản phẩm, loại lốc/thùng và số đơn vị lẻ từ 2 đến 1.000.000.");
    }
}

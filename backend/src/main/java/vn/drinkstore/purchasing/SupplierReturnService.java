package vn.drinkstore.purchasing;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.drinkstore.common.Db;

/** Read-only history of damaged goods rejected during receiving. */
@Service
public class SupplierReturnService {
    private final Db db;
    public SupplierReturnService(Db db) { this.db=db; }
    public Object list(int page,int size) {
        String where=" from lan_nhap_hang r where r.trang_thai='CONFIRMED' and exists(select 1 from chi_tiet_lan_nhap c where c.lan_nhap_id=r.id and c.so_luong_loai>0)";
        var result=db.page("select r.id"+where+" order by r.ngay_xac_nhan desc,r.id desc","select count(*)"+where,List.of(),page,size);
        @SuppressWarnings("unchecked") var items=(List<Map<String,Object>>)result.get("items");
        for(var row:items) row.putAll(receiptRejection(Db.n(row,"id")));
        return result;
    }
    private Map<String,Object> receiptRejection(long id) {
        var row=db.one("select r.id,r.id as lan_nhap_id,r.ngay_xac_nhan as ngay_lap,r.ngay_xac_nhan,n.ten as nha_cung_cap from lan_nhap_hang r join don_dat_hang_ncc d on d.id=r.don_ncc_id join nha_cung_cap n on n.id=d.nha_cung_cap_id where r.id=? and r.trang_thai='CONFIRMED'",id);
        var lines=db.rows("select c.id,c.so_luong_loai as so_luong,c.ly_do_loai as ly_do,q.ten_quy_cach,s.ten as ten_san_pham,c.gia_nhap_thuc_te as don_gia,c.so_luong_loai*c.gia_nhap_thuc_te as thanh_tien from chi_tiet_lan_nhap c join chi_tiet_don_ncc d on d.id=c.ct_don_ncc_id join quy_cach_san_pham q on q.id=d.quy_cach_id join san_pham s on s.id=q.san_pham_id where c.lan_nhap_id=? and c.so_luong_loai>0 order by c.id",id);
        row.put("source","RECEIPT_REJECTION"); row.put("history_key","receipt-"+id);
        row.put("ma_phieu","TRA-NHAN-"+id); row.put("trang_thai","CONFIRMED");
        row.put("items",lines); row.put("refunds",List.of());
        row.put("tong_tien",lines.stream().map(l->Db.money(l,"thanh_tien")).reduce(BigDecimal.ZERO,BigDecimal::add));
        row.put("so_tien_giam_no",BigDecimal.ZERO); row.put("so_tien_cho_hoan",BigDecimal.ZERO); row.put("so_tien_da_hoan",BigDecimal.ZERO);
        // These goods never entered stock/payables. This is a read-only history projection,
        // not a new warehouse return, credit note or refund transaction.
        return row;
    }
}

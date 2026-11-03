package vn.drinkstore.sales;

import java.math.*;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.drinkstore.common.*;

@Service
public class PromotionService {
    private final Db db;
    public PromotionService(Db db) { this.db=db; }
    public record Discount(Long promotionId,BigDecimal amount) {}
    public Discount calculate(String code,long customer,List<Map<String,Object>> lines,boolean lock) {
        if(code==null || code.isBlank()) return new Discount(null,BigDecimal.ZERO);
        var candidates=db.jdbc().queryForList("select * from khuyen_mai where ma_code=?"+(lock?" for update":""),code);
        if(candidates.isEmpty()) throw ApiException.bad("Mã giảm giá không tồn tại");
        var p=candidates.getFirst(); long id=Db.n(p,"id");
        if(db.number("select count(*) from uu_dai_so_luong where khuyen_mai_id=?",id)>0) throw ApiException.bad("Quantity gift rules are not configured for online checkout");
        if(db.number("select count(*) from khuyen_mai where id=? and trang_thai='ACTIVE' and now() between bat_dau and ket_thuc",id)==0) throw ApiException.bad("Mã đã hết hạn hoặc ngừng hoạt động");
        long total=db.number("select count(*) from su_dung_khuyen_mai where khuyen_mai_id=? and trang_thai='APPLIED'",id);
        long own=db.number("select count(*) from su_dung_khuyen_mai where khuyen_mai_id=? and khach_hang_id=? and trang_thai='APPLIED'",id,customer);
        if(p.get("gioi_han_su_dung")!=null && total>=Db.n(p,"gioi_han_su_dung")) throw ApiException.bad("Mã đã hết lượt sử dụng");
        if(p.get("gioi_han_moi_khach")!=null && own>=Db.n(p,"gioi_han_moi_khach")) throw ApiException.bad("Bạn đã dùng hết lượt mã này");
        BigDecimal subtotal=BigDecimal.ZERO, eligible=BigDecimal.ZERO;
        for(var l:lines) {
            BigDecimal line=Db.money(l,"gia_ban").multiply(BigDecimal.valueOf(Db.n(l,"so_luong"))); subtotal=subtotal.add(line);
            long matches=db.number("select count(*) from pham_vi_khuyen_mai where khuyen_mai_id=? and ((?='PRODUCT' and san_pham_id=?) or (?='CATEGORY' and loai_san_pham_id=?) or (?='BRAND' and thuong_hieu_id=?))",id,p.get("pham_vi_ap_dung"),l.get("san_pham_id"),p.get("pham_vi_ap_dung"),l.get("loai_san_pham_id"),p.get("pham_vi_ap_dung"),l.get("thuong_hieu_id"));
            if("ALL".equals(p.get("pham_vi_ap_dung")) || matches>0) eligible=eligible.add(line);
        }
        if(p.get("don_toi_thieu")!=null && subtotal.compareTo(Db.money(p,"don_toi_thieu"))<0) throw ApiException.bad("Đơn chưa đạt giá trị tối thiểu");
        if(eligible.signum()==0) throw ApiException.bad("Giỏ hàng không có sản phẩm thuộc phạm vi mã giảm giá");
        BigDecimal amount="PERCENT".equals(p.get("loai_giam"))?eligible.multiply(Db.money(p,"gia_tri_giam")).divide(new BigDecimal("100"),2,RoundingMode.HALF_UP):Db.money(p,"gia_tri_giam");
        if(p.get("giam_toi_da")!=null) amount=amount.min(Db.money(p,"giam_toi_da"));
        return new Discount(id,amount.min(eligible).setScale(2,RoundingMode.HALF_UP));
    }
}

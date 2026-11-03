package vn.drinkstore.sales;

import java.util.*;
import java.math.BigDecimal;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;

@Service
public class CartService {
    private final Db db; private final PromotionService promotions;
    public CartService(Db db,PromotionService promotions) { this.db=db; this.promotions=promotions; }
    public long cart(long customer) {
        db.jdbc().update("insert into gio_hang(khach_hang_id) values (?) on conflict(khach_hang_id) do nothing",customer);
        return db.id("select id from gio_hang where khach_hang_id=? for update",customer);
    }
    public List<Map<String,Object>> lines(long cart) {
        return db.jdbc().queryForList("""
            select c.id,c.quy_cach_id,c.so_luong,c.gia_tam_tinh,q.ten_quy_cach,q.don_vi_tinh,
              q.he_so_quy_doi,q.gia_ban,q.gia_von,s.id as san_pham_id,s.ten,k.so_luong_co_ban,
              s.trang_thai,s.loai_san_pham_id,s.thuong_hieu_id,
              (s.trang_thai='DANG_BAN' and s.hien_thi and l.hien_thi and b.hien_thi and q.dang_ban) as available,
              (c.gia_tam_tinh<>q.gia_ban) as price_changed
            from chi_tiet_gio_hang c join quy_cach_san_pham q on q.id=c.quy_cach_id
            join san_pham s on s.id=q.san_pham_id join so_luong_san_pham k on k.san_pham_id=s.id
            join loai_san_pham l on l.id=s.loai_san_pham_id
            join thuong_hieu b on b.id=s.thuong_hieu_id where c.gio_hang_id=? order by s.id,q.id
            """,cart);
    }
    public List<Map<String,Object>> selectedLines(long customer,List<Long> packages) {
        var all=lines(cart(customer));
        if(packages==null) return all;
        var ids=new HashSet<>(packages);
        if(ids.isEmpty()) throw ApiException.bad("Chưa chọn sản phẩm");
        var selected=all.stream().filter(l->ids.contains(Db.n(l,"quy_cach_id"))).toList();
        if(selected.size()!=ids.size()) throw ApiException.bad("Giỏ hàng đã thay đổi; vui lòng tải lại");
        return selected;
    }
    public static void validateStock(List<Map<String,Object>> lines) {
        var needed=new HashMap<Long,Long>();
        for(var l:lines) {
            if(!Boolean.TRUE.equals(l.get("available"))) throw ApiException.bad("Sản phẩm ngừng bán hoặc bị ẩn: "+l.get("ten"));
            long product=Db.n(l,"san_pham_id");
            long qty=Math.multiplyExact(Db.n(l,"so_luong"),Db.n(l,"he_so_quy_doi"));
            long total=needed.merge(product,qty,Long::sum);
            if(total>Db.n(l,"so_luong_co_ban")) throw ApiException.bad("Không đủ số lượng: "+l.get("ten"));
        }
    }
    @Transactional public Object view(long customer,String code) {
        var lines=lines(cart(customer));
        var discount=promotions.calculate(code,customer,lines,false);
        BigDecimal total=lines.stream().map(l->Db.money(l,"gia_ban").multiply(BigDecimal.valueOf(Db.n(l,"so_luong")))).reduce(BigDecimal.ZERO,BigDecimal::add);
        var publicLines=lines.stream().map(l->{var copy=new LinkedHashMap<>(l); copy.remove("gia_von"); return copy;}).toList();
        return Map.of("items",publicLines,"subtotal",total,"discount",discount.amount(),"total",total.subtract(discount.amount()));
    }
    @Transactional public Object put(long customer,long packageId,int quantity) {
        long cart=cart(customer);
        var p=db.entity(vn.drinkstore.domain.QuyCachSanPham.class,"select * from quy_cach_san_pham where id=?",packageId);
        db.jdbc().update("insert into chi_tiet_gio_hang(gio_hang_id,quy_cach_id,so_luong,gia_tam_tinh) values (?,?,?,?) on conflict(gio_hang_id,quy_cach_id) do update set so_luong=excluded.so_luong,gia_tam_tinh=excluded.gia_tam_tinh",cart,packageId,quantity,p.giaBan());
        validateStock(lines(cart));
        db.jdbc().update("update gio_hang set ngay_cap_nhat=now() where id=?",cart);
        return view(customer,null);
    }
    @Transactional public void remove(long customer,long packageId) { db.jdbc().update("delete from chi_tiet_gio_hang where gio_hang_id=? and quy_cach_id=?",cart(customer),packageId); }
    @Transactional public Object reorder(long customer,long order) {
        db.one("select id from don_hang where id=? and khach_hang_id=?",order,customer);
        long cart=cart(customer);
        var previous=db.jdbc().queryForList("select quy_cach_id,sum(so_luong)::int as so_luong from chi_tiet_don_hang where don_hang_id=? group by quy_cach_id",order);
        for(var l:previous) {
            long existing=db.number("select coalesce(sum(so_luong),0) from chi_tiet_gio_hang where gio_hang_id=? and quy_cach_id=?",cart,l.get("quy_cach_id"));
            put(customer,Db.n(l,"quy_cach_id"),Math.toIntExact(existing+Db.n(l,"so_luong")));
        }
        return view(customer,null);
    }
}

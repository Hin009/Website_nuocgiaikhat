package vn.drinkstore.catalog;

import java.util.*;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.*;

@RestController
@RequestMapping("/api/v1/catalog")
public class CatalogController {
    @org.springframework.beans.factory.annotation.Autowired private vn.drinkstore.billing.MomoProperties momo;
    private final Db db;
    private final java.math.BigDecimal shipping;
    private final Map<String,String> bankTransfer;
    public CatalogController(Db db,@org.springframework.beans.factory.annotation.Value("${app.shipping-fee}") java.math.BigDecimal shipping,
        @org.springframework.beans.factory.annotation.Value("${app.bank-transfer.bank-id:}") String bankId,
        @org.springframework.beans.factory.annotation.Value("${app.bank-transfer.bank-name:}") String bankName,
        @org.springframework.beans.factory.annotation.Value("${app.bank-transfer.account-number:}") String accountNumber,
        @org.springframework.beans.factory.annotation.Value("${app.bank-transfer.account-name:}") String accountName) {
        this.db=db; this.shipping=shipping;
        this.bankTransfer=Map.of("bankId",bankId.trim(),"bankName",bankName.trim(),"accountNumber",accountNumber.trim(),"accountName",accountName.trim());
    }
    @GetMapping("/checkout-options") public Object checkoutOptions() {
        var methods=new ArrayList<Map<String,Object>>();
        methods.add(Map.of("code","COD","label","Thanh toán khi nhận hàng (COD)","description","Thanh toán khi đơn hàng được giao."));
        methods.add(Map.of("code","MOMO","label","Ví điện tử MoMo (Sandbox)","enabled",momo.ready(),"description",momo.ready()?"Quét QR bằng ứng dụng MoMo Test. Không phát sinh tiền thật.":"MoMo Sandbox chưa sẵn sàng. Cửa hàng cần hoàn tất cấu hình trước khi nhận thanh toán."));
        return Map.of("shippingFee",shipping,"bankTransfer",bankTransfer,"paymentMethods",methods,"momoEnabled",momo.ready());
    }

    private static final String VISIBLE=" s.trang_thai in ('DANG_BAN','HET_HANG') and s.hien_thi and exists(select 1 from loai_san_pham c where c.id=s.loai_san_pham_id and c.hien_thi) and exists(select 1 from thuong_hieu b where b.id=s.thuong_hieu_id and b.hien_thi) ";
    private static final String EXPIRY="""
        case when k.so_luong_co_ban>0 then (
          select min(c.ngay_het_han) from chi_tiet_lan_nhap c
          join lan_nhap_hang r on r.id=c.lan_nhap_id
          join chi_tiet_don_ncc l on l.id=c.ct_don_ncc_id
          join quy_cach_san_pham q on q.id=l.quy_cach_id
          where q.san_pham_id=s.id and r.trang_thai='CONFIRMED' and c.so_luong_thuc_nhan>0
            and c.ngay_het_han>=(now() at time zone 'Asia/Ho_Chi_Minh')::date
        ) end as next_expiry
        """;
    @GetMapping("/products")
    public Object products(@RequestParam(defaultValue="") String q,@RequestParam(required=false) Long categoryId,
        @RequestParam(required=false) Long brandId,@RequestParam(required=false) Boolean inStock,
        @RequestParam(defaultValue="newest") String sort,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        String where=" from san_pham s join so_luong_san_pham k on k.san_pham_id=s.id where "+VISIBLE+" and s.ten ilike ?";
        var args=new ArrayList<Object>(); args.add("%"+q+"%");
        if(categoryId!=null) { where+=" and s.loai_san_pham_id=?"; args.add(categoryId); }
        if(brandId!=null) { where+=" and s.thuong_hieu_id=?"; args.add(brandId); }
        if(inStock!=null) where+=inStock?" and k.so_luong_co_ban>0":" and k.so_luong_co_ban=0";
        String order=switch(sort) { case "name" -> "s.ten,s.id"; case "priceAsc" -> "gia_tu nulls last,s.id"; case "priceDesc" -> "gia_tu desc nulls last,s.id"; case "newest" -> "s.ngay_tao desc,s.id desc"; default -> throw ApiException.bad("sort: newest, name, priceAsc, priceDesc"); };
        return db.page("select s.*,k.so_luong_co_ban,"+EXPIRY+",(select min(gia_ban) from quy_cach_san_pham where san_pham_id=s.id and dang_ban) as gia_tu"+where+" order by "+order,"select count(*)"+where,args,page,size);
    }
    @GetMapping("/products/{id}") public Object product(@PathVariable long id) {
        var p=db.one("select s.*,k.so_luong_co_ban,"+EXPIRY+" from san_pham s join so_luong_san_pham k on k.san_pham_id=s.id where s.id=? and "+VISIBLE,id);
        p.put("packages",db.rows("select id,san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban,?::bigint/he_so_quy_doi as so_luong_co_the_mua from quy_cach_san_pham where san_pham_id=? and dang_ban order by he_so_quy_doi,id",p.get("so_luong_co_ban"),id));
        p.put("images",db.jdbc().queryForList("select id,duong_dan,anh_chinh,thu_tu from hinh_anh_san_pham where san_pham_id=? order by anh_chinh desc,thu_tu,id",id)); return p;
    }
    @GetMapping("/categories") public Object categories() { return db.jdbc().queryForList("select id,ten,mo_ta,hinh_anh from loai_san_pham where hien_thi order by ten"); }
    @GetMapping("/brands") public Object brands() { return db.jdbc().queryForList("select id,ten,mo_ta,logo from thuong_hieu where hien_thi order by ten"); }
    @GetMapping("/promotions") public Object promotions() {
        var promotions=db.jdbc().queryForList("select id,ma_code,ten,loai_giam,gia_tri_giam,giam_toi_da,don_toi_thieu,bat_dau,ket_thuc,pham_vi_ap_dung from khuyen_mai where trang_thai='ACTIVE' and now() between bat_dau and ket_thuc order by ket_thuc");
        var scopes=db.jdbc().queryForList("select s.khuyen_mai_id,s.san_pham_id,s.loai_san_pham_id,s.thuong_hieu_id from pham_vi_khuyen_mai s join khuyen_mai p on p.id=s.khuyen_mai_id where p.trang_thai='ACTIVE' and now() between p.bat_dau and p.ket_thuc");
        for(var promotion:promotions) promotion.put("scopes",scopes.stream().filter(scope->Db.n(scope,"khuyen_mai_id")==Db.n(promotion,"id")).toList());
        return promotions;
    }
    @GetMapping("/products/{id}/reviews") public Object reviews(@PathVariable long id,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        product(id);
        String from=" from danh_gia_san_pham d join chi_tiet_don_hang c on c.id=d.chi_tiet_don_hang_id join quy_cach_san_pham q on q.id=c.quy_cach_id join khach_hang k on k.id=d.khach_hang_id where q.san_pham_id=? and d.trang_thai='APPROVED'";
        return db.page("select d.id,d.so_sao,d.noi_dung,d.ngay_danh_gia,k.ho_ten"+from+" order by d.id desc","select count(*)"+from,List.of(id),page,size);
    }
}

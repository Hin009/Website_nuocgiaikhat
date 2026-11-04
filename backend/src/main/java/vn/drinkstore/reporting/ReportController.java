package vn.drinkstore.reporting;

import java.time.LocalDate;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.*;

@RestController
@RequestMapping("/api/v1")
public class ReportController {
    private final Db db;
    public ReportController(Db db) { this.db=db; }
    @GetMapping("/health") public Object health() { db.number("select 1"); return Map.of("status","UP","service","drink-store-api"); }
    @GetMapping("/staff/products") @PreAuthorize("@access.has('REPORT_STOCK')")
    public Object products(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        var result=db.page("select p.id,p.sku,p.ten,p.loai_san_pham_id,p.thuong_hieu_id,p.dung_tich,p.loai_bao_bi,p.mo_ta,p.trang_thai,p.hien_thi,p.ngay_tao,coalesce(k.so_luong_co_ban,0) as so_luong_co_ban,k.nguong_canh_bao from san_pham p left join so_luong_san_pham k on k.san_pham_id=p.id order by p.id desc","select count(*) from san_pham",List.of(),page,size);
        @SuppressWarnings("unchecked") var rows=(List<Map<String,Object>>)result.get("items");
        for(var row:rows) {
            row.put("packages",db.rows("select id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban,dang_ban from quy_cach_san_pham where san_pham_id=? order by he_so_quy_doi,id",row.get("id")));
            row.put("images",db.rows("select duong_dan,anh_chinh from hinh_anh_san_pham where san_pham_id=? order by anh_chinh desc,thu_tu,id",row.get("id")));
        }
        return result;
    }
    @GetMapping("/staff/products/{id}/inventory-details") @PreAuthorize("@access.admin() or @access.has('REPORT_STOCK')")
    public Object inventoryDetails(@PathVariable long id) {
        db.one("select id from san_pham where id=?",id);
        var batches=db.rows("""
            select c.id,r.id as receipt_id,r.ngay_nhap,c.ngay_san_xuat,c.ngay_het_han,
              c.so_luong_thuc_nhan*l.he_so_quy_doi::bigint as received_units
            from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id
            join chi_tiet_don_ncc l on l.id=c.ct_don_ncc_id
            join quy_cach_san_pham q on q.id=l.quy_cach_id
            where q.san_pham_id=? and r.trang_thai='CONFIRMED' and c.so_luong_thuc_nhan>0
            order by c.ngay_het_han asc nulls last,r.ngay_nhap desc,c.id desc
            """,id);
        var adjustments=db.rows("""
            select d.id,d.so_luong_truoc,d.so_luong_sau,d.chenh_lech,d.ly_do,d.thoi_diem,
              n.ho_ten as adjusted_by
            from dieu_chinh_so_luong d join nhan_vien n on n.id=d.nguoi_dieu_chinh_id
            where d.san_pham_id=? order by d.thoi_diem desc,d.id desc limit 100
            """,id);
        return Map.of("batches",batches,"adjustments",adjustments);
    }
    @GetMapping("/staff/reports/stock") @PreAuthorize("@access.has('REPORT_STOCK')")
    public Object stock(@RequestParam(defaultValue="false") boolean lowOnly,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) {
        String where=lowOnly?" where canh_bao":""; return db.page("select * from v_ton_san_pham"+where+" order by san_pham_id","select count(*) from v_ton_san_pham"+where,List.of(),page,size);
    }
    @GetMapping("/staff/reports/purchases") @PreAuthorize("@access.has('REPORT_STOCK')")
    public Object purchases(@RequestParam LocalDate from,@RequestParam LocalDate to) {
        range(from,to);
        return db.jdbc().queryForList("""
            select po.nha_cung_cap_id,q.san_pham_id,sum(c.so_luong_thuc_nhan::bigint*l.he_so_quy_doi) as so_luong_co_ban,
              sum(c.so_luong_thuc_nhan*c.gia_nhap_thuc_te) as tong_gia_tri
            from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id
            join chi_tiet_don_ncc l on l.id=c.ct_don_ncc_id join quy_cach_san_pham q on q.id=l.quy_cach_id
            join don_dat_hang_ncc po on po.id=r.don_ncc_id
            where r.trang_thai='CONFIRMED' and r.ngay_xac_nhan>=cast(? as date) and r.ngay_xac_nhan<cast(? as date)+interval '1 day'
            group by po.nha_cung_cap_id,q.san_pham_id order by po.nha_cung_cap_id,q.san_pham_id
            """,from,to);
    }
    @GetMapping("/management/reports/revenue") @PreAuthorize("@access.admin()")
    public Object revenue(@RequestParam LocalDate from,@RequestParam LocalDate to,@RequestParam(defaultValue="day") String group) {
        range(from,to);
        if(!Set.of("day","week","month","quarter","year").contains(group)) throw ApiException.bad("group: day, week, month, quarter, year");
        return db.jdbc().queryForList("""
            select date_trunc(?,d.ngay_dat at time zone 'Asia/Ho_Chi_Minh') as period,count(*) as orders,
              sum(d.tong_tien-d.phi_van_chuyen) as net_sales,
              sum(d.phi_van_chuyen) as shipping_collected
            from don_hang d
            where d.trang_thai in ('DA_GIAO','HOAN_TAT') and d.ngay_dat>=cast(? as date) and d.ngay_dat<cast(? as date)+interval '1 day'
            group by period order by period
            """,group,from,to);
    }
    @GetMapping("/management/reports/order-status") @PreAuthorize("@access.admin()") public Object status() { return db.jdbc().queryForList("select trang_thai,count(*) as total from don_hang group by trang_thai order by trang_thai"); }
    @GetMapping("/management/reports/promotions") @PreAuthorize("@access.admin()") public Object promotions() {
        return db.jdbc().queryForList("select p.id,p.ten,count(u.id) as used,coalesce(sum(u.so_tien_giam),0) as discount,coalesce(sum(d.tong_tien),0) as order_value from khuyen_mai p left join su_dung_khuyen_mai u on u.khuyen_mai_id=p.id and u.trang_thai='APPLIED' left join don_hang d on d.id=u.don_hang_id group by p.id order by p.id");
    }
    @GetMapping("/management/reports/expiring-documents") @PreAuthorize("@access.admin()") public Object expiring() { return db.jdbc().queryForList("select * from giay_to_ncc where ngay_het_han<=current_date+30 order by ngay_het_han"); }
    private void range(LocalDate from,LocalDate to) { if(to.isBefore(from) || to.isAfter(from.plusYears(5))) throw ApiException.bad("Khoảng thời gian không hợp lệ hoặc vượt 5 năm"); }
}

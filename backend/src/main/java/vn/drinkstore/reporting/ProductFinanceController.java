package vn.drinkstore.reporting;

import java.time.LocalDate;
import java.util.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import vn.drinkstore.common.*;

@RestController
@RequestMapping("/api/v1/management/reports")
@PreAuthorize("@access.admin() and @access.has('REPORT_ALL')")
public class ProductFinanceController {
    private final Db db;
    public ProductFinanceController(Db db) { this.db=db; }
    @GetMapping("/product-profit")
    public Object products(@RequestParam(required=false) LocalDate from,@RequestParam(required=false) LocalDate to) {
        if((from==null)!=(to==null) || (from!=null && (to.isBefore(from) || to.isAfter(from.plusYears(5))))) throw ApiException.bad("Chọn khoảng thời gian hợp lệ, tối đa 5 năm; bỏ cả hai ngày để xem toàn bộ.");
        LocalDate first=from==null?LocalDate.of(1900,1,1):from, last=to==null?LocalDate.of(9999,12,30):to;
        return db.rows(SQL,first,last,first,last);
    }
    public static final String SQL="""
        with bounds as (select cast(? as date)::timestamp at time zone 'Asia/Ho_Chi_Minh' as start_at,
          (cast(? as date)+1)::timestamp at time zone 'Asia/Ho_Chi_Minh' as end_at),
        imports as (
          select q.san_pham_id,sum(c.so_luong_thuc_nhan::bigint*d.he_so_quy_doi) as imported_qty,
            sum(c.so_luong_thuc_nhan*c.gia_nhap_thuc_te) as import_amount
          from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id
          join chi_tiet_don_ncc d on d.id=c.ct_don_ncc_id join quy_cach_san_pham q on q.id=d.quy_cach_id cross join bounds b
          where r.trang_thai='CONFIRMED' and r.ngay_xac_nhan>=b.start_at and r.ngay_xac_nhan<b.end_at group by q.san_pham_id
        ), sale_lines as (
          select c.id,c.don_hang_id,q.san_pham_id,c.so_luong,c.he_so_quy_doi,c.gia_von_don_vi,
            c.so_luong*c.don_gia as gross,d.giam_gia,
            sum(c.so_luong*c.don_gia) over(partition by d.id) as order_gross,
            max(c.id) over(partition by d.id) as last_line
          from chi_tiet_don_hang c join don_hang d on d.id=c.don_hang_id join quy_cach_san_pham q on q.id=c.quy_cach_id
          where d.trang_thai in ('DA_GIAO','HOAN_TAT') and d.ngay_dat>=cast(? as date)::timestamp at time zone 'Asia/Ho_Chi_Minh'
            and d.ngay_dat<(cast(? as date)+1)::timestamp at time zone 'Asia/Ho_Chi_Minh'
        ), shares as (
          select *,case when order_gross>0 then trunc(giam_gia*gross/order_gross,2) else 0 end as share from sale_lines
        ), allocated as (
          select *,case when id=last_line then giam_gia-sum(case when id<>last_line then share else 0 end) over(partition by don_hang_id)
            else share end as discount from shares
        ), sales as (
          select san_pham_id,sum(so_luong::bigint*he_so_quy_doi) as sold_qty,sum(gross) as gross_sales,
            sum(discount) as discount,sum(gross-discount) as net_sales,sum(so_luong*gia_von_don_vi) as cost_of_goods,
            sum(case when gia_von_don_vi=0 and gross>0 then so_luong::bigint*he_so_quy_doi else 0 end) as zero_cost_qty
          from allocated group by san_pham_id
        ), result as (
          select p.id as product_id,p.sku,p.ten as product_name,
            coalesce(i.imported_qty,0) as imported_qty,coalesce(i.import_amount,0) as import_amount,
            coalesce(s.sold_qty,0) as sold_qty,coalesce(s.gross_sales,0) as gross_sales,coalesce(s.discount,0) as discount,
            coalesce(s.net_sales,0) as net_sales,coalesce(s.cost_of_goods,0) as cost_of_goods,
            coalesce(s.net_sales,0)-coalesce(s.cost_of_goods,0) as gross_profit,coalesce(s.zero_cost_qty,0) as zero_cost_qty,
            coalesce(k.so_luong_co_ban,0) as current_stock
          from san_pham p left join imports i on i.san_pham_id=p.id
          left join sales s on s.san_pham_id=p.id left join so_luong_san_pham k on k.san_pham_id=p.id
        ) select *,case when net_sales<>0 then round(gross_profit/net_sales*100,2) else null end as margin_percent
          from result order by gross_profit desc,product_id
        """;
}

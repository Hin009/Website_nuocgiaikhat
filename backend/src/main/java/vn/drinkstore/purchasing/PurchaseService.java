package vn.drinkstore.purchasing;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

@Service
public class PurchaseService {
    private final Db db; private final Access access;
    public PurchaseService(Db db,Access access) { this.db=db; this.access=access; }
    @Transactional public Object create(PurchaseController.Create r) {
        long supplier=r.supplierId();
        db.one("select id from nha_cung_cap where id=? for update",supplier);
        if(db.number("select count(*) from nha_cung_cap where id=? and trang_thai='HOP_TAC'",supplier)==0) throw ApiException.bad("Nhà cung cấp không hoạt động");
        for(var line:r.items()) {
            ImportPackaging.validate(line);
            long product=line.packageId()==null?line.productId():Db.n(db.one("select san_pham_id from quy_cach_san_pham where id=?",line.packageId()),"san_pham_id");
            if(db.number("select count(*) from nha_cung_cap_san_pham where nha_cung_cap_id=? and san_pham_id=?",supplier,product)==0)
                throw ApiException.bad("Sản phẩm chưa được gán cho nhà cung cấp. Cập nhật sản phẩm trong quản lý nhà cung cấp trước khi lập đơn nhập.");
        }
        long id=db.id("insert into don_dat_hang_ncc(ma_don_nhap,nha_cung_cap_id,nguoi_lap_id,ngay_giao_du_kien) values (?,?,?,?) returning id","DN-"+UUID.randomUUID(),supplier,access.employee(),r.expectedDate());
        for(var l:r.items()) {
            long packageId=importPackage(l);
            if(db.number("select count(*) from nha_cung_cap_san_pham sp join quy_cach_san_pham q on q.san_pham_id=sp.san_pham_id where sp.nha_cung_cap_id=? and q.id=?",supplier,packageId)==0) throw ApiException.bad("Quy cách không thuộc sản phẩm nhà cung cấp này");
            db.jdbc().update("insert into chi_tiet_don_ncc(don_ncc_id,quy_cach_id,so_luong_dat,gia_nhap_du_kien,he_so_quy_doi) select ?,id,?,?,he_so_quy_doi from quy_cach_san_pham where id=?",id,l.quantity(),l.unitCost(),packageId);
        }
        db.audit(access.account(),"PURCHASE_CREATE","don_dat_hang_ncc",id); return detail(id);
    }
    private long importPackage(PurchaseController.Line line) {
        ImportPackaging.validate(line);
        if(line.packageId()!=null) return line.packageId();
        // Serialize package creation for this product without changing any used package's factor.
        db.one("select id from san_pham where id=? for update",line.productId());
        var existing=db.rows("select id from quy_cach_san_pham where san_pham_id=? and don_vi_tinh=? and he_so_quy_doi=? order by id limit 1",line.productId(),line.packaging(),line.unitsPerPackage());
        if(!existing.isEmpty()) return Db.n(existing.getFirst(),"id");
        var primary=db.one("select gia_ban/he_so_quy_doi as base_price,gia_von/he_so_quy_doi as base_cost from quy_cach_san_pham where san_pham_id=? order by he_so_quy_doi,id limit 1",line.productId());
        String label=("LOC".equals(line.packaging())?"Lốc ":"Thùng ")+line.unitsPerPackage()+" đơn vị (nhập)";
        long packageId=db.id("insert into quy_cach_san_pham(san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban,gia_von,dang_ban) values (?,?,?,?,?,?,false) returning id",line.productId(),label,line.packaging(),line.unitsPerPackage(),Db.money(primary,"base_price").multiply(java.math.BigDecimal.valueOf(line.unitsPerPackage())),Db.money(primary,"base_cost").multiply(java.math.BigDecimal.valueOf(line.unitsPerPackage())));
        db.audit(access.account(),"IMPORT_PACKAGE_CREATE","quy_cach_san_pham",packageId);
        return packageId;
    }
    public Map<String,Object> detail(long id) {
        var p=db.one("select * from don_dat_hang_ncc where id=?",id);
        p.put("items",db.rows("""
            select d.*,coalesce(a.received,0) as so_luong_da_nhan,coalesce(a.rejected,0) as so_luong_da_tra_loi,
              greatest(d.so_luong_dat-coalesce(a.received,0)-coalesce(a.rejected,0),0) as so_luong_con_lai
            from chi_tiet_don_ncc d left join lateral (
              select sum(c.so_luong_thuc_nhan) as received,sum(c.so_luong_loai) as rejected
              from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id
              where c.ct_don_ncc_id=d.id and r.trang_thai='CONFIRMED'
            ) a on true where d.don_ncc_id=? order by d.id
            """,id));
        p.put("receipts",db.jdbc().queryForList("select * from lan_nhap_hang where don_ncc_id=? order by id",id)); return p;
    }
    @Transactional public Object decide(long id,PurchaseController.Decision r) {
        var p=db.one("select * from don_dat_hang_ncc where id=? for update",id);
        String old=p.get("trang_thai").toString(), next=r.status();
        if(next.equals(old)) return detail(id);
        boolean valid=(old.equals("CHO_DUYET") && Set.of("DA_DUYET","TU_CHOI","DA_HUY").contains(next)) || (old.equals("DA_DUYET") && Set.of("DANG_GIAO","DA_HUY").contains(next));
        if(!valid) throw ApiException.bad("Chuyển trạng thái đơn nhập không hợp lệ");
        if(next.equals("TU_CHOI") && (r.reason()==null || r.reason().isBlank())) throw ApiException.bad("Cần lý do từ chối");
        db.jdbc().update("update don_dat_hang_ncc set trang_thai=?,nguoi_duyet_id=?,ly_do_tu_choi=?,ngay_duyet=now() where id=?",next,access.employee(),r.reason(),id);
        db.audit(access.account(),"PURCHASE_"+next,"don_dat_hang_ncc",id); return detail(id);
    }
    @Transactional public Object receipt(long purchase,PurchaseController.Receive r) {
        var po=db.one("select * from don_dat_hang_ncc where id=? for update",purchase);
        if(!Set.of("DA_DUYET","DANG_GIAO","DA_NHAN_MOT_PHAN").contains(po.get("trang_thai"))) throw ApiException.bad("Chỉ nhận hàng cho đơn đã duyệt và chưa nhận đủ");
        long id=db.id("insert into lan_nhap_hang(don_ncc_id,nguoi_nhan_id) values (?,?) returning id",purchase,access.employee());
        var seen=new HashSet<Long>();
        for(var line:r.items()) {
            if(!seen.add(line.purchaseLineId())) throw ApiException.bad("Mỗi dòng đơn nhập chỉ được ghi một lần.");
            ReceiptRules.validate(line);
            db.one("select id from chi_tiet_don_ncc where id=? and don_ncc_id=?",line.purchaseLineId(),purchase);
            long remaining=db.number("select d.so_luong_dat-coalesce((select sum(c.so_luong_thuc_nhan::bigint+c.so_luong_loai) from chi_tiet_lan_nhap c join lan_nhap_hang r on r.id=c.lan_nhap_id where c.ct_don_ncc_id=d.id and r.trang_thai='CONFIRMED'),0) from chi_tiet_don_ncc d where d.id=?",line.purchaseLineId());
            if((long)line.quantity()+line.rejectedQuantity()>remaining) throw ApiException.bad("Tổng hàng đạt và hàng lỗi vượt số lượng còn phải giao.");
            db.jdbc().update("insert into chi_tiet_lan_nhap(lan_nhap_id,don_ncc_id,ct_don_ncc_id,so_luong_thuc_nhan,gia_nhap_thuc_te,so_luong_loai,ly_do_loai) values (?,?,?,?,?,?,?)",id,purchase,line.purchaseLineId(),line.quantity(),line.actualCost(),line.rejectedQuantity(),line.rejectionReason());
        }
        db.audit(access.account(),"RECEIPT_DRAFT","lan_nhap_hang",id); return receiptDetail(id);
    }
    public Object receipts(int page,int size) {
        var result=db.page("select r.*,n.ten as nha_cung_cap from lan_nhap_hang r join don_dat_hang_ncc o on o.id=r.don_ncc_id join nha_cung_cap n on n.id=o.nha_cung_cap_id order by r.id desc","select count(*) from lan_nhap_hang",List.of(),page,size);
        @SuppressWarnings("unchecked") var items=(List<Map<String,Object>>)result.get("items");
        for(var row:items) row.put("items",receiptLines(Db.n(row,"id")));
        return result;
    }
    private List<Map<String,Object>> receiptLines(long id) {
        return db.rows("select c.*,q.id as quy_cach_id,q.san_pham_id,q.ten_quy_cach,s.ten as ten_san_pham,c.so_luong_thuc_nhan from chi_tiet_lan_nhap c join chi_tiet_don_ncc d on d.id=c.ct_don_ncc_id join quy_cach_san_pham q on q.id=d.quy_cach_id join san_pham s on s.id=q.san_pham_id where c.lan_nhap_id=? order by c.id",id);
    }
    public Object receiptDetail(long id) {
        var r=db.one("select * from lan_nhap_hang where id=?",id);
        r.put("items",receiptLines(id)); return r;
    }
    @Transactional public Object confirm(long receipt) {
        // Lock purchase before receipt, same order as creation; DB trigger handles over-receiving.
        long purchase=Db.n(db.one("select don_ncc_id from lan_nhap_hang where id=?",receipt),"don_ncc_id");
        db.one("select id from don_dat_hang_ncc where id=? for update",purchase);
        var r=db.one("select * from lan_nhap_hang where id=? for update",receipt);
        if("CONFIRMED".equals(r.get("trang_thai"))) return receiptDetail(receipt);
        if(!"DRAFT".equals(r.get("trang_thai"))) throw ApiException.bad("Chi xac nhan lan nhap DRAFT");
        db.jdbc().update("update lan_nhap_hang set trang_thai='CONFIRMED' where id=?",receipt);
        db.audit(access.account(),"RECEIPT_CONFIRM","lan_nhap_hang",receipt); return receiptDetail(receipt);
    }
    @Transactional public Object payDebt(long debt,PurchaseController.DebtPayment r) {
        db.one("select id from cong_no_ncc where id=? for update",debt);
        var d=db.one("select * from cong_no_ncc where id=?",debt);
        if(r.amount().compareTo(Db.money(d,"so_tien_con_no"))>0) throw ApiException.bad("Số tiền vượt công nợ còn lại");
        db.jdbc().update("insert into thanh_toan_ncc(cong_no_id,so_tien,phuong_thuc,ma_tham_chieu) values (?,?,?,?)",debt,r.amount(),r.method(),r.reference());
        db.audit(access.account(),"DEBT_PAYMENT","cong_no_ncc",debt);
        return db.one("select * from cong_no_ncc where id=?",debt);
    }
}

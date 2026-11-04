package vn.drinkstore.management;

import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.drinkstore.common.*;
import vn.drinkstore.security.Access;

/** Only server-defined table/column identifiers enter SQL; user values are always bound. */
@Service
public class ManagementService {
    public record Resource(String table,Set<String> fields,Set<String> required) {}
    private static Resource spec(String table,String fields,String required) {
        return new Resource(table,Set.of(fields.split(",")),Set.of(required.split(",")));
    }
    private static final Map<String,Resource> RESOURCES=Map.ofEntries(
        Map.entry("products",spec("san_pham","sku,loai_san_pham_id,thuong_hieu_id,ten,mo_ta,thanh_phan,dinh_duong,xuat_xu,dung_tich,loai_bao_bi,huong_vi,so_ngay_han_dung,huong_dan_bao_quan,trang_thai,hien_thi","sku,loai_san_pham_id,thuong_hieu_id,ten")),
        Map.entry("packages",spec("quy_cach_san_pham","san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban,gia_von,dang_ban","san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban")),
        Map.entry("supplier-documents",spec("giay_to_ncc","nha_cung_cap_id,loai_giay,so_giay,ngay_cap,ngay_het_han,tep_dinh_kem","nha_cung_cap_id,loai_giay,so_giay")),
        Map.entry("images",spec("hinh_anh_san_pham","san_pham_id,duong_dan,anh_chinh,thu_tu","san_pham_id,duong_dan")),
        Map.entry("categories",spec("loai_san_pham","ten,mo_ta,hinh_anh,hien_thi","ten")),
        Map.entry("brands",spec("thuong_hieu","ten,mo_ta,logo,hien_thi","ten")),
        Map.entry("suppliers",spec("nha_cung_cap","ten,ma_so_thue,nguoi_lien_he,dien_thoai,email,dia_chi,trang_thai,loai_nha_cung_cap,trang_thai_xac_minh,ghi_chu_xac_minh","ten")),
        Map.entry("supplier-products",spec("nha_cung_cap_san_pham","nha_cung_cap_id,san_pham_id,gia_nhap_tham_khao","nha_cung_cap_id,san_pham_id")),
        Map.entry("promotions",spec("khuyen_mai","ma_code,ten,mo_ta,loai_giam,gia_tri_giam,giam_toi_da,don_toi_thieu,bat_dau,ket_thuc,gioi_han_su_dung,gioi_han_moi_khach,pham_vi_ap_dung,trang_thai","ten,loai_giam,gia_tri_giam,bat_dau,ket_thuc")),
        Map.entry("promotion-scopes",spec("pham_vi_khuyen_mai","khuyen_mai_id,san_pham_id,loai_san_pham_id,thuong_hieu_id","khuyen_mai_id"))
    );
    private final Db db; private final Access access;
    public ManagementService(Db db,Access access) { this.db=db; this.access=access; }
    public Resource resource(String name) { var r=RESOURCES.get(name); if(r==null) throw ApiException.missing(); return r; }
    public Object list(String name,int page,int size) {
        var r=resource(name); String order=name.equals("supplier-products")?"nha_cung_cap_id,san_pham_id":"id desc"; return db.page("select * from "+r.table()+" order by "+order,"select count(*) from "+r.table(),List.of(),page,size);
    }
    public Object detail(String name,long id) { if(name.equals("supplier-products")) throw ApiException.bad("Use /supplier-products/{supplierId}/{productId}"); return db.one("select * from "+resource(name).table()+" where id=?",id); }
    private String placeholder(String field) {
        if(Set.of("bat_dau","ket_thuc").contains(field)) return "cast(? as timestamptz)";
        if(Set.of("ngay_cap","ngay_het_han").contains(field)) return "cast(? as date)";
        return "?";
    }
    @Transactional public Object save(String name,Long id,Map<String,Object> body) {
        return saveInternal(name,id,body,false);
    }
    private Object saveInternal(String name,Long id,Map<String,Object> body,boolean verificationConfirmed) {
        var r=resource(name);
        if(name.equals("supplier-products") && id!=null) throw ApiException.bad("Use composite supplier and product IDs");
        if(body.isEmpty() || !r.fields().containsAll(body.keySet())) throw ApiException.bad("Trường không được hỗ trợ; xem docs/API.md. Không sửa số lượng trực tiếp.");
        if(id==null && !body.keySet().containsAll(r.required())) throw ApiException.bad("Thiếu trường bắt buộc: "+r.required());
        for(var key:body.keySet()) {
            var v=body.get(key);
            if(v instanceof Map || v instanceof List || (r.required().contains(key) && (v==null || v.toString().isBlank()))) throw ApiException.bad("Giá trị không hợp lệ: "+key);
        }
        if(id!=null) db.one("select id from "+r.table()+" where id=? for update",id);
        if(name.equals("packages") && id!=null && (body.containsKey("san_pham_id") || body.containsKey("he_so_quy_doi"))) {
            if(db.number("select (select count(*) from chi_tiet_don_hang where quy_cach_id=?) + (select count(*) from chi_tiet_don_ncc where quy_cach_id=?)",id,id)>0) throw ApiException.bad("Create a new package after it has been used in orders");
        }

        if(name.equals("suppliers")) {
            body=new LinkedHashMap<>(body);
            var previous=id==null?new LinkedHashMap<String,Object>():db.one("select * from nha_cung_cap where id=?",id);
            var merged=new LinkedHashMap<>(previous); merged.putAll(body);
            if(body.containsKey("dien_thoai")) PhoneNumbers.validate(body.get("dien_thoai"),false);
            boolean legalChanged=Set.of("ten","dia_chi","ma_so_thue","loai_nha_cung_cap").stream()
                .anyMatch(k->bodyContainsChanged(k,previous,merged));
            String verification=Objects.toString(merged.get("trang_thai_xac_minh"),"CHUA_XAC_MINH");
            if(legalChanged || body.containsKey("trang_thai_xac_minh")) {
                String type=Objects.toString(merged.get("loai_nha_cung_cap"),"DOANH_NGHIEP");
                String tax=SupplierLegalRules.taxCode(type,Objects.toString(merged.get("ma_so_thue"),null));
                if(!Set.of("CHUA_XAC_MINH","DA_XAC_MINH","CAN_KIEM_TRA_LAI").contains(verification)) throw ApiException.bad("Trạng thái xác minh không hợp lệ");
                if(tax!=null) {
                    // All supplier writers serialize duplicate checks, including differently formatted branch codes.
                    db.jdbc().execute("select pg_advisory_xact_lock(77004119)");
                    if(db.number("select count(*) from nha_cung_cap where replace(ma_so_thue,'-','')=? and id<>?",tax.replace("-",""),id==null?0:id)>0)
                        throw new ApiException(org.springframework.http.HttpStatus.CONFLICT,"Mã số thuế / số định danh đã thuộc một nhà cung cấp khác.");
                }
                body.put("ma_so_thue",tax); body.put("loai_nha_cung_cap",type);
                if("DA_XAC_MINH".equals(verification)) {
                    if((legalChanged || !"DA_XAC_MINH".equals(previous.get("trang_thai_xac_minh"))) && !verificationConfirmed)
                        verification="CAN_KIEM_TRA_LAI";
                    else if(tax==null) throw ApiException.bad("Cần mã số thuế / số định danh trước khi xác minh.");
                }
                body.put("trang_thai_xac_minh",verification);
            }
        }
        if(name.equals("promotions") && (id==null || body.containsKey("pham_vi_ap_dung")) && !Set.of("CATEGORY","BRAND").contains(Objects.toString(body.get("pham_vi_ap_dung"),"")))
            throw ApiException.bad("Mã khuyến mãi chỉ áp dụng cho loại sản phẩm hoặc thương hiệu.");
        if(name.equals("promotion-scopes") && body.get("san_pham_id")!=null)
            throw ApiException.bad("Chỉ chọn phạm vi theo loại sản phẩm hoặc thương hiệu.");
        var keys=new ArrayList<>(body.keySet()); Collections.sort(keys);
        var values=new ArrayList<Object>(); for(String k:keys) values.add(body.get(k));
        long result;
        if(name.equals("supplier-products")) {
            if(id!=null) throw ApiException.bad("Use composite supplier and product IDs");
            var saved=db.one("insert into nha_cung_cap_san_pham(nha_cung_cap_id,san_pham_id,gia_nhap_tham_khao) values (?,?,?) returning *",body.get("nha_cung_cap_id"),body.get("san_pham_id"),body.get("gia_nhap_tham_khao"));
            db.audit(access.account(),"CREATE","nha_cung_cap_san_pham",((Number)body.get("nha_cung_cap_id")).longValue());
            return saved;
        }
        if(id==null) result=db.id("insert into "+r.table()+" ("+String.join(",",keys)+") values ("+keys.stream().map(this::placeholder).reduce((a,b)->a+","+b).orElseThrow()+") returning id",values.toArray());
        else {
            values.add(id);
            db.jdbc().update("update "+r.table()+" set "+keys.stream().map(k->k+"="+placeholder(k)).reduce((a,b)->a+","+b).orElseThrow()+" where id=?",values.toArray()); result=id;
        }
        if(name.equals("suppliers") && body.containsKey("trang_thai_xac_minh") && !"DA_XAC_MINH".equals(body.get("trang_thai_xac_minh")))
            db.jdbc().update("update nha_cung_cap set nguoi_xac_minh_id=null,thoi_diem_xac_minh=null where id=?",result);
        db.audit(access.account(),id==null?"CREATE":"UPDATE",r.table(),result);
        return detail(name,result);
    }
    @Transactional public void delete(String name,long id) {
        var r=resource(name); if(name.equals("supplier-products")) throw ApiException.bad("Use composite supplier and product IDs"); db.one("select id from "+r.table()+" where id=? for update",id);
        if(name.equals("products")) {
            if(db.number("select (select count(*) from chi_tiet_don_hang d join quy_cach_san_pham q on q.id=d.quy_cach_id where q.san_pham_id=?) + (select count(*) from chi_tiet_don_ncc d join quy_cach_san_pham q on q.id=d.quy_cach_id where q.san_pham_id=?)",id,id)>0) throw ApiException.bad("San pham da giao dich, hay an san pham");
        }
        db.jdbc().update("delete from "+r.table()+" where id=?",id); db.audit(access.account(),"DELETE",r.table(),id);
    }
    public Object supplierProduct(long supplier,long product) {
        return db.one("select * from nha_cung_cap_san_pham where nha_cung_cap_id=? and san_pham_id=?",supplier,product);
    }
    @Transactional public void deleteSupplierProduct(long supplier,long product) {
        supplierProduct(supplier,product);
        db.jdbc().update("delete from nha_cung_cap_san_pham where nha_cung_cap_id=? and san_pham_id=?",supplier,product);
        db.audit(access.account(),"DELETE","nha_cung_cap_san_pham",supplier);
    }
    @Transactional public Object productEditor(Long id,ManagementController.ProductEditor r) {
        if(!access.admin()) throw new org.springframework.security.access.AccessDeniedException("Admin required");
        db.one("select id from loai_san_pham where id=?",r.categoryId());
        // Take the inventory lock first, matching order/receipt triggers. Reject stale stock edits.
        if(id!=null && r.stock()!=null) {
            long current=db.number("select so_luong_co_ban from so_luong_san_pham where san_pham_id=? for update",id);
            if(r.expectedStock()==null || current!=r.expectedStock()) throw new ApiException(org.springframework.http.HttpStatus.CONFLICT,"Tồn kho đã thay đổi. Đóng form và tải lại sản phẩm trước khi sửa.");
        }
        if(r.imageUrl()!=null && !r.imageUrl().isBlank()) {
            String url=r.imageUrl();
            boolean valid=url.matches("/api/v1/media/products/[a-f0-9-]+\\.(png|jpg|webp)");
            try { var uri=java.net.URI.create(url); valid|=("http".equals(uri.getScheme()) || "https".equals(uri.getScheme())) && uri.getHost()!=null; }
            catch(IllegalArgumentException e) { throw ApiException.bad("Đường dẫn ảnh không hợp lệ"); }
            if(!valid) throw ApiException.bad("Ảnh phải là URL http/https hoặc ảnh được tải lên");
        }
        var brands=db.rows("select id from thuong_hieu where lower(ten)=lower(?) order by id",r.brand());
        long brand=brands.isEmpty()?db.id("insert into thuong_hieu(ten) values (?) returning id",r.brand()):Db.n(brands.getFirst(),"id");
        var fields=new LinkedHashMap<String,Object>();
        fields.put("ten",r.fullName()); fields.put("thuong_hieu_id",brand); fields.put("loai_san_pham_id",r.categoryId());
        fields.put("dung_tich",r.volume()); fields.put("mo_ta",r.description()); fields.put("loai_bao_bi",r.packaging());
        fields.put("trang_thai",r.active()?"DANG_BAN":"NGUNG_KINH_DOANH"); fields.put("hien_thi",r.active());
        if(id==null) fields.put("sku","WB-"+UUID.randomUUID());
        @SuppressWarnings("unchecked") var product=(Map<String,Object>)save("products",id,fields);
        long productId=Db.n(product,"id");
        if(id==null) {
            save("packages",null,Map.of("san_pham_id",productId,"ten_quy_cach",r.packaging()+" lẻ","don_vi_tinh",r.packaging(),"he_so_quy_doi",1,"gia_ban",r.price()));
        } else {
            if(r.packageId()==null) {
                save("packages",null,Map.of("san_pham_id",productId,"ten_quy_cach",r.packaging()+" lẻ","don_vi_tinh",r.packaging(),"he_so_quy_doi",1,"gia_ban",r.price()));
            } else {
                db.one("select id from quy_cach_san_pham where id=? and san_pham_id=?",r.packageId(),productId);
                save("packages",r.packageId(),Map.of("gia_ban",r.price()));
            }
        }
        if(r.imageUrl()!=null && !r.imageUrl().isBlank()) {
            var images=db.rows("select id from hinh_anh_san_pham where san_pham_id=? order by anh_chinh desc,thu_tu,id limit 1",productId);
            db.jdbc().update("update hinh_anh_san_pham set anh_chinh=false where san_pham_id=? and anh_chinh",productId);
            if(images.isEmpty()) db.jdbc().update("insert into hinh_anh_san_pham(san_pham_id,duong_dan,anh_chinh,thu_tu) values (?,?,true,0)",productId,r.imageUrl());
            else db.jdbc().update("update hinh_anh_san_pham set duong_dan=?,anh_chinh=true where id=?",r.imageUrl(),images.getFirst().get("id"));
        }
        if(r.stock()!=null) {
            long current=db.number("select so_luong_co_ban from so_luong_san_pham where san_pham_id=? for update",productId);
            recordStockAdjustment(productId,current,r.stock(),r.stockReason());
        }
        return product;
    }
    @Transactional public Object updateStock(long product,ManagementController.StockUpdate r) {
        if(!access.admin()) throw new org.springframework.security.access.AccessDeniedException("Admin required");
        db.one("select id from san_pham where id=?",product);
        long current=db.number("select so_luong_co_ban from so_luong_san_pham where san_pham_id=? for update",product);
        if(r.expectedStock()==null || current!=r.expectedStock())
            throw new ApiException(org.springframework.http.HttpStatus.CONFLICT,"Tồn kho đã thay đổi. Tải lại danh sách rồi kiểm tra số lượng trước khi lưu.");
        recordStockAdjustment(product,current,r.stock(),r.reason());
        return Map.of("productId",product,"stock",r.stock());
    }
    private void recordStockAdjustment(long product,long current,long stock,String reason) {
        if(current==stock) return;
        if(reason==null || reason.isBlank()) throw ApiException.bad("Nhập lý do điều chỉnh số lượng");
        long pack=db.id("select id from quy_cach_san_pham where san_pham_id=? order by he_so_quy_doi,id limit 1",product);
        long adjustment=db.id("insert into dieu_chinh_so_luong(san_pham_id,quy_cach_id,nguoi_dieu_chinh_id,so_luong_truoc,so_luong_sau,ly_do) values (?,?,?,?,?,?) returning id",product,pack,access.employee(),current,stock,reason.trim());
        db.audit(access.account(),"STOCK_ADJUST","dieu_chinh_so_luong",adjustment);
    }
    private static boolean bodyContainsChanged(String key,Map<String,Object> previous,Map<String,Object> merged) {
        return !Objects.equals(previous.get(key),merged.get(key));
    }
    private static String optional(String text) { return text==null || text.isBlank()?null:text.trim(); }
    public Object checkSupplierTax(Long id,String type,String code) {
        String tax=SupplierLegalRules.taxCode(type,code);
        if(tax==null) throw ApiException.bad("Nhập mã số thuế / số định danh để kiểm tra.");
        boolean duplicate=db.number("select count(*) from nha_cung_cap where replace(ma_so_thue,'-','')=? and id<>?",tax.replace("-",""),id==null?0:id)>0;
        return Map.of("taxCode",tax,"duplicate",duplicate,"message",duplicate?"Mã số đã thuộc một nhà cung cấp khác.":"Đúng định dạng, không trùng mã. Tiếp tục đối chiếu hồ sơ và thông tin trên cổng tra cứu.");
    }
    public java.util.List<Long> supplierProductIds(long id) {
        db.one("select id from nha_cung_cap where id=?",id);
        return db.jdbc().queryForList("select san_pham_id from nha_cung_cap_san_pham where nha_cung_cap_id=? order by san_pham_id",Long.class,id);
    }
    public Object suppliers(int page,int size) {
        return db.page("select n.*,array(select s.san_pham_id from nha_cung_cap_san_pham s where s.nha_cung_cap_id=n.id order by s.san_pham_id) as product_ids from nha_cung_cap n order by n.id desc","select count(*) from nha_cung_cap",List.of(),page,size);
    }
    private void replaceSupplierProducts(long supplier,java.util.List<Long> products) {
        var ids=new LinkedHashSet<>(products);
        for(long product:ids) db.one("select id from san_pham where id=?",product);
        for(long previous:supplierProductIds(supplier))
            if(!ids.contains(previous)) db.jdbc().update("delete from nha_cung_cap_san_pham where nha_cung_cap_id=? and san_pham_id=?",supplier,previous);
        for(long product:ids) db.jdbc().update("insert into nha_cung_cap_san_pham(nha_cung_cap_id,san_pham_id) values (?,?) on conflict (nha_cung_cap_id,san_pham_id) do nothing",supplier,product);
        db.audit(access.account(),"UPDATE_SUPPLIER_PRODUCTS","nha_cung_cap",supplier);
    }
    @Transactional public Object supplierEditor(Long id,ManagementController.SupplierEditor r) {
        var fields=new LinkedHashMap<String,Object>();
        fields.put("ten",r.fullName().trim()); fields.put("ma_so_thue",optional(r.taxCode())); fields.put("nguoi_lien_he",optional(r.contactName()));
        fields.put("dien_thoai",optional(r.phone())); fields.put("email",optional(r.email())); fields.put("dia_chi",optional(r.address())); fields.put("trang_thai",r.status());
        fields.put("loai_nha_cung_cap",r.supplierType()); fields.put("trang_thai_xac_minh",r.verificationStatus()); fields.put("ghi_chu_xac_minh",optional(r.verificationNotes()));
        if("DA_XAC_MINH".equals(r.verificationStatus()) && !r.verificationConfirmed()) throw ApiException.bad("Xác nhận đã đối chiếu hồ sơ và thông tin trên cổng tra cứu.");
        var result=saveInternal("suppliers",id,fields,r.verificationConfirmed());
        @SuppressWarnings("unchecked") var row=(Map<String,Object>)result;
        long saved=Db.n(row,"id");
        if("DA_XAC_MINH".equals(row.get("trang_thai_xac_minh")))
            db.jdbc().update("update nha_cung_cap set nguoi_xac_minh_id=?,thoi_diem_xac_minh=now() where id=?",access.account(),saved);
        else db.jdbc().update("update nha_cung_cap set nguoi_xac_minh_id=null,thoi_diem_xac_minh=null where id=?",saved);
        // Omitted productIds preserves assignments for older clients; [] explicitly clears them.
        if(r.productIds()!=null) replaceSupplierProducts(saved,r.productIds());
        var response=db.one("select * from nha_cung_cap where id=?",saved);
        response.put("product_ids",supplierProductIds(saved));
        return response;
    }
    private String scopeColumn(String scope) {
        return switch(scope) { case "PRODUCT" -> "san_pham_id"; case "CATEGORY" -> "loai_san_pham_id"; case "BRAND" -> "thuong_hieu_id"; default -> throw ApiException.bad("Phạm vi không hợp lệ"); };
    }
    public Object promotions(int page,int size) {
        var result=db.page("select p.*,(select count(*) from su_dung_khuyen_mai u where u.khuyen_mai_id=p.id and u.trang_thai='APPLIED') as luot_da_dung from khuyen_mai p order by p.id desc","select count(*) from khuyen_mai",List.of(),page,size);
        @SuppressWarnings("unchecked") var items=(List<Map<String,Object>>)result.get("items");
        for(var item:items) item.put("scope_ids","ALL".equals(item.get("pham_vi_ap_dung"))?List.of():db.jdbc().queryForList("select "+scopeColumn(item.get("pham_vi_ap_dung").toString())+" from pham_vi_khuyen_mai where khuyen_mai_id=? and "+scopeColumn(item.get("pham_vi_ap_dung").toString())+" is not null order by id",Long.class,item.get("id")));
        return result;
    }
    @Transactional public Object promotionEditor(Long id,ManagementController.PromotionEditor r) {
        if(!Set.of("CATEGORY","BRAND").contains(r.scope())) throw ApiException.bad("Chỉ chọn loại sản phẩm hoặc thương hiệu.");
        if(!r.endsAt().isAfter(r.startsAt())) throw ApiException.bad("Thời gian kết thúc phải sau thời gian bắt đầu");
        if("PERCENT".equals(r.discountType()) && r.value().compareTo(new java.math.BigDecimal("100"))>0) throw ApiException.bad("Mức giảm phần trăm không vượt quá 100%");
        var ids=new LinkedHashSet<>(r.scopeIds());
        if(!"ALL".equals(r.scope()) && ids.isEmpty()) throw ApiException.bad("Chọn ít nhất một đối tượng áp dụng");
        if("ALL".equals(r.scope()) && !ids.isEmpty()) throw ApiException.bad("Phạm vi toàn bộ đơn không nhận danh sách đối tượng");
        if(id!=null) {
            db.one("select id from khuyen_mai where id=? for update",id);
            if(db.number("select count(*) from uu_dai_so_luong where khuyen_mai_id=?",id)>0) throw ApiException.bad("Mã này có quy tắc tặng hàng riêng; không sửa bằng form mã giảm giá");
        }
        if(!ids.isEmpty()) {
            String table=switch(r.scope()) { case "PRODUCT" -> "san_pham"; case "CATEGORY" -> "loai_san_pham"; case "BRAND" -> "thuong_hieu"; default -> throw ApiException.bad("Phạm vi không hợp lệ"); };
            for(Long selected:ids) db.one("select id from "+table+" where id=?",selected);
        }
        var fields=new LinkedHashMap<String,Object>();
        fields.put("ma_code",r.code().toUpperCase(Locale.ROOT)); fields.put("ten",r.fullName().trim()); fields.put("mo_ta",optional(r.description()));
        fields.put("loai_giam",r.discountType()); fields.put("gia_tri_giam",r.value()); fields.put("giam_toi_da",r.maxDiscount()); fields.put("don_toi_thieu",r.minimumOrder());
        fields.put("bat_dau",r.startsAt().toString()); fields.put("ket_thuc",r.endsAt().toString()); fields.put("gioi_han_su_dung",r.totalLimit()); fields.put("gioi_han_moi_khach",r.customerLimit());
        fields.put("pham_vi_ap_dung",r.scope()); fields.put("trang_thai",r.status());
        @SuppressWarnings("unchecked") var row=(Map<String,Object>)save("promotions",id,fields);
        long result=Db.n(row,"id");
        db.jdbc().update("delete from pham_vi_khuyen_mai where khuyen_mai_id=?",result);
        for(Long selected:ids) db.jdbc().update("insert into pham_vi_khuyen_mai(khuyen_mai_id,"+scopeColumn(r.scope())+") values (?,?)",result,selected);
        row.put("scope_ids",List.copyOf(ids));
        return row;
    }

}

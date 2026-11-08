package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.DependsOn;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** Price existing stock only on its next confirmed receipt; historical sales keep their snapshots. */
@Component
@DependsOn("directReceivingSchema")
public class AutomaticPricingSchema {
    public static final String VERSION="20261107_automatic_sale_pricing";
    public static final String DDL="""
CREATE OR REPLACE FUNCTION public.fn_weighted_receipt_cost(old_qty BIGINT,old_cost NUMERIC,incoming_units BIGINT,incoming_value NUMERIC)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE STRICT AS $$
 SELECT round((old_qty*old_cost+incoming_value)/nullif(old_qty+incoming_units,0),2)
$$;
CREATE OR REPLACE FUNCTION public.fn_automatic_sale_price(cost NUMERIC)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE STRICT AS $$ SELECT round(cost*1.25,2) $$;
CREATE OR REPLACE FUNCTION public.fn_package_automatic_price() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 NEW.gia_ban:=public.fn_automatic_sale_price(NEW.gia_von);
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_package_automatic_price ON public.quy_cach_san_pham;
CREATE TRIGGER trg_package_automatic_price BEFORE INSERT OR UPDATE OF gia_von,gia_ban ON public.quy_cach_san_pham
FOR EACH ROW EXECUTE FUNCTION public.fn_package_automatic_price();
CREATE OR REPLACE FUNCTION public.fn_receive_inventory() RETURNS trigger
    LANGUAGE plpgsql SET search_path=public,pg_temp
    AS $$
DECLARE rec RECORD; order_state TEXT; accumulated BIGINT; order_complete BOOLEAN; old_qty BIGINT; old_cost NUMERIC; new_cost NUMERIC; incoming_units BIGINT; incoming_value NUMERIC; priced_products BIGINT[]:='{}';
BEGIN
 IF OLD.trang_thai='CONFIRMED' AND NEW.trang_thai<>'CONFIRMED' THEN
   RAISE EXCEPTION 'Khong duoc huy xac nhan nhap';
 END IF;
 IF NEW.trang_thai <> 'CONFIRMED' OR OLD.trang_thai='CONFIRMED' THEN RETURN NEW; END IF;
 SELECT trang_thai INTO order_state FROM don_dat_hang_ncc WHERE id=NEW.don_ncc_id FOR UPDATE;
 IF order_state NOT IN ('DA_DUYET','DANG_GIAO','DA_NHAN_MOT_PHAN') THEN
  RAISE EXCEPTION 'Don NCC chua duoc duyet hoac da ket thuc';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM chi_tiet_lan_nhap WHERE lan_nhap_id=NEW.id AND (so_luong_thuc_nhan>0 OR so_luong_loai>0)) THEN
  RAISE EXCEPTION 'Lan nhap phai co it nhat mot san pham du dieu kien nhap';
 END IF;
 FOR rec IN
   SELECT ct.id,ct.ct_don_ncc_id,ct.so_luong_thuc_nhan,ct.so_luong_loai,ct.ly_do_loai,ct.gia_nhap_thuc_te,
          d.so_luong_dat,d.he_so_quy_doi,q.san_pham_id
   FROM chi_tiet_lan_nhap ct JOIN chi_tiet_don_ncc d ON d.id=ct.ct_don_ncc_id
   JOIN quy_cach_san_pham q ON q.id=d.quy_cach_id
   WHERE ct.lan_nhap_id=NEW.id ORDER BY q.san_pham_id,d.id LOOP
   SELECT COALESCE(sum(c.so_luong_thuc_nhan::bigint+c.so_luong_loai),0) INTO accumulated
   FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
   WHERE c.ct_don_ncc_id=rec.ct_don_ncc_id AND (l.trang_thai='CONFIRMED' OR l.id=NEW.id);
   IF accumulated > rec.so_luong_dat THEN
    RAISE EXCEPTION 'Nhan vuot so luong dat cho chi tiet %', rec.ct_don_ncc_id;
   END IF;
   IF rec.so_luong_loai>0 AND coalesce(trim(rec.ly_do_loai),'')='' THEN RAISE EXCEPTION 'Can ly do tu choi hang loi'; END IF;
   IF rec.so_luong_thuc_nhan > 0 THEN
     IF NOT (rec.san_pham_id=ANY(priced_products)) THEN
       SELECT so_luong_co_ban INTO old_qty FROM so_luong_san_pham WHERE san_pham_id=rec.san_pham_id FOR UPDATE;
       SELECT gia_von/he_so_quy_doi INTO old_cost FROM quy_cach_san_pham WHERE san_pham_id=rec.san_pham_id ORDER BY he_so_quy_doi,id LIMIT 1;
       SELECT sum(c.so_luong_thuc_nhan::bigint*l.he_so_quy_doi),sum(c.so_luong_thuc_nhan*c.gia_nhap_thuc_te)
         INTO incoming_units,incoming_value
       FROM chi_tiet_lan_nhap c JOIN chi_tiet_don_ncc l ON l.id=c.ct_don_ncc_id
       JOIN quy_cach_san_pham q ON q.id=l.quy_cach_id
       WHERE c.lan_nhap_id=NEW.id AND q.san_pham_id=rec.san_pham_id AND c.so_luong_thuc_nhan>0;
       new_cost:=public.fn_weighted_receipt_cost(old_qty,old_cost,incoming_units,incoming_value);
       UPDATE quy_cach_san_pham SET gia_von=round(new_cost*he_so_quy_doi,2),
         gia_ban=public.fn_automatic_sale_price(round(new_cost*he_so_quy_doi,2)) WHERE san_pham_id=rec.san_pham_id;
       priced_products:=array_append(priced_products,rec.san_pham_id);
     END IF;
     INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
     VALUES(rec.san_pham_id,'NHAP_HANG',rec.id,rec.so_luong_thuc_nhan::bigint*rec.he_so_quy_doi,0,0);
   END IF;
 END LOOP;
 NEW.ngay_xac_nhan:=now();
 RETURN NEW;
END $$;
INSERT INTO public.backend_schema_migration(version) VALUES ('20261107_automatic_sale_pricing') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public AutomaticPricingSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status->{
            jdbc.execute("select pg_advisory_xact_lock(77004122)");
            if(jdbc.queryForObject("select count(*) from public.backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}

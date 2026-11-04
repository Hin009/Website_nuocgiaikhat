package vn.drinkstore.purchasing;

import jakarta.annotation.PostConstruct;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** Versioned, additive upgrade for existing Docker volumes. Fresh installs use the consolidated SQL. */
@Component
public class PurchasingSchema {
    public static final String VERSION = "20261104_supplier_returns_cost";
    public static final String DDL = """

CREATE TABLE IF NOT EXISTS backend_schema_migration (version varchar(100) PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE chi_tiet_lan_nhap ADD COLUMN IF NOT EXISTS ly_do_loai varchar(2000);
ALTER TABLE bien_dong_so_luong DROP CONSTRAINT IF EXISTS bien_dong_so_luong_loai_check;
ALTER TABLE bien_dong_so_luong ADD CONSTRAINT bien_dong_so_luong_loai_check CHECK(loai IN ('BAN_ONLINE','BAN_TAI_QUAY','HUY_DON','NHAP_HANG','DIEU_CHINH','CACH_LY_TRA_NCC','HUY_TRA_NCC'));
CREATE OR REPLACE FUNCTION fn_receive_inventory() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE rec RECORD; order_state TEXT; accumulated BIGINT; order_complete BOOLEAN; old_qty BIGINT; old_cost NUMERIC; new_cost NUMERIC;
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
   SELECT COALESCE(sum(c.so_luong_thuc_nhan),0) INTO accumulated
   FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
   WHERE c.ct_don_ncc_id=rec.ct_don_ncc_id AND (l.trang_thai='CONFIRMED' OR l.id=NEW.id);
   IF accumulated + rec.so_luong_loai > rec.so_luong_dat THEN
    RAISE EXCEPTION 'Nhan vuot so luong dat cho chi tiet %', rec.ct_don_ncc_id;
   END IF;
   IF rec.so_luong_loai>0 AND coalesce(trim(rec.ly_do_loai),'')='' THEN RAISE EXCEPTION 'Can ly do tu choi hang loi'; END IF;
   IF rec.so_luong_thuc_nhan > 0 THEN
     SELECT so_luong_co_ban INTO old_qty FROM so_luong_san_pham WHERE san_pham_id=rec.san_pham_id FOR UPDATE;
     SELECT gia_von/he_so_quy_doi INTO old_cost FROM quy_cach_san_pham WHERE san_pham_id=rec.san_pham_id ORDER BY he_so_quy_doi,id LIMIT 1;
     new_cost := (old_qty*old_cost+rec.so_luong_thuc_nhan*rec.gia_nhap_thuc_te)/(old_qty+rec.so_luong_thuc_nhan::bigint*rec.he_so_quy_doi);
     UPDATE quy_cach_san_pham SET gia_von=round(new_cost*he_so_quy_doi,2) WHERE san_pham_id=rec.san_pham_id;
     INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
     VALUES(rec.san_pham_id,'NHAP_HANG',rec.id,rec.so_luong_thuc_nhan::bigint*rec.he_so_quy_doi,0,0);
   END IF;
 END LOOP;
 NEW.ngay_xac_nhan:=now();
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION fn_receive_finalize() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE all_received BOOLEAN; total_due NUMERIC(18,2);
BEGIN
 IF NEW.trang_thai<>'CONFIRMED' OR OLD.trang_thai='CONFIRMED' THEN RETURN NULL; END IF;
 SELECT NOT EXISTS (
   SELECT 1 FROM chi_tiet_don_ncc d
   WHERE d.don_ncc_id=NEW.don_ncc_id AND d.so_luong_dat > (
     SELECT COALESCE(sum(c.so_luong_thuc_nhan),0)
     FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
     WHERE c.ct_don_ncc_id=d.id AND l.trang_thai='CONFIRMED'
   )
 ) INTO all_received;
 UPDATE don_dat_hang_ncc SET trang_thai=CASE WHEN all_received THEN 'DA_NHAN_DU' ELSE 'DA_NHAN_MOT_PHAN' END
 WHERE id=NEW.don_ncc_id;
 SELECT COALESCE(sum(so_luong_thuc_nhan*gia_nhap_thuc_te),0) INTO total_due
 FROM chi_tiet_lan_nhap WHERE lan_nhap_id=NEW.id;
 INSERT INTO cong_no_ncc(lan_nhap_id,so_tien_phai_tra,so_tien_con_no,trang_thai)
 VALUES(NEW.id,total_due,total_due,CASE WHEN total_due=0 THEN 'DA_TRA' ELSE 'CHUA_TRA' END);
 RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION tao_don_tai_quay(p_ma_don TEXT,p_nhan_vien_id BIGINT,p_phuong_thuc TEXT,p_items JSONB)
 RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE order_id BIGINT; r RECORD; total_amount NUMERIC(18,2):=0; payment_id BIGINT;
BEGIN
 IF p_phuong_thuc NOT IN ('CASH','BANK_TRANSFER','QR') THEN RAISE EXCEPTION 'POS chi ho tro tien mat / chuyen khoan QR'; END IF;
 IF jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'Gio POS rong'; END IF;
 IF NOT EXISTS (SELECT 1 FROM nhan_vien WHERE id=p_nhan_vien_id AND trang_thai='ACTIVE') THEN RAISE EXCEPTION 'Nhan vien khong hop le'; END IF;
 PERFORM set_config('beverage.pos_authorized','1',true);
 INSERT INTO don_hang(ma_don,kenh_ban,nhan_vien_xu_ly_id,trang_thai)
 VALUES(p_ma_don,'TAI_QUAY',p_nhan_vien_id,'HOAN_TAT') RETURNING id INTO order_id;
 -- Tránh direct insert chi tiết bị trigger chặn; logic ghi POS thực hiện bằng guard transaction-local.
 PERFORM set_config('beverage.pos_order_id',order_id::text,true);
 FOR r IN
  SELECT q.id AS quy_cach_id,q.san_pham_id,q.ten_quy_cach,q.he_so_quy_doi,q.gia_ban,q.gia_von,
       s.ten AS ten_san_pham, sum((item->>'so_luong')::int)::int AS qty
  FROM jsonb_array_elements(p_items) AS item
  JOIN quy_cach_san_pham q ON q.id=(item->>'quy_cach_id')::bigint
  JOIN san_pham s ON s.id=q.san_pham_id
  WHERE q.dang_ban AND s.hien_thi AND s.trang_thai='DANG_BAN'
  GROUP BY q.id,s.ten ORDER BY q.san_pham_id,q.id LOOP
   IF r.qty<=0 THEN RAISE EXCEPTION 'So luong POS khong hop le'; END IF;
   PERFORM 1 FROM so_luong_san_pham WHERE san_pham_id=r.san_pham_id FOR UPDATE;
   SELECT gia_von INTO r.gia_von FROM quy_cach_san_pham WHERE id=r.quy_cach_id;
   INSERT INTO chi_tiet_don_hang(don_hang_id,quy_cach_id,ten_san_pham,ten_quy_cach,so_luong,he_so_quy_doi,don_gia,gia_von_don_vi)
   VALUES(order_id,r.quy_cach_id,r.ten_san_pham,r.ten_quy_cach,r.qty,r.he_so_quy_doi,r.gia_ban,r.gia_von);
   total_amount := total_amount + r.qty*r.gia_ban;
 END LOOP;
 IF (SELECT COALESCE(sum((item->>'so_luong')::int),0) FROM jsonb_array_elements(p_items) item) <>
    (SELECT COALESCE(sum(so_luong),0) FROM chi_tiet_don_hang WHERE don_hang_id=order_id) THEN
    RAISE EXCEPTION 'Gio POS co san pham khong hop le hoac ngung ban';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM chi_tiet_don_hang WHERE don_hang_id=order_id) THEN RAISE EXCEPTION 'Gio POS khong co san pham hop le'; END IF;
 FOR r IN
  SELECT q.san_pham_id,sum(c.so_luong::bigint*c.he_so_quy_doi) AS qty
  FROM chi_tiet_don_hang c JOIN quy_cach_san_pham q ON q.id=c.quy_cach_id
  WHERE c.don_hang_id=order_id GROUP BY q.san_pham_id ORDER BY q.san_pham_id LOOP
   INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
   VALUES(r.san_pham_id,'BAN_TAI_QUAY',order_id,-r.qty,0,0);
 END LOOP;
 UPDATE don_hang SET tong_tien=total_amount,da_tru_so_luong=TRUE,ngay_hoan_tat=now() WHERE id=order_id;
 INSERT INTO thanh_toan(don_hang_id,phuong_thuc,so_tien,trang_thai)
 VALUES(order_id,p_phuong_thuc,total_amount,'SUCCESS') RETURNING id INTO payment_id;
 PERFORM lap_hoa_don_tu_don(order_id,p_nhan_vien_id);
 UPDATE hoa_don SET trang_thai='PAID' WHERE don_hang_id=order_id;
 PERFORM set_config('beverage.pos_order_id','',true);
 PERFORM set_config('beverage.pos_authorized','',true);
 RETURN order_id;
END $$;
INSERT INTO backend_schema_migration(version) VALUES ('20261104_supplier_returns_cost') ON CONFLICT DO NOTHING;
        """;
    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    public PurchasingSchema(JdbcTemplate jdbc,org.springframework.transaction.PlatformTransactionManager manager) {
        this.jdbc=jdbc; this.tx=new TransactionTemplate(manager);
    }
    @PostConstruct public void upgrade() {
        tx.executeWithoutResult(status -> {
            jdbc.execute("select pg_advisory_xact_lock(77004120)");
            jdbc.execute("CREATE TABLE IF NOT EXISTS backend_schema_migration (version varchar(100) PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())");
            if(jdbc.queryForObject("select count(*) from backend_schema_migration where version=?",Long.class,VERSION)==0) jdbc.execute(DDL);
        });
    }
}

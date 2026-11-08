-- Complete PostgreSQL schema and data exported from Docker on 20261108-153506 (Asia/Bangkok).
-- PRIVATE SNAPSHOT: includes account hashes, customer data and authentication history.
-- Restore into an EMPTY database only.
-- Product image FILES live in the separate product_images Docker volume.

BEGIN;
--
-- PostgreSQL database dump
--

\restrict HqdEQRc2MRWeNIeRTOQz6p1YufoXSmH0G3awYF0gt3SpV7WvECqxVzND6BQfWlO

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: backend_payment_invoice(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.backend_payment_invoice() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.trang_thai='SUCCESS' AND OLD.trang_thai<>'SUCCESS' THEN
  UPDATE hoa_don SET trang_thai='PAID' WHERE don_hang_id=NEW.don_hang_id AND trang_thai='ISSUED';
 END IF;
 RETURN NEW;
END $$;


--
-- Name: fn_automatic_sale_price(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_automatic_sale_price(cost numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE STRICT
    AS $$ SELECT ceil(cost*1.25/500)*500 $$;


--
-- Name: fn_chi_tiet_hoa_don_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_chi_tiet_hoa_don_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Chi tiet hoa don bat bien'; END IF;
 RETURN NEW;
END $$;


--
-- Name: fn_chong_sua_bien_dong(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_chong_sua_bien_dong() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN RAISE EXCEPTION 'Nhat ky bien dong so luong chi duoc ghi them'; END $$;


--
-- Name: fn_dieu_chinh_so_luong(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_dieu_chinh_so_luong() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE current_qty BIGINT;
BEGIN
 SELECT so_luong_co_ban INTO current_qty FROM so_luong_san_pham WHERE san_pham_id=NEW.san_pham_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Chua co ban ghi so luong cho san pham %',NEW.san_pham_id; END IF;
 NEW.so_luong_truoc := current_qty;
 IF NEW.so_luong_sau <> current_qty THEN
   INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
   VALUES(NEW.san_pham_id,'DIEU_CHINH',NEW.id,NEW.so_luong_sau-current_qty,current_qty,NEW.so_luong_sau);
 END IF;
 RETURN NEW;
END $$;


--
-- Name: fn_hoa_don_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_hoa_don_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Khong duoc xoa hoa don noi bo'; END IF;
 IF ROW(NEW.don_hang_id,NEW.nguoi_lap_id,NEW.ma_hoa_don,NEW.ngay_lap,NEW.kenh_ban,NEW.tong_thanh_toan,NEW.phi_van_chuyen,NEW.giam_gia)
    IS DISTINCT FROM ROW(OLD.don_hang_id,OLD.nguoi_lap_id,OLD.ma_hoa_don,OLD.ngay_lap,OLD.kenh_ban,OLD.tong_thanh_toan,OLD.phi_van_chuyen,OLD.giam_gia) THEN
   RAISE EXCEPTION 'Khong duoc sua noi dung hoa don';
 END IF;
 RETURN NEW;
END $$;


--
-- Name: fn_immutable_posted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_immutable_posted() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN RAISE EXCEPTION 'Chung tu da ghi so khong duoc sua/xoa'; END $$;


--
-- Name: fn_invoice_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_invoice_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.trang_thai IS DISTINCT FROM OLD.trang_thai THEN
   INSERT INTO lich_su_hoa_don(hoa_don_id,trang_thai_cu,trang_thai_moi,ly_do)
   VALUES(NEW.id,OLD.trang_thai,NEW.trang_thai,'Cap nhat trang thai theo nghiep vu don hang');
 END IF;
 RETURN NULL;
END $$;


--
-- Name: fn_khoi_tao_so_luong(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_khoi_tao_so_luong() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 INSERT INTO so_luong_san_pham(san_pham_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$;


--
-- Name: fn_order_history(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_order_history() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF NEW.trang_thai IS DISTINCT FROM OLD.trang_thai THEN
  INSERT INTO lich_su_trang_thai_don(don_hang_id,trang_thai_cu,trang_thai_moi)
  VALUES(NEW.id,OLD.trang_thai,NEW.trang_thai);
  IF NEW.kenh_ban='ONLINE' AND NEW.trang_thai='DANG_CHUAN_BI' THEN
    PERFORM lap_hoa_don_tu_don(NEW.id,NEW.nhan_vien_xu_ly_id);
  END IF;
  IF NEW.trang_thai IN ('DA_HUY','TU_CHOI') THEN
    UPDATE su_dung_khuyen_mai SET trang_thai='REVERSED' WHERE don_hang_id=NEW.id AND trang_thai='APPLIED';
    UPDATE hoa_don SET trang_thai='CANCELLED' WHERE don_hang_id=NEW.id AND trang_thai<>'CANCELLED';
  END IF;
 END IF;
 RETURN NULL;
END $$;


--
-- Name: fn_order_inventory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_order_inventory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r RECORD; sign_qty INT; kind VARCHAR(30);
BEGIN
 IF TG_OP='INSERT' THEN
   IF NEW.kenh_ban='ONLINE' AND NEW.trang_thai <> 'CHO_XAC_NHAN' THEN
      RAISE EXCEPTION 'Don online phai bat dau CHO_XAC_NHAN';
   END IF;
   IF NEW.kenh_ban='TAI_QUAY' AND (NEW.trang_thai <> 'HOAN_TAT'
      OR current_setting('beverage.pos_authorized',true) IS DISTINCT FROM '1') THEN
      RAISE EXCEPTION 'Don POS phai duoc tao qua nghiep vu POS';
   END IF;
   RETURN NEW;
 END IF;
 IF NEW.trang_thai=OLD.trang_thai THEN RETURN NEW; END IF;
 IF OLD.kenh_ban <> NEW.kenh_ban THEN RAISE EXCEPTION 'Khong duoc doi kenh ban'; END IF;
 IF OLD.trang_thai IN ('DA_HUY','TU_CHOI','HOAN_TAT') THEN
   RAISE EXCEPTION 'Khong duoc chuyen tu trang thai ket thuc';
 END IF;
 -- Don online chi tru khi xac nhan; POS da hoan tat duoc xu ly qua function POS rieng.
 IF NEW.kenh_ban='ONLINE' AND NEW.trang_thai='DANG_CHUAN_BI' AND NOT OLD.da_tru_so_luong THEN
   IF OLD.trang_thai<>'CHO_XAC_NHAN' THEN RAISE EXCEPTION 'Chi duoc xac nhan don dang cho'; END IF;
   IF NOT EXISTS(SELECT 1 FROM chi_tiet_don_hang WHERE don_hang_id=NEW.id) THEN RAISE EXCEPTION 'Don chua co chi tiet'; END IF;
   FOR r IN SELECT q.san_pham_id,sum(ct.so_luong::bigint*ct.he_so_quy_doi) AS qty
     FROM chi_tiet_don_hang ct JOIN quy_cach_san_pham q ON q.id=ct.quy_cach_id
     WHERE ct.don_hang_id=NEW.id GROUP BY q.san_pham_id ORDER BY q.san_pham_id LOOP
       INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
       VALUES(r.san_pham_id,'BAN_ONLINE',NEW.id,-r.qty,0,0);
   END LOOP;
   NEW.da_tru_so_luong:=TRUE;
 ELSIF NEW.trang_thai IN ('DA_HUY','TU_CHOI') AND OLD.da_tru_so_luong THEN
   FOR r IN SELECT q.san_pham_id,sum(ct.so_luong::bigint*ct.he_so_quy_doi) AS qty
     FROM chi_tiet_don_hang ct JOIN quy_cach_san_pham q ON q.id=ct.quy_cach_id
     WHERE ct.don_hang_id=NEW.id GROUP BY q.san_pham_id ORDER BY q.san_pham_id LOOP
       INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
       VALUES(r.san_pham_id,'HUY_DON',NEW.id,r.qty,0,0);
   END LOOP;
   NEW.da_tru_so_luong:=FALSE;
 END IF;
 NEW.ngay_cap_nhat:=now();
 RETURN NEW;
END $$;


--
-- Name: fn_package_automatic_price(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_package_automatic_price() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 NEW.gia_ban:=public.fn_automatic_sale_price(NEW.gia_von);
 RETURN NEW;
END $$;


--
-- Name: fn_protect_order_lines(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_order_lines() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE o don_hang%ROWTYPE;
BEGIN
 SELECT * INTO o FROM don_hang WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.don_hang_id ELSE NEW.don_hang_id END;
 IF (o.kenh_ban='TAI_QUAY' AND current_setting('beverage.pos_order_id',true) IS DISTINCT FROM o.id::text)
    OR (o.kenh_ban<>'TAI_QUAY' AND o.trang_thai <> 'CHO_XAC_NHAN') THEN
   RAISE EXCEPTION 'Khong duoc sua chi tiet don da xac nhan hoac tai quay';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;


--
-- Name: fn_protect_received_lines(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_received_lines() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE status_now TEXT;
BEGIN
 SELECT trang_thai INTO status_now FROM lan_nhap_hang
 WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.lan_nhap_id ELSE NEW.lan_nhap_id END;
 IF status_now='CONFIRMED' THEN RAISE EXCEPTION 'Khong duoc sua chi tiet lan nhap da xac nhan'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;


--
-- Name: fn_receive_finalize(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_receive_finalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE all_received BOOLEAN; total_due NUMERIC(18,2);
BEGIN
 IF NEW.trang_thai<>'CONFIRMED' OR OLD.trang_thai='CONFIRMED' THEN RETURN NULL; END IF;
 SELECT NOT EXISTS (
   SELECT 1 FROM chi_tiet_don_ncc d
   WHERE d.don_ncc_id=NEW.don_ncc_id AND d.so_luong_dat > (
     SELECT COALESCE(sum(c.so_luong_thuc_nhan::bigint+c.so_luong_loai),0)
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


--
-- Name: fn_receive_inventory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_receive_inventory() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
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


--
-- Name: fn_so_luong_bien_dong(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_so_luong_bien_dong() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE current_qty BIGINT;
BEGIN
  INSERT INTO so_luong_san_pham(san_pham_id) VALUES(NEW.san_pham_id) ON CONFLICT DO NOTHING;
  SELECT so_luong_co_ban INTO current_qty FROM so_luong_san_pham WHERE san_pham_id=NEW.san_pham_id FOR UPDATE;
  IF current_qty + NEW.so_luong_thay_doi < 0 THEN
    RAISE EXCEPTION 'Khong du so luong san pham %: co %, can thay doi %', NEW.san_pham_id,current_qty,NEW.so_luong_thay_doi;
  END IF;
  NEW.so_luong_truoc := current_qty;
  NEW.so_luong_sau := current_qty + NEW.so_luong_thay_doi;
  UPDATE so_luong_san_pham SET so_luong_co_ban=NEW.so_luong_sau,ngay_cap_nhat=now() WHERE san_pham_id=NEW.san_pham_id;
  RETURN NEW;
END $$;


--
-- Name: fn_supplier_payment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_supplier_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 UPDATE cong_no_ncc SET so_tien_con_no=so_tien_con_no-NEW.so_tien,
 trang_thai=CASE WHEN so_tien_con_no-NEW.so_tien=0 THEN 'DA_TRA' ELSE 'TRA_MOT_PHAN' END
 WHERE id=NEW.cong_no_id AND so_tien_con_no>=NEW.so_tien;
 IF NOT FOUND THEN RAISE EXCEPTION 'Thanh toan vuot cong no'; END IF;
 RETURN NEW;
END $$;


--
-- Name: fn_weighted_receipt_cost(bigint, numeric, bigint, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_weighted_receipt_cost(old_qty bigint, old_cost numeric, incoming_units bigint, incoming_value numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
 SELECT round((old_qty*old_cost+incoming_value)/nullif(old_qty+incoming_units,0),2)
$$;


--
-- Name: lap_hoa_don_tu_don(bigint, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lap_hoa_don_tu_don(p_don_hang_id bigint, p_nhan_vien_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE invoice_id BIGINT; od don_hang%ROWTYPE;
BEGIN
 SELECT * INTO od FROM don_hang WHERE id=p_don_hang_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Khong tim thay don hang'; END IF;
 IF (od.kenh_ban='ONLINE' AND od.trang_thai NOT IN ('DANG_CHUAN_BI','DANG_GIAO','DA_GIAO'))
    OR (od.kenh_ban='TAI_QUAY' AND od.trang_thai<>'HOAN_TAT') THEN
    RAISE EXCEPTION 'Don hang chua du dieu kien lap hoa don';
 END IF;
 SELECT id INTO invoice_id FROM hoa_don WHERE don_hang_id=p_don_hang_id;
 IF invoice_id IS NOT NULL THEN RETURN invoice_id; END IF;
 INSERT INTO hoa_don(don_hang_id,nguoi_lap_id,ma_hoa_don,kenh_ban,tong_thanh_toan,phi_van_chuyen,giam_gia)
 VALUES(od.id,p_nhan_vien_id,'HD-'||od.id,od.kenh_ban,od.tong_tien,od.phi_van_chuyen,od.giam_gia)
 RETURNING id INTO invoice_id;
 INSERT INTO chi_tiet_hoa_don(hoa_don_id,chi_tiet_don_hang_id,ten_san_pham,ten_quy_cach,so_luong,don_gia)
 SELECT invoice_id,c.id,c.ten_san_pham,c.ten_quy_cach,c.so_luong,c.don_gia
 FROM chi_tiet_don_hang c WHERE c.don_hang_id=od.id;
 RETURN invoice_id;
END $$;


--
-- Name: tao_don_tai_quay(text, bigint, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tao_don_tai_quay(p_ma_don text, p_nhan_vien_id bigint, p_phuong_thuc text, p_items jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: backend_schema_migration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backend_schema_migration (
    version character varying(100) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: bien_dong_so_luong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bien_dong_so_luong (
    id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    loai character varying(30) NOT NULL,
    nguon_id bigint NOT NULL,
    so_luong_thay_doi bigint NOT NULL,
    so_luong_truoc bigint NOT NULL,
    so_luong_sau bigint NOT NULL,
    thoi_diem timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT bien_dong_so_luong_check CHECK ((so_luong_sau = (so_luong_truoc + so_luong_thay_doi))),
    CONSTRAINT bien_dong_so_luong_loai_check CHECK (((loai)::text = ANY ((ARRAY['BAN_ONLINE'::character varying, 'BAN_TAI_QUAY'::character varying, 'HUY_DON'::character varying, 'NHAP_HANG'::character varying, 'DIEU_CHINH'::character varying, 'CACH_LY_TRA_NCC'::character varying, 'HUY_TRA_NCC'::character varying])::text[]))),
    CONSTRAINT bien_dong_so_luong_so_luong_sau_check CHECK ((so_luong_sau >= 0)),
    CONSTRAINT bien_dong_so_luong_so_luong_thay_doi_check CHECK ((so_luong_thay_doi <> 0)),
    CONSTRAINT bien_dong_so_luong_so_luong_truoc_check CHECK ((so_luong_truoc >= 0))
);


--
-- Name: bien_dong_so_luong_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.bien_dong_so_luong ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.bien_dong_so_luong_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chi_tiet_don_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_don_hang (
    id bigint NOT NULL,
    don_hang_id bigint NOT NULL,
    quy_cach_id bigint NOT NULL,
    ten_san_pham character varying(255) NOT NULL,
    ten_quy_cach character varying(60) NOT NULL,
    so_luong integer NOT NULL,
    he_so_quy_doi integer NOT NULL,
    don_gia numeric(18,2) NOT NULL,
    gia_von_don_vi numeric(18,2) NOT NULL,
    thanh_tien numeric(18,2) GENERATED ALWAYS AS (((so_luong)::numeric * don_gia)) STORED,
    CONSTRAINT chi_tiet_don_hang_don_gia_check CHECK ((don_gia >= (0)::numeric)),
    CONSTRAINT chi_tiet_don_hang_gia_von_don_vi_check CHECK ((gia_von_don_vi >= (0)::numeric)),
    CONSTRAINT chi_tiet_don_hang_he_so_quy_doi_check CHECK ((he_so_quy_doi > 0)),
    CONSTRAINT chi_tiet_don_hang_so_luong_check CHECK ((so_luong > 0))
);


--
-- Name: chi_tiet_don_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_don_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.chi_tiet_don_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chi_tiet_don_ncc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_don_ncc (
    id bigint NOT NULL,
    don_ncc_id bigint NOT NULL,
    quy_cach_id bigint NOT NULL,
    so_luong_dat integer NOT NULL,
    he_so_quy_doi integer NOT NULL,
    gia_nhap_du_kien numeric(18,2) NOT NULL,
    CONSTRAINT chi_tiet_don_ncc_gia_nhap_du_kien_check CHECK ((gia_nhap_du_kien >= (0)::numeric)),
    CONSTRAINT chi_tiet_don_ncc_he_so_quy_doi_check CHECK ((he_so_quy_doi > 0)),
    CONSTRAINT chi_tiet_don_ncc_so_luong_dat_check CHECK ((so_luong_dat > 0))
);


--
-- Name: chi_tiet_don_ncc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_don_ncc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.chi_tiet_don_ncc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chi_tiet_gio_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_gio_hang (
    id bigint NOT NULL,
    gio_hang_id bigint NOT NULL,
    quy_cach_id bigint NOT NULL,
    so_luong integer NOT NULL,
    gia_tam_tinh numeric(18,2) NOT NULL,
    CONSTRAINT chi_tiet_gio_hang_gia_tam_tinh_check CHECK ((gia_tam_tinh >= (0)::numeric)),
    CONSTRAINT chi_tiet_gio_hang_so_luong_check CHECK ((so_luong > 0))
);


--
-- Name: chi_tiet_gio_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_gio_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.chi_tiet_gio_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chi_tiet_hoa_don; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_hoa_don (
    id bigint NOT NULL,
    hoa_don_id bigint NOT NULL,
    chi_tiet_don_hang_id bigint NOT NULL,
    ten_san_pham character varying(255) NOT NULL,
    ten_quy_cach character varying(60) NOT NULL,
    so_luong integer NOT NULL,
    don_gia numeric(18,2) NOT NULL,
    thanh_tien numeric(18,2) GENERATED ALWAYS AS (((so_luong)::numeric * don_gia)) STORED,
    CONSTRAINT chi_tiet_hoa_don_don_gia_check CHECK ((don_gia >= (0)::numeric)),
    CONSTRAINT chi_tiet_hoa_don_so_luong_check CHECK ((so_luong > 0))
);


--
-- Name: chi_tiet_hoa_don_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_hoa_don ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.chi_tiet_hoa_don_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chi_tiet_lan_nhap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_lan_nhap (
    id bigint NOT NULL,
    lan_nhap_id bigint NOT NULL,
    don_ncc_id bigint NOT NULL,
    ct_don_ncc_id bigint NOT NULL,
    so_luong_thuc_nhan integer NOT NULL,
    so_luong_loai integer DEFAULT 0 NOT NULL,
    chenh_lech integer DEFAULT 0 NOT NULL,
    gia_nhap_thuc_te numeric(18,2) NOT NULL,
    ly_do_loai character varying(2000),
    ngay_san_xuat date,
    ngay_het_han date,
    CONSTRAINT chi_tiet_lan_nhap_gia_nhap_thuc_te_check CHECK ((gia_nhap_thuc_te >= (0)::numeric)),
    CONSTRAINT chi_tiet_lan_nhap_so_luong_loai_check CHECK ((so_luong_loai >= 0)),
    CONSTRAINT chi_tiet_lan_nhap_so_luong_thuc_nhan_check CHECK ((so_luong_thuc_nhan >= 0)),
    CONSTRAINT receipt_product_dates_check CHECK ((((ngay_san_xuat IS NULL) AND (ngay_het_han IS NULL)) OR ((ngay_san_xuat IS NOT NULL) AND (ngay_het_han IS NOT NULL) AND (ngay_het_han >= ngay_san_xuat))))
);


--
-- Name: chi_tiet_lan_nhap_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_lan_nhap ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.chi_tiet_lan_nhap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cong_no_ncc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cong_no_ncc (
    id bigint NOT NULL,
    lan_nhap_id bigint NOT NULL,
    so_tien_phai_tra numeric(18,2) NOT NULL,
    so_tien_con_no numeric(18,2) NOT NULL,
    han_thanh_toan date,
    trang_thai character varying(20) DEFAULT 'CHUA_TRA'::character varying NOT NULL,
    CONSTRAINT cong_no_ncc_check CHECK ((so_tien_con_no <= so_tien_phai_tra)),
    CONSTRAINT cong_no_ncc_so_tien_con_no_check CHECK ((so_tien_con_no >= (0)::numeric)),
    CONSTRAINT cong_no_ncc_so_tien_phai_tra_check CHECK ((so_tien_phai_tra >= (0)::numeric)),
    CONSTRAINT cong_no_ncc_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['CHUA_TRA'::character varying, 'TRA_MOT_PHAN'::character varying, 'DA_TRA'::character varying])::text[])))
);


--
-- Name: cong_no_ncc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cong_no_ncc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cong_no_ncc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: danh_gia_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.danh_gia_san_pham (
    id bigint NOT NULL,
    khach_hang_id bigint NOT NULL,
    chi_tiet_don_hang_id bigint NOT NULL,
    so_sao integer NOT NULL,
    noi_dung text,
    trang_thai character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    ngay_danh_gia timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT danh_gia_san_pham_so_sao_check CHECK (((so_sao >= 1) AND (so_sao <= 5))),
    CONSTRAINT danh_gia_san_pham_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'HIDDEN'::character varying])::text[])))
);


--
-- Name: danh_gia_san_pham_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.danh_gia_san_pham ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.danh_gia_san_pham_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dia_chi_giao_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dia_chi_giao_hang (
    id bigint NOT NULL,
    khach_hang_id bigint NOT NULL,
    ten_nguoi_nhan character varying(150) NOT NULL,
    so_dien_thoai character varying(25),
    dia_chi text NOT NULL,
    phuong_xa character varying(150),
    quan_huyen character varying(150),
    tinh_thanh character varying(150),
    mac_dinh boolean DEFAULT false NOT NULL
);


--
-- Name: dia_chi_giao_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dia_chi_giao_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dia_chi_giao_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dieu_chinh_so_luong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dieu_chinh_so_luong (
    id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    quy_cach_id bigint NOT NULL,
    nguoi_dieu_chinh_id bigint NOT NULL,
    so_luong_truoc bigint NOT NULL,
    so_luong_sau bigint NOT NULL,
    chenh_lech bigint GENERATED ALWAYS AS ((so_luong_sau - so_luong_truoc)) STORED,
    ly_do text NOT NULL,
    thoi_diem timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dieu_chinh_so_luong_ly_do_check CHECK ((length(TRIM(BOTH FROM ly_do)) > 0)),
    CONSTRAINT dieu_chinh_so_luong_so_luong_sau_check CHECK ((so_luong_sau >= 0)),
    CONSTRAINT dieu_chinh_so_luong_so_luong_truoc_check CHECK ((so_luong_truoc >= 0))
);


--
-- Name: dieu_chinh_so_luong_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.dieu_chinh_so_luong ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.dieu_chinh_so_luong_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: don_dat_hang_ncc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.don_dat_hang_ncc (
    id bigint NOT NULL,
    ma_don_nhap character varying(50) NOT NULL,
    nha_cung_cap_id bigint NOT NULL,
    nguoi_lap_id bigint NOT NULL,
    nguoi_duyet_id bigint,
    ngay_dat timestamp with time zone DEFAULT now() NOT NULL,
    ngay_giao_du_kien date,
    trang_thai character varying(30) DEFAULT 'DA_DUYET'::character varying NOT NULL,
    ly_do_tu_choi text,
    ghi_chu text,
    ngay_duyet timestamp with time zone,
    CONSTRAINT don_dat_hang_ncc_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['CHO_DUYET'::character varying, 'DA_DUYET'::character varying, 'TU_CHOI'::character varying, 'DANG_GIAO'::character varying, 'DA_NHAN_MOT_PHAN'::character varying, 'DA_NHAN_DU'::character varying, 'DA_HUY'::character varying])::text[])))
);


--
-- Name: don_dat_hang_ncc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.don_dat_hang_ncc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.don_dat_hang_ncc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: don_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.don_hang (
    id bigint NOT NULL,
    ma_don character varying(50) NOT NULL,
    kenh_ban character varying(12) NOT NULL,
    khach_hang_id bigint,
    nhan_vien_xu_ly_id bigint,
    ngay_dat timestamp with time zone DEFAULT now() NOT NULL,
    ngay_hoan_tat timestamp with time zone,
    trang_thai character varying(25) NOT NULL,
    phi_van_chuyen numeric(18,2) DEFAULT 0 NOT NULL,
    giam_gia numeric(18,2) DEFAULT 0 NOT NULL,
    tong_tien numeric(18,2) DEFAULT 0 NOT NULL,
    ghi_chu text,
    ten_nguoi_nhan character varying(150),
    sdt_nguoi_nhan character varying(25),
    dia_chi_nhan text,
    thoi_gian_nhan_du_kien timestamp with time zone,
    da_tru_so_luong boolean DEFAULT false NOT NULL,
    ngay_cap_nhat timestamp with time zone DEFAULT now() NOT NULL,
    khuyen_mai_id bigint,
    CONSTRAINT don_hang_check CHECK (((((kenh_ban)::text = 'ONLINE'::text) AND (khach_hang_id IS NOT NULL) AND (dia_chi_nhan IS NOT NULL)) OR (((kenh_ban)::text = 'TAI_QUAY'::text) AND (nhan_vien_xu_ly_id IS NOT NULL)))),
    CONSTRAINT don_hang_check1 CHECK ((((kenh_ban)::text <> 'TAI_QUAY'::text) OR ((trang_thai)::text = ANY ((ARRAY['HOAN_TAT'::character varying, 'DA_HUY'::character varying])::text[])))),
    CONSTRAINT don_hang_giam_gia_check CHECK ((giam_gia >= (0)::numeric)),
    CONSTRAINT don_hang_kenh_ban_check CHECK (((kenh_ban)::text = ANY ((ARRAY['ONLINE'::character varying, 'TAI_QUAY'::character varying])::text[]))),
    CONSTRAINT don_hang_phi_van_chuyen_check CHECK ((phi_van_chuyen >= (0)::numeric)),
    CONSTRAINT don_hang_tong_tien_check CHECK ((tong_tien >= (0)::numeric)),
    CONSTRAINT don_hang_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['CHO_XAC_NHAN'::character varying, 'DANG_CHUAN_BI'::character varying, 'DANG_GIAO'::character varying, 'DA_GIAO'::character varying, 'HOAN_TAT'::character varying, 'DA_HUY'::character varying, 'TU_CHOI'::character varying])::text[])))
);


--
-- Name: don_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.don_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.don_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: giay_to_ncc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.giay_to_ncc (
    id bigint NOT NULL,
    nha_cung_cap_id bigint NOT NULL,
    loai_giay character varying(100) NOT NULL,
    so_giay character varying(120) NOT NULL,
    ngay_cap date,
    ngay_het_han date,
    tep_dinh_kem text,
    CONSTRAINT giay_to_ncc_check CHECK (((ngay_het_han IS NULL) OR (ngay_cap IS NULL) OR (ngay_het_han >= ngay_cap)))
);


--
-- Name: giay_to_ncc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.giay_to_ncc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.giay_to_ncc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: gio_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gio_hang (
    id bigint NOT NULL,
    khach_hang_id bigint NOT NULL,
    ngay_cap_nhat timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: gio_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.gio_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.gio_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hinh_anh_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hinh_anh_san_pham (
    id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    duong_dan text NOT NULL,
    anh_chinh boolean DEFAULT false NOT NULL,
    thu_tu integer DEFAULT 0 NOT NULL
);


--
-- Name: hinh_anh_san_pham_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.hinh_anh_san_pham ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.hinh_anh_san_pham_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hoa_don; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hoa_don (
    id bigint NOT NULL,
    don_hang_id bigint NOT NULL,
    nguoi_lap_id bigint,
    ma_hoa_don character varying(50) NOT NULL,
    ngay_lap timestamp with time zone DEFAULT now() NOT NULL,
    kenh_ban character varying(12) NOT NULL,
    tong_thanh_toan numeric(18,2) NOT NULL,
    phi_van_chuyen numeric(18,2) DEFAULT 0 NOT NULL,
    giam_gia numeric(18,2) DEFAULT 0 NOT NULL,
    trang_thai character varying(20) DEFAULT 'ISSUED'::character varying NOT NULL,
    CONSTRAINT hoa_don_kenh_ban_check CHECK (((kenh_ban)::text = ANY ((ARRAY['ONLINE'::character varying, 'TAI_QUAY'::character varying])::text[]))),
    CONSTRAINT hoa_don_tong_thanh_toan_check CHECK ((tong_thanh_toan >= (0)::numeric)),
    CONSTRAINT hoa_don_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['ISSUED'::character varying, 'PAID'::character varying, 'CANCELLED'::character varying])::text[])))
);


--
-- Name: hoa_don_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.hoa_don ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.hoa_don_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hoan_tien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hoan_tien (
    id bigint NOT NULL,
    thanh_toan_id bigint NOT NULL,
    nguoi_xu_ly_id bigint NOT NULL,
    ly_do text NOT NULL,
    so_tien numeric(18,2) NOT NULL,
    trang_thai character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    ngay_yeu_cau timestamp with time zone DEFAULT now() NOT NULL,
    ngay_hoan timestamp with time zone,
    CONSTRAINT hoan_tien_so_tien_check CHECK ((so_tien > (0)::numeric)),
    CONSTRAINT hoan_tien_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'COMPLETED'::character varying, 'REJECTED'::character varying])::text[])))
);


--
-- Name: hoan_tien_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.hoan_tien ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.hoan_tien_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: khach_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khach_hang (
    id bigint NOT NULL,
    tai_khoan_id bigint NOT NULL,
    ho_ten character varying(150) NOT NULL,
    dien_thoai character varying(25),
    anh_dai_dien text,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: khach_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.khach_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.khach_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: khuyen_mai; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khuyen_mai (
    id bigint NOT NULL,
    ma_code character varying(60),
    ten character varying(150) NOT NULL,
    mo_ta text,
    loai_giam character varying(15) NOT NULL,
    gia_tri_giam numeric(18,2) NOT NULL,
    giam_toi_da numeric(18,2),
    don_toi_thieu numeric(18,2) DEFAULT 0 NOT NULL,
    bat_dau timestamp with time zone NOT NULL,
    ket_thuc timestamp with time zone NOT NULL,
    gioi_han_su_dung integer,
    gioi_han_moi_khach integer,
    pham_vi_ap_dung character varying(20) DEFAULT 'ALL'::character varying NOT NULL,
    trang_thai character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    CONSTRAINT khuyen_mai_check CHECK ((ket_thuc > bat_dau)),
    CONSTRAINT khuyen_mai_check1 CHECK ((((loai_giam)::text <> 'PERCENT'::text) OR (gia_tri_giam <= (100)::numeric))),
    CONSTRAINT khuyen_mai_don_toi_thieu_check CHECK ((don_toi_thieu >= (0)::numeric)),
    CONSTRAINT khuyen_mai_gia_tri_giam_check CHECK ((gia_tri_giam >= (0)::numeric)),
    CONSTRAINT khuyen_mai_giam_toi_da_check CHECK ((giam_toi_da >= (0)::numeric)),
    CONSTRAINT khuyen_mai_gioi_han_moi_khach_check CHECK ((gioi_han_moi_khach >= 0)),
    CONSTRAINT khuyen_mai_gioi_han_su_dung_check CHECK ((gioi_han_su_dung >= 0)),
    CONSTRAINT khuyen_mai_loai_giam_check CHECK (((loai_giam)::text = ANY ((ARRAY['PERCENT'::character varying, 'FIXED'::character varying])::text[]))),
    CONSTRAINT khuyen_mai_pham_vi_ap_dung_check CHECK (((pham_vi_ap_dung)::text = ANY ((ARRAY['ALL'::character varying, 'PRODUCT'::character varying, 'CATEGORY'::character varying, 'BRAND'::character varying])::text[]))),
    CONSTRAINT khuyen_mai_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[])))
);


--
-- Name: khuyen_mai_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.khuyen_mai ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.khuyen_mai_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lan_nhap_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lan_nhap_hang (
    id bigint NOT NULL,
    don_ncc_id bigint NOT NULL,
    nguoi_nhan_id bigint NOT NULL,
    ngay_nhap timestamp with time zone DEFAULT now() NOT NULL,
    trang_thai character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    ngay_xac_nhan timestamp with time zone,
    ghi_chu text,
    CONSTRAINT lan_nhap_hang_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['DRAFT'::character varying, 'CONFIRMED'::character varying, 'CANCELLED'::character varying])::text[])))
);


--
-- Name: lan_nhap_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lan_nhap_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lan_nhap_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lich_su_hoa_don; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lich_su_hoa_don (
    id bigint NOT NULL,
    hoa_don_id bigint NOT NULL,
    tai_khoan_thuc_hien_id bigint,
    trang_thai_cu character varying(20),
    trang_thai_moi character varying(20) NOT NULL,
    ly_do text NOT NULL,
    thoi_gian timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lich_su_hoa_don_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lich_su_hoa_don ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lich_su_hoa_don_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lich_su_trang_thai_don; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lich_su_trang_thai_don (
    id bigint NOT NULL,
    don_hang_id bigint NOT NULL,
    tai_khoan_thuc_hien_id bigint,
    trang_thai_cu character varying(25),
    trang_thai_moi character varying(25) NOT NULL,
    ghi_chu text,
    thoi_gian timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: lich_su_trang_thai_don_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lich_su_trang_thai_don ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lich_su_trang_thai_don_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lien_he_khach_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lien_he_khach_hang (
    id bigint NOT NULL,
    khach_hang_id bigint,
    ho_ten character varying(150),
    email character varying(255),
    dien_thoai character varying(25),
    noi_dung text NOT NULL,
    phan_hoi text,
    nhan_vien_phan_hoi_id bigint,
    trang_thai character varying(20) DEFAULT 'MOI'::character varying NOT NULL,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL,
    ngay_phan_hoi timestamp with time zone,
    CONSTRAINT lien_he_khach_hang_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['MOI'::character varying, 'DANG_XU_LY'::character varying, 'DA_PHAN_HOI'::character varying, 'DA_DONG'::character varying])::text[])))
);


--
-- Name: lien_he_khach_hang_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.lien_he_khach_hang ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.lien_he_khach_hang_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: loai_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.loai_san_pham (
    id bigint NOT NULL,
    ten character varying(150) NOT NULL,
    mo_ta text,
    hinh_anh text,
    hien_thi boolean DEFAULT true NOT NULL
);


--
-- Name: loai_san_pham_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.loai_san_pham ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.loai_san_pham_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nha_cung_cap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nha_cung_cap (
    id bigint NOT NULL,
    ten character varying(255) NOT NULL,
    ma_so_thue character varying(30),
    nguoi_lien_he character varying(150),
    dien_thoai character varying(25),
    email character varying(255),
    dia_chi text,
    trang_thai character varying(25) DEFAULT 'HOP_TAC'::character varying NOT NULL,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL,
    loai_nha_cung_cap character varying(30) DEFAULT 'DOANH_NGHIEP'::character varying NOT NULL,
    trang_thai_xac_minh character varying(30) DEFAULT 'CHUA_XAC_MINH'::character varying NOT NULL,
    ghi_chu_xac_minh character varying(2000),
    nguoi_xac_minh_id bigint,
    thoi_diem_xac_minh timestamp with time zone,
    CONSTRAINT nha_cung_cap_loai_nha_cung_cap_check CHECK (((loai_nha_cung_cap)::text = ANY ((ARRAY['DOANH_NGHIEP'::character varying, 'HO_KINH_DOANH'::character varying, 'CA_NHAN'::character varying])::text[]))),
    CONSTRAINT nha_cung_cap_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['HOP_TAC'::character varying, 'NGUNG_HOP_TAC'::character varying])::text[]))),
    CONSTRAINT nha_cung_cap_trang_thai_xac_minh_check CHECK (((trang_thai_xac_minh)::text = ANY ((ARRAY['CHUA_XAC_MINH'::character varying, 'DA_XAC_MINH'::character varying, 'CAN_KIEM_TRA_LAI'::character varying])::text[])))
);


--
-- Name: nha_cung_cap_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.nha_cung_cap ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.nha_cung_cap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nha_cung_cap_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nha_cung_cap_san_pham (
    nha_cung_cap_id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    gia_nhap_tham_khao numeric(18,2),
    CONSTRAINT nha_cung_cap_san_pham_gia_nhap_tham_khao_check CHECK ((gia_nhap_tham_khao >= (0)::numeric))
);


--
-- Name: nhan_vien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien (
    id bigint NOT NULL,
    tai_khoan_id bigint NOT NULL,
    ma_nhan_vien character varying(30) NOT NULL,
    ho_ten character varying(150) NOT NULL,
    ngay_sinh date,
    gioi_tinh character varying(15),
    dien_thoai character varying(25),
    email_lien_he character varying(255),
    dia_chi text,
    chuc_vu character varying(100),
    ngay_vao_lam date,
    trang_thai character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    CONSTRAINT nhan_vien_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['ACTIVE'::character varying, 'ON_LEAVE'::character varying, 'RESIGNED'::character varying])::text[])))
);


--
-- Name: nhan_vien_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.nhan_vien ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.nhan_vien_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: nhat_ky_hoat_dong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhat_ky_hoat_dong (
    id bigint NOT NULL,
    tai_khoan_id bigint,
    hanh_dong character varying(160) NOT NULL,
    doi_tuong character varying(100),
    doi_tuong_id bigint,
    du_lieu_thay_doi jsonb,
    thoi_diem timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nhat_ky_hoat_dong_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.nhat_ky_hoat_dong ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.nhat_ky_hoat_dong_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: password_reset_challenge; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_challenge (
    id uuid NOT NULL,
    tai_khoan_id bigint NOT NULL,
    otp_hash character varying(100),
    het_han timestamp with time zone NOT NULL,
    so_lan_sai integer DEFAULT 0 NOT NULL,
    reset_token_hash character varying(64),
    reset_het_han timestamp with time zone,
    da_dung boolean DEFAULT false NOT NULL,
    gui_that_bai boolean DEFAULT false NOT NULL,
    tao_luc timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT password_reset_challenge_so_lan_sai_check CHECK (((so_lan_sai >= 0) AND (so_lan_sai <= 5)))
);


--
-- Name: pham_vi_khuyen_mai; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pham_vi_khuyen_mai (
    id bigint NOT NULL,
    khuyen_mai_id bigint NOT NULL,
    san_pham_id bigint,
    loai_san_pham_id bigint,
    thuong_hieu_id bigint,
    CONSTRAINT pham_vi_khuyen_mai_check CHECK ((num_nonnulls(san_pham_id, loai_san_pham_id, thuong_hieu_id) = 1))
);


--
-- Name: pham_vi_khuyen_mai_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.pham_vi_khuyen_mai ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pham_vi_khuyen_mai_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: phien_xac_thuc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phien_xac_thuc (
    id bigint NOT NULL,
    tai_khoan_id bigint NOT NULL,
    token_hash text NOT NULL,
    het_han timestamp with time zone NOT NULL,
    da_thu_hoi boolean DEFAULT false NOT NULL,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: phien_xac_thuc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.phien_xac_thuc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.phien_xac_thuc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: quy_cach_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quy_cach_san_pham (
    id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    ten_quy_cach character varying(60) NOT NULL,
    don_vi_tinh character varying(30) NOT NULL,
    he_so_quy_doi integer NOT NULL,
    gia_ban numeric(18,2) NOT NULL,
    gia_von numeric(18,2) DEFAULT 0 NOT NULL,
    dang_ban boolean DEFAULT true NOT NULL,
    CONSTRAINT quy_cach_san_pham_gia_ban_check CHECK ((gia_ban >= (0)::numeric)),
    CONSTRAINT quy_cach_san_pham_gia_von_check CHECK ((gia_von >= (0)::numeric)),
    CONSTRAINT quy_cach_san_pham_he_so_quy_doi_check CHECK ((he_so_quy_doi > 0))
);


--
-- Name: quy_cach_san_pham_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.quy_cach_san_pham ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.quy_cach_san_pham_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: quyen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quyen (
    id bigint NOT NULL,
    ma_quyen character varying(100) NOT NULL,
    ten_quyen character varying(150) NOT NULL,
    ma_chuc_nang character varying(30) NOT NULL,
    hanh_dong character varying(30) NOT NULL,
    mo_ta text
);


--
-- Name: quyen_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.quyen ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.quyen_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.san_pham (
    id bigint NOT NULL,
    loai_san_pham_id bigint NOT NULL,
    thuong_hieu_id bigint NOT NULL,
    sku character varying(80) NOT NULL,
    ten character varying(255) NOT NULL,
    mo_ta text,
    thanh_phan text,
    dinh_duong text,
    xuat_xu character varying(150),
    dung_tich character varying(80),
    loai_bao_bi character varying(40),
    huong_vi character varying(100),
    so_ngay_han_dung integer,
    huong_dan_bao_quan text,
    trang_thai character varying(30) DEFAULT 'DANG_BAN'::character varying NOT NULL,
    hien_thi boolean DEFAULT true NOT NULL,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL,
    ngay_cap_nhat timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT san_pham_so_ngay_han_dung_check CHECK ((so_ngay_han_dung > 0)),
    CONSTRAINT san_pham_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['DANG_BAN'::character varying, 'HET_HANG'::character varying, 'NGUNG_KINH_DOANH'::character varying])::text[])))
);


--
-- Name: san_pham_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.san_pham ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.san_pham_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: san_pham_yeu_thich; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.san_pham_yeu_thich (
    khach_hang_id bigint NOT NULL,
    san_pham_id bigint NOT NULL,
    ngay_them timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: so_luong_san_pham; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.so_luong_san_pham (
    san_pham_id bigint NOT NULL,
    so_luong_co_ban bigint DEFAULT 0 NOT NULL,
    nguong_canh_bao bigint DEFAULT 10 NOT NULL,
    ngay_cap_nhat timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT so_luong_san_pham_nguong_canh_bao_check CHECK ((nguong_canh_bao >= 0)),
    CONSTRAINT so_luong_san_pham_so_luong_co_ban_check CHECK ((so_luong_co_ban >= 0))
);


--
-- Name: su_dung_khuyen_mai; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.su_dung_khuyen_mai (
    id bigint NOT NULL,
    khuyen_mai_id bigint NOT NULL,
    khach_hang_id bigint,
    don_hang_id bigint NOT NULL,
    so_tien_giam numeric(18,2) NOT NULL,
    trang_thai character varying(20) DEFAULT 'APPLIED'::character varying NOT NULL,
    ngay_su_dung timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT su_dung_khuyen_mai_so_tien_giam_check CHECK ((so_tien_giam >= (0)::numeric)),
    CONSTRAINT su_dung_khuyen_mai_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['APPLIED'::character varying, 'REVERSED'::character varying])::text[])))
);


--
-- Name: su_dung_khuyen_mai_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.su_dung_khuyen_mai ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.su_dung_khuyen_mai_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tai_khoan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tai_khoan (
    id bigint NOT NULL,
    email character varying(255) NOT NULL,
    mat_khau_hash text NOT NULL,
    trang_thai character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    email_da_xac_thuc boolean DEFAULT false NOT NULL,
    so_lan_dang_nhap_sai integer DEFAULT 0 NOT NULL,
    khoa_den timestamp with time zone,
    ngay_tao timestamp with time zone DEFAULT now() NOT NULL,
    ngay_cap_nhat timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tai_khoan_so_lan_dang_nhap_sai_check CHECK ((so_lan_dang_nhap_sai >= 0)),
    CONSTRAINT tai_khoan_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['ACTIVE'::character varying, 'LOCKED'::character varying, 'DISABLED'::character varying])::text[])))
);


--
-- Name: tai_khoan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tai_khoan ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tai_khoan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tai_khoan_vai_tro; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tai_khoan_vai_tro (
    tai_khoan_id bigint NOT NULL,
    vai_tro_id bigint NOT NULL
);


--
-- Name: thanh_toan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thanh_toan (
    id bigint NOT NULL,
    don_hang_id bigint NOT NULL,
    phuong_thuc character varying(30) NOT NULL,
    ma_giao_dich character varying(120),
    idempotency_key character varying(120),
    so_tien numeric(18,2) NOT NULL,
    trang_thai character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    thoi_gian timestamp with time zone DEFAULT now() NOT NULL,
    thong_tin_cong jsonb,
    CONSTRAINT thanh_toan_phuong_thuc_check CHECK (((phuong_thuc)::text = ANY ((ARRAY['COD'::character varying, 'CASH'::character varying, 'BANK_TRANSFER'::character varying, 'QR'::character varying, 'MOMO'::character varying, 'VNPAY'::character varying, 'ZALOPAY'::character varying, 'CARD'::character varying])::text[]))),
    CONSTRAINT thanh_toan_so_tien_check CHECK ((so_tien >= (0)::numeric)),
    CONSTRAINT thanh_toan_trang_thai_check CHECK (((trang_thai)::text = ANY ((ARRAY['PENDING'::character varying, 'SUCCESS'::character varying, 'FAILED'::character varying, 'CANCELLED'::character varying, 'REFUNDED'::character varying])::text[])))
);


--
-- Name: thanh_toan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.thanh_toan ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.thanh_toan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: thanh_toan_ncc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thanh_toan_ncc (
    id bigint NOT NULL,
    cong_no_id bigint NOT NULL,
    so_tien numeric(18,2) NOT NULL,
    phuong_thuc character varying(30) NOT NULL,
    ma_tham_chieu character varying(120),
    ngay_thanh_toan timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT thanh_toan_ncc_so_tien_check CHECK ((so_tien > (0)::numeric))
);


--
-- Name: thanh_toan_ncc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.thanh_toan_ncc ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.thanh_toan_ncc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: thuong_hieu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thuong_hieu (
    id bigint NOT NULL,
    ten character varying(150) NOT NULL,
    logo text,
    mo_ta text,
    hien_thi boolean DEFAULT true NOT NULL
);


--
-- Name: thuong_hieu_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.thuong_hieu ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.thuong_hieu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: uu_dai_so_luong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uu_dai_so_luong (
    id bigint NOT NULL,
    khuyen_mai_id bigint NOT NULL,
    quy_cach_id bigint,
    so_luong_mua integer NOT NULL,
    so_luong_tang integer DEFAULT 0 NOT NULL,
    ghi_chu_combo text,
    CONSTRAINT uu_dai_so_luong_so_luong_mua_check CHECK ((so_luong_mua > 0)),
    CONSTRAINT uu_dai_so_luong_so_luong_tang_check CHECK ((so_luong_tang >= 0))
);


--
-- Name: uu_dai_so_luong_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.uu_dai_so_luong ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.uu_dai_so_luong_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: v_doanh_thu_ngay; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_doanh_thu_ngay AS
 SELECT ((thoi_gian AT TIME ZONE 'Asia/Ho_Chi_Minh'::text))::date AS ngay,
    count(DISTINCT don_hang_id) AS so_don,
    sum(so_tien) AS tong_da_thu
   FROM public.thanh_toan t
  WHERE ((trang_thai)::text = 'SUCCESS'::text)
  GROUP BY (((thoi_gian AT TIME ZONE 'Asia/Ho_Chi_Minh'::text))::date);


--
-- Name: v_nhap_hang_da_xac_nhan; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_nhap_hang_da_xac_nhan AS
 SELECT d.don_ncc_id,
    o.nha_cung_cap_id,
    q.san_pham_id,
    sum(((c.so_luong_thuc_nhan)::bigint * d.he_so_quy_doi)) AS so_luong_co_ban_nhap,
    sum(((c.so_luong_thuc_nhan)::numeric * c.gia_nhap_thuc_te)) AS gia_tri_nhap
   FROM ((((public.chi_tiet_lan_nhap c
     JOIN public.lan_nhap_hang l ON ((l.id = c.lan_nhap_id)))
     JOIN public.chi_tiet_don_ncc d ON ((d.id = c.ct_don_ncc_id)))
     JOIN public.don_dat_hang_ncc o ON ((o.id = d.don_ncc_id)))
     JOIN public.quy_cach_san_pham q ON ((q.id = d.quy_cach_id)))
  WHERE ((l.trang_thai)::text = 'CONFIRMED'::text)
  GROUP BY d.don_ncc_id, o.nha_cung_cap_id, q.san_pham_id;


--
-- Name: v_ton_san_pham; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ton_san_pham AS
 SELECT s.id AS san_pham_id,
    s.sku,
    s.ten,
    k.so_luong_co_ban,
    k.nguong_canh_bao,
    (k.so_luong_co_ban <= k.nguong_canh_bao) AS canh_bao
   FROM (public.san_pham s
     JOIN public.so_luong_san_pham k ON ((k.san_pham_id = s.id)));


--
-- Name: v_ton_theo_quy_cach; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ton_theo_quy_cach AS
 SELECT q.san_pham_id,
    q.id AS quy_cach_id,
    q.ten_quy_cach,
    q.he_so_quy_doi,
    k.so_luong_co_ban,
    (k.so_luong_co_ban / q.he_so_quy_doi) AS so_luong_co_the_ban
   FROM (public.quy_cach_san_pham q
     JOIN public.so_luong_san_pham k ON ((k.san_pham_id = q.san_pham_id)));


--
-- Name: vai_tro; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vai_tro (
    id bigint NOT NULL,
    ma_vai_tro character varying(30) NOT NULL,
    ten_vai_tro character varying(100) NOT NULL,
    mo_ta text,
    CONSTRAINT vai_tro_ma_vai_tro_check CHECK (((ma_vai_tro)::text = ANY ((ARRAY['KHACH_HANG'::character varying, 'NHAN_VIEN'::character varying, 'QUAN_TRI_VIEN'::character varying])::text[])))
);


--
-- Name: vai_tro_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.vai_tro ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.vai_tro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: vai_tro_quyen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vai_tro_quyen (
    vai_tro_id bigint NOT NULL,
    quyen_id bigint NOT NULL
);


--
-- Data for Name: backend_schema_migration; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.backend_schema_migration VALUES
	('20261104_supplier_returns_cost', '2026-11-04 12:00:57.363459+07'),
	('20261104_receiving_disposition', '2026-11-04 12:30:49.926829+07'),
	('20261104_remove_warehouse_returns', '2026-11-04 14:26:44.024912+07'),
	('20261104_receiving_product_dates', '2026-11-04 16:34:11.196274+07'),
	('20261104_direct_receiving', '2026-11-04 17:39:34.263522+07'),
	('20261107_automatic_sale_pricing', '2026-11-07 19:59:38.342052+07'),
	('20261107_round_selling_prices_500', '2026-11-07 20:18:25.783827+07'),
	('20261108_customer_password_reset', '2026-11-08 13:33:30.520089+07');


--
-- Data for Name: bien_dong_so_luong; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.bien_dong_so_luong OVERRIDING SYSTEM VALUE VALUES
	(1, 27, 'DIEU_CHINH', 1, 30, 0, 30, '2026-11-03 16:15:54.103561+07'),
	(2, 26, 'DIEU_CHINH', 2, 20, 0, 20, '2026-11-03 16:17:34.908471+07'),
	(3, 27, 'BAN_ONLINE', 1, -10, 30, 20, '2026-11-03 16:38:23.783332+07'),
	(4, 21, 'NHAP_HANG', 1, 98, 0, 98, '2026-11-04 10:59:33.262019+07'),
	(5, 21, 'NHAP_HANG', 2, 100, 98, 198, '2026-11-04 12:12:20.214256+07'),
	(6, 21, 'CACH_LY_TRA_NCC', 1, -5, 198, 193, '2026-11-04 12:12:29.060721+07'),
	(7, 25, 'NHAP_HANG', 3, 90, 0, 90, '2026-11-04 12:14:43.161711+07'),
	(8, 21, 'DIEU_CHINH', 3, -145, 193, 48, '2026-11-04 12:59:11.791323+07'),
	(9, 17, 'NHAP_HANG', 4, 24, 0, 24, '2026-11-04 13:00:35.391049+07'),
	(10, 20, 'NHAP_HANG', 5, 30, 0, 30, '2026-11-04 13:01:27.226165+07'),
	(11, 20, 'BAN_ONLINE', 2, -10, 30, 20, '2026-11-04 13:04:11.849425+07'),
	(12, 22, 'NHAP_HANG', 6, 36, 0, 36, '2026-11-04 13:15:49.496649+07'),
	(13, 24, 'NHAP_HANG', 8, 120, 0, 120, '2026-11-15 14:04:27.396664+07'),
	(14, 24, 'DIEU_CHINH', 4, -110, 120, 10, '2026-11-15 14:08:01.077523+07'),
	(15, 25, 'DIEU_CHINH', 5, -80, 90, 10, '2026-11-15 14:08:09.629563+07'),
	(16, 26, 'NHAP_HANG', 10, 120, 20, 140, '2026-11-15 14:09:48.91325+07'),
	(17, 22, 'BAN_ONLINE', 3, -8, 36, 28, '2026-11-04 14:35:34.329885+07'),
	(18, 22, 'HUY_DON', 3, 8, 28, 36, '2026-11-04 14:37:04.762617+07'),
	(19, 26, 'DIEU_CHINH', 6, -90, 140, 50, '2026-11-04 14:38:17.917651+07'),
	(20, 26, 'NHAP_HANG', 11, 48, 50, 98, '2026-11-04 16:47:55.792225+07'),
	(21, 24, 'NHAP_HANG', 12, 120, 10, 130, '2026-11-04 16:50:17.101014+07'),
	(22, 17, 'NHAP_HANG', 13, 24, 24, 48, '2026-11-04 17:21:56.50741+07'),
	(50, 27, 'DIEU_CHINH', 39, -20, 20, 0, '2026-11-07 19:47:08.37355+07'),
	(51, 26, 'DIEU_CHINH', 40, -98, 98, 0, '2026-11-07 19:47:15.778221+07'),
	(52, 24, 'DIEU_CHINH', 41, -130, 130, 0, '2026-11-07 19:47:21.654046+07'),
	(53, 22, 'DIEU_CHINH', 42, -36, 36, 0, '2026-11-07 19:47:28.526976+07'),
	(54, 21, 'DIEU_CHINH', 43, -48, 48, 0, '2026-11-07 19:47:37.189569+07'),
	(55, 20, 'DIEU_CHINH', 44, -20, 20, 0, '2026-11-07 19:47:45.690126+07'),
	(56, 17, 'DIEU_CHINH', 45, -48, 48, 0, '2026-11-07 19:47:52.184601+07'),
	(57, 25, 'DIEU_CHINH', 46, -10, 10, 0, '2026-11-07 19:48:11.970284+07'),
	(58, 20, 'NHAP_HANG', 44, 60, 0, 60, '2026-11-07 20:03:17.895325+07'),
	(59, 24, 'NHAP_HANG', 45, 60, 0, 60, '2026-11-07 20:04:20.515294+07'),
	(60, 26, 'NHAP_HANG', 47, 120, 0, 120, '2026-11-07 20:06:21.282405+07'),
	(61, 17, 'NHAP_HANG', 46, 240, 0, 240, '2026-11-07 20:06:23.640955+07'),
	(62, 24, 'NHAP_HANG', 48, 120, 60, 180, '2026-11-07 20:22:03.712417+07'),
	(63, 24, 'BAN_ONLINE', 36, -5, 180, 175, '2026-11-07 20:23:57.794667+07'),
	(64, 24, 'BAN_ONLINE', 37, -3, 175, 172, '2026-11-08 15:15:46.004724+07'),
	(65, 22, 'NHAP_HANG', 49, 144, 0, 144, '2026-11-08 15:23:49.336349+07');


--
-- Data for Name: chi_tiet_don_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_don_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 9, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 1, 8000.00, 0.00, DEFAULT),
	(2, 2, 6, 'Red Bull 250ml', 'Lon lẻ', 10, 1, 13000.00, 10000.00, DEFAULT),
	(3, 3, 26, 'Pocari Sweat 350ml', 'Chai lẻ', 8, 1, 14000.00, 10000.00, DEFAULT),
	(36, 36, 20, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 5, 1, 31000.00, 24444.44, DEFAULT),
	(37, 37, 20, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 3, 1, 31000.00, 24444.44, DEFAULT);


--
-- Data for Name: chi_tiet_don_ncc; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_don_ncc OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 17, 98, 1, 10000.00),
	(2, 2, 17, 100, 1, 10000.00),
	(3, 3, 7, 99, 1, 5000.00),
	(4, 4, 31, 1, 24, 250000.00),
	(5, 5, 32, 10, 6, 60000.00),
	(6, 6, 33, 10, 6, 60000.00),
	(7, 7, 34, 5, 24, 250000.00),
	(8, 8, 35, 5, 24, 300000.00),
	(9, 9, 36, 5, 6, 25000.00),
	(10, 10, 37, 5, 24, 240000.00),
	(11, 11, 37, 2, 24, 200000.00),
	(12, 12, 35, 5, 24, 250000.00),
	(13, 13, 31, 1, 24, 200000.00),
	(14, 14, 38, 10, 6, 100000.00),
	(15, 15, 32, 10, 6, 140000.00),
	(44, 44, 37, 5, 24, 280000.00),
	(45, 45, 31, 10, 24, 240000.00),
	(46, 46, 35, 5, 24, 180000.00),
	(47, 47, 71, 6, 24, 250000.00);


--
-- Data for Name: chi_tiet_gio_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_gio_hang OVERRIDING SYSTEM VALUE VALUES
	(53, 141, 26, 10, 13500.00);


--
-- Data for Name: chi_tiet_hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 8000.00, DEFAULT),
	(2, 2, 2, 'Red Bull 250ml', 'Lon lẻ', 10, 13000.00, DEFAULT),
	(3, 3, 3, 'Pocari Sweat 350ml', 'Chai lẻ', 8, 14000.00, DEFAULT),
	(36, 36, 36, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 5, 31000.00, DEFAULT),
	(37, 37, 37, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 3, 31000.00, DEFAULT);


--
-- Data for Name: chi_tiet_lan_nhap; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_lan_nhap OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 1, 98, 0, 0, 10000.00, NULL, NULL, NULL),
	(2, 2, 2, 2, 100, 0, 0, 10000.00, '', NULL, NULL),
	(3, 3, 3, 3, 90, 9, 0, 5000.00, 'lỗi', NULL, NULL),
	(4, 4, 4, 4, 1, 0, 0, 250000.00, '', NULL, NULL),
	(5, 5, 5, 5, 5, 5, 0, 60000.00, 'Bể', NULL, NULL),
	(6, 6, 6, 6, 6, 4, 0, 60000.00, 'hư', NULL, NULL),
	(7, 7, 7, 7, 0, 5, 0, 250000.00, 'bể', NULL, NULL),
	(8, 8, 8, 8, 5, 0, 0, 300000.00, '', NULL, NULL),
	(9, 9, 9, 9, 0, 5, 0, 25000.00, 'Hư', NULL, NULL),
	(10, 10, 10, 10, 5, 0, 0, 240000.00, '', NULL, NULL),
	(11, 11, 11, 11, 2, 0, 0, 200000.00, 'bể', '2026-11-04', '2026-11-29'),
	(12, 12, 12, 12, 5, 0, 0, 250000.00, '', '2026-10-31', '2027-10-30'),
	(13, 13, 13, 13, 1, 0, 0, 200000.00, '', '2026-11-04', '2027-11-04'),
	(44, 44, 15, 15, 10, 0, 0, 200000.00, '', '2026-11-01', '2027-11-01'),
	(45, 45, 14, 14, 10, 0, 0, 350000.00, '', '2026-11-07', '2027-11-07'),
	(46, 46, 45, 45, 10, 0, 0, 240000.00, '', '2026-11-05', '2027-05-09'),
	(47, 47, 44, 44, 5, 0, 0, 280000.00, '', '2026-11-07', '2027-12-07'),
	(48, 48, 46, 46, 5, 0, 0, 180000.00, '', '2026-11-05', '2027-11-05'),
	(49, 49, 47, 47, 6, 0, 0, 250000.00, '', '2026-03-01', '2027-03-01');


--
-- Data for Name: cong_no_ncc; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.cong_no_ncc OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 980000.00, 980000.00, NULL, 'CHUA_TRA'),
	(2, 2, 950000.00, 950000.00, NULL, 'CHUA_TRA'),
	(3, 3, 450000.00, 450000.00, NULL, 'CHUA_TRA'),
	(4, 4, 250000.00, 250000.00, NULL, 'CHUA_TRA'),
	(5, 5, 300000.00, 300000.00, NULL, 'CHUA_TRA'),
	(6, 6, 360000.00, 360000.00, NULL, 'CHUA_TRA'),
	(7, 7, 0.00, 0.00, NULL, 'DA_TRA'),
	(8, 8, 1500000.00, 1500000.00, NULL, 'CHUA_TRA'),
	(9, 9, 0.00, 0.00, NULL, 'DA_TRA'),
	(10, 10, 1200000.00, 1200000.00, NULL, 'CHUA_TRA'),
	(11, 11, 400000.00, 400000.00, NULL, 'CHUA_TRA'),
	(12, 12, 1250000.00, 1250000.00, NULL, 'CHUA_TRA'),
	(13, 13, 200000.00, 200000.00, NULL, 'CHUA_TRA'),
	(44, 44, 2000000.00, 2000000.00, NULL, 'CHUA_TRA'),
	(45, 45, 3500000.00, 3500000.00, NULL, 'CHUA_TRA'),
	(46, 47, 1400000.00, 1400000.00, NULL, 'CHUA_TRA'),
	(47, 46, 2400000.00, 2400000.00, NULL, 'CHUA_TRA'),
	(48, 48, 900000.00, 900000.00, NULL, 'CHUA_TRA'),
	(49, 49, 1500000.00, 1500000.00, NULL, 'CHUA_TRA');


--
-- Data for Name: danh_gia_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dia_chi_giao_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.dia_chi_giao_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'SonY', '0123456789', '24/1 Kha Vạn Cân', 'Phường Tam Thắng', NULL, 'Thành phố Hồ Chí Minh', true),
	(2, 6, 'hưng Ngô', '0786566862', '335 Hậu Giang', 'Phường Bình Tây', NULL, 'Thành phố Hồ Chí Minh', true);


--
-- Data for Name: dieu_chinh_so_luong; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.dieu_chinh_so_luong OVERRIDING SYSTEM VALUE VALUES
	(1, 27, 9, 2, 0, 30, DEFAULT, 'nhập hàng', '2026-11-03 16:15:54.103561+07'),
	(2, 26, 8, 2, 0, 20, DEFAULT, 'nhập hàng', '2026-11-03 16:17:34.908471+07'),
	(3, 21, 17, 2, 193, 48, DEFAULT, 'Hư', '2026-11-04 12:59:11.791323+07'),
	(4, 24, 20, 2, 120, 10, DEFAULT, 'Hư', '2026-11-15 14:08:01.077523+07'),
	(5, 25, 7, 2, 90, 10, DEFAULT, 'Hư', '2026-11-15 14:08:09.629563+07'),
	(6, 26, 8, 2, 140, 50, DEFAULT, 'Hư', '2026-11-04 14:38:17.917651+07'),
	(39, 27, 9, 2, 20, 0, DEFAULT, 'HƯ', '2026-11-07 19:47:08.37355+07'),
	(40, 26, 8, 2, 98, 0, DEFAULT, 'HƯ', '2026-11-07 19:47:15.778221+07'),
	(41, 24, 20, 2, 130, 0, DEFAULT, 'HƯ', '2026-11-07 19:47:21.654046+07'),
	(42, 22, 26, 2, 36, 0, DEFAULT, 'HƯ', '2026-11-07 19:47:28.526976+07'),
	(43, 21, 17, 2, 48, 0, DEFAULT, 'hư', '2026-11-07 19:47:37.189569+07'),
	(44, 20, 6, 2, 20, 0, DEFAULT, 'hư', '2026-11-07 19:47:45.690126+07'),
	(45, 17, 11, 2, 48, 0, DEFAULT, 'hư', '2026-11-07 19:47:52.184601+07'),
	(46, 25, 7, 2, 10, 0, DEFAULT, 'hư', '2026-11-07 19:48:11.970284+07');


--
-- Data for Name: don_dat_hang_ncc; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.don_dat_hang_ncc OVERRIDING SYSTEM VALUE VALUES
	(1, 'DN-ecae6c25-7ca9-435f-bccd-80f5c455fae6', 1, 2, 2, '2026-11-04 10:58:45.457189+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 10:59:07.421739+07'),
	(2, 'DN-e18691d0-8ec6-48f8-b3b3-7dbe47fbb18e', 1, 2, 2, '2026-11-04 10:59:44.233531+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 11:33:58.936078+07'),
	(3, 'DN-11337488-3885-4f7e-8ea3-01a9dad24208', 1, 2, 2, '2026-11-04 12:13:34.789937+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 12:13:36.855034+07'),
	(4, 'DN-37bf0eeb-8b1f-40ac-8802-62b141f2380f', 1, 2, 2, '2026-11-04 13:00:10.774914+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 13:00:16.584068+07'),
	(5, 'DN-54f754f7-eed1-40dd-b6d5-a68312a5cf00', 1, 2, 2, '2026-11-04 13:01:10.070012+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 13:01:12.073721+07'),
	(6, 'DN-b2311acf-426a-4de4-a7da-0860bac2ede3', 2, 2, 2, '2026-11-04 13:11:08.69586+07', NULL, 'DA_NHAN_DU', NULL, NULL, '2026-11-04 13:15:18.672048+07'),
	(7, 'DN-186df4ea-c3b7-4179-8038-cdfe0789d491', 1, 2, 2, '2026-11-04 13:43:56.957398+07', '2026-11-14', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 13:44:16.373392+07'),
	(8, 'DN-0efa3e03-c2a1-48c9-b57c-b5121035212f', 2, 2, 2, '2026-11-04 13:54:57.810125+07', '2026-11-15', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 13:55:08.848794+07'),
	(9, 'DN-360db5b7-4833-4a05-87af-9e3da018617d', 2, 2, 2, '2026-11-15 14:05:54.594634+07', '2026-11-20', 'DA_NHAN_DU', NULL, NULL, '2026-11-15 14:06:07.752294+07'),
	(10, 'DN-567a53ea-ac4b-42a1-905c-bd6a463c6acb', 2, 2, 2, '2026-11-15 14:09:13.89244+07', '2026-11-17', 'DA_NHAN_DU', NULL, NULL, '2026-11-15 14:09:34.614701+07'),
	(11, 'DN-1e05136b-5177-4f7f-868a-8cf3cf02da83', 2, 2, 2, '2026-11-04 16:18:20.873601+07', '2026-11-05', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 16:18:30.274333+07'),
	(12, 'DN-c9dd99b6-b390-4661-91a9-5730eb2e87ba', 2, 2, 2, '2026-11-04 16:48:33.864302+07', '2026-11-05', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 16:48:39.612381+07'),
	(13, 'DN-5a2191fe-da73-4010-a1e3-72c938289c04', 1, 2, 2, '2026-11-04 17:20:14.801639+07', '2026-11-04', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 17:20:32.142359+07'),
	(15, 'DN-570647c9-3917-4a86-9c7f-fa9ddf15efdf', 1, 2, 2, '2026-11-04 17:29:32.283776+07', '2026-11-14', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 17:29:37.163446+07'),
	(14, 'DN-7cbe1b41-4a0e-4571-8c80-38f09a759151', 2, 2, NULL, '2026-11-04 17:29:08.79452+07', '2026-11-06', 'DA_NHAN_DU', NULL, NULL, NULL),
	(44, 'DN-c1b2dda5-3f0c-4d98-94a2-e2de1df682f5', 2, 2, NULL, '2026-11-07 20:04:56.693895+07', '2026-11-10', 'DA_NHAN_DU', NULL, NULL, NULL),
	(45, 'DN-3e726dc1-482c-4596-831b-db5cea549d85', 1, 2, NULL, '2026-11-07 20:05:33.072203+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(46, 'DN-fcf95eb5-cf81-48ff-88b1-272ce18fdf05', 2, 2, NULL, '2026-11-07 20:21:21.527205+07', '2026-11-08', 'DA_NHAN_DU', NULL, NULL, NULL),
	(47, 'DN-72daed3f-6602-46bd-80a4-b2858d2408f1', 2, 2, NULL, '2026-11-08 15:23:04.721186+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL);


--
-- Data for Name: don_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.don_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 'DH-6c1a7221-fc52-436f-8308-5ac6fbe4a865', 'ONLINE', 1, 2, '2026-11-03 16:37:52.820068+07', NULL, 'DA_GIAO', 0.00, 0.00, 80000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-03 16:38:29.510031+07', NULL),
	(2, 'DH-0813adbd-aaa0-44dd-8317-57abbe8d3b7d', 'ONLINE', 1, 3, '2026-11-04 13:03:18.413361+07', NULL, 'DA_GIAO', 0.00, 0.00, 130000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-04 13:05:10.352992+07', NULL),
	(3, 'DH-ad03213a-3dfb-4d0f-bb40-d3c26a4b34dd', 'ONLINE', 1, 3, '2026-11-04 14:34:38.732069+07', NULL, 'DA_HUY', 0.00, 11200.00, 100800.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-04 14:37:04.762617+07', 1),
	(36, 'DH-a4e572de-dfa9-4d7a-b4e0-ff37106904b5', 'ONLINE', 1, 2, '2026-11-07 20:23:40.626183+07', NULL, 'DA_GIAO', 0.00, 0.00, 155000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-07 20:24:03.891591+07', NULL),
	(37, 'DH-952a4d25-3d9c-460c-b667-4745274d50dd', 'ONLINE', 6, 2, '2026-11-08 15:15:30.126268+07', NULL, 'DA_GIAO', 0.00, 18600.00, 74400.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-08 15:15:50.298675+07', 34);


--
-- Data for Name: giay_to_ncc; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: gio_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.gio_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, '2026-11-07 20:23:36.079704+07'),
	(141, 6, '2026-11-08 15:27:00.035876+07');


--
-- Data for Name: hinh_anh_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 2, 'HD-1', '2026-11-03 16:38:23.783332+07', 'ONLINE', 80000.00, 0.00, 0.00, 'ISSUED'),
	(2, 2, 3, 'HD-2', '2026-11-04 13:04:11.849425+07', 'ONLINE', 130000.00, 0.00, 0.00, 'ISSUED'),
	(3, 3, 3, 'HD-3', '2026-11-04 14:35:34.329885+07', 'ONLINE', 100800.00, 0.00, 11200.00, 'CANCELLED'),
	(36, 36, 2, 'HD-36', '2026-11-07 20:23:57.794667+07', 'ONLINE', 155000.00, 0.00, 0.00, 'ISSUED'),
	(37, 37, 2, 'HD-37', '2026-11-08 15:15:46.004724+07', 'ONLINE', 74400.00, 0.00, 18600.00, 'ISSUED');


--
-- Data for Name: hoan_tien; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: khach_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.khach_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 3, 'SonY', '1234567890', NULL, '2026-11-03 15:25:38.232189+07'),
	(6, 5, 'hưng Ngô', '0786566862', NULL, '2026-11-08 13:36:04.528191+07');


--
-- Data for Name: khuyen_mai; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.khuyen_mai OVERRIDING SYSTEM VALUE VALUES
	(34, 'WATERBUS10', 'Giảm giá mạnh', NULL, 'PERCENT', 20.00, 50000.00, 0.00, '2026-11-08 15:02:23+07', '2026-11-10 15:00:00+07', 100, 5, 'CATEGORY', 'ACTIVE'),
	(1, 'EASPORT', 'Giảm giá mạnh', NULL, 'PERCENT', 10.00, 50000.00, 0.00, '2026-11-04 14:32:25+07', '2026-11-10 14:32:25+07', 2, 1, 'CATEGORY', 'ACTIVE');


--
-- Data for Name: lan_nhap_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lan_nhap_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 2, '2026-11-04 10:59:30.831078+07', 'CONFIRMED', '2026-11-04 10:59:33.262019+07', NULL),
	(2, 2, 2, '2026-11-04 12:12:17.013658+07', 'CONFIRMED', '2026-11-04 12:12:20.214256+07', NULL),
	(3, 3, 2, '2026-11-04 12:14:00.716347+07', 'CONFIRMED', '2026-11-04 12:14:43.161711+07', NULL),
	(4, 4, 2, '2026-11-04 13:00:31.306911+07', 'CONFIRMED', '2026-11-04 13:00:35.391049+07', NULL),
	(5, 5, 2, '2026-11-04 13:01:23.814677+07', 'CONFIRMED', '2026-11-04 13:01:27.226165+07', NULL),
	(6, 6, 2, '2026-11-04 13:15:46.748109+07', 'CONFIRMED', '2026-11-04 13:15:49.496649+07', NULL),
	(7, 7, 2, '2026-11-04 13:53:59.862233+07', 'CONFIRMED', '2026-11-04 13:54:10.677797+07', NULL),
	(8, 8, 2, '2026-11-15 14:04:19.083592+07', 'CONFIRMED', '2026-11-15 14:04:27.396664+07', NULL),
	(9, 9, 2, '2026-11-15 14:07:24.035317+07', 'CONFIRMED', '2026-11-15 14:07:28.16431+07', NULL),
	(10, 10, 2, '2026-11-15 14:09:40.50754+07', 'CONFIRMED', '2026-11-15 14:09:48.91325+07', NULL),
	(11, 11, 2, '2026-11-04 16:18:56.527476+07', 'CONFIRMED', '2026-11-04 16:47:55.792225+07', NULL),
	(12, 12, 2, '2026-11-04 16:49:48.743673+07', 'CONFIRMED', '2026-11-04 16:50:17.101014+07', NULL),
	(13, 13, 3, '2026-11-04 17:21:10.930847+07', 'CONFIRMED', '2026-11-04 17:21:56.50741+07', NULL),
	(44, 15, 2, '2026-11-07 20:03:12.879314+07', 'CONFIRMED', '2026-11-07 20:03:17.895325+07', NULL),
	(45, 14, 2, '2026-11-07 20:04:16.814618+07', 'CONFIRMED', '2026-11-07 20:04:20.515294+07', NULL),
	(47, 44, 2, '2026-11-07 20:06:17.046454+07', 'CONFIRMED', '2026-11-07 20:06:21.282405+07', NULL),
	(46, 45, 2, '2026-11-07 20:05:57.794819+07', 'CONFIRMED', '2026-11-07 20:06:23.640955+07', NULL),
	(48, 46, 2, '2026-11-07 20:21:58.958308+07', 'CONFIRMED', '2026-11-07 20:22:03.712417+07', NULL),
	(49, 47, 2, '2026-11-08 15:23:44.149261+07', 'CONFIRMED', '2026-11-08 15:23:49.336349+07', NULL);


--
-- Data for Name: lich_su_hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lich_su_hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 3, NULL, 'ISSUED', 'CANCELLED', 'Cap nhat trang thai theo nghiep vu don hang', '2026-11-04 14:37:04.762617+07');


--
-- Data for Name: lich_su_trang_thai_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lich_su_trang_thai_don OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-03 16:38:23.783332+07'),
	(2, 1, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-03 16:38:26.349807+07'),
	(3, 1, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-03 16:38:29.510031+07'),
	(4, 2, 4, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-04 13:04:11.849425+07'),
	(5, 2, 4, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-04 13:04:26.28501+07'),
	(6, 2, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-04 13:05:10.352992+07'),
	(7, 3, 4, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-04 14:35:34.329885+07'),
	(8, 3, 4, 'DANG_CHUAN_BI', 'DA_HUY', 'Không thích bán nữa ', '2026-11-04 14:37:04.762617+07'),
	(40, 36, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-07 20:23:57.794667+07'),
	(41, 36, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-07 20:24:00.962555+07'),
	(42, 36, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-07 20:24:03.891591+07'),
	(43, 37, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-08 15:15:46.004724+07'),
	(44, 37, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-08 15:15:48.551074+07'),
	(45, 37, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-08 15:15:50.298675+07');


--
-- Data for Name: lien_he_khach_hang; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: loai_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.loai_san_pham OVERRIDING SYSTEM VALUE VALUES
	(1, 'Nước ngọt có ga', 'Nước giải khát có ga', NULL, true),
	(2, 'Nước suối', 'Nước tinh khiết', NULL, true),
	(3, 'Trà đóng chai', 'Trà pha sẵn', NULL, true),
	(7, 'Nước tăng lực', 'Đồ uống tăng lực đóng lon hoặc chai.', NULL, true),
	(8, 'Nước thể thao', 'Các loại đồ uống thể thao.', NULL, true),
	(9, 'Nước trái cây', 'Đồ uống và nước ép trái cây đóng gói.', NULL, true),
	(10, 'Sữa và ca cao', 'Sữa và đồ uống ca cao dùng sẵn.', NULL, true);


--
-- Data for Name: nha_cung_cap; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nha_cung_cap OVERRIDING SYSTEM VALUE VALUES
	(2, 'Coca-cola', '1234567777', 'Skywind', '0910209811', 'Coca@gmail.com', NULL, 'HOP_TAC', '2026-11-04 13:10:07.968792+07', 'DOANH_NGHIEP', 'DA_XAC_MINH', NULL, 2, '2026-11-04 13:10:07.968792+07'),
	(1, 'Boobiboo', '1234567890', 'Mister_Dat', '1234567890', 'Mr.Dat@gmail.com', '24/1 Kha Vạn Cân', 'HOP_TAC', '2026-11-04 10:57:21.919355+07', 'DOANH_NGHIEP', 'CAN_KIEM_TRA_LAI', NULL, NULL, NULL);


--
-- Data for Name: nha_cung_cap_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nha_cung_cap_san_pham VALUES
	(1, 23, NULL),
	(1, 20, NULL),
	(1, 17, NULL),
	(2, 26, NULL),
	(2, 24, NULL),
	(2, 22, NULL);


--
-- Data for Name: nhan_vien; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nhan_vien OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'NV-1', 'Quản trị viên', NULL, NULL, NULL, NULL, NULL, 'ADMIN', '2026-11-03', 'ACTIVE'),
	(3, 4, 'NV-4', 'Quân AB', NULL, NULL, '0792040241', NULL, NULL, NULL, NULL, 'ACTIVE'),
	(4, 3, 'NV-3', 'SonY', NULL, NULL, '0123456789', NULL, NULL, NULL, NULL, 'ACTIVE'),
	(2, 2, 'NV-2', 'Ocean', NULL, NULL, '0786566862', NULL, '31 Chu Văn An, Phường Bình Tiên, Thành phố Hồ Chí Minh', NULL, NULL, 'ACTIVE');


--
-- Data for Name: nhat_ky_hoat_dong; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nhat_ky_hoat_dong OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'LOGIN', 'tai_khoan', 1, NULL, '2026-11-03 13:15:58.629248+07'),
	(2, 1, 'LOGIN', 'tai_khoan', 1, NULL, '2026-11-03 15:23:53.063427+07'),
	(3, 1, 'ACCOUNT_CREATE', 'tai_khoan', 2, NULL, '2026-11-03 15:24:45.072766+07'),
	(4, 1, 'ACCOUNT_CREATE', 'tai_khoan', 3, NULL, '2026-11-03 15:25:38.232189+07'),
	(5, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-03 15:26:57.972299+07'),
	(6, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-03 15:27:05.711546+07'),
	(7, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-03 15:29:54.975792+07'),
	(8, 2, 'ACCOUNT_CREATE', 'tai_khoan', 4, NULL, '2026-11-03 15:33:33.131211+07'),
	(9, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:33:57.120073+07'),
	(10, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:34:06.244885+07'),
	(11, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:34:21.42966+07'),
	(12, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:34:31.972223+07'),
	(13, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-03 15:42:48.875423+07'),
	(14, 2, 'ACCOUNT_EDIT', 'tai_khoan', 3, NULL, '2026-11-03 15:48:14.871356+07'),
	(15, 2, 'ACCOUNT_EDIT', 'tai_khoan', 3, NULL, '2026-11-03 15:48:20.501197+07'),
	(16, 2, 'UPDATE', 'san_pham', 2, NULL, '2026-11-03 15:52:19.69644+07'),
	(17, 2, 'UPDATE', 'quy_cach_san_pham', 4, NULL, '2026-11-03 15:52:19.69644+07'),
	(18, 2, 'ACCOUNT_EDIT', 'tai_khoan', 3, NULL, '2026-11-03 15:53:31.383078+07'),
	(19, 2, 'ACCOUNT_EDIT', 'tai_khoan', 3, NULL, '2026-11-03 15:53:41.725217+07'),
	(20, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:53:53.114177+07'),
	(21, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:54:30.035152+07'),
	(22, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:55:26.226455+07'),
	(23, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-03 15:56:04.156692+07'),
	(24, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-03 15:56:17.766715+07'),
	(25, 2, 'STAFF_PROFILE', 'nhan_vien', 2, NULL, '2026-11-03 15:56:54.639782+07'),
	(26, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-03 15:57:38.276637+07'),
	(27, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-03 15:58:52.525088+07'),
	(28, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-03 16:10:29.983817+07'),
	(29, 2, 'UPDATE', 'san_pham', 27, NULL, '2026-11-03 16:15:54.103561+07'),
	(30, 2, 'UPDATE', 'quy_cach_san_pham', 9, NULL, '2026-11-03 16:15:54.103561+07'),
	(31, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 1, NULL, '2026-11-03 16:15:54.103561+07'),
	(32, 2, 'UPDATE', 'san_pham', 26, NULL, '2026-11-03 16:17:34.908471+07'),
	(33, 2, 'UPDATE', 'quy_cach_san_pham', 8, NULL, '2026-11-03 16:17:34.908471+07'),
	(34, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 2, NULL, '2026-11-03 16:17:34.908471+07'),
	(35, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-03 16:37:25.617458+07'),
	(36, 3, 'CHECKOUT', 'don_hang', 1, NULL, '2026-11-03 16:37:52.820068+07'),
	(37, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 1, NULL, '2026-11-03 16:38:23.783332+07'),
	(38, 2, 'ORDER_DANG_GIAO', 'don_hang', 1, NULL, '2026-11-03 16:38:26.349807+07'),
	(39, 2, 'ORDER_DA_GIAO', 'don_hang', 1, NULL, '2026-11-03 16:38:29.510031+07'),
	(40, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-04 10:31:09.553664+07'),
	(41, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 10:31:44.162218+07'),
	(42, 2, 'CREATE', 'nha_cung_cap', 1, NULL, '2026-11-04 10:57:21.919355+07'),
	(43, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 10:57:29.314875+07'),
	(44, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 10:57:35.368896+07'),
	(45, 2, 'CREATE', 'nha_cung_cap_san_pham', 1, NULL, '2026-11-04 10:58:45.08907+07'),
	(46, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 1, NULL, '2026-11-04 10:58:45.457189+07'),
	(47, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 1, NULL, '2026-11-04 10:59:07.421739+07'),
	(48, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 1, NULL, '2026-11-04 10:59:30.831078+07'),
	(49, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 1, NULL, '2026-11-04 10:59:33.262019+07'),
	(50, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 2, NULL, '2026-11-04 10:59:44.233531+07'),
	(51, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 11:31:56.13304+07'),
	(52, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 11:32:56.205483+07'),
	(53, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 2, NULL, '2026-11-04 11:33:58.936078+07'),
	(54, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 2, NULL, '2026-11-04 12:12:17.013658+07'),
	(55, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 2, NULL, '2026-11-04 12:12:20.214256+07'),
	(56, 2, 'SUPPLIER_RETURN_QUARANTINE', 'phieu_tra_ncc', 1, NULL, '2026-11-04 12:12:29.060721+07'),
	(57, 2, 'SUPPLIER_RETURN_CONFIRM', 'phieu_tra_ncc', 1, NULL, '2026-11-04 12:12:44.501429+07'),
	(58, 2, 'CREATE', 'nha_cung_cap_san_pham', 1, NULL, '2026-11-04 12:13:34.607068+07'),
	(59, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 3, NULL, '2026-11-04 12:13:34.789937+07'),
	(60, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 3, NULL, '2026-11-04 12:13:36.855034+07'),
	(61, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 3, NULL, '2026-11-04 12:14:00.716347+07'),
	(62, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 3, NULL, '2026-11-04 12:14:43.161711+07'),
	(63, 2, 'ACCOUNT_EDIT', 'tai_khoan', 3, NULL, '2026-11-04 12:36:34.171497+07'),
	(64, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 12:58:14.779346+07'),
	(65, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-04 12:58:14.779346+07'),
	(66, 2, 'UPDATE', 'san_pham', 21, NULL, '2026-11-04 12:59:11.791323+07'),
	(67, 2, 'UPDATE', 'quy_cach_san_pham', 17, NULL, '2026-11-04 12:59:11.791323+07'),
	(68, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 3, NULL, '2026-11-04 12:59:11.791323+07'),
	(69, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-04 12:59:43.580452+07'),
	(70, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-04 12:59:43.580452+07'),
	(71, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 31, NULL, '2026-11-04 13:00:10.774914+07'),
	(72, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 4, NULL, '2026-11-04 13:00:10.774914+07'),
	(73, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 4, NULL, '2026-11-04 13:00:16.584068+07'),
	(74, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 4, NULL, '2026-11-04 13:00:31.306911+07'),
	(75, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 4, NULL, '2026-11-04 13:00:35.391049+07'),
	(76, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 32, NULL, '2026-11-04 13:01:10.070012+07'),
	(77, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 5, NULL, '2026-11-04 13:01:10.070012+07'),
	(78, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 5, NULL, '2026-11-04 13:01:12.073721+07'),
	(79, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 5, NULL, '2026-11-04 13:01:23.814677+07'),
	(80, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 5, NULL, '2026-11-04 13:01:27.226165+07'),
	(81, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-04 13:02:13.461228+07'),
	(82, 3, 'CHECKOUT', 'don_hang', 2, NULL, '2026-11-04 13:03:18.413361+07'),
	(83, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 13:03:44.833403+07'),
	(84, 4, 'ORDER_DANG_CHUAN_BI', 'don_hang', 2, NULL, '2026-11-04 13:04:11.849425+07'),
	(85, 4, 'ORDER_DANG_GIAO', 'don_hang', 2, NULL, '2026-11-04 13:04:26.28501+07'),
	(86, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 13:05:04.978915+07'),
	(87, 2, 'ORDER_DA_GIAO', 'don_hang', 2, NULL, '2026-11-04 13:05:10.352992+07'),
	(88, 2, 'CREATE', 'nha_cung_cap', 2, NULL, '2026-11-04 13:10:07.968792+07'),
	(89, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 2, NULL, '2026-11-04 13:10:07.968792+07'),
	(90, 2, 'UPDATE', 'nha_cung_cap', 2, NULL, '2026-11-04 13:10:10.779908+07'),
	(91, 2, 'UPDATE', 'nha_cung_cap', 2, NULL, '2026-11-04 13:10:34.045753+07'),
	(92, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 33, NULL, '2026-11-04 13:11:08.69586+07'),
	(93, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 6, NULL, '2026-11-04 13:11:08.69586+07'),
	(94, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 6, NULL, '2026-11-04 13:15:18.672048+07'),
	(95, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 6, NULL, '2026-11-04 13:15:46.748109+07'),
	(96, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 6, NULL, '2026-11-04 13:15:49.496649+07'),
	(97, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 34, NULL, '2026-11-04 13:43:56.957398+07'),
	(98, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 7, NULL, '2026-11-04 13:43:56.957398+07'),
	(99, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 7, NULL, '2026-11-04 13:44:16.373392+07'),
	(100, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 7, NULL, '2026-11-04 13:53:59.862233+07');
INSERT INTO public.nhat_ky_hoat_dong OVERRIDING SYSTEM VALUE VALUES
	(101, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 7, NULL, '2026-11-04 13:54:10.677797+07'),
	(102, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 35, NULL, '2026-11-04 13:54:57.810125+07'),
	(103, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 8, NULL, '2026-11-04 13:54:57.810125+07'),
	(104, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 8, NULL, '2026-11-04 13:55:08.848794+07'),
	(105, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-15 14:03:39.037519+07'),
	(106, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 8, NULL, '2026-11-15 14:04:19.083592+07'),
	(107, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 8, NULL, '2026-11-15 14:04:27.396664+07'),
	(108, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 36, NULL, '2026-11-15 14:05:54.594634+07'),
	(109, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 9, NULL, '2026-11-15 14:05:54.594634+07'),
	(110, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 9, NULL, '2026-11-15 14:06:07.752294+07'),
	(111, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 9, NULL, '2026-11-15 14:07:24.035317+07'),
	(112, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 9, NULL, '2026-11-15 14:07:28.16431+07'),
	(113, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 4, NULL, '2026-11-15 14:08:01.077523+07'),
	(114, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 5, NULL, '2026-11-15 14:08:09.629563+07'),
	(115, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 37, NULL, '2026-11-15 14:09:13.89244+07'),
	(116, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 10, NULL, '2026-11-15 14:09:13.89244+07'),
	(117, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 10, NULL, '2026-11-15 14:09:34.614701+07'),
	(118, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 10, NULL, '2026-11-15 14:09:40.50754+07'),
	(119, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 10, NULL, '2026-11-15 14:09:48.91325+07'),
	(120, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 14:19:52.228479+07'),
	(121, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 14:28:56.635521+07'),
	(122, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 14:29:49.451727+07'),
	(123, 2, 'CREATE', 'khuyen_mai', 1, NULL, '2026-11-04 14:33:44.457276+07'),
	(124, 3, 'CHECKOUT', 'don_hang', 3, NULL, '2026-11-04 14:34:38.732069+07'),
	(125, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 14:35:21.951468+07'),
	(126, 4, 'ORDER_DANG_CHUAN_BI', 'don_hang', 3, NULL, '2026-11-04 14:35:34.329885+07'),
	(127, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 14:36:06.46461+07'),
	(128, 4, 'ORDER_DA_HUY', 'don_hang', 3, NULL, '2026-11-04 14:37:04.762617+07'),
	(129, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 6, NULL, '2026-11-04 14:38:17.917651+07'),
	(130, 2, 'STAFF_PROFILE', 'nhan_vien', 2, NULL, '2026-11-04 14:49:00.451955+07'),
	(131, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 16:02:34.904803+07'),
	(132, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-04 16:06:24.292369+07'),
	(133, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 16:16:20.216214+07'),
	(134, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 11, NULL, '2026-11-04 16:18:20.873601+07'),
	(135, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 11, NULL, '2026-11-04 16:18:30.274333+07'),
	(136, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 11, NULL, '2026-11-04 16:18:56.527476+07'),
	(137, 2, 'RECEIPT_DATES', 'chi_tiet_lan_nhap', 11, NULL, '2026-11-04 16:47:35.587197+07'),
	(138, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 11, NULL, '2026-11-04 16:47:55.792225+07'),
	(139, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 12, NULL, '2026-11-04 16:48:33.864302+07'),
	(140, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 12, NULL, '2026-11-04 16:48:39.612381+07'),
	(141, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 12, NULL, '2026-11-04 16:49:48.743673+07'),
	(142, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 12, NULL, '2026-11-04 16:50:17.101014+07'),
	(143, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 16:57:24.927009+07'),
	(144, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 16:57:36.813736+07'),
	(145, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 16:58:33.382964+07'),
	(146, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-04 17:01:06.848412+07'),
	(147, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-04 17:03:45.786161+07'),
	(148, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 13, NULL, '2026-11-04 17:20:14.801639+07'),
	(149, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 13, NULL, '2026-11-04 17:20:32.142359+07'),
	(150, 4, 'RECEIPT_DRAFT', 'lan_nhap_hang', 13, NULL, '2026-11-04 17:21:10.930847+07'),
	(151, 4, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 13, NULL, '2026-11-04 17:21:56.50741+07'),
	(152, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 38, NULL, '2026-11-04 17:29:08.79452+07'),
	(153, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 14, NULL, '2026-11-04 17:29:08.79452+07'),
	(154, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 15, NULL, '2026-11-04 17:29:32.283776+07'),
	(155, 2, 'PURCHASE_DA_DUYET', 'don_dat_hang_ncc', 15, NULL, '2026-11-04 17:29:37.163446+07'),
	(186, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-07 19:12:27.624876+07'),
	(187, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-07 19:45:29.981298+07'),
	(188, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-07 19:45:29.981298+07'),
	(189, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-07 19:45:42.209431+07'),
	(190, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-07 19:45:42.209431+07'),
	(191, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 39, NULL, '2026-11-07 19:47:08.37355+07'),
	(192, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 40, NULL, '2026-11-07 19:47:15.778221+07'),
	(193, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 41, NULL, '2026-11-07 19:47:21.654046+07'),
	(194, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 42, NULL, '2026-11-07 19:47:28.526976+07'),
	(195, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 43, NULL, '2026-11-07 19:47:37.189569+07'),
	(196, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 44, NULL, '2026-11-07 19:47:45.690126+07'),
	(197, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 45, NULL, '2026-11-07 19:47:52.184601+07'),
	(198, 2, 'STOCK_ADJUST', 'dieu_chinh_so_luong', 46, NULL, '2026-11-07 19:48:11.970284+07'),
	(199, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 44, NULL, '2026-11-07 20:03:12.879314+07'),
	(200, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 44, NULL, '2026-11-07 20:03:17.895325+07'),
	(201, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 45, NULL, '2026-11-07 20:04:16.814618+07'),
	(202, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 45, NULL, '2026-11-07 20:04:20.515294+07'),
	(203, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 44, NULL, '2026-11-07 20:04:56.693895+07'),
	(204, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 45, NULL, '2026-11-07 20:05:33.072203+07'),
	(205, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 46, NULL, '2026-11-07 20:05:57.794819+07'),
	(206, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 47, NULL, '2026-11-07 20:06:17.046454+07'),
	(207, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 47, NULL, '2026-11-07 20:06:21.282405+07'),
	(208, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 46, NULL, '2026-11-07 20:06:23.640955+07'),
	(209, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 46, NULL, '2026-11-07 20:21:21.527205+07'),
	(210, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 48, NULL, '2026-11-07 20:21:58.958308+07'),
	(211, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 48, NULL, '2026-11-07 20:22:03.712417+07'),
	(212, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-07 20:23:35.136678+07'),
	(213, 3, 'CHECKOUT', 'don_hang', 36, NULL, '2026-11-07 20:23:40.626183+07'),
	(214, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 36, NULL, '2026-11-07 20:23:57.794667+07'),
	(215, 2, 'ORDER_DANG_GIAO', 'don_hang', 36, NULL, '2026-11-07 20:24:00.962555+07'),
	(216, 2, 'ORDER_DA_GIAO', 'don_hang', 36, NULL, '2026-11-07 20:24:03.891591+07'),
	(217, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-08 13:05:26.842716+07'),
	(218, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 13:06:19.797015+07'),
	(219, 5, 'REGISTER', 'tai_khoan', 5, NULL, '2026-11-08 13:36:04.528191+07'),
	(220, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-08 13:36:05.039286+07'),
	(221, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-08 13:58:29.685332+07'),
	(222, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 14:07:48.442756+07'),
	(223, 5, 'PASSWORD_RESET_OTP', 'tai_khoan', 5, NULL, '2026-11-08 14:17:40.508557+07'),
	(224, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 14:18:10.667802+07'),
	(225, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-08 14:18:27.061316+07'),
	(226, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-08 14:21:37.42176+07'),
	(227, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-08 14:31:09.413202+07'),
	(228, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-08 14:31:09.413202+07'),
	(229, 2, 'CREATE', 'khuyen_mai', 34, NULL, '2026-11-08 15:03:19.26275+07'),
	(230, 2, 'UPDATE', 'khuyen_mai', 1, NULL, '2026-11-08 15:03:45.086902+07');
INSERT INTO public.nhat_ky_hoat_dong OVERRIDING SYSTEM VALUE VALUES
	(231, 2, 'UPDATE', 'khuyen_mai', 1, NULL, '2026-11-08 15:04:04.149984+07'),
	(232, 5, 'CHECKOUT', 'don_hang', 37, NULL, '2026-11-08 15:15:30.126268+07'),
	(233, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 37, NULL, '2026-11-08 15:15:46.004724+07'),
	(234, 2, 'ORDER_DANG_GIAO', 'don_hang', 37, NULL, '2026-11-08 15:15:48.551074+07'),
	(235, 2, 'ORDER_DA_GIAO', 'don_hang', 37, NULL, '2026-11-08 15:15:50.298675+07'),
	(236, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 15:21:01.214918+07'),
	(237, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 71, NULL, '2026-11-08 15:23:04.721186+07'),
	(238, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 47, NULL, '2026-11-08 15:23:04.721186+07'),
	(239, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 49, NULL, '2026-11-08 15:23:44.149261+07'),
	(240, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 49, NULL, '2026-11-08 15:23:49.336349+07'),
	(241, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-08 15:25:46.554382+07'),
	(242, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 15:28:24.988022+07');


--
-- Data for Name: password_reset_challenge; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.password_reset_challenge VALUES
	('73e37192-2814-4ed8-9470-7112ddee92e4', 5, NULL, '2026-11-08 14:10:16.603355+07', 0, NULL, NULL, true, true, '2026-11-08 14:05:16.603355+07'),
	('1952c34f-de94-42cc-bf7b-d2ec81c6a45e', 5, NULL, '2026-11-08 14:11:50.133957+07', 0, NULL, NULL, true, true, '2026-11-08 14:06:50.133957+07'),
	('c976587b-5cc1-443b-bd3f-a5b122be2fe3', 5, NULL, '2026-11-08 14:18:00.724709+07', 0, NULL, NULL, true, true, '2026-11-08 14:13:00.724709+07'),
	('09721f70-2c85-4d65-8ae6-3a9c40c8301a', 5, NULL, '2026-11-08 14:21:27.259834+07', 0, NULL, NULL, true, false, '2026-11-08 14:16:27.259834+07');


--
-- Data for Name: pham_vi_khuyen_mai; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.pham_vi_khuyen_mai OVERRIDING SYSTEM VALUE VALUES
	(34, 34, NULL, 10, NULL),
	(35, 34, NULL, 9, NULL),
	(36, 34, NULL, 8, NULL),
	(37, 34, NULL, 7, NULL),
	(38, 34, NULL, 3, NULL),
	(39, 34, NULL, 2, NULL),
	(40, 34, NULL, 1, NULL),
	(44, 1, NULL, 10, NULL),
	(45, 1, NULL, 8, NULL),
	(46, 1, NULL, 7, NULL);


--
-- Data for Name: phien_xac_thuc; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.phien_xac_thuc OVERRIDING SYSTEM VALUE VALUES
	(1, 1, '6167d736b6d17cc669d1072b42f3c79d43b24677b650681445856b902e025309', '2026-11-03 21:15:59.011174+07', true, '2026-11-03 13:15:58.629248+07'),
	(2, 1, '03ca8c2bf444b990dab5045e081e693f63e3056fe2dfa155aa59d78cfb8b78df', '2026-11-03 23:23:53.391026+07', true, '2026-11-03 15:23:53.063427+07'),
	(26, 4, 'fa82d9bdc80a0c86a47d08319f47fa4765deab1f55abe88a2841f10bd493550d', '2026-11-04 22:19:52.575499+07', true, '2026-11-04 14:19:52.228479+07'),
	(6, 4, 'c9fa5b4ae74f3b2da396f4f713b03f1905ef36a7c7653c0fccccd189fc9381f0', '2026-11-03 23:33:57.441364+07', true, '2026-11-03 15:33:57.120073+07'),
	(5, 2, '942e12434a9146876045a6792edce58b9f5fe6023c4c00f19eebb7d5231d1bb8', '2026-11-03 23:29:55.312403+07', true, '2026-11-03 15:29:54.975792+07'),
	(7, 4, 'e893555090347beaf46028c9fea11a7b721625f1c03da4879ac8606ca01bec33', '2026-11-03 23:34:06.571629+07', false, '2026-11-03 15:34:06.244885+07'),
	(8, 4, '2d3f35666ed6e267ea9a69e437b8fb8e53f6d8fabd00675e136600744ee56b0c', '2026-11-03 23:34:21.741593+07', true, '2026-11-03 15:34:21.42966+07'),
	(9, 4, '5b78973097fa90613987f5019dddc66d70195201c78b1786e5c5d1bcef9556f8', '2026-11-03 23:34:32.354979+07', true, '2026-11-03 15:34:31.972223+07'),
	(27, 4, 'd60066a6322b7813d6f8441092dce21d15ced1b213ee387d29492400bc379449', '2026-11-04 22:28:57.0393+07', true, '2026-11-04 14:28:56.635521+07'),
	(28, 2, 'a1e89eff7e79b8a1979c79ea6caa6aecb1154c27705264df6775a6d205383a8c', '2026-11-04 22:29:49.782755+07', true, '2026-11-04 14:29:49.451727+07'),
	(30, 2, '5ad374e468341d1b37aae7147314db05f6254e92cdab16c398fcb38d435e786b', '2026-11-04 22:36:06.800234+07', true, '2026-11-04 14:36:06.46461+07'),
	(3, 3, '074eb33ae4f0639f4efdff2e2b7dac8efb737c388d1dfcdba7cc53b8e9cae0a7', '2026-11-03 23:26:58.319005+07', true, '2026-11-03 15:26:57.972299+07'),
	(4, 3, '9643564d76961228ea4e7316bee0b131656c370ae9bdd65a9d681750a306192c', '2026-11-03 23:27:06.107111+07', true, '2026-11-03 15:27:05.711546+07'),
	(10, 2, '9d9d73ceea1bf80b331bb5c0fd8b254ba94a868f41e8e180207f02345ed18509', '2026-11-03 23:42:49.742288+07', true, '2026-11-03 15:42:48.875423+07'),
	(11, 4, 'de143aebfe36df1e0df7849c4560261ff28c303e91f162a07505b7b19be40288', '2026-11-03 23:53:53.537902+07', true, '2026-11-03 15:53:53.114177+07'),
	(12, 4, 'eb6f43fbb36370c8766cdaf817ee64dd9fa8c006e67ac4ea804adfc1e815634c', '2026-11-03 23:54:30.446587+07', true, '2026-11-03 15:54:30.035152+07'),
	(13, 4, '2b35c35c66815371a57c93bac8064b03170e28fdc4ad0554e18896b146703ee1', '2026-11-03 23:55:26.574215+07', true, '2026-11-03 15:55:26.226455+07'),
	(14, 2, '1d43c8483b2058013db7ed3a46c319686861807d8ea892cb73c89bfa35c66e36', '2026-11-03 23:56:04.550803+07', true, '2026-11-03 15:56:04.156692+07'),
	(15, 2, 'f892ff8a28407f18869e077d0f2823735c50972123fb789a7be911ec23b9d771', '2026-11-03 23:56:18.159059+07', true, '2026-11-03 15:56:17.766715+07'),
	(16, 3, '8464b708f475c06cea3c4715277225137197366626d47cc5e4bd826901998ac4', '2026-11-03 23:57:38.577874+07', false, '2026-11-03 15:57:38.276637+07'),
	(17, 4, '2103c4432ef6ec4f0ef016439e46c8a113dccdfecb4c1cbf9394d095c2038604', '2026-11-03 23:58:52.849175+07', true, '2026-11-03 15:58:52.525088+07'),
	(19, 3, '494fc5d42d5afccf9df32b907f3787282b517ad865e5299d28f9a9f38c4aa73d', '2026-11-04 00:37:26.574017+07', false, '2026-11-03 16:37:25.617458+07'),
	(18, 2, '9bb40af5a9cac3c6711d8d09e28cbdc123ef3c6a4064284d5a96374283d4746a', '2026-11-04 00:10:30.837251+07', true, '2026-11-03 16:10:29.983817+07'),
	(20, 3, '0658149d2b2442f4ac4aadb8cd3608ab3f480d6d277363b15f1f7fd3b77873a3', '2026-11-04 18:31:09.995028+07', false, '2026-11-04 10:31:09.553664+07'),
	(22, 3, 'd7b6694d8fe10602253034420efb75738fe18528e90c73716a2a549d7a888434', '2026-11-04 21:02:13.817865+07', false, '2026-11-04 13:02:13.461228+07'),
	(21, 2, 'fbb95406df674d380bcaf8c4e7f479aef4312903ed3f58c09fc1fa87eea73fa4', '2026-11-04 18:31:44.452433+07', true, '2026-11-04 10:31:44.162218+07'),
	(23, 4, '25dd336e600eb073fc59ab6d016994a4eca7d50b7adeaeec687c2f4e4c9f3824', '2026-11-04 21:03:45.211475+07', true, '2026-11-04 13:03:44.833403+07'),
	(24, 2, 'ee96ecbe6ff2c6f86170d186d75696ab055744fac760f94ba84eb2d6ce23cdc9', '2026-11-04 21:05:05.256177+07', false, '2026-11-04 13:05:04.978915+07'),
	(25, 2, '4183a80ffdf26191e8b5c7324729c420faa4ed29b90e3513690221e0ad89406c', '2026-11-15 22:03:39.581231+07', true, '2026-11-15 14:03:39.037519+07'),
	(29, 4, 'f0e12dfda5e13b099532a98d4b4cf1fd4c013875c13ce979defb0bfd2ea21146', '2026-11-04 22:35:22.246273+07', true, '2026-11-04 14:35:21.951468+07'),
	(31, 2, '98624957ece775c31b8fd7f76ac953646aed0a2e60a71f4dc415714c348a972b', '2026-11-05 00:02:35.213789+07', false, '2026-11-04 16:02:34.904803+07'),
	(32, 3, 'ee0b58aef6f598eebe454bb7352312891690c2ebf7a984afc61ace1c3f4271d2', '2026-11-05 00:06:24.607271+07', true, '2026-11-04 16:06:24.292369+07'),
	(33, 2, 'd64dc18f82dc620e1de5545c3e2490430d71d6df674eaa6e0254476d6782ea43', '2026-11-05 00:16:20.543496+07', false, '2026-11-04 16:16:20.216214+07'),
	(34, 4, '4d6990a340d7c4707ede65b45e32daa1b95099eb79d3255d9e124e0110a5e2ca', '2026-11-05 00:57:27.442013+07', false, '2026-11-04 16:57:24.927009+07'),
	(35, 4, '486f7b87bc57873a58ca0928bd6061e31dc28905856fe482b094cd110d5dad17', '2026-11-05 00:57:38.097097+07', false, '2026-11-04 16:57:36.813736+07'),
	(36, 4, '31b41570d2d581a89ca7424c6d6950b7352163bdfef4f15a16e92ff6706ad1c3', '2026-11-05 00:58:33.815755+07', false, '2026-11-04 16:58:33.382964+07'),
	(37, 4, 'e469cc965b598abe646f0c64e9538ff51c72bdbffa390f7f8d7341814877f740', '2026-11-05 01:01:07.45073+07', false, '2026-11-04 17:01:06.848412+07'),
	(38, 2, '7e3d5da91d910560cfbe7fea1bbb6dc092717643cdb4b9e4a60e154cd89ad6aa', '2026-11-05 01:03:46.109798+07', false, '2026-11-04 17:03:45.786161+07'),
	(59, 2, 'd2abc8ddaf2fdb22c959243cabc7d22b36bea11468ae8c5b06cc055638065670', '2026-11-08 03:12:28.388186+07', false, '2026-11-07 19:12:27.624876+07'),
	(60, 3, '5660c14a5d8a50696728116dbe9d2690d389294b8c5af17f7c1898f6a24497c5', '2026-11-08 04:23:35.571725+07', false, '2026-11-07 20:23:35.136678+07'),
	(61, 3, '81b69e35b3acd75739582e34894075f2abfcff5e0fef12c00f8ec7a3fd00d07c', '2026-11-08 21:05:27.3484+07', true, '2026-11-08 13:05:26.842716+07'),
	(68, 5, '89fd81bed631c4373c5a890f8762d99a9c82671fa9621d1106f76451d269b5b6', '2026-11-08 22:21:37.753482+07', false, '2026-11-08 14:21:37.42176+07'),
	(62, 2, '4e244674034bacfe4402ae652a3c3966fc1f2bd70268efaef8dbe22be2bc18bf', '2026-11-08 21:06:20.080329+07', true, '2026-11-08 13:06:19.797015+07'),
	(65, 2, '390aa87c955831e42cdb0c8bda1a89ef3070b04b64ecab0c453cda4660e43772', '2026-11-08 22:07:48.816292+07', true, '2026-11-08 14:07:48.442756+07'),
	(63, 5, 'e23f6570593ea7eeb703f5c188caadfd53b060cb884abed71c2a5721347cfea0', '2026-11-08 21:36:05.401497+07', true, '2026-11-08 13:36:05.039286+07'),
	(64, 5, 'a2e144047f5d155748088f96472d6bd67bffc3788d3cca6d80ae1f676fed486e', '2026-11-08 21:58:30.724522+07', true, '2026-11-08 13:58:29.685332+07'),
	(66, 2, '8ea695071e4451895a238c5c8734f8a8e243a5a4a3ec8bd9413f7019c598e7dc', '2026-11-08 22:18:10.948034+07', true, '2026-11-08 14:18:10.667802+07'),
	(67, 5, '1e1e9e1dc291350a8c379e099c3670dd376c31bcf353c4609b86c2f1e22257f6', '2026-11-08 22:18:27.36246+07', true, '2026-11-08 14:18:27.061316+07'),
	(69, 2, '22a8acfba8a57c26341c7842372cebd8bb3e1ec2478cb587d77253fa0a420973', '2026-11-08 23:21:02.004198+07', true, '2026-11-08 15:21:01.214918+07'),
	(70, 4, 'a4b8f697b981098eefc10df170b970b8ee8ce68712a9d415021ab2e4734effd4', '2026-11-08 23:25:46.975873+07', true, '2026-11-08 15:25:46.554382+07'),
	(71, 2, 'c7fc57bb7a4a8a2f3ffbe3a61495b7ec63e410fa0efbbae87d5ec0e08d18be01', '2026-11-08 23:28:25.293836+07', false, '2026-11-08 15:28:24.988022+07');


--
-- Data for Name: quy_cach_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.quy_cach_san_pham OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'Lon lẻ', 'LON', 1, 12000.00, 8000.00, true),
	(2, 1, 'Lốc 6 lon', 'LOC', 6, 69000.00, 48000.00, true),
	(3, 1, 'Thùng 24 lon', 'THUNG', 24, 270000.00, 192000.00, true),
	(5, 2, 'Thùng 24 chai', 'THUNG', 24, 160000.00, 108000.00, true),
	(4, 2, 'Chai lẻ', 'CHAI', 1, 7010.00, 4500.00, true),
	(10, 11, 'Lon lẻ', 'LON', 1, 11000.00, 0.00, true),
	(12, 12, 'Lon lẻ', 'LON', 1, 12000.00, 0.00, true),
	(13, 10, 'Lon lẻ', 'LON', 1, 11000.00, 0.00, true),
	(14, 18, 'Chai lẻ', 'CHAI', 1, 10000.00, 0.00, true),
	(15, 15, 'Chai lẻ', 'CHAI', 1, 6000.00, 0.00, true),
	(16, 13, 'Chai lẻ', 'CHAI', 1, 6000.00, 0.00, true),
	(18, 5, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(19, 19, 'Lon lẻ', 'LON', 1, 11000.00, 0.00, true),
	(21, 8, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(22, 6, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(23, 16, 'Chai lẻ', 'CHAI', 1, 12000.00, 0.00, true),
	(24, 4, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(25, 23, 'Chai lẻ', 'CHAI', 1, 12000.00, 0.00, true),
	(27, 3, 'Lon lẻ', 'LON', 1, 11000.00, 0.00, true),
	(28, 14, 'Chai lẻ', 'CHAI', 1, 6000.00, 0.00, true),
	(29, 9, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(30, 7, 'Lon lẻ', 'LON', 1, 10000.00, 0.00, true),
	(9, 27, 'Hộp lẻ', 'HOP', 1, 8000.00, 0.00, true),
	(26, 22, 'Chai lẻ', 'CHAI', 1, 13500.00, 10416.67, true),
	(33, 22, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 78500.00, 62500.02, false),
	(7, 25, 'Hộp lẻ', 'HOP', 1, 9000.00, 5000.00, true),
	(17, 21, 'Lon lẻ', 'LON', 1, 12000.00, 5050.51, true),
	(71, 22, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 313000.00, 250000.08, false),
	(34, 23, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 288000.00, 0.00, false),
	(11, 17, 'Chai lẻ', 'CHAI', 1, 12500.00, 10000.00, true),
	(31, 17, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 300000.00, 240000.00, false),
	(6, 20, 'Lon lẻ', 'LON', 1, 42000.00, 33333.33, true),
	(32, 20, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 250000.00, 199999.98, false),
	(8, 26, 'Hộp lẻ', 'HOP', 1, 15000.00, 11666.67, true),
	(36, 26, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 88000.00, 70000.02, false),
	(37, 26, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 350500.00, 280000.08, false),
	(20, 24, 'Hộp lẻ', 'HOP', 1, 31000.00, 24444.44, true),
	(38, 24, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 183500.00, 146666.64, false),
	(35, 24, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 733500.00, 586666.56, false);


--
-- Data for Name: quyen; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.quyen OVERRIDING SYSTEM VALUE VALUES
	(1, 'PRODUCT_READ', 'Tra cứu sản phẩm', 'BR1', 'READ', NULL),
	(2, 'PRODUCT_MANAGE', 'Quản lý danh mục sản phẩm', 'BR1', 'MANAGE', NULL),
	(3, 'PRODUCT_ADJUST', 'Điều chỉnh số lượng', 'BR1', 'ADJUST', NULL),
	(4, 'CATEGORY_READ', 'Tra cứu loại / thương hiệu', 'BR2', 'READ', NULL),
	(5, 'CATEGORY_MANAGE', 'Quản lý loại / thương hiệu', 'BR2', 'MANAGE', NULL),
	(6, 'CART_MANAGE', 'Giỏ hàng cá nhân', 'BR3', 'MANAGE', NULL),
	(7, 'PAYMENT_READ', 'Đối soát thanh toán', 'BR4', 'READ', NULL),
	(8, 'POS_PAYMENT', 'Thu tiền tại quầy', 'BR4', 'POS', NULL),
	(9, 'REFUND_MANAGE', 'Hoàn tiền', 'BR4', 'REFUND', NULL),
	(10, 'ORDER_READ', 'Tra cứu đơn', 'BR5', 'READ', NULL),
	(11, 'ORDER_UPDATE', 'Xử lý đơn online', 'BR5', 'UPDATE', NULL),
	(12, 'POS_SELL', 'Bán hàng tại quầy', 'BR5', 'POS', NULL),
	(13, 'INVOICE_READ', 'Tra cứu và in hóa đơn', 'BR6', 'READ', NULL),
	(14, 'INVOICE_REPORT', 'Thống kê hóa đơn', 'BR6', 'REPORT', NULL),
	(15, 'CUSTOMER_READ', 'Tra cứu khách hàng', 'BR7', 'READ', NULL),
	(16, 'CUSTOMER_SUPPORT', 'Chăm sóc khách hàng', 'BR7', 'SUPPORT', NULL),
	(17, 'CUSTOMER_LOCK', 'Khóa tài khoản khách hàng', 'BR7', 'LOCK', NULL),
	(18, 'STAFF_SELF', 'Hồ sơ cá nhân nhân viên', 'BR8', 'SELF', NULL),
	(19, 'STAFF_MANAGE', 'Quản lý nhân viên', 'BR8', 'MANAGE', NULL),
	(20, 'ROLE_MANAGE', 'Phân quyền', 'BR9', 'MANAGE', NULL),
	(21, 'REPORT_STOCK', 'Tra cứu tồn và lịch sử nhập', 'BR10', 'STOCK', NULL),
	(22, 'REPORT_ALL', 'Báo cáo quản trị', 'BR10', 'ALL', NULL),
	(23, 'PROMOTION_MANAGE', 'Quản lý khuyến mãi', 'BR11', 'MANAGE', NULL),
	(24, 'SUPPLIER_READ', 'Tra cứu nhà cung cấp', 'BR12', 'READ', NULL),
	(25, 'SUPPLIER_MANAGE', 'Quản lý nhà cung cấp', 'BR12', 'MANAGE', NULL),
	(26, 'IMPORT_CREATE', 'Lập đơn NCC', 'BR13', 'CREATE', NULL),
	(27, 'IMPORT_APPROVE', 'Duyệt đơn NCC', 'BR13', 'APPROVE', NULL),
	(28, 'IMPORT_RECEIVE', 'Xác nhận nhập', 'BR13', 'RECEIVE', NULL),
	(29, 'IMPORT_READ', 'Tra cứu đơn NCC và nhập', 'BR13', 'READ', NULL),
	(30, 'IMPORT_REPORT', 'Thống kê nhập hàng', 'BR13', 'REPORT', NULL);


--
-- Data for Name: san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.san_pham OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 'SP001', 'Nước ngọt vị cam 330ml', NULL, NULL, NULL, NULL, '330ml', 'LON', NULL, NULL, NULL, 'DANG_BAN', true, '2026-11-03 13:15:07.268189+07', '2026-11-03 13:15:07.268189+07'),
	(2, 2, 2, 'SP002', 'Nước suối 500ml', '', NULL, NULL, NULL, '500ml', 'CHAI', NULL, NULL, NULL, 'DANG_BAN', true, '2026-11-03 13:15:07.268189+07', '2026-11-03 13:15:07.268189+07'),
	(3, 1, 9, 'CAT-SCHWEPPES-SODA-330', 'Schweppes Soda 330ml', 'Nước soda Schweppes đóng lon; có thể dùng trực tiếp hoặc pha đồ uống.', NULL, NULL, NULL, '330ml', 'LON', 'Soda', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(4, 1, 8, 'CAT-MIRINDA-CAM-320', 'Mirinda cam 320ml', 'Nước ngọt có ga Mirinda hương cam, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(5, 1, 8, 'CAT-MIRINDA-SODA-320', 'Mirinda soda kem 320ml', 'Nước ngọt có ga Mirinda hương soda kem, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Soda kem', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(6, 1, 7, 'CAT-7UP-320', '7Up chanh 320ml', 'Nước ngọt có ga 7Up hương chanh, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(7, 1, 6, 'CAT-FANTA-CAM-330', 'Fanta cam 330ml', 'Nước ngọt có ga Fanta hương cam, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(8, 1, 5, 'CAT-SPRITE-330', 'Sprite chanh 330ml', 'Nước ngọt có ga Sprite hương chanh, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(9, 1, 4, 'CAT-PEPSI-320', 'Pepsi Cola 320ml', 'Nước ngọt có ga Pepsi vị cola, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(10, 1, 4, 'CAT-PEPSI-ZERO-320', 'Pepsi không calo 320ml', 'Nước ngọt Pepsi không calo, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(11, 1, 3, 'CAT-COCA-330', 'Coca-Cola nguyên bản 330ml', 'Nước ngọt có ga vị cola, đóng lon. Dùng ngon hơn khi uống lạnh.', NULL, NULL, NULL, '330ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(12, 1, 3, 'CAT-COCA-ZERO-330', 'Coca-Cola Zero Sugar 330ml', 'Nước ngọt có ga Coca-Cola Zero Sugar, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(13, 2, 15, 'CAT-LAVIE-500', 'La Vie 500ml', 'Nước uống La Vie đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(14, 2, 14, 'CAT-DASANI-500', 'Dasani 500ml', 'Nước uống Dasani đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(15, 2, 13, 'CAT-AQUAFINA-500', 'Aquafina 500ml', 'Nước uống Aquafina đóng chai, tiện mang theo.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(16, 3, 18, 'CAT-KHONGDO-500', 'Trà xanh Không Độ 500ml', 'Trà xanh Không Độ đóng chai dùng sẵn.', NULL, NULL, NULL, '500ml', 'CHAI', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(17, 3, 17, 'CAT-TEAPLUS-455', 'TEA+ trà ô long 455ml', 'Trà ô long TEA+ đóng chai dùng sẵn.', NULL, NULL, NULL, '455ml', 'CHAI', 'Ô long', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(18, 3, 16, 'CAT-C2-CHANH-455', 'C2 trà xanh hương chanh 455ml', 'Trà xanh C2 hương chanh, đóng chai dùng sẵn.', NULL, NULL, NULL, '455ml', 'CHAI', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(19, 7, 12, 'CAT-NUMBER1-330', 'Number 1 330ml', 'Nước tăng lực Number 1 đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(20, 7, 11, 'CAT-REDBULL-250', 'Red Bull 250ml', 'Nước tăng lực Red Bull đóng lon.', NULL, NULL, NULL, '250ml', 'LON', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(22, 8, 20, 'CAT-POCARI-350', 'Pocari Sweat 350ml', 'Nước uống Pocari Sweat đóng chai.', NULL, NULL, NULL, '350ml', 'CHAI', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(23, 8, 19, 'CAT-REVIVE-500', 'Revive 500ml', 'Nước uống thể thao Revive đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(24, 9, 21, 'CAT-VFRESH-CAM-1000', 'Vfresh nước cam 1 lít', 'Đồ uống trái cây Vfresh vị cam, đóng hộp.', NULL, NULL, NULL, '1 lít', 'HOP', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(25, 10, 24, 'CAT-MILO-180', 'Milo ca cao 180ml', 'Đồ uống ca cao Milo đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Ca cao', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(27, 10, 22, 'CAT-VINAMILK-180', 'Vinamilk sữa có đường 180ml', 'Sữa Vinamilk có đường đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Có đường', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(26, 10, 23, 'CAT-TH-180', 'TH true MILK sữa có đường 180ml', 'Sữa TH true MILK có đường đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Có đường', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(21, 7, 10, 'CAT-STING-330', 'Sting dâu 330ml', 'Nước tăng lực Sting hương dâu, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Dâu', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07');


--
-- Data for Name: san_pham_yeu_thich; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: so_luong_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.so_luong_san_pham VALUES
	(1, 0, 10, '2026-11-03 13:15:07.268189+07'),
	(2, 0, 10, '2026-11-03 13:15:07.268189+07'),
	(3, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(4, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(5, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(6, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(7, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(8, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(9, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(10, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(11, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(12, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(13, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(14, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(15, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(16, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(18, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(19, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(23, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(27, 0, 10, '2026-11-07 19:47:08.37355+07'),
	(21, 0, 10, '2026-11-07 19:47:37.189569+07'),
	(25, 0, 10, '2026-11-07 19:48:11.970284+07'),
	(20, 60, 10, '2026-11-07 20:03:17.895325+07'),
	(26, 120, 10, '2026-11-07 20:06:21.282405+07'),
	(17, 240, 10, '2026-11-07 20:06:23.640955+07'),
	(24, 172, 10, '2026-11-08 15:15:46.004724+07'),
	(22, 144, 10, '2026-11-08 15:23:49.336349+07');


--
-- Data for Name: su_dung_khuyen_mai; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.su_dung_khuyen_mai OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 3, 11200.00, 'REVERSED', '2026-11-04 14:35:34.329885+07'),
	(34, 34, 6, 37, 18600.00, 'APPLIED', '2026-11-08 15:15:46.004724+07');


--
-- Data for Name: tai_khoan; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tai_khoan OVERRIDING SYSTEM VALUE VALUES
	(1, 'admin@example.com', '$2a$12$MfubYvycFKC0ZqAel2pGE.iRndUT.0pzAoaASMGrF/GlCMYSfPr2e', 'ACTIVE', false, 0, NULL, '2026-11-03 13:15:31.236235+07', '2026-11-03 13:15:31.236235+07'),
	(3, 'khach@waterbus.demo', '$2a$12$2S9Y9IfCzQLO2j2aWseEEuzCzfaKV5jTQP3V72ziXlyReqybw9CFy', 'ACTIVE', false, 0, NULL, '2026-11-03 15:25:38.232189+07', '2026-11-03 15:25:38.232189+07'),
	(5, 'ngogiahung.hcm@gmail.com', '$2a$12$GNzYebmY6Zdwm2pGaI/a8.ZcPbxmD1CBqghry6FrX18bHLEj4l1YS', 'ACTIVE', false, 0, NULL, '2026-11-08 13:36:04.528191+07', '2026-11-08 13:36:04.528191+07'),
	(4, 'quanab@gmail.com', '$2a$12$lCmOhKd9shm64LhJ4Xhe5.qBZFKpwR4muYURmfwwcHpN2xBCcy1wC', 'ACTIVE', false, 0, NULL, '2026-11-03 15:33:33.131211+07', '2026-11-03 15:33:33.131211+07'),
	(2, 'admin1@gmail.com', '$2a$12$fHKdnzX9UlbpNkVWQta84.ay2gcRG2yixliG7Tco62hPQvVD/kfNe', 'ACTIVE', false, 0, NULL, '2026-11-03 15:24:45.072766+07', '2026-11-03 15:24:45.072766+07');


--
-- Data for Name: tai_khoan_vai_tro; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tai_khoan_vai_tro VALUES
	(1, 3),
	(2, 3),
	(4, 2),
	(3, 1),
	(5, 1);


--
-- Data for Name: thanh_toan; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.thanh_toan OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'COD', NULL, NULL, 80000.00, 'PENDING', '2026-11-03 16:37:52.820068+07', NULL),
	(2, 2, 'COD', NULL, NULL, 130000.00, 'PENDING', '2026-11-04 13:03:18.413361+07', NULL),
	(3, 3, 'COD', NULL, NULL, 100800.00, 'PENDING', '2026-11-04 14:34:38.732069+07', NULL),
	(36, 36, 'COD', NULL, NULL, 155000.00, 'PENDING', '2026-11-07 20:23:40.626183+07', NULL),
	(37, 37, 'COD', NULL, NULL, 74400.00, 'PENDING', '2026-11-08 15:15:30.126268+07', NULL);


--
-- Data for Name: thanh_toan_ncc; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: thuong_hieu; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.thuong_hieu OVERRIDING SYSTEM VALUE VALUES
	(1, 'Thương hiệu A', NULL, NULL, true),
	(2, 'Thương hiệu B', NULL, NULL, true),
	(3, 'Coca-Cola', NULL, 'Thương hiệu nước giải khát Coca-Cola.', true),
	(4, 'Pepsi', NULL, 'Thương hiệu nước giải khát Pepsi.', true),
	(5, 'Sprite', NULL, 'Thương hiệu nước ngọt Sprite.', true),
	(6, 'Fanta', NULL, 'Thương hiệu nước ngọt Fanta.', true),
	(7, '7Up', NULL, 'Thương hiệu nước ngọt 7Up.', true),
	(8, 'Mirinda', NULL, 'Thương hiệu nước ngọt Mirinda.', true),
	(9, 'Schweppes', NULL, 'Thương hiệu nước giải khát Schweppes.', true),
	(10, 'Sting', NULL, 'Thương hiệu nước tăng lực Sting.', true),
	(11, 'Red Bull', NULL, 'Thương hiệu nước tăng lực Red Bull.', true),
	(12, 'Number 1', NULL, 'Thương hiệu nước tăng lực Number 1.', true),
	(13, 'Aquafina', NULL, 'Thương hiệu nước uống đóng chai Aquafina.', true),
	(14, 'Dasani', NULL, 'Thương hiệu nước uống đóng chai Dasani.', true),
	(15, 'La Vie', NULL, 'Thương hiệu nước uống đóng chai La Vie.', true),
	(16, 'C2', NULL, 'Thương hiệu trà đóng chai C2.', true),
	(17, 'TEA+', NULL, 'Thương hiệu trà ô long TEA+.', true),
	(18, 'Không Độ', NULL, 'Thương hiệu trà đóng chai Không Độ.', true),
	(19, 'Revive', NULL, 'Thương hiệu nước uống thể thao Revive.', true),
	(20, 'Pocari Sweat', NULL, 'Thương hiệu nước uống Pocari Sweat.', true),
	(21, 'Vfresh', NULL, 'Thương hiệu đồ uống trái cây Vfresh.', true),
	(22, 'Vinamilk', NULL, 'Thương hiệu sữa Vinamilk.', true),
	(23, 'TH true MILK', NULL, 'Thương hiệu sữa TH true MILK.', true),
	(24, 'Milo', NULL, 'Thương hiệu đồ uống ca cao Milo.', true);


--
-- Data for Name: uu_dai_so_luong; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: vai_tro; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.vai_tro OVERRIDING SYSTEM VALUE VALUES
	(1, 'KHACH_HANG', 'Khách hàng', 'Mua hàng qua Website'),
	(2, 'NHAN_VIEN', 'Nhân viên', 'Bán tại quầy, xử lý đơn và nhập hàng theo đơn NCC đã duyệt'),
	(3, 'QUAN_TRI_VIEN', 'Quản trị viên', 'Có tất cả quyền nhân viên và nghiệp vụ quản trị');


--
-- Data for Name: vai_tro_quyen; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.vai_tro_quyen VALUES
	(1, 1),
	(2, 1),
	(3, 1),
	(3, 2),
	(3, 3),
	(1, 4),
	(2, 4),
	(3, 4),
	(3, 5),
	(1, 6),
	(2, 7),
	(3, 7),
	(2, 8),
	(3, 8),
	(3, 9),
	(2, 10),
	(3, 10),
	(2, 11),
	(3, 11),
	(2, 12),
	(3, 12),
	(2, 13),
	(3, 13),
	(3, 14),
	(2, 15),
	(3, 15),
	(2, 16),
	(3, 16),
	(3, 17),
	(2, 18),
	(3, 18),
	(3, 19),
	(3, 20),
	(2, 21),
	(3, 21),
	(3, 22),
	(3, 23),
	(2, 24),
	(3, 24),
	(3, 25),
	(3, 26),
	(3, 27),
	(2, 28),
	(3, 28),
	(2, 29),
	(3, 29),
	(3, 30);


--
-- Name: bien_dong_so_luong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.bien_dong_so_luong_id_seq', 65, true);


--
-- Name: chi_tiet_don_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_don_hang_id_seq', 37, true);


--
-- Name: chi_tiet_don_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_don_ncc_id_seq', 47, true);


--
-- Name: chi_tiet_gio_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_gio_hang_id_seq', 56, true);


--
-- Name: chi_tiet_hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_hoa_don_id_seq', 37, true);


--
-- Name: chi_tiet_lan_nhap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_lan_nhap_id_seq', 49, true);


--
-- Name: cong_no_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cong_no_ncc_id_seq', 49, true);


--
-- Name: danh_gia_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.danh_gia_san_pham_id_seq', 1, false);


--
-- Name: dia_chi_giao_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dia_chi_giao_hang_id_seq', 2, true);


--
-- Name: dieu_chinh_so_luong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dieu_chinh_so_luong_id_seq', 46, true);


--
-- Name: don_dat_hang_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.don_dat_hang_ncc_id_seq', 47, true);


--
-- Name: don_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.don_hang_id_seq', 37, true);


--
-- Name: giay_to_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.giay_to_ncc_id_seq', 1, false);


--
-- Name: gio_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gio_hang_id_seq', 215, true);


--
-- Name: hinh_anh_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hinh_anh_san_pham_id_seq', 1, false);


--
-- Name: hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hoa_don_id_seq', 37, true);


--
-- Name: hoan_tien_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hoan_tien_id_seq', 1, false);


--
-- Name: khach_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.khach_hang_id_seq', 6, true);


--
-- Name: khuyen_mai_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.khuyen_mai_id_seq', 34, true);


--
-- Name: lan_nhap_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lan_nhap_hang_id_seq', 49, true);


--
-- Name: lich_su_hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lich_su_hoa_don_id_seq', 33, true);


--
-- Name: lich_su_trang_thai_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lich_su_trang_thai_don_id_seq', 45, true);


--
-- Name: lien_he_khach_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lien_he_khach_hang_id_seq', 1, false);


--
-- Name: loai_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.loai_san_pham_id_seq', 10, true);


--
-- Name: nha_cung_cap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nha_cung_cap_id_seq', 2, true);


--
-- Name: nhan_vien_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nhan_vien_id_seq', 4, true);


--
-- Name: nhat_ky_hoat_dong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nhat_ky_hoat_dong_id_seq', 242, true);


--
-- Name: pham_vi_khuyen_mai_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pham_vi_khuyen_mai_id_seq', 46, true);


--
-- Name: phien_xac_thuc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.phien_xac_thuc_id_seq', 71, true);


--
-- Name: quy_cach_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.quy_cach_san_pham_id_seq', 71, true);


--
-- Name: quyen_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.quyen_id_seq', 30, true);


--
-- Name: san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.san_pham_id_seq', 27, true);


--
-- Name: su_dung_khuyen_mai_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.su_dung_khuyen_mai_id_seq', 34, true);


--
-- Name: tai_khoan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tai_khoan_id_seq', 5, true);


--
-- Name: thanh_toan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.thanh_toan_id_seq', 37, true);


--
-- Name: thanh_toan_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.thanh_toan_ncc_id_seq', 1, false);


--
-- Name: thuong_hieu_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.thuong_hieu_id_seq', 24, true);


--
-- Name: uu_dai_so_luong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.uu_dai_so_luong_id_seq', 1, false);


--
-- Name: vai_tro_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.vai_tro_id_seq', 3, true);


--
-- Name: backend_schema_migration backend_schema_migration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backend_schema_migration
    ADD CONSTRAINT backend_schema_migration_pkey PRIMARY KEY (version);


--
-- Name: bien_dong_so_luong bien_dong_so_luong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bien_dong_so_luong
    ADD CONSTRAINT bien_dong_so_luong_pkey PRIMARY KEY (id);


--
-- Name: bien_dong_so_luong bien_dong_so_luong_san_pham_id_loai_nguon_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bien_dong_so_luong
    ADD CONSTRAINT bien_dong_so_luong_san_pham_id_loai_nguon_id_key UNIQUE (san_pham_id, loai, nguon_id);


--
-- Name: chi_tiet_don_hang chi_tiet_don_hang_don_hang_id_quy_cach_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_hang
    ADD CONSTRAINT chi_tiet_don_hang_don_hang_id_quy_cach_id_key UNIQUE (don_hang_id, quy_cach_id);


--
-- Name: chi_tiet_don_hang chi_tiet_don_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_hang
    ADD CONSTRAINT chi_tiet_don_hang_pkey PRIMARY KEY (id);


--
-- Name: chi_tiet_don_ncc chi_tiet_don_ncc_don_ncc_id_quy_cach_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_ncc
    ADD CONSTRAINT chi_tiet_don_ncc_don_ncc_id_quy_cach_id_key UNIQUE (don_ncc_id, quy_cach_id);


--
-- Name: chi_tiet_don_ncc chi_tiet_don_ncc_id_don_ncc_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_ncc
    ADD CONSTRAINT chi_tiet_don_ncc_id_don_ncc_id_key UNIQUE (id, don_ncc_id);


--
-- Name: chi_tiet_don_ncc chi_tiet_don_ncc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_ncc
    ADD CONSTRAINT chi_tiet_don_ncc_pkey PRIMARY KEY (id);


--
-- Name: chi_tiet_gio_hang chi_tiet_gio_hang_gio_hang_id_quy_cach_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_gio_hang
    ADD CONSTRAINT chi_tiet_gio_hang_gio_hang_id_quy_cach_id_key UNIQUE (gio_hang_id, quy_cach_id);


--
-- Name: chi_tiet_gio_hang chi_tiet_gio_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_gio_hang
    ADD CONSTRAINT chi_tiet_gio_hang_pkey PRIMARY KEY (id);


--
-- Name: chi_tiet_hoa_don chi_tiet_hoa_don_hoa_don_id_chi_tiet_don_hang_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_hoa_don
    ADD CONSTRAINT chi_tiet_hoa_don_hoa_don_id_chi_tiet_don_hang_id_key UNIQUE (hoa_don_id, chi_tiet_don_hang_id);


--
-- Name: chi_tiet_hoa_don chi_tiet_hoa_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_hoa_don
    ADD CONSTRAINT chi_tiet_hoa_don_pkey PRIMARY KEY (id);


--
-- Name: chi_tiet_lan_nhap chi_tiet_lan_nhap_lan_nhap_id_ct_don_ncc_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_nhap
    ADD CONSTRAINT chi_tiet_lan_nhap_lan_nhap_id_ct_don_ncc_id_key UNIQUE (lan_nhap_id, ct_don_ncc_id);


--
-- Name: chi_tiet_lan_nhap chi_tiet_lan_nhap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_nhap
    ADD CONSTRAINT chi_tiet_lan_nhap_pkey PRIMARY KEY (id);


--
-- Name: cong_no_ncc cong_no_ncc_lan_nhap_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cong_no_ncc
    ADD CONSTRAINT cong_no_ncc_lan_nhap_id_key UNIQUE (lan_nhap_id);


--
-- Name: cong_no_ncc cong_no_ncc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cong_no_ncc
    ADD CONSTRAINT cong_no_ncc_pkey PRIMARY KEY (id);


--
-- Name: danh_gia_san_pham danh_gia_san_pham_chi_tiet_don_hang_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia_san_pham
    ADD CONSTRAINT danh_gia_san_pham_chi_tiet_don_hang_id_key UNIQUE (chi_tiet_don_hang_id);


--
-- Name: danh_gia_san_pham danh_gia_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia_san_pham
    ADD CONSTRAINT danh_gia_san_pham_pkey PRIMARY KEY (id);


--
-- Name: dia_chi_giao_hang dia_chi_giao_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dia_chi_giao_hang
    ADD CONSTRAINT dia_chi_giao_hang_pkey PRIMARY KEY (id);


--
-- Name: dieu_chinh_so_luong dieu_chinh_so_luong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dieu_chinh_so_luong
    ADD CONSTRAINT dieu_chinh_so_luong_pkey PRIMARY KEY (id);


--
-- Name: don_dat_hang_ncc don_dat_hang_ncc_ma_don_nhap_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_dat_hang_ncc
    ADD CONSTRAINT don_dat_hang_ncc_ma_don_nhap_key UNIQUE (ma_don_nhap);


--
-- Name: don_dat_hang_ncc don_dat_hang_ncc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_dat_hang_ncc
    ADD CONSTRAINT don_dat_hang_ncc_pkey PRIMARY KEY (id);


--
-- Name: don_hang don_hang_ma_don_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_hang
    ADD CONSTRAINT don_hang_ma_don_key UNIQUE (ma_don);


--
-- Name: don_hang don_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_hang
    ADD CONSTRAINT don_hang_pkey PRIMARY KEY (id);


--
-- Name: giay_to_ncc giay_to_ncc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giay_to_ncc
    ADD CONSTRAINT giay_to_ncc_pkey PRIMARY KEY (id);


--
-- Name: gio_hang gio_hang_khach_hang_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gio_hang
    ADD CONSTRAINT gio_hang_khach_hang_id_key UNIQUE (khach_hang_id);


--
-- Name: gio_hang gio_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gio_hang
    ADD CONSTRAINT gio_hang_pkey PRIMARY KEY (id);


--
-- Name: hinh_anh_san_pham hinh_anh_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hinh_anh_san_pham
    ADD CONSTRAINT hinh_anh_san_pham_pkey PRIMARY KEY (id);


--
-- Name: hoa_don hoa_don_don_hang_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_don_hang_id_key UNIQUE (don_hang_id);


--
-- Name: hoa_don hoa_don_ma_hoa_don_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_ma_hoa_don_key UNIQUE (ma_hoa_don);


--
-- Name: hoa_don hoa_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_pkey PRIMARY KEY (id);


--
-- Name: hoan_tien hoan_tien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoan_tien
    ADD CONSTRAINT hoan_tien_pkey PRIMARY KEY (id);


--
-- Name: khach_hang khach_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_pkey PRIMARY KEY (id);


--
-- Name: khach_hang khach_hang_tai_khoan_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_tai_khoan_id_key UNIQUE (tai_khoan_id);


--
-- Name: khuyen_mai khuyen_mai_ma_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khuyen_mai
    ADD CONSTRAINT khuyen_mai_ma_code_key UNIQUE (ma_code);


--
-- Name: khuyen_mai khuyen_mai_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khuyen_mai
    ADD CONSTRAINT khuyen_mai_pkey PRIMARY KEY (id);


--
-- Name: lan_nhap_hang lan_nhap_hang_id_don_ncc_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_nhap_hang
    ADD CONSTRAINT lan_nhap_hang_id_don_ncc_id_key UNIQUE (id, don_ncc_id);


--
-- Name: lan_nhap_hang lan_nhap_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_nhap_hang
    ADD CONSTRAINT lan_nhap_hang_pkey PRIMARY KEY (id);


--
-- Name: lich_su_hoa_don lich_su_hoa_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_hoa_don
    ADD CONSTRAINT lich_su_hoa_don_pkey PRIMARY KEY (id);


--
-- Name: lich_su_trang_thai_don lich_su_trang_thai_don_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_trang_thai_don
    ADD CONSTRAINT lich_su_trang_thai_don_pkey PRIMARY KEY (id);


--
-- Name: lien_he_khach_hang lien_he_khach_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lien_he_khach_hang
    ADD CONSTRAINT lien_he_khach_hang_pkey PRIMARY KEY (id);


--
-- Name: loai_san_pham loai_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loai_san_pham
    ADD CONSTRAINT loai_san_pham_pkey PRIMARY KEY (id);


--
-- Name: loai_san_pham loai_san_pham_ten_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loai_san_pham
    ADD CONSTRAINT loai_san_pham_ten_key UNIQUE (ten);


--
-- Name: nha_cung_cap nha_cung_cap_ma_so_thue_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap
    ADD CONSTRAINT nha_cung_cap_ma_so_thue_key UNIQUE (ma_so_thue);


--
-- Name: nha_cung_cap nha_cung_cap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap
    ADD CONSTRAINT nha_cung_cap_pkey PRIMARY KEY (id);


--
-- Name: nha_cung_cap_san_pham nha_cung_cap_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap_san_pham
    ADD CONSTRAINT nha_cung_cap_san_pham_pkey PRIMARY KEY (nha_cung_cap_id, san_pham_id);


--
-- Name: nhan_vien nhan_vien_ma_nhan_vien_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_ma_nhan_vien_key UNIQUE (ma_nhan_vien);


--
-- Name: nhan_vien nhan_vien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_pkey PRIMARY KEY (id);


--
-- Name: nhan_vien nhan_vien_tai_khoan_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_tai_khoan_id_key UNIQUE (tai_khoan_id);


--
-- Name: nhat_ky_hoat_dong nhat_ky_hoat_dong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhat_ky_hoat_dong
    ADD CONSTRAINT nhat_ky_hoat_dong_pkey PRIMARY KEY (id);


--
-- Name: password_reset_challenge password_reset_challenge_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_challenge
    ADD CONSTRAINT password_reset_challenge_pkey PRIMARY KEY (id);


--
-- Name: pham_vi_khuyen_mai pham_vi_khuyen_mai_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pham_vi_khuyen_mai
    ADD CONSTRAINT pham_vi_khuyen_mai_pkey PRIMARY KEY (id);


--
-- Name: phien_xac_thuc phien_xac_thuc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phien_xac_thuc
    ADD CONSTRAINT phien_xac_thuc_pkey PRIMARY KEY (id);


--
-- Name: phien_xac_thuc phien_xac_thuc_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phien_xac_thuc
    ADD CONSTRAINT phien_xac_thuc_token_hash_key UNIQUE (token_hash);


--
-- Name: quy_cach_san_pham quy_cach_san_pham_id_san_pham_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_cach_san_pham
    ADD CONSTRAINT quy_cach_san_pham_id_san_pham_id_key UNIQUE (id, san_pham_id);


--
-- Name: quy_cach_san_pham quy_cach_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_cach_san_pham
    ADD CONSTRAINT quy_cach_san_pham_pkey PRIMARY KEY (id);


--
-- Name: quy_cach_san_pham quy_cach_san_pham_san_pham_id_ten_quy_cach_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_cach_san_pham
    ADD CONSTRAINT quy_cach_san_pham_san_pham_id_ten_quy_cach_key UNIQUE (san_pham_id, ten_quy_cach);


--
-- Name: quyen quyen_ma_chuc_nang_hanh_dong_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quyen
    ADD CONSTRAINT quyen_ma_chuc_nang_hanh_dong_key UNIQUE (ma_chuc_nang, hanh_dong);


--
-- Name: quyen quyen_ma_quyen_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quyen
    ADD CONSTRAINT quyen_ma_quyen_key UNIQUE (ma_quyen);


--
-- Name: quyen quyen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quyen
    ADD CONSTRAINT quyen_pkey PRIMARY KEY (id);


--
-- Name: san_pham san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham
    ADD CONSTRAINT san_pham_pkey PRIMARY KEY (id);


--
-- Name: san_pham san_pham_sku_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham
    ADD CONSTRAINT san_pham_sku_key UNIQUE (sku);


--
-- Name: san_pham_yeu_thich san_pham_yeu_thich_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham_yeu_thich
    ADD CONSTRAINT san_pham_yeu_thich_pkey PRIMARY KEY (khach_hang_id, san_pham_id);


--
-- Name: so_luong_san_pham so_luong_san_pham_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.so_luong_san_pham
    ADD CONSTRAINT so_luong_san_pham_pkey PRIMARY KEY (san_pham_id);


--
-- Name: su_dung_khuyen_mai su_dung_khuyen_mai_khuyen_mai_id_don_hang_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.su_dung_khuyen_mai
    ADD CONSTRAINT su_dung_khuyen_mai_khuyen_mai_id_don_hang_id_key UNIQUE (khuyen_mai_id, don_hang_id);


--
-- Name: su_dung_khuyen_mai su_dung_khuyen_mai_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.su_dung_khuyen_mai
    ADD CONSTRAINT su_dung_khuyen_mai_pkey PRIMARY KEY (id);


--
-- Name: tai_khoan tai_khoan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan
    ADD CONSTRAINT tai_khoan_pkey PRIMARY KEY (id);


--
-- Name: tai_khoan_vai_tro tai_khoan_vai_tro_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_vai_tro
    ADD CONSTRAINT tai_khoan_vai_tro_pkey PRIMARY KEY (tai_khoan_id, vai_tro_id);


--
-- Name: thanh_toan thanh_toan_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan
    ADD CONSTRAINT thanh_toan_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: thanh_toan thanh_toan_ma_giao_dich_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan
    ADD CONSTRAINT thanh_toan_ma_giao_dich_key UNIQUE (ma_giao_dich);


--
-- Name: thanh_toan_ncc thanh_toan_ncc_ma_tham_chieu_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan_ncc
    ADD CONSTRAINT thanh_toan_ncc_ma_tham_chieu_key UNIQUE (ma_tham_chieu);


--
-- Name: thanh_toan_ncc thanh_toan_ncc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan_ncc
    ADD CONSTRAINT thanh_toan_ncc_pkey PRIMARY KEY (id);


--
-- Name: thanh_toan thanh_toan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan
    ADD CONSTRAINT thanh_toan_pkey PRIMARY KEY (id);


--
-- Name: thuong_hieu thuong_hieu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thuong_hieu
    ADD CONSTRAINT thuong_hieu_pkey PRIMARY KEY (id);


--
-- Name: thuong_hieu thuong_hieu_ten_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thuong_hieu
    ADD CONSTRAINT thuong_hieu_ten_key UNIQUE (ten);


--
-- Name: uu_dai_so_luong uu_dai_so_luong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uu_dai_so_luong
    ADD CONSTRAINT uu_dai_so_luong_pkey PRIMARY KEY (id);


--
-- Name: vai_tro vai_tro_ma_vai_tro_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro
    ADD CONSTRAINT vai_tro_ma_vai_tro_key UNIQUE (ma_vai_tro);


--
-- Name: vai_tro vai_tro_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro
    ADD CONSTRAINT vai_tro_pkey PRIMARY KEY (id);


--
-- Name: vai_tro_quyen vai_tro_quyen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_quyen
    ADD CONSTRAINT vai_tro_quyen_pkey PRIMARY KEY (vai_tro_id, quyen_id);


--
-- Name: idx_don_hang_kenh_ngay; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_don_hang_kenh_ngay ON public.don_hang USING btree (kenh_ban, ngay_dat DESC);


--
-- Name: idx_don_hang_khach; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_don_hang_khach ON public.don_hang USING btree (khach_hang_id, ngay_dat DESC);


--
-- Name: idx_receipt_pending_purchase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receipt_pending_purchase ON public.lan_nhap_hang USING btree (don_ncc_id) WHERE ((trang_thai)::text = 'DRAFT'::text);


--
-- Name: idx_reset_account_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reset_account_created ON public.password_reset_challenge USING btree (tai_khoan_id, tao_luc DESC);


--
-- Name: uq_anh_chinh; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_anh_chinh ON public.hinh_anh_san_pham USING btree (san_pham_id) WHERE anh_chinh;


--
-- Name: uq_dia_chi_mac_dinh; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_dia_chi_mac_dinh ON public.dia_chi_giao_hang USING btree (khach_hang_id) WHERE mac_dinh;


--
-- Name: uq_km_loai; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_km_loai ON public.pham_vi_khuyen_mai USING btree (khuyen_mai_id, loai_san_pham_id) WHERE (loai_san_pham_id IS NOT NULL);


--
-- Name: uq_km_sp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_km_sp ON public.pham_vi_khuyen_mai USING btree (khuyen_mai_id, san_pham_id) WHERE (san_pham_id IS NOT NULL);


--
-- Name: uq_km_th; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_km_th ON public.pham_vi_khuyen_mai USING btree (khuyen_mai_id, thuong_hieu_id) WHERE (thuong_hieu_id IS NOT NULL);


--
-- Name: uq_tai_khoan_email_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_tai_khoan_email_ci ON public.tai_khoan USING btree (lower((email)::text));


--
-- Name: thanh_toan trg_backend_payment_invoice; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_backend_payment_invoice AFTER UPDATE OF trang_thai ON public.thanh_toan FOR EACH ROW EXECUTE FUNCTION public.backend_payment_invoice();


--
-- Name: chi_tiet_hoa_don trg_chi_tiet_hoa_don_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_chi_tiet_hoa_don_immutable BEFORE DELETE OR UPDATE ON public.chi_tiet_hoa_don FOR EACH ROW EXECUTE FUNCTION public.fn_chi_tiet_hoa_don_immutable();


--
-- Name: bien_dong_so_luong trg_chong_sua_bien_dong; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_chong_sua_bien_dong BEFORE DELETE OR UPDATE ON public.bien_dong_so_luong FOR EACH ROW EXECUTE FUNCTION public.fn_chong_sua_bien_dong();


--
-- Name: dieu_chinh_so_luong trg_dieu_chinh_so_luong; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_dieu_chinh_so_luong BEFORE INSERT ON public.dieu_chinh_so_luong FOR EACH ROW EXECUTE FUNCTION public.fn_dieu_chinh_so_luong();


--
-- Name: hoa_don trg_hoa_don_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_hoa_don_immutable BEFORE DELETE OR UPDATE ON public.hoa_don FOR EACH ROW EXECUTE FUNCTION public.fn_hoa_don_immutable();


--
-- Name: hoa_don trg_invoice_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_invoice_history AFTER UPDATE OF trang_thai ON public.hoa_don FOR EACH ROW EXECUTE FUNCTION public.fn_invoice_history();


--
-- Name: san_pham trg_khoi_tao_so_luong; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_khoi_tao_so_luong AFTER INSERT ON public.san_pham FOR EACH ROW EXECUTE FUNCTION public.fn_khoi_tao_so_luong();


--
-- Name: don_hang trg_order_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_order_history AFTER UPDATE OF trang_thai ON public.don_hang FOR EACH ROW EXECUTE FUNCTION public.fn_order_history();


--
-- Name: don_hang trg_order_inventory; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_order_inventory BEFORE INSERT OR UPDATE OF trang_thai ON public.don_hang FOR EACH ROW EXECUTE FUNCTION public.fn_order_inventory();


--
-- Name: quy_cach_san_pham trg_package_automatic_price; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_package_automatic_price BEFORE INSERT OR UPDATE OF gia_von, gia_ban ON public.quy_cach_san_pham FOR EACH ROW EXECUTE FUNCTION public.fn_package_automatic_price();


--
-- Name: thanh_toan_ncc trg_paid_ncc_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_paid_ncc_immutable BEFORE DELETE OR UPDATE ON public.thanh_toan_ncc FOR EACH ROW EXECUTE FUNCTION public.fn_immutable_posted();


--
-- Name: chi_tiet_don_hang trg_protect_order_lines; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_order_lines BEFORE INSERT OR DELETE OR UPDATE ON public.chi_tiet_don_hang FOR EACH ROW EXECUTE FUNCTION public.fn_protect_order_lines();


--
-- Name: chi_tiet_lan_nhap trg_protect_received_lines; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_received_lines BEFORE INSERT OR DELETE OR UPDATE ON public.chi_tiet_lan_nhap FOR EACH ROW EXECUTE FUNCTION public.fn_protect_received_lines();


--
-- Name: lan_nhap_hang trg_receive_finalize; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_receive_finalize AFTER UPDATE OF trang_thai ON public.lan_nhap_hang FOR EACH ROW EXECUTE FUNCTION public.fn_receive_finalize();


--
-- Name: lan_nhap_hang trg_receive_inventory; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_receive_inventory BEFORE UPDATE OF trang_thai ON public.lan_nhap_hang FOR EACH ROW EXECUTE FUNCTION public.fn_receive_inventory();


--
-- Name: bien_dong_so_luong trg_so_luong_bien_dong; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_so_luong_bien_dong BEFORE INSERT ON public.bien_dong_so_luong FOR EACH ROW EXECUTE FUNCTION public.fn_so_luong_bien_dong();


--
-- Name: thanh_toan_ncc trg_supplier_payment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_supplier_payment AFTER INSERT ON public.thanh_toan_ncc FOR EACH ROW EXECUTE FUNCTION public.fn_supplier_payment();


--
-- Name: bien_dong_so_luong bien_dong_so_luong_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bien_dong_so_luong
    ADD CONSTRAINT bien_dong_so_luong_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: chi_tiet_don_hang chi_tiet_don_hang_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_hang
    ADD CONSTRAINT chi_tiet_don_hang_don_hang_id_fkey FOREIGN KEY (don_hang_id) REFERENCES public.don_hang(id);


--
-- Name: chi_tiet_don_hang chi_tiet_don_hang_quy_cach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_hang
    ADD CONSTRAINT chi_tiet_don_hang_quy_cach_id_fkey FOREIGN KEY (quy_cach_id) REFERENCES public.quy_cach_san_pham(id);


--
-- Name: chi_tiet_don_ncc chi_tiet_don_ncc_don_ncc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_ncc
    ADD CONSTRAINT chi_tiet_don_ncc_don_ncc_id_fkey FOREIGN KEY (don_ncc_id) REFERENCES public.don_dat_hang_ncc(id);


--
-- Name: chi_tiet_don_ncc chi_tiet_don_ncc_quy_cach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_don_ncc
    ADD CONSTRAINT chi_tiet_don_ncc_quy_cach_id_fkey FOREIGN KEY (quy_cach_id) REFERENCES public.quy_cach_san_pham(id);


--
-- Name: chi_tiet_gio_hang chi_tiet_gio_hang_gio_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_gio_hang
    ADD CONSTRAINT chi_tiet_gio_hang_gio_hang_id_fkey FOREIGN KEY (gio_hang_id) REFERENCES public.gio_hang(id) ON DELETE CASCADE;


--
-- Name: chi_tiet_gio_hang chi_tiet_gio_hang_quy_cach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_gio_hang
    ADD CONSTRAINT chi_tiet_gio_hang_quy_cach_id_fkey FOREIGN KEY (quy_cach_id) REFERENCES public.quy_cach_san_pham(id);


--
-- Name: chi_tiet_hoa_don chi_tiet_hoa_don_chi_tiet_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_hoa_don
    ADD CONSTRAINT chi_tiet_hoa_don_chi_tiet_don_hang_id_fkey FOREIGN KEY (chi_tiet_don_hang_id) REFERENCES public.chi_tiet_don_hang(id);


--
-- Name: chi_tiet_hoa_don chi_tiet_hoa_don_hoa_don_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_hoa_don
    ADD CONSTRAINT chi_tiet_hoa_don_hoa_don_id_fkey FOREIGN KEY (hoa_don_id) REFERENCES public.hoa_don(id);


--
-- Name: chi_tiet_lan_nhap chi_tiet_lan_nhap_ct_don_ncc_id_don_ncc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_nhap
    ADD CONSTRAINT chi_tiet_lan_nhap_ct_don_ncc_id_don_ncc_id_fkey FOREIGN KEY (ct_don_ncc_id, don_ncc_id) REFERENCES public.chi_tiet_don_ncc(id, don_ncc_id);


--
-- Name: chi_tiet_lan_nhap chi_tiet_lan_nhap_lan_nhap_id_don_ncc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_nhap
    ADD CONSTRAINT chi_tiet_lan_nhap_lan_nhap_id_don_ncc_id_fkey FOREIGN KEY (lan_nhap_id, don_ncc_id) REFERENCES public.lan_nhap_hang(id, don_ncc_id);


--
-- Name: cong_no_ncc cong_no_ncc_lan_nhap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cong_no_ncc
    ADD CONSTRAINT cong_no_ncc_lan_nhap_id_fkey FOREIGN KEY (lan_nhap_id) REFERENCES public.lan_nhap_hang(id);


--
-- Name: danh_gia_san_pham danh_gia_san_pham_chi_tiet_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia_san_pham
    ADD CONSTRAINT danh_gia_san_pham_chi_tiet_don_hang_id_fkey FOREIGN KEY (chi_tiet_don_hang_id) REFERENCES public.chi_tiet_don_hang(id);


--
-- Name: danh_gia_san_pham danh_gia_san_pham_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.danh_gia_san_pham
    ADD CONSTRAINT danh_gia_san_pham_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id);


--
-- Name: dia_chi_giao_hang dia_chi_giao_hang_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dia_chi_giao_hang
    ADD CONSTRAINT dia_chi_giao_hang_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id) ON DELETE CASCADE;


--
-- Name: dieu_chinh_so_luong dieu_chinh_so_luong_nguoi_dieu_chinh_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dieu_chinh_so_luong
    ADD CONSTRAINT dieu_chinh_so_luong_nguoi_dieu_chinh_id_fkey FOREIGN KEY (nguoi_dieu_chinh_id) REFERENCES public.nhan_vien(id);


--
-- Name: dieu_chinh_so_luong dieu_chinh_so_luong_quy_cach_id_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dieu_chinh_so_luong
    ADD CONSTRAINT dieu_chinh_so_luong_quy_cach_id_san_pham_id_fkey FOREIGN KEY (quy_cach_id, san_pham_id) REFERENCES public.quy_cach_san_pham(id, san_pham_id);


--
-- Name: dieu_chinh_so_luong dieu_chinh_so_luong_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dieu_chinh_so_luong
    ADD CONSTRAINT dieu_chinh_so_luong_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: don_dat_hang_ncc don_dat_hang_ncc_nguoi_duyet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_dat_hang_ncc
    ADD CONSTRAINT don_dat_hang_ncc_nguoi_duyet_id_fkey FOREIGN KEY (nguoi_duyet_id) REFERENCES public.nhan_vien(id);


--
-- Name: don_dat_hang_ncc don_dat_hang_ncc_nguoi_lap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_dat_hang_ncc
    ADD CONSTRAINT don_dat_hang_ncc_nguoi_lap_id_fkey FOREIGN KEY (nguoi_lap_id) REFERENCES public.nhan_vien(id);


--
-- Name: don_dat_hang_ncc don_dat_hang_ncc_nha_cung_cap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_dat_hang_ncc
    ADD CONSTRAINT don_dat_hang_ncc_nha_cung_cap_id_fkey FOREIGN KEY (nha_cung_cap_id) REFERENCES public.nha_cung_cap(id);


--
-- Name: don_hang don_hang_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_hang
    ADD CONSTRAINT don_hang_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id);


--
-- Name: don_hang don_hang_khuyen_mai_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_hang
    ADD CONSTRAINT don_hang_khuyen_mai_id_fkey FOREIGN KEY (khuyen_mai_id) REFERENCES public.khuyen_mai(id);


--
-- Name: don_hang don_hang_nhan_vien_xu_ly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.don_hang
    ADD CONSTRAINT don_hang_nhan_vien_xu_ly_id_fkey FOREIGN KEY (nhan_vien_xu_ly_id) REFERENCES public.nhan_vien(id);


--
-- Name: giay_to_ncc giay_to_ncc_nha_cung_cap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giay_to_ncc
    ADD CONSTRAINT giay_to_ncc_nha_cung_cap_id_fkey FOREIGN KEY (nha_cung_cap_id) REFERENCES public.nha_cung_cap(id);


--
-- Name: gio_hang gio_hang_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gio_hang
    ADD CONSTRAINT gio_hang_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id) ON DELETE CASCADE;


--
-- Name: hinh_anh_san_pham hinh_anh_san_pham_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hinh_anh_san_pham
    ADD CONSTRAINT hinh_anh_san_pham_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id) ON DELETE CASCADE;


--
-- Name: hoa_don hoa_don_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_don_hang_id_fkey FOREIGN KEY (don_hang_id) REFERENCES public.don_hang(id);


--
-- Name: hoa_don hoa_don_nguoi_lap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoa_don
    ADD CONSTRAINT hoa_don_nguoi_lap_id_fkey FOREIGN KEY (nguoi_lap_id) REFERENCES public.nhan_vien(id);


--
-- Name: hoan_tien hoan_tien_nguoi_xu_ly_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoan_tien
    ADD CONSTRAINT hoan_tien_nguoi_xu_ly_id_fkey FOREIGN KEY (nguoi_xu_ly_id) REFERENCES public.nhan_vien(id);


--
-- Name: hoan_tien hoan_tien_thanh_toan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hoan_tien
    ADD CONSTRAINT hoan_tien_thanh_toan_id_fkey FOREIGN KEY (thanh_toan_id) REFERENCES public.thanh_toan(id);


--
-- Name: khach_hang khach_hang_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id);


--
-- Name: lan_nhap_hang lan_nhap_hang_don_ncc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_nhap_hang
    ADD CONSTRAINT lan_nhap_hang_don_ncc_id_fkey FOREIGN KEY (don_ncc_id) REFERENCES public.don_dat_hang_ncc(id);


--
-- Name: lan_nhap_hang lan_nhap_hang_nguoi_nhan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_nhap_hang
    ADD CONSTRAINT lan_nhap_hang_nguoi_nhan_id_fkey FOREIGN KEY (nguoi_nhan_id) REFERENCES public.nhan_vien(id);


--
-- Name: lich_su_hoa_don lich_su_hoa_don_hoa_don_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_hoa_don
    ADD CONSTRAINT lich_su_hoa_don_hoa_don_id_fkey FOREIGN KEY (hoa_don_id) REFERENCES public.hoa_don(id);


--
-- Name: lich_su_hoa_don lich_su_hoa_don_tai_khoan_thuc_hien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_hoa_don
    ADD CONSTRAINT lich_su_hoa_don_tai_khoan_thuc_hien_id_fkey FOREIGN KEY (tai_khoan_thuc_hien_id) REFERENCES public.tai_khoan(id);


--
-- Name: lich_su_trang_thai_don lich_su_trang_thai_don_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_trang_thai_don
    ADD CONSTRAINT lich_su_trang_thai_don_don_hang_id_fkey FOREIGN KEY (don_hang_id) REFERENCES public.don_hang(id);


--
-- Name: lich_su_trang_thai_don lich_su_trang_thai_don_tai_khoan_thuc_hien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lich_su_trang_thai_don
    ADD CONSTRAINT lich_su_trang_thai_don_tai_khoan_thuc_hien_id_fkey FOREIGN KEY (tai_khoan_thuc_hien_id) REFERENCES public.tai_khoan(id);


--
-- Name: lien_he_khach_hang lien_he_khach_hang_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lien_he_khach_hang
    ADD CONSTRAINT lien_he_khach_hang_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id);


--
-- Name: lien_he_khach_hang lien_he_khach_hang_nhan_vien_phan_hoi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lien_he_khach_hang
    ADD CONSTRAINT lien_he_khach_hang_nhan_vien_phan_hoi_id_fkey FOREIGN KEY (nhan_vien_phan_hoi_id) REFERENCES public.nhan_vien(id);


--
-- Name: nha_cung_cap nha_cung_cap_nguoi_xac_minh_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap
    ADD CONSTRAINT nha_cung_cap_nguoi_xac_minh_id_fkey FOREIGN KEY (nguoi_xac_minh_id) REFERENCES public.tai_khoan(id);


--
-- Name: nha_cung_cap_san_pham nha_cung_cap_san_pham_nha_cung_cap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap_san_pham
    ADD CONSTRAINT nha_cung_cap_san_pham_nha_cung_cap_id_fkey FOREIGN KEY (nha_cung_cap_id) REFERENCES public.nha_cung_cap(id);


--
-- Name: nha_cung_cap_san_pham nha_cung_cap_san_pham_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap_san_pham
    ADD CONSTRAINT nha_cung_cap_san_pham_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: nhan_vien nhan_vien_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id);


--
-- Name: nhat_ky_hoat_dong nhat_ky_hoat_dong_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhat_ky_hoat_dong
    ADD CONSTRAINT nhat_ky_hoat_dong_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id);


--
-- Name: password_reset_challenge password_reset_challenge_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_challenge
    ADD CONSTRAINT password_reset_challenge_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id) ON DELETE CASCADE;


--
-- Name: pham_vi_khuyen_mai pham_vi_khuyen_mai_khuyen_mai_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pham_vi_khuyen_mai
    ADD CONSTRAINT pham_vi_khuyen_mai_khuyen_mai_id_fkey FOREIGN KEY (khuyen_mai_id) REFERENCES public.khuyen_mai(id) ON DELETE CASCADE;


--
-- Name: pham_vi_khuyen_mai pham_vi_khuyen_mai_loai_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pham_vi_khuyen_mai
    ADD CONSTRAINT pham_vi_khuyen_mai_loai_san_pham_id_fkey FOREIGN KEY (loai_san_pham_id) REFERENCES public.loai_san_pham(id);


--
-- Name: pham_vi_khuyen_mai pham_vi_khuyen_mai_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pham_vi_khuyen_mai
    ADD CONSTRAINT pham_vi_khuyen_mai_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: pham_vi_khuyen_mai pham_vi_khuyen_mai_thuong_hieu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pham_vi_khuyen_mai
    ADD CONSTRAINT pham_vi_khuyen_mai_thuong_hieu_id_fkey FOREIGN KEY (thuong_hieu_id) REFERENCES public.thuong_hieu(id);


--
-- Name: phien_xac_thuc phien_xac_thuc_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phien_xac_thuc
    ADD CONSTRAINT phien_xac_thuc_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id) ON DELETE CASCADE;


--
-- Name: quy_cach_san_pham quy_cach_san_pham_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_cach_san_pham
    ADD CONSTRAINT quy_cach_san_pham_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: san_pham san_pham_loai_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham
    ADD CONSTRAINT san_pham_loai_san_pham_id_fkey FOREIGN KEY (loai_san_pham_id) REFERENCES public.loai_san_pham(id);


--
-- Name: san_pham san_pham_thuong_hieu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham
    ADD CONSTRAINT san_pham_thuong_hieu_id_fkey FOREIGN KEY (thuong_hieu_id) REFERENCES public.thuong_hieu(id);


--
-- Name: san_pham_yeu_thich san_pham_yeu_thich_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham_yeu_thich
    ADD CONSTRAINT san_pham_yeu_thich_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id) ON DELETE CASCADE;


--
-- Name: san_pham_yeu_thich san_pham_yeu_thich_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.san_pham_yeu_thich
    ADD CONSTRAINT san_pham_yeu_thich_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: so_luong_san_pham so_luong_san_pham_san_pham_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.so_luong_san_pham
    ADD CONSTRAINT so_luong_san_pham_san_pham_id_fkey FOREIGN KEY (san_pham_id) REFERENCES public.san_pham(id);


--
-- Name: su_dung_khuyen_mai su_dung_khuyen_mai_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.su_dung_khuyen_mai
    ADD CONSTRAINT su_dung_khuyen_mai_don_hang_id_fkey FOREIGN KEY (don_hang_id) REFERENCES public.don_hang(id);


--
-- Name: su_dung_khuyen_mai su_dung_khuyen_mai_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.su_dung_khuyen_mai
    ADD CONSTRAINT su_dung_khuyen_mai_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id);


--
-- Name: su_dung_khuyen_mai su_dung_khuyen_mai_khuyen_mai_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.su_dung_khuyen_mai
    ADD CONSTRAINT su_dung_khuyen_mai_khuyen_mai_id_fkey FOREIGN KEY (khuyen_mai_id) REFERENCES public.khuyen_mai(id);


--
-- Name: tai_khoan_vai_tro tai_khoan_vai_tro_tai_khoan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_vai_tro
    ADD CONSTRAINT tai_khoan_vai_tro_tai_khoan_id_fkey FOREIGN KEY (tai_khoan_id) REFERENCES public.tai_khoan(id) ON DELETE CASCADE;


--
-- Name: tai_khoan_vai_tro tai_khoan_vai_tro_vai_tro_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_vai_tro
    ADD CONSTRAINT tai_khoan_vai_tro_vai_tro_id_fkey FOREIGN KEY (vai_tro_id) REFERENCES public.vai_tro(id) ON DELETE RESTRICT;


--
-- Name: thanh_toan thanh_toan_don_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan
    ADD CONSTRAINT thanh_toan_don_hang_id_fkey FOREIGN KEY (don_hang_id) REFERENCES public.don_hang(id);


--
-- Name: thanh_toan_ncc thanh_toan_ncc_cong_no_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thanh_toan_ncc
    ADD CONSTRAINT thanh_toan_ncc_cong_no_id_fkey FOREIGN KEY (cong_no_id) REFERENCES public.cong_no_ncc(id);


--
-- Name: uu_dai_so_luong uu_dai_so_luong_khuyen_mai_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uu_dai_so_luong
    ADD CONSTRAINT uu_dai_so_luong_khuyen_mai_id_fkey FOREIGN KEY (khuyen_mai_id) REFERENCES public.khuyen_mai(id) ON DELETE CASCADE;


--
-- Name: uu_dai_so_luong uu_dai_so_luong_quy_cach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uu_dai_so_luong
    ADD CONSTRAINT uu_dai_so_luong_quy_cach_id_fkey FOREIGN KEY (quy_cach_id) REFERENCES public.quy_cach_san_pham(id);


--
-- Name: vai_tro_quyen vai_tro_quyen_quyen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_quyen
    ADD CONSTRAINT vai_tro_quyen_quyen_id_fkey FOREIGN KEY (quyen_id) REFERENCES public.quyen(id) ON DELETE CASCADE;


--
-- Name: vai_tro_quyen vai_tro_quyen_vai_tro_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_quyen
    ADD CONSTRAINT vai_tro_quyen_vai_tro_id_fkey FOREIGN KEY (vai_tro_id) REFERENCES public.vai_tro(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict HqdEQRc2MRWeNIeRTOQz6p1YufoXSmH0G3awYF0gt3SpV7WvECqxVzND6BQfWlO

COMMIT;

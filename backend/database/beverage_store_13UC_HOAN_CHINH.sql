-- Complete PostgreSQL schema and data exported from Docker on 20261111-123259 (Asia/Bangkok).
-- PRIVATE SNAPSHOT: includes account hashes, customer data and authentication history.
-- Restore into an EMPTY database only.
-- Product image FILES live in the separate product_images Docker volume.

BEGIN;
--
-- PostgreSQL database dump
--

\restrict GD98DboIinVDZFRtjwNNnETTTZQY35JG8vvfzAAPiWathxWRR5bm9MYlB6zPn3l

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
-- Name: checkout_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkout_request (
    customer_id bigint NOT NULL,
    request_key uuid NOT NULL,
    fingerprint text NOT NULL,
    order_id bigint NOT NULL
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
-- Name: demo_bank_intent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demo_bank_intent (
    id uuid NOT NULL,
    payment_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:30:00'::interval) NOT NULL
);


--
-- Name: demo_bank_transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demo_bank_transaction (
    id uuid NOT NULL,
    customer_id bigint NOT NULL,
    payment_id bigint NOT NULL,
    amount numeric(18,2) NOT NULL,
    balance_after numeric(18,2) NOT NULL,
    provider character varying(30) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT demo_bank_transaction_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT demo_bank_transaction_balance_after_check CHECK ((balance_after >= (0)::numeric)),
    CONSTRAINT demo_bank_transaction_provider_check CHECK (((provider)::text = 'INTERNAL_MOCK'::text))
);


--
-- Name: demo_bank_wallet; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demo_bank_wallet (
    customer_id bigint NOT NULL,
    balance numeric(18,2) DEFAULT 5000000 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT demo_bank_wallet_balance_check CHECK ((balance >= (0)::numeric))
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
-- Name: momo_ipn_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_ipn_history (
    id bigint NOT NULL,
    attempt_id bigint NOT NULL,
    payload jsonb NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: momo_ipn_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.momo_ipn_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.momo_ipn_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: momo_payment_attempt; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_payment_attempt (
    id bigint NOT NULL,
    payment_id bigint NOT NULL,
    momo_order_id character varying(100) NOT NULL,
    request_id character varying(100) NOT NULL,
    environment character varying(10) DEFAULT 'SANDBOX'::character varying NOT NULL,
    amount bigint NOT NULL,
    status character varying(20) DEFAULT 'CREATED'::character varying NOT NULL,
    order_info text NOT NULL,
    redirect_url text NOT NULL,
    ipn_url text NOT NULL,
    pay_url text,
    qr_code_data text,
    trans_id character varying(100),
    result_code integer,
    message text,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT momo_payment_attempt_amount_check CHECK ((amount > 0)),
    CONSTRAINT momo_payment_attempt_environment_check CHECK (((environment)::text = 'SANDBOX'::text)),
    CONSTRAINT momo_payment_attempt_status_check CHECK (((status)::text = ANY ((ARRAY['CREATED'::character varying, 'PENDING'::character varying, 'FAILED'::character varying, 'SUCCESS'::character varying])::text[])))
);


--
-- Name: momo_payment_attempt_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.momo_payment_attempt ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.momo_payment_attempt_id_seq
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
-- Name: payment_notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_notification (
    id bigint NOT NULL,
    payment_id bigint NOT NULL,
    order_id bigint NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.payment_notification ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.payment_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
-- Name: sepay_webhook_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sepay_webhook_event (
    transaction_id bigint NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    gateway character varying(150) NOT NULL,
    account_number character varying(100) NOT NULL,
    reference_code character varying(200),
    transfer_content text NOT NULL,
    amount numeric(18,2) NOT NULL,
    order_id bigint,
    payment_id bigint,
    status character varying(20) DEFAULT 'RECEIVED'::character varying NOT NULL,
    reason character varying(200),
    sepay_mode character varying(4) DEFAULT 'live'::character varying NOT NULL,
    CONSTRAINT sepay_webhook_event_sepay_mode_check CHECK (((sepay_mode)::text = ANY ((ARRAY['test'::character varying, 'live'::character varying])::text[]))),
    CONSTRAINT sepay_webhook_event_status_check CHECK (((status)::text = ANY ((ARRAY['RECEIVED'::character varying, 'APPLIED'::character varying, 'REVIEW'::character varying, 'IGNORED'::character varying])::text[]))),
    CONSTRAINT sepay_webhook_event_transaction_id_check CHECK ((transaction_id > 0))
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
    transfer_reference character varying(40),
    sepay_mode character varying(4) DEFAULT 'live'::character varying NOT NULL,
    demo_banking boolean DEFAULT false NOT NULL,
    CONSTRAINT thanh_toan_phuong_thuc_check CHECK (((phuong_thuc)::text = ANY ((ARRAY['COD'::character varying, 'CASH'::character varying, 'BANK_TRANSFER'::character varying, 'QR'::character varying, 'MOMO'::character varying, 'VNPAY'::character varying, 'ZALOPAY'::character varying, 'CARD'::character varying])::text[]))),
    CONSTRAINT thanh_toan_sepay_mode_check CHECK (((sepay_mode)::text = ANY ((ARRAY['test'::character varying, 'live'::character varying])::text[]))),
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
	('20261108_customer_password_reset', '2026-11-08 13:33:30.520089+07'),
	('20261109_sepay_payments', '2026-11-09 18:40:44.982536+07'),
	('20261109_sepay_test_mode', '2026-11-09 19:50:49.306872+07'),
	('20261110_demo_bank', '2026-11-10 12:06:15.100762+07'),
	('20261110_momo_sandbox', '2026-11-10 13:10:05.999951+07');


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
	(65, 22, 'NHAP_HANG', 49, 144, 0, 144, '2026-11-08 15:23:49.336349+07'),
	(66, 11, 'NHAP_HANG', 50, 192, 0, 192, '2026-11-09 16:53:42.25684+07'),
	(67, 20, 'NHAP_HANG', 61, 240, 60, 300, '2026-11-09 18:04:32.632932+07'),
	(68, 19, 'NHAP_HANG', 60, 240, 0, 240, '2026-11-09 18:04:34.753905+07'),
	(69, 18, 'NHAP_HANG', 59, 240, 0, 240, '2026-11-09 18:04:36.770154+07'),
	(70, 12, 'NHAP_HANG', 58, 240, 0, 240, '2026-11-09 18:04:39.126907+07'),
	(71, 10, 'NHAP_HANG', 57, 240, 0, 240, '2026-11-09 18:04:42.115521+07'),
	(72, 9, 'NHAP_HANG', 56, 216, 0, 216, '2026-11-09 18:04:43.761739+07'),
	(73, 8, 'NHAP_HANG', 55, 240, 0, 240, '2026-11-09 18:04:45.823446+07'),
	(74, 6, 'NHAP_HANG', 53, 240, 0, 240, '2026-11-09 18:04:48.837272+07'),
	(75, 5, 'NHAP_HANG', 52, 240, 0, 240, '2026-11-09 18:04:51.163336+07'),
	(76, 4, 'NHAP_HANG', 51, 240, 0, 240, '2026-11-09 18:04:52.96706+07'),
	(77, 7, 'NHAP_HANG', 54, 240, 0, 240, '2026-11-09 18:05:49.779241+07'),
	(78, 15, 'NHAP_HANG', 64, 240, 0, 240, '2026-11-09 18:07:50.765448+07'),
	(79, 14, 'NHAP_HANG', 63, 240, 0, 240, '2026-11-09 18:07:52.821505+07'),
	(80, 13, 'NHAP_HANG', 62, 240, 0, 240, '2026-11-09 18:07:54.779723+07'),
	(81, 27, 'NHAP_HANG', 67, 240, 0, 240, '2026-11-09 18:10:18.340231+07'),
	(82, 26, 'NHAP_HANG', 66, 240, 120, 360, '2026-11-09 18:10:20.212427+07'),
	(83, 25, 'NHAP_HANG', 65, 240, 0, 240, '2026-11-09 18:10:22.262214+07'),
	(84, 23, 'NHAP_HANG', 71, 240, 0, 240, '2026-11-09 18:13:50.893926+07'),
	(85, 22, 'NHAP_HANG', 70, 240, 144, 384, '2026-11-09 18:13:52.693478+07'),
	(86, 17, 'NHAP_HANG', 69, 240, 240, 480, '2026-11-09 18:13:55.19694+07'),
	(87, 16, 'NHAP_HANG', 68, 240, 0, 240, '2026-11-09 18:13:57.400307+07'),
	(88, 20, 'BAN_ONLINE', 38, -10, 300, 290, '2026-11-09 19:19:35.210355+07'),
	(89, 27, 'BAN_ONLINE', 40, -10, 240, 230, '2026-11-09 20:27:35.446926+07'),
	(90, 20, 'BAN_ONLINE', 41, -10, 290, 280, '2026-11-10 12:00:52.017342+07'),
	(91, 20, 'HUY_DON', 41, 10, 280, 290, '2026-11-10 12:01:16.156814+07'),
	(92, 26, 'BAN_ONLINE', 44, -5, 360, 355, '2026-11-10 12:19:38.434618+07');


--
-- Data for Name: checkout_request; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: chi_tiet_don_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_don_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 9, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 1, 8000.00, 0.00, DEFAULT),
	(2, 2, 6, 'Red Bull 250ml', 'Lon lẻ', 10, 1, 13000.00, 10000.00, DEFAULT),
	(3, 3, 26, 'Pocari Sweat 350ml', 'Chai lẻ', 8, 1, 14000.00, 10000.00, DEFAULT),
	(36, 36, 20, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 5, 1, 31000.00, 24444.44, DEFAULT),
	(37, 37, 20, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 3, 1, 31000.00, 24444.44, DEFAULT),
	(38, 38, 6, 'Red Bull 250ml', 'Lon lẻ', 10, 1, 19000.00, 15000.00, DEFAULT),
	(39, 39, 25, 'Revive 500ml', 'Chai lẻ', 10, 1, 13500.00, 10416.67, DEFAULT),
	(40, 40, 9, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 1, 12500.00, 10000.00, DEFAULT),
	(41, 41, 6, 'Red Bull 250ml', 'Lon lẻ', 10, 1, 19000.00, 15000.00, DEFAULT),
	(42, 42, 9, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 1, 1, 12500.00, 10000.00, DEFAULT),
	(43, 43, 29, 'Pepsi  320ml', 'Lon lẻ', 10, 1, 11500.00, 9166.67, DEFAULT),
	(44, 44, 8, 'TH true MILK sữa có đường 180ml', 'Hộp lẻ', 5, 1, 13500.00, 10555.56, DEFAULT),
	(45, 45, 25, 'Revive 500ml', 'Chai lẻ', 10, 1, 13500.00, 10416.67, DEFAULT),
	(46, 46, 15, 'Aquafina 500ml', 'Chai lẻ', 5, 1, 6500.00, 5000.00, DEFAULT),
	(47, 47, 9, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 6, 1, 12500.00, 10000.00, DEFAULT);


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
	(47, 47, 71, 6, 24, 250000.00),
	(48, 48, 72, 10, 24, 230000.00),
	(49, 49, 73, 10, 24, 250000.00),
	(50, 50, 74, 10, 24, 230000.00),
	(51, 51, 75, 10, 24, 240000.00),
	(52, 52, 76, 10, 24, 220000.00),
	(53, 53, 77, 10, 24, 220000.00),
	(54, 54, 78, 9, 24, 220000.00),
	(55, 55, 79, 10, 24, 220000.00),
	(56, 56, 80, 10, 24, 220000.00),
	(57, 57, 81, 10, 24, 220000.00),
	(58, 58, 82, 10, 24, 220000.00),
	(59, 59, 83, 10, 24, 220000.00),
	(60, 60, 84, 10, 24, 120000.00),
	(61, 61, 85, 10, 24, 120000.00),
	(62, 62, 86, 10, 24, 120000.00),
	(63, 63, 87, 10, 24, 240000.00),
	(64, 64, 37, 10, 24, 240000.00),
	(65, 65, 88, 10, 24, 240000.00),
	(66, 66, 34, 10, 24, 250000.00),
	(67, 67, 71, 10, 24, 250000.00),
	(68, 68, 31, 10, 24, 250000.00),
	(69, 69, 89, 10, 24, 250000.00);


--
-- Data for Name: chi_tiet_gio_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_gio_hang OVERRIDING SYSTEM VALUE VALUES
	(131, 141, 21, 10, 11500.00);


--
-- Data for Name: chi_tiet_hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.chi_tiet_hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 8000.00, DEFAULT),
	(2, 2, 2, 'Red Bull 250ml', 'Lon lẻ', 10, 13000.00, DEFAULT),
	(3, 3, 3, 'Pocari Sweat 350ml', 'Chai lẻ', 8, 14000.00, DEFAULT),
	(36, 36, 36, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 5, 31000.00, DEFAULT),
	(37, 37, 37, 'Vfresh nước cam 1 lít', 'Hộp lẻ', 3, 31000.00, DEFAULT),
	(38, 38, 38, 'Red Bull 250ml', 'Lon lẻ', 10, 19000.00, DEFAULT),
	(39, 39, 40, 'Vinamilk sữa có đường 180ml', 'Hộp lẻ', 10, 12500.00, DEFAULT),
	(40, 40, 41, 'Red Bull 250ml', 'Lon lẻ', 10, 19000.00, DEFAULT),
	(41, 41, 44, 'TH true MILK sữa có đường 180ml', 'Hộp lẻ', 5, 13500.00, DEFAULT);


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
	(49, 49, 47, 47, 6, 0, 0, 250000.00, '', '2026-03-01', '2027-03-01'),
	(50, 50, 48, 48, 8, 2, 0, 230000.00, 'Bị rò rỉ', '2026-11-01', '2027-11-01'),
	(51, 51, 59, 59, 10, 0, 0, 220000.00, '', '2026-10-01', '2027-10-01'),
	(52, 52, 58, 58, 10, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(53, 53, 57, 57, 10, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(54, 54, 56, 56, 10, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(55, 55, 55, 55, 10, 0, 0, 220000.00, '', '2026-09-10', '2027-09-10'),
	(56, 56, 54, 54, 9, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(57, 57, 53, 53, 10, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(58, 58, 52, 52, 10, 0, 0, 220000.00, '', '2026-10-10', '2027-10-10'),
	(59, 59, 51, 51, 10, 0, 0, 240000.00, '', '2026-09-10', '2027-09-10'),
	(60, 60, 50, 50, 10, 0, 0, 230000.00, '', '2026-07-10', '2027-07-10'),
	(61, 61, 49, 49, 10, 0, 0, 250000.00, '', '2026-10-31', '2027-10-31'),
	(62, 62, 62, 62, 10, 0, 0, 120000.00, '', '2026-11-01', '2027-11-01'),
	(63, 63, 61, 61, 10, 0, 0, 120000.00, '', '2026-11-01', '2027-11-01'),
	(64, 64, 60, 60, 10, 0, 0, 120000.00, '', '2026-11-01', '2027-01-01'),
	(65, 65, 65, 65, 10, 0, 0, 240000.00, '', '2026-08-01', '2027-08-01'),
	(66, 66, 64, 64, 10, 0, 0, 240000.00, '', '2026-08-01', '2027-08-01'),
	(67, 67, 63, 63, 10, 0, 0, 240000.00, '', '2026-08-01', '2027-08-01'),
	(68, 68, 69, 69, 10, 0, 0, 250000.00, '', '2026-11-01', '2027-11-01'),
	(69, 69, 68, 68, 10, 0, 0, 250000.00, '', '2026-11-01', '2027-01-01'),
	(70, 70, 67, 67, 10, 0, 0, 250000.00, '', '2026-11-01', '2027-11-09'),
	(71, 71, 66, 66, 10, 0, 0, 250000.00, '', '2026-11-01', '2027-11-01');


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
	(49, 49, 1500000.00, 1500000.00, NULL, 'CHUA_TRA'),
	(50, 50, 1840000.00, 1840000.00, NULL, 'CHUA_TRA'),
	(51, 61, 2500000.00, 2500000.00, NULL, 'CHUA_TRA'),
	(52, 60, 2300000.00, 2300000.00, NULL, 'CHUA_TRA'),
	(53, 59, 2400000.00, 2400000.00, NULL, 'CHUA_TRA'),
	(54, 58, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(55, 57, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(56, 56, 1980000.00, 1980000.00, NULL, 'CHUA_TRA'),
	(57, 55, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(58, 53, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(59, 52, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(60, 51, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(61, 54, 2200000.00, 2200000.00, NULL, 'CHUA_TRA'),
	(62, 64, 1200000.00, 1200000.00, NULL, 'CHUA_TRA'),
	(63, 63, 1200000.00, 1200000.00, NULL, 'CHUA_TRA'),
	(64, 62, 1200000.00, 1200000.00, NULL, 'CHUA_TRA'),
	(65, 67, 2400000.00, 2400000.00, NULL, 'CHUA_TRA'),
	(66, 66, 2400000.00, 2400000.00, NULL, 'CHUA_TRA'),
	(67, 65, 2400000.00, 2400000.00, NULL, 'CHUA_TRA'),
	(68, 71, 2500000.00, 2500000.00, NULL, 'CHUA_TRA'),
	(69, 70, 2500000.00, 2500000.00, NULL, 'CHUA_TRA'),
	(70, 69, 2500000.00, 2500000.00, NULL, 'CHUA_TRA'),
	(71, 68, 2500000.00, 2500000.00, NULL, 'CHUA_TRA');


--
-- Data for Name: danh_gia_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: demo_bank_intent; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.demo_bank_intent VALUES
	('25b4e112-cb27-438f-9497-b034f74eb4e2', 42, '2026-11-10 12:09:52.044457+07', '2026-11-10 12:39:52.044457+07'),
	('d98dadc7-4c1b-4199-ad17-f7a30f44ed1b', 43, '2026-11-10 12:16:08.487221+07', '2026-11-10 12:46:08.487221+07'),
	('a5ef59db-4662-45bd-b619-78459222e28f', 44, '2026-11-10 12:18:31.475525+07', '2026-11-10 12:48:31.475525+07'),
	('b9ca5037-01a8-4b1a-a511-59f156b47344', 46, '2026-11-10 12:22:40.890866+07', '2026-11-10 12:52:40.890866+07');


--
-- Data for Name: demo_bank_transaction; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.demo_bank_transaction VALUES
	('5101a529-77f2-4336-8eba-7728c50b60fe', 7, 42, 12500.00, 4987500.00, 'INTERNAL_MOCK', '2026-11-10 12:09:53.216609+07'),
	('e79333e9-8227-4af3-832b-0b3f73c7064b', 6, 43, 92000.00, 4908000.00, 'INTERNAL_MOCK', '2026-11-10 12:17:06.918517+07'),
	('183c555e-c9db-40bb-8a0c-d9a9a9938bac', 6, 44, 54000.00, 4854000.00, 'INTERNAL_MOCK', '2026-11-10 12:19:24.33572+07');


--
-- Data for Name: demo_bank_wallet; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.demo_bank_wallet VALUES
	(7, 4987500.00, '2026-11-10 12:09:53.216609+07'),
	(6, 4854000.00, '2026-11-10 12:19:24.33572+07');


--
-- Data for Name: dia_chi_giao_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.dia_chi_giao_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'SonY', '0123456789', '24/1 Kha Vạn Cân', 'Phường Tam Thắng', NULL, 'Thành phố Hồ Chí Minh', true),
	(2, 6, 'hưng Ngô', '0786566862', '335 Hậu Giang', 'Phường Bình Tây', NULL, 'Thành phố Hồ Chí Minh', true),
	(3, 7, 'Kiểm thử Demo Bank', '0901234567', 'Địa chỉ thử nghiệm đồ án', 'Phường Ba Đình', NULL, 'Thành phố Hà Nội', true);


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
	(49, 'DN-3d5dfbe7-c399-4447-9cbc-dd264faf6127', 4, 2, NULL, '2026-11-09 17:56:41.402645+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(11, 'DN-1e05136b-5177-4f7f-868a-8cf3cf02da83', 2, 2, 2, '2026-11-04 16:18:20.873601+07', '2026-11-05', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 16:18:30.274333+07'),
	(50, 'DN-98d6100a-96f3-4716-86b2-fe817cb53f36', 4, 2, NULL, '2026-11-09 17:57:07.197219+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(12, 'DN-c9dd99b6-b390-4661-91a9-5730eb2e87ba', 2, 2, 2, '2026-11-04 16:48:33.864302+07', '2026-11-05', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 16:48:39.612381+07'),
	(51, 'DN-b87fba63-d60d-447c-a895-fcd11e9fae82', 4, 2, NULL, '2026-11-09 17:57:29.074858+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(13, 'DN-5a2191fe-da73-4010-a1e3-72c938289c04', 1, 2, 2, '2026-11-04 17:20:14.801639+07', '2026-11-04', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 17:20:32.142359+07'),
	(52, 'DN-11394617-6160-4ff2-92bd-4c920fc83cdd', 4, 2, NULL, '2026-11-09 17:57:46.391631+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(53, 'DN-77d151fd-980e-4715-bd63-c602f387a9df', 4, 2, NULL, '2026-11-09 17:58:23.556381+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(15, 'DN-570647c9-3917-4a86-9c7f-fa9ddf15efdf', 1, 2, 2, '2026-11-04 17:29:32.283776+07', '2026-11-14', 'DA_NHAN_DU', NULL, NULL, '2026-11-04 17:29:37.163446+07'),
	(14, 'DN-7cbe1b41-4a0e-4571-8c80-38f09a759151', 2, 2, NULL, '2026-11-04 17:29:08.79452+07', '2026-11-06', 'DA_NHAN_DU', NULL, NULL, NULL),
	(44, 'DN-c1b2dda5-3f0c-4d98-94a2-e2de1df682f5', 2, 2, NULL, '2026-11-07 20:04:56.693895+07', '2026-11-10', 'DA_NHAN_DU', NULL, NULL, NULL),
	(45, 'DN-3e726dc1-482c-4596-831b-db5cea549d85', 1, 2, NULL, '2026-11-07 20:05:33.072203+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(46, 'DN-fcf95eb5-cf81-48ff-88b1-272ce18fdf05', 2, 2, NULL, '2026-11-07 20:21:21.527205+07', '2026-11-08', 'DA_NHAN_DU', NULL, NULL, NULL),
	(47, 'DN-72daed3f-6602-46bd-80a4-b2858d2408f1', 2, 2, NULL, '2026-11-08 15:23:04.721186+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(48, 'DN-a27ee4e5-a66a-47bb-ad45-ae3a961b15a7', 2, 2, NULL, '2026-11-09 16:53:03.350671+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(54, 'DN-fc27dde2-a335-42ea-970b-641d0d4950c1', 4, 2, NULL, '2026-11-09 17:58:45.698157+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(55, 'DN-5d403812-e0be-4099-a1e9-1e3f2168aa83', 4, 2, NULL, '2026-11-09 17:59:08.527737+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(57, 'DN-b7e681c1-c97c-4e8c-969f-b55db60bb1e7', 4, 2, NULL, '2026-11-09 18:00:03.777024+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(58, 'DN-9b688d95-8a65-46c8-9220-c011ea6edd92', 4, 2, NULL, '2026-11-09 18:00:24.772959+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(59, 'DN-3b2238e4-9aea-48b1-ad42-6868d1dd64b4', 4, 2, NULL, '2026-11-09 18:00:47.503526+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(56, 'DN-7f88147a-22de-4bb7-95f2-8754759ee9c5', 4, 2, NULL, '2026-11-09 17:59:44.951252+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(60, 'DN-a184db20-dd17-47ba-8de2-5d245ab93631', 3, 2, NULL, '2026-11-09 18:06:24.691673+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(61, 'DN-a3625cef-a995-4843-8a8f-711b62b85ac4', 3, 2, NULL, '2026-11-09 18:06:50.823032+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(62, 'DN-6d053287-e947-4760-b46b-768086ab1f70', 3, 2, NULL, '2026-11-09 18:07:11.246927+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(63, 'DN-93d3762a-febf-41c6-bcaf-fdb844c5b30d', 2, 2, NULL, '2026-11-09 18:08:45.818902+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(64, 'DN-4af3d3b6-8d9a-490c-9783-415a55822849', 2, 2, NULL, '2026-11-09 18:09:05.133148+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(65, 'DN-f87973cc-5238-46f5-89a8-3dd64271a4e2', 2, 2, NULL, '2026-11-09 18:09:22.071504+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(66, 'DN-5ea2fe75-8cc6-46ad-bf06-ab7102604224', 1, 2, NULL, '2026-11-09 18:11:59.548297+07', '2026-11-10', 'DA_NHAN_DU', NULL, NULL, NULL),
	(67, 'DN-fa46bc5f-1027-48ba-b01d-05f1577869f6', 1, 2, NULL, '2026-11-09 18:12:15.81849+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(68, 'DN-93c86766-8127-4271-a437-9d02216ed45b', 1, 2, NULL, '2026-11-09 18:12:34.923359+07', '2026-11-09', 'DA_NHAN_DU', NULL, NULL, NULL),
	(69, 'DN-73acba49-d067-446b-a6dc-1645e7dda8d1', 1, 2, NULL, '2026-11-09 18:12:51.971713+07', '2026-11-10', 'DA_NHAN_DU', NULL, NULL, NULL);


--
-- Data for Name: don_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.don_hang OVERRIDING SYSTEM VALUE VALUES
	(38, 'DH-896c9bef-0633-44eb-ad0b-e8bd0eff06e9', 'ONLINE', 6, 2, '2026-11-09 19:18:25.537325+07', NULL, 'DA_GIAO', 0.00, 38000.00, 152000.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-09 19:52:19.576164+07', 34),
	(1, 'DH-6c1a7221-fc52-436f-8308-5ac6fbe4a865', 'ONLINE', 1, 2, '2026-11-03 16:37:52.820068+07', NULL, 'DA_GIAO', 0.00, 0.00, 80000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-03 16:38:29.510031+07', NULL),
	(46, 'DH-50d901bf-f69e-4ce8-96e3-156619cc74e9', 'ONLINE', 1, 2, '2026-11-10 12:22:40.617089+07', NULL, 'DA_HUY', 0.00, 6500.00, 26000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-10 12:40:11.858402+07', 34),
	(43, 'DH-35208fcf-4b1a-41d9-9948-352ab2e404d8', 'ONLINE', 6, 2, '2026-11-10 12:16:07.854049+07', NULL, 'DA_HUY', 0.00, 23000.00, 92000.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-10 12:17:44.06558+07', 34),
	(2, 'DH-0813adbd-aaa0-44dd-8317-57abbe8d3b7d', 'ONLINE', 1, 3, '2026-11-04 13:03:18.413361+07', NULL, 'DA_GIAO', 0.00, 0.00, 130000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-04 13:05:10.352992+07', NULL),
	(39, 'DH-dacdbd65-5775-4bf5-a64c-30aa524c96ac', 'ONLINE', 6, 2, '2026-11-09 19:53:14.65845+07', NULL, 'DA_HUY', 0.00, 13500.00, 121500.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-09 20:16:53.707903+07', 1),
	(3, 'DH-ad03213a-3dfb-4d0f-bb40-d3c26a4b34dd', 'ONLINE', 1, 3, '2026-11-04 14:34:38.732069+07', NULL, 'DA_HUY', 0.00, 11200.00, 100800.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-04 14:37:04.762617+07', 1),
	(47, 'DH-3a90eb4f-1294-4937-b82a-ee05fc78e136', 'ONLINE', 1, NULL, '2026-11-10 12:41:10.43514+07', NULL, 'CHO_XAC_NHAN', 0.00, 7500.00, 67500.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-10 12:41:10.43514+07', 1),
	(36, 'DH-a4e572de-dfa9-4d7a-b4e0-ff37106904b5', 'ONLINE', 1, 2, '2026-11-07 20:23:40.626183+07', NULL, 'DA_GIAO', 0.00, 0.00, 155000.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-07 20:24:03.891591+07', NULL),
	(40, 'DH-f2f6334c-7f87-4aa4-be75-6344a5b99b3e', 'ONLINE', 6, 2, '2026-11-09 20:26:44.280559+07', NULL, 'DA_GIAO', 0.00, 12500.00, 112500.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-09 20:27:39.102191+07', 1),
	(44, 'DH-ef3f4a13-4b1f-4aa5-be32-51bd3618e101', 'ONLINE', 6, 2, '2026-11-10 12:18:31.190542+07', NULL, 'DA_GIAO', 0.00, 13500.00, 54000.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-10 12:20:40.270878+07', 34),
	(37, 'DH-952a4d25-3d9c-460c-b667-4745274d50dd', 'ONLINE', 6, 2, '2026-11-08 15:15:30.126268+07', NULL, 'DA_GIAO', 0.00, 18600.00, 74400.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, true, '2026-11-08 15:15:50.298675+07', 34),
	(41, 'DH-95f0deaa-9c9d-400b-a585-7a063b2ebde7', 'ONLINE', 6, 3, '2026-11-10 11:59:34.077991+07', NULL, 'DA_HUY', 0.00, 0.00, 190000.00, '', 'hưng Ngô', '0786566862', 'hưng Ngô | 0786566862 | 335 Hậu Giang, Phường Bình Tây, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-10 12:01:16.156814+07', NULL),
	(42, 'DH-7eb42b17-20d6-481d-a235-c870a9c48545', 'ONLINE', 7, NULL, '2026-11-10 12:09:47.241694+07', NULL, 'CHO_XAC_NHAN', 0.00, 0.00, 12500.00, 'Đơn kiểm thử tự động Demo Bank — không có tiền thật.', 'Kiểm thử Demo Bank', '0901234567', 'Kiểm thử Demo Bank | 0901234567 | Địa chỉ thử nghiệm đồ án, Phường Ba Đình, , Thành phố Hà Nội', NULL, false, '2026-11-10 12:09:47.241694+07', NULL),
	(45, 'DH-b0d5590a-d8b1-4227-88b3-f3205cd3c49c', 'ONLINE', 1, NULL, '2026-11-10 12:21:43.5778+07', NULL, 'DA_HUY', 0.00, 13500.00, 121500.00, '', 'SonY', '0123456789', 'SonY | 0123456789 | 24/1 Kha Vạn Cân, Phường Tam Thắng, , Thành phố Hồ Chí Minh', NULL, false, '2026-11-10 12:22:01.20673+07', 1);


--
-- Data for Name: giay_to_ncc; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: gio_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.gio_hang OVERRIDING SYSTEM VALUE VALUES
	(363, 7, '2026-11-10 12:09:46.99555+07'),
	(1, 1, '2026-11-10 12:40:55.985103+07'),
	(141, 6, '2026-11-10 13:06:08.292362+07');


--
-- Data for Name: hinh_anh_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hinh_anh_san_pham OVERRIDING SYSTEM VALUE VALUES
	(1, 11, '/api/v1/media/products/d58e11cc-83c7-3c8f-8c47-1d13f9369fd6.png', true, 0),
	(2, 27, '/api/v1/media/products/dbb88be4-df1c-38cf-920e-aaa8d99fecd5.png', true, 0),
	(3, 26, '/api/v1/media/products/98e4c4ed-3a47-33a0-9f56-80112e74bbda.png', true, 0),
	(4, 25, '/api/v1/media/products/3120b46e-da11-3462-b837-4694cf74b846.png', true, 0),
	(5, 24, '/api/v1/media/products/1693e24a-faf8-3a29-83c4-12793366bc59.png', true, 0),
	(6, 23, '/api/v1/media/products/b3951d43-aebc-3f4e-b967-8d927c545f26.png', true, 0),
	(7, 22, '/api/v1/media/products/c19519f3-cccb-344e-87e7-1987b3c3f7a5.png', true, 0),
	(8, 21, '/api/v1/media/products/5a64bde0-72a2-34f1-b06c-57994fac7a17.png', true, 0),
	(9, 20, '/api/v1/media/products/ee1925ce-469d-3bb0-9bc6-de3d175335f0.png', true, 0),
	(10, 19, '/api/v1/media/products/c73e4334-62e6-30d2-8508-9ef3d896f3e1.png', true, 0),
	(11, 18, '/api/v1/media/products/4560e5d3-f002-3c81-abc4-77f749df5c84.png', true, 0),
	(12, 17, '/api/v1/media/products/6e851cfc-895a-33e0-86c0-1534c805f17d.png', true, 0),
	(13, 16, '/api/v1/media/products/7ccc2561-3e3f-3eb5-b1df-d69587974e1a.png', true, 0),
	(14, 15, '/api/v1/media/products/3df63988-d6ba-3557-983e-3715568d8048.png', true, 0),
	(15, 14, '/api/v1/media/products/192ab62a-65b8-3f95-b3fd-234a59d63c2c.png', true, 0),
	(16, 13, '/api/v1/media/products/9108e13d-b0a3-37b6-972e-d1c3551c905c.png', true, 0),
	(17, 12, '/api/v1/media/products/6ba46f39-13dc-3d85-8ba7-e5d96b5f56e7.png', true, 0),
	(18, 10, '/api/v1/media/products/d39804f1-48c5-372f-9915-1d52f4db54c4.png', true, 0),
	(19, 9, '/api/v1/media/products/fd6a6717-9ae5-34a3-a0c4-f94f332d884d.png', true, 0),
	(20, 8, '/api/v1/media/products/b7e844ed-1a8c-33d3-a6dd-cd3360cc113c.png', true, 0),
	(21, 7, '/api/v1/media/products/68760d16-abb5-3064-b90c-055867878622.png', true, 0),
	(22, 6, '/api/v1/media/products/28db5f14-1ec4-3d0f-9662-40fa8c31cf2e.png', true, 0),
	(23, 5, '/api/v1/media/products/d977c026-b676-3cc5-bfe5-747f6d23d744.png', true, 0),
	(24, 4, '/api/v1/media/products/68760d16-abb5-3064-b90c-055867878622.png', true, 0);


--
-- Data for Name: hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 2, 'HD-1', '2026-11-03 16:38:23.783332+07', 'ONLINE', 80000.00, 0.00, 0.00, 'ISSUED'),
	(2, 2, 3, 'HD-2', '2026-11-04 13:04:11.849425+07', 'ONLINE', 130000.00, 0.00, 0.00, 'ISSUED'),
	(3, 3, 3, 'HD-3', '2026-11-04 14:35:34.329885+07', 'ONLINE', 100800.00, 0.00, 11200.00, 'CANCELLED'),
	(36, 36, 2, 'HD-36', '2026-11-07 20:23:57.794667+07', 'ONLINE', 155000.00, 0.00, 0.00, 'ISSUED'),
	(37, 37, 2, 'HD-37', '2026-11-08 15:15:46.004724+07', 'ONLINE', 74400.00, 0.00, 18600.00, 'ISSUED'),
	(38, 38, 2, 'HD-38', '2026-11-09 19:19:35.210355+07', 'ONLINE', 152000.00, 0.00, 38000.00, 'ISSUED'),
	(39, 40, 2, 'HD-40', '2026-11-09 20:27:35.446926+07', 'ONLINE', 112500.00, 0.00, 12500.00, 'PAID'),
	(40, 41, 3, 'HD-41', '2026-11-10 12:00:52.017342+07', 'ONLINE', 190000.00, 0.00, 0.00, 'CANCELLED'),
	(41, 44, 2, 'HD-44', '2026-11-10 12:19:38.434618+07', 'ONLINE', 54000.00, 0.00, 13500.00, 'PAID');


--
-- Data for Name: hoan_tien; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: khach_hang; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.khach_hang OVERRIDING SYSTEM VALUE VALUES
	(1, 3, 'SonY', '1234567890', NULL, '2026-11-03 15:25:38.232189+07'),
	(6, 5, 'hưng Ngô', '0786566862', NULL, '2026-11-08 13:36:04.528191+07'),
	(7, 6, 'Kiểm thử Demo Bank', '0901234567', NULL, '2026-11-10 12:09:45.566399+07');


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
	(49, 47, 2, '2026-11-08 15:23:44.149261+07', 'CONFIRMED', '2026-11-08 15:23:49.336349+07', NULL),
	(50, 48, 2, '2026-11-09 16:53:36.440649+07', 'CONFIRMED', '2026-11-09 16:53:42.25684+07', NULL),
	(61, 49, 2, '2026-11-09 18:04:27.371103+07', 'CONFIRMED', '2026-11-09 18:04:32.632932+07', NULL),
	(60, 50, 2, '2026-11-09 18:04:10.236651+07', 'CONFIRMED', '2026-11-09 18:04:34.753905+07', NULL),
	(59, 51, 2, '2026-11-09 18:03:45.211987+07', 'CONFIRMED', '2026-11-09 18:04:36.770154+07', NULL),
	(58, 52, 2, '2026-11-09 18:03:16.684286+07', 'CONFIRMED', '2026-11-09 18:04:39.126907+07', NULL),
	(57, 53, 2, '2026-11-09 18:02:54.064071+07', 'CONFIRMED', '2026-11-09 18:04:42.115521+07', NULL),
	(56, 54, 2, '2026-11-09 18:02:41.348939+07', 'CONFIRMED', '2026-11-09 18:04:43.761739+07', NULL),
	(55, 55, 2, '2026-11-09 18:02:21.356936+07', 'CONFIRMED', '2026-11-09 18:04:45.823446+07', NULL),
	(53, 57, 2, '2026-11-09 18:01:45.95+07', 'CONFIRMED', '2026-11-09 18:04:48.837272+07', NULL),
	(52, 58, 2, '2026-11-09 18:01:33.089331+07', 'CONFIRMED', '2026-11-09 18:04:51.163336+07', NULL),
	(51, 59, 2, '2026-11-09 18:01:10.215303+07', 'CONFIRMED', '2026-11-09 18:04:52.96706+07', NULL),
	(54, 56, 2, '2026-11-09 18:02:02.090924+07', 'CONFIRMED', '2026-11-09 18:05:49.779241+07', NULL),
	(64, 60, 2, '2026-11-09 18:07:47.759973+07', 'CONFIRMED', '2026-11-09 18:07:50.765448+07', NULL),
	(63, 61, 2, '2026-11-09 18:07:36.38978+07', 'CONFIRMED', '2026-11-09 18:07:52.821505+07', NULL),
	(62, 62, 2, '2026-11-09 18:07:22.381282+07', 'CONFIRMED', '2026-11-09 18:07:54.779723+07', NULL),
	(67, 63, 2, '2026-11-09 18:10:14.988563+07', 'CONFIRMED', '2026-11-09 18:10:18.340231+07', NULL),
	(66, 64, 2, '2026-11-09 18:09:58.109937+07', 'CONFIRMED', '2026-11-09 18:10:20.212427+07', NULL),
	(65, 65, 2, '2026-11-09 18:09:43.068587+07', 'CONFIRMED', '2026-11-09 18:10:22.262214+07', NULL),
	(71, 66, 2, '2026-11-09 18:13:47.857204+07', 'CONFIRMED', '2026-11-09 18:13:50.893926+07', NULL),
	(70, 67, 2, '2026-11-09 18:13:33.898883+07', 'CONFIRMED', '2026-11-09 18:13:52.693478+07', NULL),
	(69, 68, 2, '2026-11-09 18:13:18.602635+07', 'CONFIRMED', '2026-11-09 18:13:55.19694+07', NULL),
	(68, 69, 2, '2026-11-09 18:13:04.8505+07', 'CONFIRMED', '2026-11-09 18:13:57.400307+07', NULL);


--
-- Data for Name: lich_su_hoa_don; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.lich_su_hoa_don OVERRIDING SYSTEM VALUE VALUES
	(1, 3, NULL, 'ISSUED', 'CANCELLED', 'Cap nhat trang thai theo nghiep vu don hang', '2026-11-04 14:37:04.762617+07'),
	(34, 39, NULL, 'ISSUED', 'PAID', 'Cap nhat trang thai theo nghiep vu don hang', '2026-11-09 20:27:35.446926+07'),
	(35, 40, NULL, 'ISSUED', 'CANCELLED', 'Cap nhat trang thai theo nghiep vu don hang', '2026-11-10 12:01:16.156814+07'),
	(36, 41, NULL, 'ISSUED', 'PAID', 'Cap nhat trang thai theo nghiep vu don hang', '2026-11-10 12:19:38.434618+07');


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
	(45, 37, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-08 15:15:50.298675+07'),
	(46, 38, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-09 19:19:35.210355+07'),
	(47, 38, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-09 19:30:43.968026+07'),
	(48, 38, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-09 19:52:19.576164+07'),
	(49, 39, 2, 'CHO_XAC_NHAN', 'DA_HUY', 'hết hàng
', '2026-11-09 20:16:53.707903+07'),
	(50, 40, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-09 20:27:35.446926+07'),
	(51, 40, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-09 20:27:37.25597+07'),
	(52, 40, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-09 20:27:39.102191+07'),
	(53, 41, 4, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-10 12:00:52.017342+07'),
	(54, 41, 4, 'DANG_CHUAN_BI', 'DA_HUY', 'Hết hàng
', '2026-11-10 12:01:16.156814+07'),
	(55, 43, 2, 'CHO_XAC_NHAN', 'DA_HUY', 'đéo mua
', '2026-11-10 12:17:44.06558+07'),
	(56, 44, 2, 'CHO_XAC_NHAN', 'DANG_CHUAN_BI', '', '2026-11-10 12:19:38.434618+07'),
	(57, 44, 2, 'DANG_CHUAN_BI', 'DANG_GIAO', '', '2026-11-10 12:20:38.053109+07'),
	(58, 44, 2, 'DANG_GIAO', 'DA_GIAO', '', '2026-11-10 12:20:40.270878+07'),
	(59, 45, 3, 'CHO_XAC_NHAN', 'DA_HUY', 'không mua nữa
', '2026-11-10 12:22:01.20673+07'),
	(60, 46, 2, 'CHO_XAC_NHAN', 'DA_HUY', 'dcdsvdsv', '2026-11-10 12:40:11.858402+07');


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
-- Data for Name: momo_ipn_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: momo_payment_attempt; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: nha_cung_cap; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nha_cung_cap OVERRIDING SYSTEM VALUE VALUES
	(3, 'Nước suối', NULL, 'DK Khang', '0904568777', 'DK@gmail.com', '123 Trần Bình Trọng, Phường An Đông, Thành phố Hồ Chí Minh', 'HOP_TAC', '2026-11-09 17:50:57.331424+07', 'DOANH_NGHIEP', 'CHUA_XAC_MINH', NULL, NULL, NULL),
	(2, 'Coca-cola', '1234567777', 'Skywind', '0910209811', 'Coca@gmail.com', '336/3/6 Nguyễn Thượng Hiền, Phường Gò Vấp, Thành phố Hồ Chí Minh', 'HOP_TAC', '2026-11-04 13:10:07.968792+07', 'DOANH_NGHIEP', 'CAN_KIEM_TRA_LAI', NULL, NULL, NULL),
	(1, 'Boobiboo', '1234567890', 'Mister_Dat', '1234567890', 'Mr.Dat@gmail.com', '24/1 Kha Vạn Cân, Phường Bình Trị Đông, Thành phố Hồ Chí Minh', 'HOP_TAC', '2026-11-04 10:57:21.919355+07', 'DOANH_NGHIEP', 'CAN_KIEM_TRA_LAI', NULL, NULL, NULL),
	(4, 'Nước Tăng lực', '1234568999', 'SonY', '0925857597', 'SonY@gmail.com', '24/1 Kha Vạn Cân, Phường Tam Thắng, Thành phố Hồ Chí Minh', 'HOP_TAC', '2026-11-09 17:55:21.742987+07', 'DOANH_NGHIEP', 'CHUA_XAC_MINH', NULL, NULL, NULL);


--
-- Data for Name: nha_cung_cap_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nha_cung_cap_san_pham VALUES
	(1, 23, NULL),
	(1, 17, NULL),
	(2, 26, NULL),
	(3, 15, NULL),
	(3, 14, NULL),
	(3, 13, NULL),
	(2, 27, NULL),
	(2, 25, NULL),
	(1, 22, NULL),
	(4, 20, NULL),
	(4, 19, NULL),
	(4, 18, NULL),
	(4, 12, NULL),
	(4, 10, NULL),
	(4, 9, NULL),
	(4, 8, NULL),
	(4, 7, NULL),
	(4, 6, NULL),
	(4, 5, NULL),
	(4, 4, NULL),
	(1, 24, NULL),
	(1, 16, NULL),
	(4, 21, NULL);


--
-- Data for Name: nhan_vien; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.nhan_vien OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'NV-1', 'Quản trị viên', NULL, NULL, NULL, NULL, NULL, 'ADMIN', '2026-11-03', 'ACTIVE'),
	(4, 3, 'NV-3', 'SonY', NULL, NULL, '0123456789', NULL, NULL, NULL, NULL, 'ACTIVE'),
	(2, 2, 'NV-2', 'Ocean', NULL, NULL, '0786566862', NULL, '31 Chu Văn An, Phường Bình Tiên, Thành phố Hồ Chí Minh', NULL, NULL, 'ACTIVE'),
	(3, 4, 'NV-4', 'Skywind', NULL, NULL, '0792040241', NULL, '', NULL, NULL, 'ACTIVE');


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
	(242, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-08 15:28:24.988022+07'),
	(243, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-09 16:40:23.816013+07'),
	(244, 2, 'UPDATE', 'san_pham', 11, NULL, '2026-11-09 16:51:07.25459+07'),
	(245, 2, 'UPDATE', 'nha_cung_cap', 2, NULL, '2026-11-09 16:52:33.870486+07'),
	(246, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 2, NULL, '2026-11-09 16:52:33.870486+07'),
	(247, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 72, NULL, '2026-11-09 16:53:03.350671+07'),
	(248, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 48, NULL, '2026-11-09 16:53:03.350671+07'),
	(249, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 50, NULL, '2026-11-09 16:53:36.440649+07'),
	(250, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 50, NULL, '2026-11-09 16:53:42.25684+07'),
	(251, 2, 'UPDATE', 'san_pham', 9, NULL, '2026-11-09 17:36:55.000526+07'),
	(252, 2, 'UPDATE', 'san_pham', 22, NULL, '2026-11-09 17:37:08.691505+07'),
	(253, 2, 'UPDATE', 'san_pham', 2, NULL, '2026-11-09 17:39:11.465104+07'),
	(254, 2, 'UPDATE', 'san_pham', 1, NULL, '2026-11-09 17:39:22.984679+07'),
	(255, 2, 'UPDATE', 'san_pham', 3, NULL, '2026-11-09 17:39:36.38574+07'),
	(256, 2, 'UPDATE', 'san_pham', 27, NULL, '2026-11-09 17:40:22.994536+07'),
	(257, 2, 'UPDATE', 'san_pham', 27, NULL, '2026-11-09 17:41:52.091922+07'),
	(258, 2, 'UPDATE', 'san_pham', 26, NULL, '2026-11-09 17:42:06.742869+07'),
	(259, 2, 'UPDATE', 'san_pham', 25, NULL, '2026-11-09 17:42:18.304883+07'),
	(260, 2, 'UPDATE', 'san_pham', 24, NULL, '2026-11-09 17:42:35.782074+07'),
	(261, 2, 'UPDATE', 'san_pham', 23, NULL, '2026-11-09 17:42:50.447757+07'),
	(262, 2, 'UPDATE', 'san_pham', 22, NULL, '2026-11-09 17:43:04.124826+07'),
	(263, 2, 'UPDATE', 'san_pham', 21, NULL, '2026-11-09 17:43:20.97769+07'),
	(264, 2, 'UPDATE', 'san_pham', 20, NULL, '2026-11-09 17:43:39.57856+07'),
	(265, 2, 'UPDATE', 'san_pham', 19, NULL, '2026-11-09 17:43:50.920404+07'),
	(266, 2, 'UPDATE', 'san_pham', 18, NULL, '2026-11-09 17:44:08.460482+07'),
	(267, 2, 'UPDATE', 'san_pham', 17, NULL, '2026-11-09 17:44:24.106945+07'),
	(268, 2, 'UPDATE', 'san_pham', 16, NULL, '2026-11-09 17:44:38.592944+07'),
	(269, 2, 'UPDATE', 'san_pham', 15, NULL, '2026-11-09 17:44:49.002979+07'),
	(270, 2, 'UPDATE', 'san_pham', 14, NULL, '2026-11-09 17:45:15.238292+07'),
	(271, 2, 'UPDATE', 'san_pham', 13, NULL, '2026-11-09 17:45:46.490785+07'),
	(272, 2, 'UPDATE', 'san_pham', 12, NULL, '2026-11-09 17:45:57.790142+07'),
	(273, 2, 'UPDATE', 'san_pham', 10, NULL, '2026-11-09 17:46:12.688399+07'),
	(274, 2, 'UPDATE', 'san_pham', 9, NULL, '2026-11-09 17:46:25.049531+07'),
	(275, 2, 'UPDATE', 'san_pham', 8, NULL, '2026-11-09 17:46:40.964866+07'),
	(276, 2, 'UPDATE', 'san_pham', 7, NULL, '2026-11-09 17:46:51.22119+07'),
	(277, 2, 'UPDATE', 'san_pham', 6, NULL, '2026-11-09 17:47:07.745897+07'),
	(278, 2, 'UPDATE', 'san_pham', 5, NULL, '2026-11-09 17:47:16.286921+07'),
	(279, 2, 'UPDATE', 'san_pham', 5, NULL, '2026-11-09 17:47:26.291779+07'),
	(280, 2, 'UPDATE', 'san_pham', 4, NULL, '2026-11-09 17:47:35.025836+07'),
	(281, 2, 'CREATE', 'nha_cung_cap', 3, NULL, '2026-11-09 17:50:57.331424+07'),
	(282, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 3, NULL, '2026-11-09 17:50:57.331424+07'),
	(283, 2, 'UPDATE', 'nha_cung_cap', 2, NULL, '2026-11-09 17:51:49.807379+07'),
	(284, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 2, NULL, '2026-11-09 17:51:49.807379+07'),
	(285, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-09 17:52:43.569822+07'),
	(286, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-09 17:52:43.569822+07'),
	(287, 2, 'CREATE', 'nha_cung_cap', 4, NULL, '2026-11-09 17:55:21.742987+07'),
	(288, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 4, NULL, '2026-11-09 17:55:21.742987+07'),
	(289, 2, 'UPDATE', 'nha_cung_cap', 1, NULL, '2026-11-09 17:55:51.312178+07'),
	(290, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 1, NULL, '2026-11-09 17:55:51.312178+07'),
	(291, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 73, NULL, '2026-11-09 17:56:41.402645+07'),
	(292, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 49, NULL, '2026-11-09 17:56:41.402645+07'),
	(293, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 74, NULL, '2026-11-09 17:57:07.197219+07'),
	(294, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 50, NULL, '2026-11-09 17:57:07.197219+07'),
	(295, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 75, NULL, '2026-11-09 17:57:29.074858+07'),
	(296, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 51, NULL, '2026-11-09 17:57:29.074858+07'),
	(297, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 76, NULL, '2026-11-09 17:57:46.391631+07'),
	(298, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 52, NULL, '2026-11-09 17:57:46.391631+07'),
	(299, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 77, NULL, '2026-11-09 17:58:23.556381+07'),
	(300, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 53, NULL, '2026-11-09 17:58:23.556381+07'),
	(301, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 78, NULL, '2026-11-09 17:58:45.698157+07'),
	(302, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 54, NULL, '2026-11-09 17:58:45.698157+07'),
	(303, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 79, NULL, '2026-11-09 17:59:08.527737+07'),
	(304, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 55, NULL, '2026-11-09 17:59:08.527737+07'),
	(305, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 80, NULL, '2026-11-09 17:59:44.951252+07'),
	(306, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 56, NULL, '2026-11-09 17:59:44.951252+07'),
	(307, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 81, NULL, '2026-11-09 18:00:03.777024+07'),
	(308, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 57, NULL, '2026-11-09 18:00:03.777024+07'),
	(309, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 82, NULL, '2026-11-09 18:00:24.772959+07'),
	(310, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 58, NULL, '2026-11-09 18:00:24.772959+07'),
	(311, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 83, NULL, '2026-11-09 18:00:47.503526+07'),
	(312, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 59, NULL, '2026-11-09 18:00:47.503526+07'),
	(313, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 51, NULL, '2026-11-09 18:01:10.215303+07'),
	(314, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 52, NULL, '2026-11-09 18:01:33.089331+07'),
	(315, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 53, NULL, '2026-11-09 18:01:45.95+07'),
	(316, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 54, NULL, '2026-11-09 18:02:02.090924+07'),
	(317, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 55, NULL, '2026-11-09 18:02:21.356936+07'),
	(318, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 56, NULL, '2026-11-09 18:02:41.348939+07'),
	(322, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 60, NULL, '2026-11-09 18:04:10.236651+07'),
	(323, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 61, NULL, '2026-11-09 18:04:27.371103+07'),
	(325, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 60, NULL, '2026-11-09 18:04:34.753905+07'),
	(326, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 59, NULL, '2026-11-09 18:04:36.770154+07'),
	(328, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 57, NULL, '2026-11-09 18:04:42.115521+07'),
	(329, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 56, NULL, '2026-11-09 18:04:43.761739+07'),
	(330, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 55, NULL, '2026-11-09 18:04:45.823446+07'),
	(334, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 54, NULL, '2026-11-09 18:05:49.779241+07'),
	(335, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 84, NULL, '2026-11-09 18:06:24.691673+07'),
	(336, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 60, NULL, '2026-11-09 18:06:24.691673+07'),
	(337, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 85, NULL, '2026-11-09 18:06:50.823032+07'),
	(338, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 61, NULL, '2026-11-09 18:06:50.823032+07');
INSERT INTO public.nhat_ky_hoat_dong OVERRIDING SYSTEM VALUE VALUES
	(339, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 86, NULL, '2026-11-09 18:07:11.246927+07'),
	(340, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 62, NULL, '2026-11-09 18:07:11.246927+07'),
	(341, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 62, NULL, '2026-11-09 18:07:22.381282+07'),
	(342, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 63, NULL, '2026-11-09 18:07:36.38978+07'),
	(344, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 64, NULL, '2026-11-09 18:07:50.765448+07'),
	(347, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 87, NULL, '2026-11-09 18:08:45.818902+07'),
	(348, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 63, NULL, '2026-11-09 18:08:45.818902+07'),
	(353, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 66, NULL, '2026-11-09 18:09:58.109937+07'),
	(354, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 67, NULL, '2026-11-09 18:10:14.988563+07'),
	(355, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 67, NULL, '2026-11-09 18:10:18.340231+07'),
	(357, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 65, NULL, '2026-11-09 18:10:22.262214+07'),
	(358, 2, 'UPDATE', 'nha_cung_cap', 4, NULL, '2026-11-09 18:11:13.347086+07'),
	(359, 2, 'UPDATE_SUPPLIER_PRODUCTS', 'nha_cung_cap', 4, NULL, '2026-11-09 18:11:13.347086+07'),
	(319, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 57, NULL, '2026-11-09 18:02:54.064071+07'),
	(320, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 58, NULL, '2026-11-09 18:03:16.684286+07'),
	(321, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 59, NULL, '2026-11-09 18:03:45.211987+07'),
	(324, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 61, NULL, '2026-11-09 18:04:32.632932+07'),
	(343, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 64, NULL, '2026-11-09 18:07:47.759973+07'),
	(346, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 62, NULL, '2026-11-09 18:07:54.779723+07'),
	(349, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 64, NULL, '2026-11-09 18:09:05.133148+07'),
	(350, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 88, NULL, '2026-11-09 18:09:22.071504+07'),
	(351, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 65, NULL, '2026-11-09 18:09:22.071504+07'),
	(352, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 65, NULL, '2026-11-09 18:09:43.068587+07'),
	(356, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 66, NULL, '2026-11-09 18:10:20.212427+07'),
	(327, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 58, NULL, '2026-11-09 18:04:39.126907+07'),
	(331, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 53, NULL, '2026-11-09 18:04:48.837272+07'),
	(332, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 52, NULL, '2026-11-09 18:04:51.163336+07'),
	(333, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 51, NULL, '2026-11-09 18:04:52.96706+07'),
	(345, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 63, NULL, '2026-11-09 18:07:52.821505+07'),
	(360, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 66, NULL, '2026-11-09 18:11:59.548297+07'),
	(361, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 67, NULL, '2026-11-09 18:12:15.81849+07'),
	(362, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 68, NULL, '2026-11-09 18:12:34.923359+07'),
	(363, 2, 'IMPORT_PACKAGE_CREATE', 'quy_cach_san_pham', 89, NULL, '2026-11-09 18:12:51.971713+07'),
	(364, 2, 'PURCHASE_CREATE', 'don_dat_hang_ncc', 69, NULL, '2026-11-09 18:12:51.971713+07'),
	(365, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 68, NULL, '2026-11-09 18:13:04.8505+07'),
	(366, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 69, NULL, '2026-11-09 18:13:18.602635+07'),
	(367, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 70, NULL, '2026-11-09 18:13:33.898883+07'),
	(368, 2, 'RECEIPT_DRAFT', 'lan_nhap_hang', 71, NULL, '2026-11-09 18:13:47.857204+07'),
	(369, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 71, NULL, '2026-11-09 18:13:50.893926+07'),
	(370, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 70, NULL, '2026-11-09 18:13:52.693478+07'),
	(371, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 69, NULL, '2026-11-09 18:13:55.19694+07'),
	(372, 2, 'RECEIPT_CONFIRM', 'lan_nhap_hang', 68, NULL, '2026-11-09 18:13:57.400307+07'),
	(373, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-09 18:14:34.876428+07'),
	(374, 5, 'CHECKOUT', 'don_hang', 38, NULL, '2026-11-09 19:18:25.537325+07'),
	(375, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 38, NULL, '2026-11-09 19:19:35.210355+07'),
	(376, 2, 'ORDER_DANG_GIAO', 'don_hang', 38, NULL, '2026-11-09 19:30:43.968026+07'),
	(377, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-09 19:52:04.718092+07'),
	(378, 2, 'ORDER_DA_GIAO', 'don_hang', 38, NULL, '2026-11-09 19:52:19.576164+07'),
	(379, 5, 'CHECKOUT', 'don_hang', 39, NULL, '2026-11-09 19:53:14.65845+07'),
	(380, 2, 'ORDER_DA_HUY', 'don_hang', 39, NULL, '2026-11-09 20:16:53.707903+07'),
	(381, 5, 'CHECKOUT', 'don_hang', 40, NULL, '2026-11-09 20:26:44.280559+07'),
	(382, 5, 'LOCAL_DEMO_TEST_PAYMENT_RECEIVED', 'thanh_toan', 40, NULL, '2026-11-09 20:26:48.645068+07'),
	(383, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 40, NULL, '2026-11-09 20:27:35.446926+07'),
	(384, 2, 'ORDER_DANG_GIAO', 'don_hang', 40, NULL, '2026-11-09 20:27:37.25597+07'),
	(385, 2, 'ORDER_DA_GIAO', 'don_hang', 40, NULL, '2026-11-09 20:27:39.102191+07'),
	(386, 4, 'LOGIN', 'tai_khoan', 4, NULL, '2026-11-10 11:31:47.940027+07'),
	(387, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-10 11:32:09.528041+07'),
	(388, 4, 'STAFF_PROFILE', 'nhan_vien', 3, NULL, '2026-11-10 11:55:03.21329+07'),
	(389, 5, 'CHECKOUT', 'don_hang', 41, NULL, '2026-11-10 11:59:34.077991+07'),
	(390, 4, 'ORDER_DANG_CHUAN_BI', 'don_hang', 41, NULL, '2026-11-10 12:00:52.017342+07'),
	(391, 4, 'ORDER_DA_HUY', 'don_hang', 41, NULL, '2026-11-10 12:01:16.156814+07'),
	(392, 6, 'REGISTER', 'tai_khoan', 6, NULL, '2026-11-10 12:09:45.566399+07'),
	(393, 6, 'LOGIN', 'tai_khoan', 6, NULL, '2026-11-10 12:09:46.476284+07'),
	(394, 6, 'CHECKOUT', 'don_hang', 42, NULL, '2026-11-10 12:09:47.241694+07'),
	(395, 6, 'DEMO_BANK_TRANSFER_RECEIVED', 'thanh_toan', 42, NULL, '2026-11-10 12:09:53.216609+07'),
	(396, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-10 12:11:54.224981+07'),
	(397, 5, 'CHECKOUT', 'don_hang', 43, NULL, '2026-11-10 12:16:07.854049+07'),
	(398, 5, 'DEMO_BANK_TRANSFER_RECEIVED', 'thanh_toan', 43, NULL, '2026-11-10 12:17:06.918517+07'),
	(399, 2, 'ORDER_DA_HUY', 'don_hang', 43, NULL, '2026-11-10 12:17:44.06558+07'),
	(400, 5, 'CHECKOUT', 'don_hang', 44, NULL, '2026-11-10 12:18:31.190542+07'),
	(401, 5, 'DEMO_BANK_TRANSFER_RECEIVED', 'thanh_toan', 44, NULL, '2026-11-10 12:19:24.33572+07'),
	(402, 2, 'ORDER_DANG_CHUAN_BI', 'don_hang', 44, NULL, '2026-11-10 12:19:38.434618+07'),
	(403, 2, 'ORDER_DANG_GIAO', 'don_hang', 44, NULL, '2026-11-10 12:20:38.053109+07'),
	(404, 2, 'ORDER_DA_GIAO', 'don_hang', 44, NULL, '2026-11-10 12:20:40.270878+07'),
	(405, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-10 12:21:16.63318+07'),
	(406, 3, 'CHECKOUT', 'don_hang', 45, NULL, '2026-11-10 12:21:43.5778+07'),
	(407, 3, 'ORDER_DA_HUY', 'don_hang', 45, NULL, '2026-11-10 12:22:01.20673+07'),
	(408, 3, 'CHECKOUT', 'don_hang', 46, NULL, '2026-11-10 12:22:40.617089+07'),
	(409, 3, 'LOGIN', 'tai_khoan', 3, NULL, '2026-11-10 12:26:23.480332+07'),
	(410, 2, 'ORDER_DA_HUY', 'don_hang', 46, NULL, '2026-11-10 12:40:11.858402+07'),
	(411, 3, 'CHECKOUT', 'don_hang', 47, NULL, '2026-11-10 12:41:10.43514+07'),
	(412, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-10 13:05:50.960162+07'),
	(413, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-11 11:52:48.205134+07'),
	(414, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-11 11:53:00.080848+07'),
	(415, 5, 'LOGIN', 'tai_khoan', 5, NULL, '2026-11-11 11:53:13.949678+07'),
	(416, 2, 'LOGIN', 'tai_khoan', 2, NULL, '2026-11-11 11:55:32.783075+07'),
	(417, 1, 'LOGIN', 'tai_khoan', 1, NULL, '2026-11-11 11:59:26.006605+07'),
	(418, 1, 'LOGIN', 'tai_khoan', 1, NULL, '2026-11-11 12:01:12.099936+07'),
	(419, 1, 'LOGIN', 'tai_khoan', 1, NULL, '2026-11-11 12:01:36.379302+07');


--
-- Data for Name: password_reset_challenge; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.password_reset_challenge VALUES
	('73e37192-2814-4ed8-9470-7112ddee92e4', 5, NULL, '2026-11-08 14:10:16.603355+07', 0, NULL, NULL, true, true, '2026-11-08 14:05:16.603355+07'),
	('1952c34f-de94-42cc-bf7b-d2ec81c6a45e', 5, NULL, '2026-11-08 14:11:50.133957+07', 0, NULL, NULL, true, true, '2026-11-08 14:06:50.133957+07'),
	('c976587b-5cc1-443b-bd3f-a5b122be2fe3', 5, NULL, '2026-11-08 14:18:00.724709+07', 0, NULL, NULL, true, true, '2026-11-08 14:13:00.724709+07'),
	('09721f70-2c85-4d65-8ae6-3a9c40c8301a', 5, NULL, '2026-11-08 14:21:27.259834+07', 0, NULL, NULL, true, false, '2026-11-08 14:16:27.259834+07');


--
-- Data for Name: payment_notification; Type: TABLE DATA; Schema: public; Owner: -
--



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
	(71, 2, 'c7fc57bb7a4a8a2f3ffbe3a61495b7ec63e410fa0efbbae87d5ec0e08d18be01', '2026-11-08 23:28:25.293836+07', false, '2026-11-08 15:28:24.988022+07'),
	(72, 2, '8dc91d229791a4ee077c8408fc6214f78a6132df2ebf79a33db45fc28a356fce', '2026-11-10 00:40:24.189425+07', false, '2026-11-09 16:40:23.816013+07'),
	(73, 5, 'ca7fb18b774cf87d94259852d67065856424b414c4083c06f7683d128db5ac1c', '2026-11-10 02:14:35.224924+07', false, '2026-11-09 18:14:34.876428+07'),
	(74, 2, 'd82bad100e287e77a8f4aa08761b7331ad4a0b06a7193c492219b5276f1587f3', '2026-11-10 03:52:05.313209+07', false, '2026-11-09 19:52:04.718092+07'),
	(75, 4, '2009a8bdf62a5d55644cfc35e0cee6fbe2715aa7c3955ff12c841b9d9a549ec9', '2026-11-10 19:31:48.501675+07', true, '2026-11-10 11:31:47.940027+07'),
	(76, 5, '3deef55b86037857d671be72432701ced1db64646fd17a1bc4969e2ba6980f26', '2026-11-10 19:32:09.867863+07', true, '2026-11-10 11:32:09.528041+07'),
	(77, 6, '307fc4a2a87dbf4f2dcc3e808e61becfc42e4c050dd9b80ffc9f999c5c44c47f', '2026-11-10 20:09:46.806437+07', true, '2026-11-10 12:09:46.476284+07'),
	(78, 2, '3bc2001401b67bd7d8a7a809094be6952c811fe3199c3aeda3f256161b81645b', '2026-11-10 20:11:54.531133+07', false, '2026-11-10 12:11:54.224981+07'),
	(79, 3, '74ac6c5ef13713af5cf95f0a42a2b42e8ff37cee60629e4f505cdaa7d98b9eb2', '2026-11-10 20:21:16.969846+07', true, '2026-11-10 12:21:16.63318+07'),
	(80, 3, 'e5991dbedd28ed0aa3665451e9e71019256248bbc62aeae24de9b3b8c2444a90', '2026-11-10 20:26:23.877459+07', true, '2026-11-10 12:26:23.480332+07'),
	(81, 5, '85cd74589a13192b2f312452ab961c8caea1d68da48ab23e7c6c32c288725803', '2026-11-10 21:05:51.463649+07', false, '2026-11-10 13:05:50.960162+07'),
	(82, 5, 'aaf7b60c65060a6d0446cacc5f917503f0dd4ba08595df117718c3c57d7aa2a4', '2026-11-11 19:52:48.550237+07', true, '2026-11-11 11:52:48.205134+07'),
	(83, 5, '61c0325240e0525c054ab5a3e30e68ebbb8fa1f8179d41625fffc872b95baaef', '2026-11-11 19:53:00.389439+07', true, '2026-11-11 11:53:00.080848+07'),
	(84, 5, '40d17a2c5b81b39eb7283cfb83fb4d022559903f8ef1df6376a3de8045c4fbd1', '2026-11-11 19:53:14.293222+07', false, '2026-11-11 11:53:13.949678+07'),
	(85, 2, 'f4738871c421b434f81d767600144f673ef09fbdda47cc266daef5a430712f5b', '2026-11-11 19:55:33.18645+07', false, '2026-11-11 11:55:32.783075+07'),
	(86, 1, 'a47fcf10fbb07e0d26983729dd84a195fa6387eb9216705a26386bd681cf0a38', '2026-11-11 19:59:26.787199+07', false, '2026-11-11 11:59:26.006605+07'),
	(87, 1, '8f3a15a37412a8345f4e60b3ba2efa3e10e758c204afb7445f9c098c5ec53881', '2026-11-11 20:01:12.500924+07', false, '2026-11-11 12:01:12.099936+07'),
	(88, 1, '0b7db651f7c4752d83d12f8ee1b44cee613a7ae1aee7938a6082f5b95f5e3925', '2026-11-11 20:01:36.721636+07', false, '2026-11-11 12:01:36.379302+07');


--
-- Data for Name: quy_cach_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.quy_cach_san_pham OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'Lon lẻ', 'LON', 1, 12000.00, 8000.00, true),
	(2, 1, 'Lốc 6 lon', 'LOC', 6, 69000.00, 48000.00, true),
	(3, 1, 'Thùng 24 lon', 'THUNG', 24, 270000.00, 192000.00, true),
	(5, 2, 'Thùng 24 chai', 'THUNG', 24, 160000.00, 108000.00, true),
	(4, 2, 'Chai lẻ', 'CHAI', 1, 7010.00, 4500.00, true),
	(27, 3, 'Lon lẻ', 'LON', 1, 11000.00, 0.00, true),
	(17, 21, 'Lon lẻ', 'LON', 1, 12000.00, 5050.51, true),
	(10, 11, 'Lon lẻ', 'LON', 1, 12000.00, 9583.33, true),
	(72, 11, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 287500.00, 229999.92, false),
	(15, 15, 'Chai lẻ', 'CHAI', 1, 6500.00, 5000.00, true),
	(84, 15, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 150000.00, 120000.00, false),
	(6, 20, 'Lon lẻ', 'LON', 1, 19000.00, 15000.00, true),
	(32, 20, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 112500.00, 90000.00, false),
	(73, 20, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 450000.00, 360000.00, false),
	(19, 19, 'Lon lẻ', 'LON', 1, 12000.00, 9583.33, true),
	(74, 19, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 287500.00, 229999.92, false),
	(14, 18, 'Chai lẻ', 'CHAI', 1, 12500.00, 10000.00, true),
	(75, 18, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 300000.00, 240000.00, false),
	(12, 12, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(76, 12, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(28, 14, 'Chai lẻ', 'CHAI', 1, 6500.00, 5000.00, true),
	(85, 14, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 150000.00, 120000.00, false),
	(13, 10, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(77, 10, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(29, 9, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(20, 24, 'Hộp lẻ', 'HOP', 1, 31000.00, 24444.44, true),
	(38, 24, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 183500.00, 146666.64, false),
	(35, 24, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 733500.00, 586666.56, false),
	(78, 9, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(21, 8, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(79, 8, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(22, 6, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(81, 6, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(18, 5, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(82, 5, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(24, 4, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(83, 4, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(30, 7, 'Lon lẻ', 'LON', 1, 11500.00, 9166.67, true),
	(80, 7, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 275500.00, 220000.08, false),
	(16, 13, 'Chai lẻ', 'CHAI', 1, 6500.00, 5000.00, true),
	(86, 13, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 150000.00, 120000.00, false),
	(9, 27, 'Hộp lẻ', 'HOP', 1, 12500.00, 10000.00, true),
	(87, 27, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 300000.00, 240000.00, false),
	(8, 26, 'Hộp lẻ', 'HOP', 1, 13500.00, 10555.56, true),
	(36, 26, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 79500.00, 63333.36, false),
	(37, 26, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 317000.00, 253333.44, false),
	(7, 25, 'Hộp lẻ', 'HOP', 1, 12500.00, 10000.00, true),
	(88, 25, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 300000.00, 240000.00, false),
	(25, 23, 'Chai lẻ', 'CHAI', 1, 13500.00, 10416.67, true),
	(34, 23, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 313000.00, 250000.08, false),
	(26, 22, 'Chai lẻ', 'CHAI', 1, 13500.00, 10416.67, true),
	(33, 22, 'Lốc 6 đơn vị (nhập)', 'LOC', 6, 78500.00, 62500.02, false),
	(71, 22, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 313000.00, 250000.08, false),
	(11, 17, 'Chai lẻ', 'CHAI', 1, 13000.00, 10208.33, true),
	(31, 17, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 306500.00, 244999.92, false),
	(23, 16, 'Chai lẻ', 'CHAI', 1, 13500.00, 10416.67, true),
	(89, 16, 'Thùng 24 đơn vị (nhập)', 'THUNG', 24, 313000.00, 250000.08, false);


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
	(1, 1, 1, 'SP001', 'Nước ngọt vị cam 330ml', NULL, NULL, NULL, NULL, '330ml', 'LON', NULL, NULL, NULL, 'NGUNG_KINH_DOANH', false, '2026-11-03 13:15:07.268189+07', '2026-11-03 13:15:07.268189+07'),
	(27, 10, 22, 'CAT-VINAMILK-180', 'Vinamilk sữa có đường 180ml', 'Sữa Vinamilk có đường đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Có đường', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(25, 10, 24, 'CAT-MILO-180', 'Milo ca cao 180ml', 'Đồ uống ca cao Milo đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Ca cao', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(20, 7, 11, 'CAT-REDBULL-250', 'Red Bull 250ml', 'Nước tăng lực Red Bull đóng lon.', NULL, NULL, NULL, '250ml', 'LON', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(11, 1, 3, 'CAT-COCA-330', 'Coca-Cola nguyên bản 330ml', 'Nước ngọt có ga vị cola, đóng lon. Dùng ngon hơn khi uống lạnh.', NULL, NULL, NULL, '330ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(8, 1, 5, 'CAT-SPRITE-330', 'Sprite chanh 330ml', 'Nước ngọt có ga Sprite hương chanh, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(21, 7, 10, 'CAT-STING-330', 'Sting dâu 330ml', 'Nước tăng lực Sting hương dâu, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Dâu', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(2, 2, 2, 'SP002', 'Nước suối 500ml', '', NULL, NULL, NULL, '500ml', 'CHAI', NULL, NULL, NULL, 'NGUNG_KINH_DOANH', false, '2026-11-03 13:15:07.268189+07', '2026-11-03 13:15:07.268189+07'),
	(3, 1, 9, 'CAT-SCHWEPPES-SODA-330', 'Schweppes Soda 330ml', 'Nước soda Schweppes đóng lon; có thể dùng trực tiếp hoặc pha đồ uống.', NULL, NULL, NULL, '330ml', 'LON', 'Soda', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'NGUNG_KINH_DOANH', false, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(26, 10, 23, 'CAT-TH-180', 'TH true MILK sữa có đường 180ml', 'Sữa TH true MILK có đường đóng hộp dùng sẵn.', NULL, NULL, NULL, '180ml', 'HOP', 'Có đường', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(24, 9, 21, 'CAT-VFRESH-CAM-1000', 'Vfresh nước cam 1 lít', 'Đồ uống trái cây Vfresh vị cam, đóng hộp.', NULL, NULL, NULL, '1 lít', 'HOP', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(23, 8, 19, 'CAT-REVIVE-500', 'Revive 500ml', 'Nước uống thể thao Revive đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(22, 8, 20, 'CAT-POCARI-350', 'Pocari Sweat 500ml', 'Nước uống Pocari Sweat đóng chai.', NULL, NULL, NULL, '350ml', 'CHAI', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(19, 7, 12, 'CAT-NUMBER1-330', 'Number 1 330ml', 'Nước tăng lực Number 1 đóng lon.', NULL, NULL, NULL, '330ml', 'CHAI', 'Nguyên bản', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(18, 3, 16, 'CAT-C2-CHANH-455', 'C2 trà xanh hương chanh 455ml', 'Trà xanh C2 hương chanh, đóng chai dùng sẵn.', NULL, NULL, NULL, '455ml', 'CHAI', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(17, 3, 17, 'CAT-TEAPLUS-455', 'TEA+ trà ô long 455ml', 'Trà ô long TEA+ đóng chai dùng sẵn.', NULL, NULL, NULL, '455ml', 'CHAI', 'Ô long', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(16, 3, 18, 'CAT-KHONGDO-500', 'Trà xanh Không Độ 500ml', 'Trà xanh Không Độ đóng chai dùng sẵn.', NULL, NULL, NULL, '500ml', 'CHAI', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(15, 2, 13, 'CAT-AQUAFINA-500', 'Aquafina 500ml', 'Nước uống Aquafina đóng chai, tiện mang theo.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(14, 2, 14, 'CAT-DASANI-500', 'Dasani 500ml', 'Nước uống Dasani đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(13, 2, 15, 'CAT-LAVIE-500', 'La Vie 500ml', 'Nước uống La Vie đóng chai.', NULL, NULL, NULL, '500ml', 'CHAI', 'Không vị', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(12, 1, 3, 'CAT-COCA-ZERO-330', 'Coca-Cola Zero Sugar 330ml', 'Nước ngọt có ga Coca-Cola Zero Sugar, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(10, 1, 4, 'CAT-PEPSI-ZERO-320', 'Pepsi không calo 320ml', 'Nước ngọt Pepsi không calo, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(9, 1, 4, 'CAT-PEPSI-320', 'Pepsi  320ml', 'Nước ngọt có ga Pepsi vị cola, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cola', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(7, 1, 6, 'CAT-FANTA-CAM-330', 'Fanta cam 330ml', 'Nước ngọt có ga Fanta hương cam, đóng lon.', NULL, NULL, NULL, '330ml', 'LON', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(6, 1, 7, 'CAT-7UP-320', '7Up chanh 320ml', 'Nước ngọt có ga 7Up hương chanh, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Chanh', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(4, 1, 8, 'CAT-MIRINDA-CAM-320', 'Mirinda cam 320ml', 'Nước ngọt có ga Mirinda hương cam, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Cam', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07'),
	(5, 1, 8, 'CAT-MIRINDA-SODA-320', 'Mirinda soda kem 320ml', 'Nước ngọt có ga Mirinda hương soda kem, đóng lon.', NULL, NULL, NULL, '320ml', 'LON', 'Soda kem', NULL, 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.', 'DANG_BAN', true, '2026-11-03 16:15:08.356368+07', '2026-11-03 16:15:08.356368+07');


--
-- Data for Name: san_pham_yeu_thich; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: sepay_webhook_event; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.sepay_webhook_event VALUES
	(47020, '2026-11-09 20:12:05.945764+07', 'ACB', '0000000002', 'SB38BFC0A150C7', 'WBAF390131D4C34DA78D03.', 121500.00, NULL, NULL, 'REVIEW', 'WRONG_RECEIVING_ACCOUNT_OR_BANK', 'test');


--
-- Data for Name: so_luong_san_pham; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.so_luong_san_pham VALUES
	(1, 0, 10, '2026-11-03 13:15:07.268189+07'),
	(2, 0, 10, '2026-11-03 13:15:07.268189+07'),
	(3, 0, 10, '2026-11-03 16:15:08.356368+07'),
	(21, 0, 10, '2026-11-07 19:47:37.189569+07'),
	(24, 172, 10, '2026-11-08 15:15:46.004724+07'),
	(11, 192, 10, '2026-11-09 16:53:42.25684+07'),
	(19, 240, 10, '2026-11-09 18:04:34.753905+07'),
	(18, 240, 10, '2026-11-09 18:04:36.770154+07'),
	(12, 240, 10, '2026-11-09 18:04:39.126907+07'),
	(10, 240, 10, '2026-11-09 18:04:42.115521+07'),
	(9, 216, 10, '2026-11-09 18:04:43.761739+07'),
	(8, 240, 10, '2026-11-09 18:04:45.823446+07'),
	(6, 240, 10, '2026-11-09 18:04:48.837272+07'),
	(5, 240, 10, '2026-11-09 18:04:51.163336+07'),
	(4, 240, 10, '2026-11-09 18:04:52.96706+07'),
	(7, 240, 10, '2026-11-09 18:05:49.779241+07'),
	(15, 240, 10, '2026-11-09 18:07:50.765448+07'),
	(14, 240, 10, '2026-11-09 18:07:52.821505+07'),
	(13, 240, 10, '2026-11-09 18:07:54.779723+07'),
	(25, 240, 10, '2026-11-09 18:10:22.262214+07'),
	(23, 240, 10, '2026-11-09 18:13:50.893926+07'),
	(22, 384, 10, '2026-11-09 18:13:52.693478+07'),
	(17, 480, 10, '2026-11-09 18:13:55.19694+07'),
	(16, 240, 10, '2026-11-09 18:13:57.400307+07'),
	(27, 230, 10, '2026-11-09 20:27:35.446926+07'),
	(20, 290, 10, '2026-11-10 12:01:16.156814+07'),
	(26, 355, 10, '2026-11-10 12:19:38.434618+07');


--
-- Data for Name: su_dung_khuyen_mai; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.su_dung_khuyen_mai OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 1, 3, 11200.00, 'REVERSED', '2026-11-04 14:35:34.329885+07'),
	(34, 34, 6, 37, 18600.00, 'APPLIED', '2026-11-08 15:15:46.004724+07'),
	(35, 34, 6, 38, 38000.00, 'APPLIED', '2026-11-09 19:19:35.210355+07'),
	(36, 1, 6, 40, 12500.00, 'APPLIED', '2026-11-09 20:27:35.446926+07'),
	(37, 34, 6, 44, 13500.00, 'APPLIED', '2026-11-10 12:19:38.434618+07');


--
-- Data for Name: tai_khoan; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tai_khoan OVERRIDING SYSTEM VALUE VALUES
	(4, 'quanab@gmail.com', '$2a$12$lCmOhKd9shm64LhJ4Xhe5.qBZFKpwR4muYURmfwwcHpN2xBCcy1wC', 'ACTIVE', false, 0, NULL, '2026-11-03 15:33:33.131211+07', '2026-11-03 15:33:33.131211+07'),
	(6, 'demo-bank-smoke-9ca5d8f3-7f6a-41b6-9756-bef6324c809b@test.invalid', '$2a$12$T0oUAJzVGC.UNRMxXpuaZOgVdxYaIMz9iBpvSMoPDVjCI1HbpdEGS', 'ACTIVE', false, 0, NULL, '2026-11-10 12:09:45.566399+07', '2026-11-10 12:09:45.566399+07'),
	(3, 'khach@waterbus.demo', '$2a$12$2S9Y9IfCzQLO2j2aWseEEuzCzfaKV5jTQP3V72ziXlyReqybw9CFy', 'ACTIVE', false, 0, NULL, '2026-11-03 15:25:38.232189+07', '2026-11-03 15:25:38.232189+07'),
	(5, 'ngogiahung.hcm@gmail.com', '$2a$12$GNzYebmY6Zdwm2pGaI/a8.ZcPbxmD1CBqghry6FrX18bHLEj4l1YS', 'ACTIVE', false, 0, NULL, '2026-11-08 13:36:04.528191+07', '2026-11-08 13:36:04.528191+07'),
	(2, 'admin1@gmail.com', '$2a$12$fHKdnzX9UlbpNkVWQta84.ay2gcRG2yixliG7Tco62hPQvVD/kfNe', 'ACTIVE', false, 0, NULL, '2026-11-03 15:24:45.072766+07', '2026-11-03 15:24:45.072766+07'),
	(1, 'admin@example.com', '$2a$12$MfubYvycFKC0ZqAel2pGE.iRndUT.0pzAoaASMGrF/GlCMYSfPr2e', 'ACTIVE', false, 0, NULL, '2026-11-03 13:15:31.236235+07', '2026-11-03 13:15:31.236235+07');


--
-- Data for Name: tai_khoan_vai_tro; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.tai_khoan_vai_tro VALUES
	(1, 3),
	(2, 3),
	(4, 2),
	(3, 1),
	(5, 1),
	(6, 1);


--
-- Data for Name: thanh_toan; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.thanh_toan OVERRIDING SYSTEM VALUE VALUES
	(1, 1, 'COD', NULL, NULL, 80000.00, 'PENDING', '2026-11-03 16:37:52.820068+07', NULL, NULL, 'live', false),
	(2, 2, 'COD', NULL, NULL, 130000.00, 'PENDING', '2026-11-04 13:03:18.413361+07', NULL, NULL, 'live', false),
	(3, 3, 'COD', NULL, NULL, 100800.00, 'PENDING', '2026-11-04 14:34:38.732069+07', NULL, NULL, 'live', false),
	(36, 36, 'COD', NULL, NULL, 155000.00, 'PENDING', '2026-11-07 20:23:40.626183+07', NULL, NULL, 'live', false),
	(37, 37, 'COD', NULL, NULL, 74400.00, 'PENDING', '2026-11-08 15:15:30.126268+07', NULL, NULL, 'live', false),
	(38, 38, 'BANK_TRANSFER', NULL, NULL, 152000.00, 'PENDING', '2026-11-09 19:18:25.537325+07', NULL, 'WBD1E79EC91C644DD68CBB', 'live', false),
	(39, 39, 'BANK_TRANSFER', NULL, NULL, 121500.00, 'PENDING', '2026-11-09 19:53:14.65845+07', NULL, 'WBAF390131D4C34DA78D03', 'test', false),
	(40, 40, 'BANK_TRANSFER', 'LOCAL_DEMO:test:40', 'LOCAL_DEMO:test:40', 112500.00, 'SUCCESS', '2026-11-09 20:26:48.645068+07', '{"mode": "test", "provider": "LOCAL_DEMO", "realMoney": false}', 'WBF1143B20E34D49C993A9', 'test', false),
	(41, 41, 'BANK_TRANSFER', NULL, NULL, 190000.00, 'PENDING', '2026-11-10 11:59:34.077991+07', NULL, 'WB526F5C5E18034599981E', 'live', false),
	(42, 42, 'BANK_TRANSFER', 'INTERNAL_MOCK:test:5101a529-77f2-4336-8eba-7728c50b60fe', 'INTERNAL_MOCK:test:5101a529-77f2-4336-8eba-7728c50b60fe', 12500.00, 'SUCCESS', '2026-11-10 12:09:53.216609+07', '{"mode": "test", "provider": "INTERNAL_MOCK", "realMoney": false, "transactionId": "5101a529-77f2-4336-8eba-7728c50b60fe"}', 'WBBAEF0F6570824738A55D', 'test', true),
	(43, 43, 'BANK_TRANSFER', 'INTERNAL_MOCK:test:e79333e9-8227-4af3-832b-0b3f73c7064b', 'INTERNAL_MOCK:test:e79333e9-8227-4af3-832b-0b3f73c7064b', 92000.00, 'SUCCESS', '2026-11-10 12:17:06.918517+07', '{"mode": "test", "provider": "INTERNAL_MOCK", "realMoney": false, "transactionId": "e79333e9-8227-4af3-832b-0b3f73c7064b"}', 'WB04E07159738D466292E9', 'test', true),
	(44, 44, 'BANK_TRANSFER', 'INTERNAL_MOCK:test:183c555e-c9db-40bb-8a0c-d9a9a9938bac', 'INTERNAL_MOCK:test:183c555e-c9db-40bb-8a0c-d9a9a9938bac', 54000.00, 'SUCCESS', '2026-11-10 12:19:24.33572+07', '{"mode": "test", "provider": "INTERNAL_MOCK", "realMoney": false, "transactionId": "183c555e-c9db-40bb-8a0c-d9a9a9938bac"}', 'WB0782EF9DE71E4B22A407', 'test', true),
	(45, 45, 'COD', NULL, NULL, 121500.00, 'PENDING', '2026-11-10 12:21:43.5778+07', NULL, NULL, 'live', false),
	(46, 46, 'BANK_TRANSFER', NULL, NULL, 26000.00, 'PENDING', '2026-11-10 12:22:40.617089+07', NULL, 'WBD06FDC496CC14CC3B3F2', 'test', true),
	(47, 47, 'BANK_TRANSFER', NULL, NULL, 67500.00, 'PENDING', '2026-11-10 12:41:10.43514+07', NULL, NULL, 'live', false);


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

SELECT pg_catalog.setval('public.bien_dong_so_luong_id_seq', 92, true);


--
-- Name: chi_tiet_don_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_don_hang_id_seq', 47, true);


--
-- Name: chi_tiet_don_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_don_ncc_id_seq', 69, true);


--
-- Name: chi_tiet_gio_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_gio_hang_id_seq', 131, true);


--
-- Name: chi_tiet_hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_hoa_don_id_seq', 41, true);


--
-- Name: chi_tiet_lan_nhap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chi_tiet_lan_nhap_id_seq', 71, true);


--
-- Name: cong_no_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cong_no_ncc_id_seq', 71, true);


--
-- Name: danh_gia_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.danh_gia_san_pham_id_seq', 1, false);


--
-- Name: dia_chi_giao_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dia_chi_giao_hang_id_seq', 3, true);


--
-- Name: dieu_chinh_so_luong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dieu_chinh_so_luong_id_seq', 46, true);


--
-- Name: don_dat_hang_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.don_dat_hang_ncc_id_seq', 69, true);


--
-- Name: don_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.don_hang_id_seq', 47, true);


--
-- Name: giay_to_ncc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.giay_to_ncc_id_seq', 1, false);


--
-- Name: gio_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gio_hang_id_seq', 518, true);


--
-- Name: hinh_anh_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hinh_anh_san_pham_id_seq', 24, true);


--
-- Name: hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hoa_don_id_seq', 41, true);


--
-- Name: hoan_tien_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hoan_tien_id_seq', 1, false);


--
-- Name: khach_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.khach_hang_id_seq', 7, true);


--
-- Name: khuyen_mai_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.khuyen_mai_id_seq', 34, true);


--
-- Name: lan_nhap_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lan_nhap_hang_id_seq', 71, true);


--
-- Name: lich_su_hoa_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lich_su_hoa_don_id_seq', 36, true);


--
-- Name: lich_su_trang_thai_don_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lich_su_trang_thai_don_id_seq', 60, true);


--
-- Name: lien_he_khach_hang_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.lien_he_khach_hang_id_seq', 1, false);


--
-- Name: loai_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.loai_san_pham_id_seq', 10, true);


--
-- Name: momo_ipn_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.momo_ipn_history_id_seq', 1, false);


--
-- Name: momo_payment_attempt_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.momo_payment_attempt_id_seq', 1, false);


--
-- Name: nha_cung_cap_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nha_cung_cap_id_seq', 4, true);


--
-- Name: nhan_vien_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nhan_vien_id_seq', 4, true);


--
-- Name: nhat_ky_hoat_dong_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.nhat_ky_hoat_dong_id_seq', 419, true);


--
-- Name: payment_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payment_notification_id_seq', 1, false);


--
-- Name: pham_vi_khuyen_mai_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pham_vi_khuyen_mai_id_seq', 46, true);


--
-- Name: phien_xac_thuc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.phien_xac_thuc_id_seq', 88, true);


--
-- Name: quy_cach_san_pham_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.quy_cach_san_pham_id_seq', 89, true);


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

SELECT pg_catalog.setval('public.su_dung_khuyen_mai_id_seq', 37, true);


--
-- Name: tai_khoan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tai_khoan_id_seq', 6, true);


--
-- Name: thanh_toan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.thanh_toan_id_seq', 47, true);


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
-- Name: checkout_request checkout_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkout_request
    ADD CONSTRAINT checkout_request_pkey PRIMARY KEY (customer_id, request_key);


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
-- Name: demo_bank_intent demo_bank_intent_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_intent
    ADD CONSTRAINT demo_bank_intent_payment_id_key UNIQUE (payment_id);


--
-- Name: demo_bank_intent demo_bank_intent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_intent
    ADD CONSTRAINT demo_bank_intent_pkey PRIMARY KEY (id);


--
-- Name: demo_bank_transaction demo_bank_transaction_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_transaction
    ADD CONSTRAINT demo_bank_transaction_payment_id_key UNIQUE (payment_id);


--
-- Name: demo_bank_transaction demo_bank_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_transaction
    ADD CONSTRAINT demo_bank_transaction_pkey PRIMARY KEY (id);


--
-- Name: demo_bank_wallet demo_bank_wallet_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_wallet
    ADD CONSTRAINT demo_bank_wallet_pkey PRIMARY KEY (customer_id);


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
-- Name: momo_ipn_history momo_ipn_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ipn_history
    ADD CONSTRAINT momo_ipn_history_pkey PRIMARY KEY (id);


--
-- Name: momo_payment_attempt momo_payment_attempt_momo_order_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_payment_attempt
    ADD CONSTRAINT momo_payment_attempt_momo_order_id_key UNIQUE (momo_order_id);


--
-- Name: momo_payment_attempt momo_payment_attempt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_payment_attempt
    ADD CONSTRAINT momo_payment_attempt_pkey PRIMARY KEY (id);


--
-- Name: momo_payment_attempt momo_payment_attempt_request_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_payment_attempt
    ADD CONSTRAINT momo_payment_attempt_request_id_key UNIQUE (request_id);


--
-- Name: momo_payment_attempt momo_payment_attempt_trans_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_payment_attempt
    ADD CONSTRAINT momo_payment_attempt_trans_id_key UNIQUE (trans_id);


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
-- Name: payment_notification payment_notification_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notification
    ADD CONSTRAINT payment_notification_payment_id_key UNIQUE (payment_id);


--
-- Name: payment_notification payment_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notification
    ADD CONSTRAINT payment_notification_pkey PRIMARY KEY (id);


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
-- Name: sepay_webhook_event sepay_webhook_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sepay_webhook_event
    ADD CONSTRAINT sepay_webhook_event_pkey PRIMARY KEY (sepay_mode, transaction_id);


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
-- Name: idx_payment_transfer_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payment_transfer_reference ON public.thanh_toan USING btree (transfer_reference);


--
-- Name: idx_receipt_pending_purchase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_receipt_pending_purchase ON public.lan_nhap_hang USING btree (don_ncc_id) WHERE ((trang_thai)::text = 'DRAFT'::text);


--
-- Name: idx_reset_account_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reset_account_created ON public.password_reset_challenge USING btree (tai_khoan_id, tao_luc DESC);


--
-- Name: idx_sepay_event_review; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sepay_event_review ON public.sepay_webhook_event USING btree (status, received_at DESC);


--
-- Name: momo_one_active_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX momo_one_active_attempt ON public.momo_payment_attempt USING btree (payment_id) WHERE ((status)::text = ANY ((ARRAY['CREATED'::character varying, 'PENDING'::character varying])::text[]));


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
-- Name: checkout_request checkout_request_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkout_request
    ADD CONSTRAINT checkout_request_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.khach_hang(id);


--
-- Name: checkout_request checkout_request_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkout_request
    ADD CONSTRAINT checkout_request_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.don_hang(id);


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
-- Name: demo_bank_intent demo_bank_intent_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_intent
    ADD CONSTRAINT demo_bank_intent_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.thanh_toan(id);


--
-- Name: demo_bank_transaction demo_bank_transaction_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_transaction
    ADD CONSTRAINT demo_bank_transaction_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.demo_bank_wallet(customer_id);


--
-- Name: demo_bank_transaction demo_bank_transaction_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_transaction
    ADD CONSTRAINT demo_bank_transaction_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.thanh_toan(id);


--
-- Name: demo_bank_wallet demo_bank_wallet_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demo_bank_wallet
    ADD CONSTRAINT demo_bank_wallet_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.khach_hang(id);


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
-- Name: momo_ipn_history momo_ipn_history_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ipn_history
    ADD CONSTRAINT momo_ipn_history_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.momo_payment_attempt(id);


--
-- Name: momo_payment_attempt momo_payment_attempt_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_payment_attempt
    ADD CONSTRAINT momo_payment_attempt_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.thanh_toan(id);


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
-- Name: payment_notification payment_notification_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notification
    ADD CONSTRAINT payment_notification_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.don_hang(id);


--
-- Name: payment_notification payment_notification_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_notification
    ADD CONSTRAINT payment_notification_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.thanh_toan(id);


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
-- Name: sepay_webhook_event sepay_webhook_event_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sepay_webhook_event
    ADD CONSTRAINT sepay_webhook_event_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.don_hang(id);


--
-- Name: sepay_webhook_event sepay_webhook_event_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sepay_webhook_event
    ADD CONSTRAINT sepay_webhook_event_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.thanh_toan(id);


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

\unrestrict GD98DboIinVDZFRtjwNNnETTTZQY35JG8vvfzAAPiWathxWRR5bm9MYlB6zPn3l

COMMIT;

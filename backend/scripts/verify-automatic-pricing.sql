-- Runs the installed trigger bodies against TEMPORARY tables only, then rolls back.
-- Does not create a database, consume production sequences or modify business rows.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path=pg_temp,public;
CREATE TEMP TABLE so_luong_san_pham(san_pham_id bigint PRIMARY KEY,so_luong_co_ban bigint NOT NULL DEFAULT 0,ngay_cap_nhat timestamptz);
CREATE TEMP TABLE quy_cach_san_pham(id bigint PRIMARY KEY,san_pham_id bigint,he_so_quy_doi int,gia_von numeric(18,2),gia_ban numeric(18,2));
CREATE TEMP TABLE don_dat_hang_ncc(id bigint PRIMARY KEY,trang_thai text);
CREATE TEMP TABLE chi_tiet_don_ncc(id bigint PRIMARY KEY,don_ncc_id bigint,quy_cach_id bigint,so_luong_dat int,he_so_quy_doi int);
CREATE TEMP TABLE lan_nhap_hang(id bigint PRIMARY KEY,don_ncc_id bigint,trang_thai text,ngay_xac_nhan timestamptz);
CREATE TEMP TABLE chi_tiet_lan_nhap(id bigint PRIMARY KEY,lan_nhap_id bigint,ct_don_ncc_id bigint,so_luong_thuc_nhan int,so_luong_loai int,ly_do_loai text,gia_nhap_thuc_te numeric(18,2));
CREATE TEMP TABLE bien_dong_so_luong(san_pham_id bigint,loai text,nguon_id bigint,so_luong_thay_doi bigint,so_luong_truoc bigint,so_luong_sau bigint);
DO $verify$
DECLARE name text; definition text;
BEGIN
 FOREACH name IN ARRAY ARRAY['fn_receive_inventory','fn_so_luong_bien_dong'] LOOP
  definition:=pg_get_functiondef(('public.'||name||'()')::regprocedure);
  EXECUTE replace(definition,'public.'||name||'()','pg_temp.'||name||'()');
  EXECUTE 'ALTER FUNCTION pg_temp.'||name||'() SET search_path=pg_temp,public';
 END LOOP;
END $verify$;
CREATE TRIGGER test_inventory BEFORE UPDATE ON pg_temp.lan_nhap_hang FOR EACH ROW EXECUTE FUNCTION pg_temp.fn_receive_inventory();
CREATE TRIGGER test_movement BEFORE INSERT ON pg_temp.bien_dong_so_luong FOR EACH ROW EXECUTE FUNCTION pg_temp.fn_so_luong_bien_dong();
CREATE TRIGGER test_price BEFORE INSERT OR UPDATE OF gia_von,gia_ban ON pg_temp.quy_cach_san_pham FOR EACH ROW EXECUTE FUNCTION public.fn_package_automatic_price();
INSERT INTO so_luong_san_pham VALUES(1,50,NULL),(2,0,NULL);
INSERT INTO quy_cach_san_pham VALUES(1,1,1,8000,10000),(2,1,6,48000,60000),(3,2,24,0,0);
INSERT INTO don_dat_hang_ncc VALUES(1,'DA_DUYET'),(2,'DA_DUYET'),(3,'DA_DUYET');
INSERT INTO chi_tiet_don_ncc VALUES(1,1,1,12,1),(2,1,2,15,6),(3,2,1,5,1),(4,3,3,1,24);
INSERT INTO lan_nhap_hang VALUES(1,1,'DRAFT',NULL),(2,2,'DRAFT',NULL),(3,3,'DRAFT',NULL);
INSERT INTO chi_tiet_lan_nhap VALUES(1,1,1,10,2,'Broken',9000),(2,1,2,15,0,NULL,54000),(3,2,3,0,5,'Expired',9000),(4,3,4,1,0,NULL,240000);
UPDATE lan_nhap_hang SET trang_thai='CONFIRMED' WHERE id=1;
UPDATE lan_nhap_hang SET trang_thai='CONFIRMED' WHERE id=1;
DO $verify$ BEGIN
 IF public.fn_automatic_sale_price(11666.67)<>15000 OR public.fn_automatic_sale_price(58333.33)<>73000
    OR public.fn_automatic_sale_price(10000)<>12500 THEN RAISE EXCEPTION 'Incorrect 500 dong price rounding'; END IF;
 IF (SELECT so_luong_co_ban FROM so_luong_san_pham WHERE san_pham_id=1)<>150 THEN RAISE EXCEPTION 'Incorrect accepted stock'; END IF;
 IF (SELECT gia_von FROM quy_cach_san_pham WHERE id=1)<>8666.67 THEN RAISE EXCEPTION 'Incorrect weighted cost'; END IF;
 IF (SELECT gia_ban FROM quy_cach_san_pham WHERE id=1)<>11000 THEN RAISE EXCEPTION 'Incorrect rounded selling price'; END IF;
 IF (SELECT gia_ban FROM quy_cach_san_pham WHERE id=2)<>65500 THEN RAISE EXCEPTION 'Incorrect rounded pack price'; END IF;
 IF (SELECT count(*) FROM bien_dong_so_luong)<>2 THEN RAISE EXCEPTION 'Repeated confirmation changed inventory'; END IF;
END $verify$;
UPDATE lan_nhap_hang SET trang_thai='CONFIRMED' WHERE id=2;
DO $verify$ BEGIN
 IF (SELECT gia_von FROM quy_cach_san_pham WHERE id=1)<>8666.67 OR (SELECT so_luong_co_ban FROM so_luong_san_pham WHERE san_pham_id=1)<>150
 THEN RAISE EXCEPTION 'Rejected-only delivery changed cost/stock'; END IF;
END $verify$;
UPDATE lan_nhap_hang SET trang_thai='CONFIRMED' WHERE id=3;
UPDATE quy_cach_san_pham SET gia_ban=1 WHERE id=3;
DO $verify$ BEGIN
 IF (SELECT gia_von FROM quy_cach_san_pham WHERE id=3)<>240000 OR (SELECT gia_ban FROM quy_cach_san_pham WHERE id=3)<>300000
 THEN RAISE EXCEPTION 'Incorrect first case cost or price override'; END IF;
 IF (SELECT so_luong_co_ban FROM so_luong_san_pham WHERE san_pham_id=2)<>24 THEN RAISE EXCEPTION 'Incorrect first receipt stock'; END IF;
END $verify$;
SELECT 'PASS: weighted cost 8,666.67; sale 11,000; grouped packages; rejected goods; first receipt; idempotence; rounded price enforcement' AS result;
ROLLBACK;

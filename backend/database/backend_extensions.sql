-- Backend integration for beverage_store_13UC_HOAN_CHINH.sql, applied afterwards.
-- Keep the original supplied schema unchanged; record coupon selection until confirmation.
BEGIN;
ALTER TABLE don_hang ADD COLUMN IF NOT EXISTS khuyen_mai_id BIGINT REFERENCES khuyen_mai(id);
CREATE OR REPLACE FUNCTION backend_payment_invoice() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.trang_thai='SUCCESS' AND OLD.trang_thai<>'SUCCESS' THEN
  UPDATE hoa_don SET trang_thai='PAID' WHERE don_hang_id=NEW.don_hang_id AND trang_thai='ISSUED';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_backend_payment_invoice ON thanh_toan;
CREATE TRIGGER trg_backend_payment_invoice AFTER UPDATE OF trang_thai ON thanh_toan
 FOR EACH ROW EXECUTE FUNCTION backend_payment_invoice();
COMMIT;

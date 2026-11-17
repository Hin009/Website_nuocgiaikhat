-- Preserve the identity at confirmation time independently of subsequent handlers.
ALTER TABLE public.don_hang
 ADD COLUMN IF NOT EXISTS nhan_vien_xac_nhan_id bigint REFERENCES public.nhan_vien(id) ON DELETE SET NULL,
 ADD COLUMN IF NOT EXISTS ten_nhan_vien_xac_nhan text,
 ADD COLUMN IF NOT EXISTS ma_nhan_vien_xac_nhan text,
 ADD COLUMN IF NOT EXISTS thoi_gian_xac_nhan timestamptz;
CREATE INDEX IF NOT EXISTS idx_order_confirmation_employee ON public.don_hang(nhan_vien_xac_nhan_id);

-- Only backfill from an actual pending -> confirmed history event with a recorded actor.
WITH confirmed AS (
 SELECT DISTINCT ON (h.don_hang_id) h.don_hang_id,n.id,n.ho_ten,n.ma_nhan_vien,h.thoi_gian
 FROM public.lich_su_trang_thai_don h
 JOIN public.nhan_vien n ON n.tai_khoan_id=h.tai_khoan_thuc_hien_id
 WHERE h.trang_thai_cu='CHO_XAC_NHAN' AND h.trang_thai_moi='DANG_CHUAN_BI'
 ORDER BY h.don_hang_id,h.thoi_gian,h.id
)
UPDATE public.don_hang d
SET nhan_vien_xac_nhan_id=c.id,ten_nhan_vien_xac_nhan=c.ho_ten,
 ma_nhan_vien_xac_nhan=c.ma_nhan_vien,thoi_gian_xac_nhan=c.thoi_gian
FROM confirmed c
WHERE d.id=c.don_hang_id AND d.kenh_ban='ONLINE'
 AND d.nhan_vien_xac_nhan_id IS NULL AND d.ten_nhan_vien_xac_nhan IS NULL;

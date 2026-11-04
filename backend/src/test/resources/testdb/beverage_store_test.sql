-- BEVERAGE STORE: POSTGRESQL 16+, DATABASE TRONG
-- Khop 43 lop du lieu trong So_do_lop_du_lieu_tong_quat_13UC.dot;
-- bo sung bang phien_xac_thuc cho dang nhap.
-- Web online + Desktop POS; backend phai enforce permission theo BR9.
-- DATABASE PHẢI ĐƯỢC TẠO TRƯỚC: CREATE DATABASE beverage_store;
-- CHAY DUY NHAT TREN DATABASE TRONG; KHONG CHAY DE LEN DU LIEU CU.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ===== A. TAI KHOAN, PHAN QUYEN, KHACH HANG, NHAN VIEN =====
CREATE TABLE quyen (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ma_quyen VARCHAR(100) NOT NULL UNIQUE,
 ten_quyen VARCHAR(150) NOT NULL,
 ma_chuc_nang VARCHAR(30) NOT NULL,
 hanh_dong VARCHAR(30) NOT NULL,
 mo_ta TEXT,
 UNIQUE(ma_chuc_nang,hanh_dong)
);
CREATE TABLE vai_tro (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ma_vai_tro VARCHAR(30) NOT NULL UNIQUE CHECK(ma_vai_tro IN ('KHACH_HANG','NHAN_VIEN','QUAN_TRI_VIEN')),
 ten_vai_tro VARCHAR(100) NOT NULL,
 mo_ta TEXT
);
CREATE TABLE tai_khoan (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 email VARCHAR(255) NOT NULL,
 mat_khau_hash TEXT NOT NULL,
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK(trang_thai IN ('ACTIVE','LOCKED','DISABLED')),
 email_da_xac_thuc BOOLEAN NOT NULL DEFAULT FALSE,
 so_lan_dang_nhap_sai INT NOT NULL DEFAULT 0 CHECK(so_lan_dang_nhap_sai >= 0),
 khoa_den TIMESTAMPTZ, ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now(),
 ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_tai_khoan_email_ci ON tai_khoan (lower(email));
CREATE TABLE tai_khoan_vai_tro (
 tai_khoan_id BIGINT NOT NULL REFERENCES tai_khoan(id) ON DELETE CASCADE,
 vai_tro_id BIGINT NOT NULL REFERENCES vai_tro(id) ON DELETE RESTRICT,
 PRIMARY KEY(tai_khoan_id,vai_tro_id)
);
CREATE TABLE vai_tro_quyen (
 vai_tro_id BIGINT NOT NULL REFERENCES vai_tro(id) ON DELETE CASCADE,
 quyen_id BIGINT NOT NULL REFERENCES quyen(id) ON DELETE CASCADE,
 PRIMARY KEY(vai_tro_id,quyen_id)
);
CREATE TABLE phien_xac_thuc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tai_khoan_id BIGINT NOT NULL REFERENCES tai_khoan(id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE,
 het_han TIMESTAMPTZ NOT NULL,
 da_thu_hoi BOOLEAN NOT NULL DEFAULT FALSE,
 ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE khach_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tai_khoan_id BIGINT NOT NULL UNIQUE REFERENCES tai_khoan(id),
 ho_ten VARCHAR(150) NOT NULL, dien_thoai VARCHAR(25), anh_dai_dien TEXT,
 ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE nhan_vien (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tai_khoan_id BIGINT NOT NULL UNIQUE REFERENCES tai_khoan(id),
 ma_nhan_vien VARCHAR(30) NOT NULL UNIQUE, ho_ten VARCHAR(150) NOT NULL,
 ngay_sinh DATE, gioi_tinh VARCHAR(15), dien_thoai VARCHAR(25), email_lien_he VARCHAR(255),
 dia_chi TEXT, chuc_vu VARCHAR(100), ngay_vao_lam DATE,
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK(trang_thai IN ('ACTIVE','ON_LEAVE','RESIGNED'))
);
CREATE TABLE dia_chi_giao_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khach_hang_id BIGINT NOT NULL REFERENCES khach_hang(id) ON DELETE CASCADE,
 ten_nguoi_nhan VARCHAR(150) NOT NULL, so_dien_thoai VARCHAR(25),
 dia_chi TEXT NOT NULL, phuong_xa VARCHAR(150), quan_huyen VARCHAR(150), tinh_thanh VARCHAR(150),
 mac_dinh BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE UNIQUE INDEX uq_dia_chi_mac_dinh ON dia_chi_giao_hang(khach_hang_id) WHERE mac_dinh;
CREATE TABLE lien_he_khach_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khach_hang_id BIGINT REFERENCES khach_hang(id),
 ho_ten VARCHAR(150), email VARCHAR(255), dien_thoai VARCHAR(25),
 noi_dung TEXT NOT NULL, phan_hoi TEXT,
 nhan_vien_phan_hoi_id BIGINT REFERENCES nhan_vien(id),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'MOI' CHECK(trang_thai IN ('MOI','DANG_XU_LY','DA_PHAN_HOI','DA_DONG')),
 ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now(), ngay_phan_hoi TIMESTAMPTZ
);
CREATE TABLE nhat_ky_hoat_dong (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 tai_khoan_id BIGINT REFERENCES tai_khoan(id), hanh_dong VARCHAR(160) NOT NULL,
 doi_tuong VARCHAR(100), doi_tuong_id BIGINT, du_lieu_thay_doi JSONB,
 thoi_diem TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== B. DANH MUC, QUY CACH, SO LUONG, SAN PHAM =====
CREATE TABLE loai_san_pham (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, ten VARCHAR(150) NOT NULL UNIQUE,
 mo_ta TEXT, hinh_anh TEXT, hien_thi BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE thuong_hieu (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, ten VARCHAR(150) NOT NULL UNIQUE,
 logo TEXT, mo_ta TEXT, hien_thi BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE san_pham (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 loai_san_pham_id BIGINT NOT NULL REFERENCES loai_san_pham(id),
 thuong_hieu_id BIGINT NOT NULL REFERENCES thuong_hieu(id),
 sku VARCHAR(80) NOT NULL UNIQUE, ten VARCHAR(255) NOT NULL,
 mo_ta TEXT, thanh_phan TEXT, dinh_duong TEXT, xuat_xu VARCHAR(150),
 dung_tich VARCHAR(80), loai_bao_bi VARCHAR(40), huong_vi VARCHAR(100),
 so_ngay_han_dung INT CHECK(so_ngay_han_dung > 0), huong_dan_bao_quan TEXT,
 trang_thai VARCHAR(30) NOT NULL DEFAULT 'DANG_BAN' CHECK(trang_thai IN ('DANG_BAN','HET_HANG','NGUNG_KINH_DOANH')),
 hien_thi BOOLEAN NOT NULL DEFAULT TRUE,
 ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now(), ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE hinh_anh_san_pham (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id) ON DELETE CASCADE,
 duong_dan TEXT NOT NULL, anh_chinh BOOLEAN NOT NULL DEFAULT FALSE, thu_tu INT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX uq_anh_chinh ON hinh_anh_san_pham(san_pham_id) WHERE anh_chinh;
CREATE TABLE quy_cach_san_pham (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id),
 ten_quy_cach VARCHAR(60) NOT NULL, don_vi_tinh VARCHAR(30) NOT NULL,
 he_so_quy_doi INT NOT NULL CHECK(he_so_quy_doi > 0),
 gia_ban NUMERIC(18,2) NOT NULL CHECK(gia_ban >= 0),
 gia_von NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK(gia_von >= 0),
 dang_ban BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE(san_pham_id,ten_quy_cach), UNIQUE(id,san_pham_id)
);
CREATE TABLE so_luong_san_pham (
 san_pham_id BIGINT PRIMARY KEY REFERENCES san_pham(id),
 so_luong_co_ban BIGINT NOT NULL DEFAULT 0 CHECK(so_luong_co_ban >= 0),
 nguong_canh_bao BIGINT NOT NULL DEFAULT 10 CHECK(nguong_canh_bao >= 0),
 ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION fn_khoi_tao_so_luong() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO so_luong_san_pham(san_pham_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_khoi_tao_so_luong AFTER INSERT ON san_pham
 FOR EACH ROW EXECUTE FUNCTION fn_khoi_tao_so_luong();
CREATE TABLE dieu_chinh_so_luong (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id),
 quy_cach_id BIGINT NOT NULL,
 nguoi_dieu_chinh_id BIGINT NOT NULL REFERENCES nhan_vien(id),
 so_luong_truoc BIGINT NOT NULL CHECK(so_luong_truoc >= 0),
 so_luong_sau BIGINT NOT NULL CHECK(so_luong_sau >= 0),
 chenh_lech BIGINT GENERATED ALWAYS AS (so_luong_sau-so_luong_truoc) STORED,
 ly_do TEXT NOT NULL CHECK(length(trim(ly_do)) > 0),
 thoi_diem TIMESTAMPTZ NOT NULL DEFAULT now(),
 FOREIGN KEY(quy_cach_id,san_pham_id) REFERENCES quy_cach_san_pham(id,san_pham_id)
);
CREATE TABLE bien_dong_so_luong (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id),
 loai VARCHAR(30) NOT NULL CHECK(loai IN ('BAN_ONLINE','BAN_TAI_QUAY','HUY_DON','NHAP_HANG','DIEU_CHINH')),
 nguon_id BIGINT NOT NULL,
 so_luong_thay_doi BIGINT NOT NULL CHECK(so_luong_thay_doi <> 0),
 so_luong_truoc BIGINT NOT NULL CHECK(so_luong_truoc >= 0),
 so_luong_sau BIGINT NOT NULL CHECK(so_luong_sau >= 0),
 thoi_diem TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(so_luong_sau = so_luong_truoc + so_luong_thay_doi),
 UNIQUE(san_pham_id,loai,nguon_id)
);
CREATE TABLE san_pham_yeu_thich (
 khach_hang_id BIGINT NOT NULL REFERENCES khach_hang(id) ON DELETE CASCADE,
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id),
 ngay_them TIMESTAMPTZ NOT NULL DEFAULT now(),
 PRIMARY KEY(khach_hang_id,san_pham_id)
);

-- ===== C. GIO HANG, DON HANG, THANH TOAN, HOA DON =====
CREATE TABLE gio_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khach_hang_id BIGINT NOT NULL UNIQUE REFERENCES khach_hang(id) ON DELETE CASCADE,
 ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE chi_tiet_gio_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 gio_hang_id BIGINT NOT NULL REFERENCES gio_hang(id) ON DELETE CASCADE,
 quy_cach_id BIGINT NOT NULL REFERENCES quy_cach_san_pham(id),
 so_luong INT NOT NULL CHECK(so_luong > 0),
 gia_tam_tinh NUMERIC(18,2) NOT NULL CHECK(gia_tam_tinh >= 0),
 UNIQUE(gio_hang_id,quy_cach_id)
);
CREATE TABLE don_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ma_don VARCHAR(50) NOT NULL UNIQUE,
 kenh_ban VARCHAR(12) NOT NULL CHECK(kenh_ban IN ('ONLINE','TAI_QUAY')),
 khach_hang_id BIGINT REFERENCES khach_hang(id),
 nhan_vien_xu_ly_id BIGINT REFERENCES nhan_vien(id),
 ngay_dat TIMESTAMPTZ NOT NULL DEFAULT now(),
 ngay_hoan_tat TIMESTAMPTZ,
 trang_thai VARCHAR(25) NOT NULL CHECK(trang_thai IN ('CHO_XAC_NHAN','DANG_CHUAN_BI','DANG_GIAO','DA_GIAO','HOAN_TAT','DA_HUY','TU_CHOI')),
 phi_van_chuyen NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK(phi_van_chuyen >= 0),
 giam_gia NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK(giam_gia >= 0),
 tong_tien NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK(tong_tien >= 0),
 ghi_chu TEXT, ten_nguoi_nhan VARCHAR(150), sdt_nguoi_nhan VARCHAR(25),
 dia_chi_nhan TEXT, thoi_gian_nhan_du_kien TIMESTAMPTZ,
 da_tru_so_luong BOOLEAN NOT NULL DEFAULT FALSE,
 ngay_cap_nhat TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK((kenh_ban='ONLINE' AND khach_hang_id IS NOT NULL AND dia_chi_nhan IS NOT NULL)
    OR (kenh_ban='TAI_QUAY' AND nhan_vien_xu_ly_id IS NOT NULL)),
 CHECK(kenh_ban <> 'TAI_QUAY' OR trang_thai IN ('HOAN_TAT','DA_HUY'))
);
CREATE INDEX idx_don_hang_kenh_ngay ON don_hang(kenh_ban,ngay_dat DESC);
CREATE INDEX idx_don_hang_khach ON don_hang(khach_hang_id,ngay_dat DESC);
CREATE TABLE chi_tiet_don_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_hang_id BIGINT NOT NULL REFERENCES don_hang(id),
 quy_cach_id BIGINT NOT NULL REFERENCES quy_cach_san_pham(id),
 ten_san_pham VARCHAR(255) NOT NULL, ten_quy_cach VARCHAR(60) NOT NULL,
 so_luong INT NOT NULL CHECK(so_luong > 0),
 he_so_quy_doi INT NOT NULL CHECK(he_so_quy_doi > 0),
 don_gia NUMERIC(18,2) NOT NULL CHECK(don_gia >= 0),
 gia_von_don_vi NUMERIC(18,2) NOT NULL CHECK(gia_von_don_vi >= 0),
 thanh_tien NUMERIC(18,2) GENERATED ALWAYS AS (so_luong*don_gia) STORED,
 UNIQUE(don_hang_id,quy_cach_id)
);
CREATE TABLE lich_su_trang_thai_don (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_hang_id BIGINT NOT NULL REFERENCES don_hang(id),
 tai_khoan_thuc_hien_id BIGINT REFERENCES tai_khoan(id),
 trang_thai_cu VARCHAR(25), trang_thai_moi VARCHAR(25) NOT NULL,
 ghi_chu TEXT, thoi_gian TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE danh_gia_san_pham (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khach_hang_id BIGINT NOT NULL REFERENCES khach_hang(id),
 chi_tiet_don_hang_id BIGINT NOT NULL UNIQUE REFERENCES chi_tiet_don_hang(id),
 so_sao INT NOT NULL CHECK(so_sao BETWEEN 1 AND 5), noi_dung TEXT,
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(trang_thai IN ('PENDING','APPROVED','HIDDEN')),
 ngay_danh_gia TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE thanh_toan (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_hang_id BIGINT NOT NULL REFERENCES don_hang(id),
 phuong_thuc VARCHAR(30) NOT NULL CHECK(phuong_thuc IN ('COD','CASH','BANK_TRANSFER','QR','MOMO','VNPAY','ZALOPAY','CARD')),
 ma_giao_dich VARCHAR(120) UNIQUE, idempotency_key VARCHAR(120) UNIQUE,
 so_tien NUMERIC(18,2) NOT NULL CHECK(so_tien >= 0),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(trang_thai IN ('PENDING','SUCCESS','FAILED','CANCELLED','REFUNDED')),
 thoi_gian TIMESTAMPTZ NOT NULL DEFAULT now(), thong_tin_cong JSONB
);
CREATE TABLE hoan_tien (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 thanh_toan_id BIGINT NOT NULL REFERENCES thanh_toan(id),
 nguoi_xu_ly_id BIGINT NOT NULL REFERENCES nhan_vien(id),
 ly_do TEXT NOT NULL, so_tien NUMERIC(18,2) NOT NULL CHECK(so_tien > 0),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK(trang_thai IN ('PENDING','APPROVED','COMPLETED','REJECTED')),
 ngay_yeu_cau TIMESTAMPTZ NOT NULL DEFAULT now(), ngay_hoan TIMESTAMPTZ
);
CREATE TABLE hoa_don (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_hang_id BIGINT NOT NULL UNIQUE REFERENCES don_hang(id),
 nguoi_lap_id BIGINT REFERENCES nhan_vien(id),
 ma_hoa_don VARCHAR(50) NOT NULL UNIQUE,
 ngay_lap TIMESTAMPTZ NOT NULL DEFAULT now(),
 kenh_ban VARCHAR(12) NOT NULL CHECK(kenh_ban IN ('ONLINE','TAI_QUAY')),
 tong_thanh_toan NUMERIC(18,2) NOT NULL CHECK(tong_thanh_toan >= 0),
 phi_van_chuyen NUMERIC(18,2) NOT NULL DEFAULT 0,
 giam_gia NUMERIC(18,2) NOT NULL DEFAULT 0,
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'ISSUED' CHECK(trang_thai IN ('ISSUED','PAID','CANCELLED'))
);
CREATE TABLE chi_tiet_hoa_don (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 hoa_don_id BIGINT NOT NULL REFERENCES hoa_don(id),
 chi_tiet_don_hang_id BIGINT NOT NULL REFERENCES chi_tiet_don_hang(id),
 ten_san_pham VARCHAR(255) NOT NULL, ten_quy_cach VARCHAR(60) NOT NULL,
 so_luong INT NOT NULL CHECK(so_luong > 0), don_gia NUMERIC(18,2) NOT NULL CHECK(don_gia >= 0),
 thanh_tien NUMERIC(18,2) GENERATED ALWAYS AS (so_luong*don_gia) STORED,
 UNIQUE(hoa_don_id,chi_tiet_don_hang_id)
);
CREATE TABLE lich_su_hoa_don (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 hoa_don_id BIGINT NOT NULL REFERENCES hoa_don(id),
 tai_khoan_thuc_hien_id BIGINT REFERENCES tai_khoan(id),
 trang_thai_cu VARCHAR(20), trang_thai_moi VARCHAR(20) NOT NULL,
 ly_do TEXT NOT NULL, thoi_gian TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== D. KHUYEN MAI =====
CREATE TABLE khuyen_mai (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ma_code VARCHAR(60) UNIQUE, ten VARCHAR(150) NOT NULL, mo_ta TEXT,
 loai_giam VARCHAR(15) NOT NULL CHECK(loai_giam IN ('PERCENT','FIXED')),
 gia_tri_giam NUMERIC(18,2) NOT NULL CHECK(gia_tri_giam >= 0),
 giam_toi_da NUMERIC(18,2) CHECK(giam_toi_da >= 0),
 don_toi_thieu NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK(don_toi_thieu >= 0),
 bat_dau TIMESTAMPTZ NOT NULL, ket_thuc TIMESTAMPTZ NOT NULL,
 gioi_han_su_dung INT CHECK(gioi_han_su_dung >= 0),
 gioi_han_moi_khach INT CHECK(gioi_han_moi_khach >= 0),
 pham_vi_ap_dung VARCHAR(20) NOT NULL DEFAULT 'ALL' CHECK(pham_vi_ap_dung IN ('ALL','PRODUCT','CATEGORY','BRAND')),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK(trang_thai IN ('ACTIVE','INACTIVE')),
 CHECK(ket_thuc > bat_dau), CHECK(loai_giam <> 'PERCENT' OR gia_tri_giam <= 100)
);
CREATE TABLE pham_vi_khuyen_mai (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khuyen_mai_id BIGINT NOT NULL REFERENCES khuyen_mai(id) ON DELETE CASCADE,
 san_pham_id BIGINT REFERENCES san_pham(id),
 loai_san_pham_id BIGINT REFERENCES loai_san_pham(id),
 thuong_hieu_id BIGINT REFERENCES thuong_hieu(id),
 CHECK(num_nonnulls(san_pham_id,loai_san_pham_id,thuong_hieu_id)=1)
);
CREATE UNIQUE INDEX uq_km_sp ON pham_vi_khuyen_mai(khuyen_mai_id,san_pham_id) WHERE san_pham_id IS NOT NULL;
CREATE UNIQUE INDEX uq_km_loai ON pham_vi_khuyen_mai(khuyen_mai_id,loai_san_pham_id) WHERE loai_san_pham_id IS NOT NULL;
CREATE UNIQUE INDEX uq_km_th ON pham_vi_khuyen_mai(khuyen_mai_id,thuong_hieu_id) WHERE thuong_hieu_id IS NOT NULL;
CREATE TABLE uu_dai_so_luong (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khuyen_mai_id BIGINT NOT NULL REFERENCES khuyen_mai(id) ON DELETE CASCADE,
 quy_cach_id BIGINT REFERENCES quy_cach_san_pham(id),
 so_luong_mua INT NOT NULL CHECK(so_luong_mua > 0),
 so_luong_tang INT NOT NULL DEFAULT 0 CHECK(so_luong_tang >= 0),
 ghi_chu_combo TEXT
);
CREATE TABLE su_dung_khuyen_mai (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 khuyen_mai_id BIGINT NOT NULL REFERENCES khuyen_mai(id),
 khach_hang_id BIGINT REFERENCES khach_hang(id),
 don_hang_id BIGINT NOT NULL REFERENCES don_hang(id),
 so_tien_giam NUMERIC(18,2) NOT NULL CHECK(so_tien_giam >= 0),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'APPLIED' CHECK(trang_thai IN ('APPLIED','REVERSED')),
 ngay_su_dung TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(khuyen_mai_id,don_hang_id)
);

-- ===== E. NHA CUNG CAP, DON NCC, LAN NHAP, CONG NO =====
CREATE TABLE nha_cung_cap (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ten VARCHAR(255) NOT NULL, ma_so_thue VARCHAR(30) UNIQUE,
 nguoi_lien_he VARCHAR(150), dien_thoai VARCHAR(25), email VARCHAR(255), dia_chi TEXT,
 trang_thai VARCHAR(25) NOT NULL DEFAULT 'HOP_TAC' CHECK(trang_thai IN ('HOP_TAC','NGUNG_HOP_TAC')),
 ngay_tao TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE nha_cung_cap_san_pham (
 nha_cung_cap_id BIGINT NOT NULL REFERENCES nha_cung_cap(id),
 san_pham_id BIGINT NOT NULL REFERENCES san_pham(id),
 gia_nhap_tham_khao NUMERIC(18,2) CHECK(gia_nhap_tham_khao >= 0),
 PRIMARY KEY(nha_cung_cap_id,san_pham_id)
);
CREATE TABLE giay_to_ncc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 nha_cung_cap_id BIGINT NOT NULL REFERENCES nha_cung_cap(id),
 loai_giay VARCHAR(100) NOT NULL, so_giay VARCHAR(120) NOT NULL,
 ngay_cap DATE, ngay_het_han DATE, tep_dinh_kem TEXT,
 CHECK(ngay_het_han IS NULL OR ngay_cap IS NULL OR ngay_het_han >= ngay_cap)
);
CREATE TABLE don_dat_hang_ncc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ma_don_nhap VARCHAR(50) NOT NULL UNIQUE,
 nha_cung_cap_id BIGINT NOT NULL REFERENCES nha_cung_cap(id),
 nguoi_lap_id BIGINT NOT NULL REFERENCES nhan_vien(id),
 nguoi_duyet_id BIGINT REFERENCES nhan_vien(id),
 ngay_dat TIMESTAMPTZ NOT NULL DEFAULT now(), ngay_giao_du_kien DATE,
 trang_thai VARCHAR(30) NOT NULL DEFAULT 'CHO_DUYET' CHECK(trang_thai IN ('CHO_DUYET','DA_DUYET','TU_CHOI','DANG_GIAO','DA_NHAN_MOT_PHAN','DA_NHAN_DU','DA_HUY')),
 ly_do_tu_choi TEXT, ghi_chu TEXT, ngay_duyet TIMESTAMPTZ
);
CREATE TABLE chi_tiet_don_ncc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_ncc_id BIGINT NOT NULL REFERENCES don_dat_hang_ncc(id),
 quy_cach_id BIGINT NOT NULL REFERENCES quy_cach_san_pham(id),
 so_luong_dat INT NOT NULL CHECK(so_luong_dat > 0),
 he_so_quy_doi INT NOT NULL CHECK(he_so_quy_doi > 0),
 gia_nhap_du_kien NUMERIC(18,2) NOT NULL CHECK(gia_nhap_du_kien >= 0),
 UNIQUE(don_ncc_id,quy_cach_id), UNIQUE(id,don_ncc_id)
);
CREATE TABLE lan_nhap_hang (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 don_ncc_id BIGINT NOT NULL REFERENCES don_dat_hang_ncc(id),
 nguoi_nhan_id BIGINT NOT NULL REFERENCES nhan_vien(id),
 ngay_nhap TIMESTAMPTZ NOT NULL DEFAULT now(),
 trang_thai VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK(trang_thai IN ('DRAFT','CONFIRMED','CANCELLED')),
 ngay_xac_nhan TIMESTAMPTZ, ghi_chu TEXT,
 UNIQUE(id,don_ncc_id)
);
CREATE TABLE chi_tiet_lan_nhap (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 lan_nhap_id BIGINT NOT NULL,
 don_ncc_id BIGINT NOT NULL,
 ct_don_ncc_id BIGINT NOT NULL,
 so_luong_thuc_nhan INT NOT NULL CHECK(so_luong_thuc_nhan >= 0),
 so_luong_loai INT NOT NULL DEFAULT 0 CHECK(so_luong_loai >= 0),
 chenh_lech INT NOT NULL DEFAULT 0,
 gia_nhap_thuc_te NUMERIC(18,2) NOT NULL CHECK(gia_nhap_thuc_te >= 0),
 FOREIGN KEY(lan_nhap_id,don_ncc_id) REFERENCES lan_nhap_hang(id,don_ncc_id),
 FOREIGN KEY(ct_don_ncc_id,don_ncc_id) REFERENCES chi_tiet_don_ncc(id,don_ncc_id),
 UNIQUE(lan_nhap_id,ct_don_ncc_id)
);
CREATE TABLE cong_no_ncc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 lan_nhap_id BIGINT NOT NULL UNIQUE REFERENCES lan_nhap_hang(id),
 so_tien_phai_tra NUMERIC(18,2) NOT NULL CHECK(so_tien_phai_tra >= 0),
 so_tien_con_no NUMERIC(18,2) NOT NULL CHECK(so_tien_con_no >= 0),
 han_thanh_toan DATE, trang_thai VARCHAR(20) NOT NULL DEFAULT 'CHUA_TRA' CHECK(trang_thai IN ('CHUA_TRA','TRA_MOT_PHAN','DA_TRA')),
 CHECK(so_tien_con_no <= so_tien_phai_tra)
);
CREATE TABLE thanh_toan_ncc (
 id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 cong_no_id BIGINT NOT NULL REFERENCES cong_no_ncc(id),
 so_tien NUMERIC(18,2) NOT NULL CHECK(so_tien > 0),
 phuong_thuc VARCHAR(30) NOT NULL, ma_tham_chieu VARCHAR(120) UNIQUE,
 ngay_thanh_toan TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ===== TRIGGERS: TAO DONG SO LUONG/ LICH SU TRONG TRANSACTION =====
-- Trigger la co che toan ven; phan quyen can duoc kiem tra tai service backend.
CREATE OR REPLACE FUNCTION fn_so_luong_bien_dong() RETURNS TRIGGER LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_so_luong_bien_dong BEFORE INSERT ON bien_dong_so_luong
 FOR EACH ROW EXECUTE FUNCTION fn_so_luong_bien_dong();
CREATE OR REPLACE FUNCTION fn_chong_sua_bien_dong() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Nhat ky bien dong so luong chi duoc ghi them'; END $$;
CREATE TRIGGER trg_chong_sua_bien_dong BEFORE UPDATE OR DELETE ON bien_dong_so_luong
 FOR EACH ROW EXECUTE FUNCTION fn_chong_sua_bien_dong();

-- Dieu chinh so luong phai dua vao so luong thuc te, co ly do va nguoi thuc hien.
CREATE OR REPLACE FUNCTION fn_dieu_chinh_so_luong() RETURNS TRIGGER LANGUAGE plpgsql AS $$
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
-- identity default is available in BEFORE INSERT for generated-always identity
CREATE TRIGGER trg_dieu_chinh_so_luong BEFORE INSERT ON dieu_chinh_so_luong
 FOR EACH ROW EXECUTE FUNCTION fn_dieu_chinh_so_luong();

CREATE OR REPLACE FUNCTION fn_order_inventory() RETURNS TRIGGER LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_order_inventory BEFORE INSERT OR UPDATE OF trang_thai ON don_hang
 FOR EACH ROW EXECUTE FUNCTION fn_order_inventory();

CREATE OR REPLACE FUNCTION fn_order_history() RETURNS TRIGGER LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_order_history AFTER UPDATE OF trang_thai ON don_hang
 FOR EACH ROW EXECUTE FUNCTION fn_order_history();

CREATE OR REPLACE FUNCTION fn_invoice_history() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.trang_thai IS DISTINCT FROM OLD.trang_thai THEN
   INSERT INTO lich_su_hoa_don(hoa_don_id,trang_thai_cu,trang_thai_moi,ly_do)
   VALUES(NEW.id,OLD.trang_thai,NEW.trang_thai,'Cap nhat trang thai theo nghiep vu don hang');
 END IF;
 RETURN NULL;
END $$;
CREATE TRIGGER trg_invoice_history AFTER UPDATE OF trang_thai ON hoa_don
 FOR EACH ROW EXECUTE FUNCTION fn_invoice_history();
CREATE OR REPLACE FUNCTION fn_hoa_don_immutable() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Khong duoc xoa hoa don noi bo'; END IF;
 IF ROW(NEW.don_hang_id,NEW.nguoi_lap_id,NEW.ma_hoa_don,NEW.ngay_lap,NEW.kenh_ban,NEW.tong_thanh_toan,NEW.phi_van_chuyen,NEW.giam_gia)
    IS DISTINCT FROM ROW(OLD.don_hang_id,OLD.nguoi_lap_id,OLD.ma_hoa_don,OLD.ngay_lap,OLD.kenh_ban,OLD.tong_thanh_toan,OLD.phi_van_chuyen,OLD.giam_gia) THEN
   RAISE EXCEPTION 'Khong duoc sua noi dung hoa don';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_hoa_don_immutable BEFORE UPDATE OR DELETE ON hoa_don
 FOR EACH ROW EXECUTE FUNCTION fn_hoa_don_immutable();
CREATE OR REPLACE FUNCTION fn_chi_tiet_hoa_don_immutable() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'Chi tiet hoa don bat bien'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_chi_tiet_hoa_don_immutable BEFORE UPDATE OR DELETE ON chi_tiet_hoa_don
 FOR EACH ROW EXECUTE FUNCTION fn_chi_tiet_hoa_don_immutable();

-- Tao 1 hoa don noi bo tu don hang da du dieu kien. Idempotent.
CREATE OR REPLACE FUNCTION lap_hoa_don_tu_don(p_don_hang_id BIGINT,p_nhan_vien_id BIGINT DEFAULT NULL)
 RETURNS BIGINT LANGUAGE plpgsql AS $$
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

-- Nhan hang theo don NCC da duyet, nhieu dot; khoa don va tinh tong theo TUNG dong don.
CREATE OR REPLACE FUNCTION fn_receive_inventory() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE rec RECORD; order_state TEXT; accumulated BIGINT; order_complete BOOLEAN;
BEGIN
 IF OLD.trang_thai='CONFIRMED' AND NEW.trang_thai<>'CONFIRMED' THEN
   RAISE EXCEPTION 'Khong duoc huy xac nhan nhap';
 END IF;
 IF NEW.trang_thai <> 'CONFIRMED' OR OLD.trang_thai='CONFIRMED' THEN RETURN NEW; END IF;
 SELECT trang_thai INTO order_state FROM don_dat_hang_ncc WHERE id=NEW.don_ncc_id FOR UPDATE;
 IF order_state NOT IN ('DA_DUYET','DANG_GIAO','DA_NHAN_MOT_PHAN') THEN
  RAISE EXCEPTION 'Don NCC chua duoc duyet hoac da ket thuc';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM chi_tiet_lan_nhap WHERE lan_nhap_id=NEW.id AND so_luong_thuc_nhan>0) THEN
  RAISE EXCEPTION 'Lan nhap phai co it nhat mot san pham du dieu kien nhap';
 END IF;
 FOR rec IN
   SELECT ct.id,ct.ct_don_ncc_id,ct.so_luong_thuc_nhan,ct.gia_nhap_thuc_te,
          d.so_luong_dat,d.he_so_quy_doi,q.san_pham_id
   FROM chi_tiet_lan_nhap ct JOIN chi_tiet_don_ncc d ON d.id=ct.ct_don_ncc_id
   JOIN quy_cach_san_pham q ON q.id=d.quy_cach_id
   WHERE ct.lan_nhap_id=NEW.id ORDER BY q.san_pham_id,d.id LOOP
   SELECT COALESCE(sum(c.so_luong_thuc_nhan),0) INTO accumulated
   FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
   WHERE c.ct_don_ncc_id=rec.ct_don_ncc_id AND (l.trang_thai='CONFIRMED' OR l.id=NEW.id);
   IF accumulated > rec.so_luong_dat THEN
    RAISE EXCEPTION 'Nhan vuot so luong dat cho chi tiet %', rec.ct_don_ncc_id;
   END IF;
   IF rec.so_luong_thuc_nhan > 0 THEN
     INSERT INTO bien_dong_so_luong(san_pham_id,loai,nguon_id,so_luong_thay_doi,so_luong_truoc,so_luong_sau)
     VALUES(rec.san_pham_id,'NHAP_HANG',rec.id,rec.so_luong_thuc_nhan::bigint*rec.he_so_quy_doi,0,0);
   END IF;
 END LOOP;
 NEW.ngay_xac_nhan:=now();
 RETURN NEW;
END $$;
CREATE TRIGGER trg_receive_inventory BEFORE UPDATE OF trang_thai ON lan_nhap_hang
 FOR EACH ROW EXECUTE FUNCTION fn_receive_inventory();

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
 INSERT INTO cong_no_ncc(lan_nhap_id,so_tien_phai_tra,so_tien_con_no)
 VALUES(NEW.id,total_due,total_due);
 RETURN NULL;
END $$;
CREATE TRIGGER trg_receive_finalize AFTER UPDATE OF trang_thai ON lan_nhap_hang
 FOR EACH ROW EXECUTE FUNCTION fn_receive_finalize();

CREATE OR REPLACE FUNCTION fn_supplier_payment() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
 UPDATE cong_no_ncc SET so_tien_con_no=so_tien_con_no-NEW.so_tien,
 trang_thai=CASE WHEN so_tien_con_no-NEW.so_tien=0 THEN 'DA_TRA' ELSE 'TRA_MOT_PHAN' END
 WHERE id=NEW.cong_no_id AND so_tien_con_no>=NEW.so_tien;
 IF NOT FOUND THEN RAISE EXCEPTION 'Thanh toan vuot cong no'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_supplier_payment AFTER INSERT ON thanh_toan_ncc
 FOR EACH ROW EXECUTE FUNCTION fn_supplier_payment();

CREATE OR REPLACE FUNCTION fn_immutable_posted() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Chung tu da ghi so khong duoc sua/xoa'; END $$;
CREATE TRIGGER trg_paid_ncc_immutable BEFORE UPDATE OR DELETE ON thanh_toan_ncc
 FOR EACH ROW EXECUTE FUNCTION fn_immutable_posted();
CREATE OR REPLACE FUNCTION fn_protect_received_lines() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE status_now TEXT;
BEGIN
 SELECT trang_thai INTO status_now FROM lan_nhap_hang
 WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.lan_nhap_id ELSE NEW.lan_nhap_id END;
 IF status_now='CONFIRMED' THEN RAISE EXCEPTION 'Khong duoc sua chi tiet lan nhap da xac nhan'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
CREATE TRIGGER trg_protect_received_lines BEFORE INSERT OR UPDATE OR DELETE ON chi_tiet_lan_nhap
 FOR EACH ROW EXECUTE FUNCTION fn_protect_received_lines();
CREATE OR REPLACE FUNCTION fn_protect_order_lines() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE o don_hang%ROWTYPE;
BEGIN
 SELECT * INTO o FROM don_hang WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.don_hang_id ELSE NEW.don_hang_id END;
 IF (o.kenh_ban='TAI_QUAY' AND current_setting('beverage.pos_order_id',true) IS DISTINCT FROM o.id::text)
    OR (o.kenh_ban<>'TAI_QUAY' AND o.trang_thai <> 'CHO_XAC_NHAN') THEN
   RAISE EXCEPTION 'Khong duoc sua chi tiet don da xac nhan hoac tai quay';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $$;
-- Danh cho don online; don tai quay phai tao qua function POS ben duoi.
CREATE TRIGGER trg_protect_order_lines BEFORE INSERT OR UPDATE OR DELETE ON chi_tiet_don_hang
 FOR EACH ROW EXECUTE FUNCTION fn_protect_order_lines();

-- POS: khong cho ghi truc tiep don tai quay ma bo qua quy trinh; function nay duoc goi trong 1 transaction.
-- CHI GOI SAU KHI DA XAC NHAN THU TIEN MAT HOAC DOI SOAT QR THANH CONG.
-- Khong tu dong tin rang chuyen khoan da thanh cong chi vi client bao thanh cong.
-- p_items = [{"quy_cach_id":1,"so_luong":2}, ...]; gia lay lai tu DB.
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

-- UC10: VIEW theo thuc te giao dich; phan quyen doc VIEW tai backend.
CREATE VIEW v_ton_san_pham AS
 SELECT s.id AS san_pham_id,s.sku,s.ten,k.so_luong_co_ban,k.nguong_canh_bao,
        (k.so_luong_co_ban<=k.nguong_canh_bao) AS canh_bao
 FROM san_pham s JOIN so_luong_san_pham k ON k.san_pham_id=s.id;
CREATE VIEW v_ton_theo_quy_cach AS
 SELECT q.san_pham_id,q.id AS quy_cach_id,q.ten_quy_cach,q.he_so_quy_doi,
        k.so_luong_co_ban,(k.so_luong_co_ban/q.he_so_quy_doi)::bigint AS so_luong_co_the_ban
 FROM quy_cach_san_pham q JOIN so_luong_san_pham k ON k.san_pham_id=q.san_pham_id;
CREATE VIEW v_doanh_thu_ngay AS
 SELECT (t.thoi_gian AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS ngay,
        count(DISTINCT t.don_hang_id) AS so_don,sum(t.so_tien) AS tong_da_thu
 FROM thanh_toan t WHERE t.trang_thai='SUCCESS' GROUP BY 1;
CREATE VIEW v_nhap_hang_da_xac_nhan AS
 SELECT d.don_ncc_id,o.nha_cung_cap_id,q.san_pham_id,
        sum(c.so_luong_thuc_nhan::bigint*d.he_so_quy_doi) AS so_luong_co_ban_nhap,
        sum(c.so_luong_thuc_nhan*c.gia_nhap_thuc_te) AS gia_tri_nhap
 FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
 JOIN chi_tiet_don_ncc d ON d.id=c.ct_don_ncc_id
 JOIN don_dat_hang_ncc o ON o.id=d.don_ncc_id
 JOIN quy_cach_san_pham q ON q.id=d.quy_cach_id
 WHERE l.trang_thai='CONFIRMED' GROUP BY d.don_ncc_id,o.nha_cung_cap_id,q.san_pham_id;

-- ===== DU LIEU MAU AN TOAN: VAI TRO VA QUYEN =====
INSERT INTO vai_tro(ma_vai_tro,ten_vai_tro,mo_ta) VALUES
 ('KHACH_HANG','Khách hàng','Mua hàng qua Website'),
 ('NHAN_VIEN','Nhân viên','Bán tại quầy, xử lý đơn và nhập hàng theo đơn NCC đã duyệt'),
 ('QUAN_TRI_VIEN','Quản trị viên','Có tất cả quyền nhân viên và nghiệp vụ quản trị');
INSERT INTO quyen(ma_quyen,ten_quyen,ma_chuc_nang,hanh_dong) VALUES
 ('PRODUCT_READ','Tra cứu sản phẩm','BR1','READ'),
 ('PRODUCT_MANAGE','Quản lý danh mục sản phẩm','BR1','MANAGE'),
 ('PRODUCT_ADJUST','Điều chỉnh số lượng','BR1','ADJUST'),
 ('CATEGORY_READ','Tra cứu loại / thương hiệu','BR2','READ'),
 ('CATEGORY_MANAGE','Quản lý loại / thương hiệu','BR2','MANAGE'),
 ('CART_MANAGE','Giỏ hàng cá nhân','BR3','MANAGE'),
 ('PAYMENT_READ','Đối soát thanh toán','BR4','READ'),
 ('POS_PAYMENT','Thu tiền tại quầy','BR4','POS'),
 ('REFUND_MANAGE','Hoàn tiền','BR4','REFUND'),
 ('ORDER_READ','Tra cứu đơn','BR5','READ'),
 ('ORDER_UPDATE','Xử lý đơn online','BR5','UPDATE'),
 ('POS_SELL','Bán hàng tại quầy','BR5','POS'),
 ('INVOICE_READ','Tra cứu và in hóa đơn','BR6','READ'),
 ('INVOICE_REPORT','Thống kê hóa đơn','BR6','REPORT'),
 ('CUSTOMER_READ','Tra cứu khách hàng','BR7','READ'),
 ('CUSTOMER_SUPPORT','Chăm sóc khách hàng','BR7','SUPPORT'),
 ('CUSTOMER_LOCK','Khóa tài khoản khách hàng','BR7','LOCK'),
 ('STAFF_SELF','Hồ sơ cá nhân nhân viên','BR8','SELF'),
 ('STAFF_MANAGE','Quản lý nhân viên','BR8','MANAGE'),
 ('ROLE_MANAGE','Phân quyền','BR9','MANAGE'),
 ('REPORT_STOCK','Tra cứu tồn và lịch sử nhập','BR10','STOCK'),
 ('REPORT_ALL','Báo cáo quản trị','BR10','ALL'),
 ('PROMOTION_MANAGE','Quản lý khuyến mãi','BR11','MANAGE'),
 ('SUPPLIER_READ','Tra cứu nhà cung cấp','BR12','READ'),
 ('SUPPLIER_MANAGE','Quản lý nhà cung cấp','BR12','MANAGE'),
 ('IMPORT_CREATE','Lập đơn NCC','BR13','CREATE'),
 ('IMPORT_APPROVE','Duyệt đơn NCC','BR13','APPROVE'),
 ('IMPORT_RECEIVE','Xác nhận nhập','BR13','RECEIVE'),
 ('IMPORT_READ','Tra cứu đơn NCC và nhập','BR13','READ'),
 ('IMPORT_REPORT','Thống kê nhập hàng','BR13','REPORT');
-- Nhan vien khong co IMPORT_CREATE/APPROVE; QUAN_TRI_VIEN ke thua tat ca quyen nhan vien.
INSERT INTO vai_tro_quyen(vai_tro_id,quyen_id)
SELECT v.id,q.id FROM vai_tro v JOIN quyen q ON (
 (v.ma_vai_tro='NHAN_VIEN' AND q.ma_quyen IN (
   'PRODUCT_READ','CATEGORY_READ','PAYMENT_READ','POS_PAYMENT','ORDER_READ','ORDER_UPDATE',
   'POS_SELL','INVOICE_READ','CUSTOMER_READ','CUSTOMER_SUPPORT','STAFF_SELF','REPORT_STOCK',
   'SUPPLIER_READ','IMPORT_RECEIVE','IMPORT_READ'))
 OR (v.ma_vai_tro='QUAN_TRI_VIEN' AND q.ma_quyen NOT IN ('CART_MANAGE'))
 OR (v.ma_vai_tro='KHACH_HANG' AND q.ma_quyen IN ('PRODUCT_READ','CATEGORY_READ','CART_MANAGE'))
);

INSERT INTO loai_san_pham(ten,mo_ta) VALUES ('Nước ngọt có ga','Nước giải khát có ga'),('Nước suối','Nước tinh khiết'),('Trà đóng chai','Trà pha sẵn');
INSERT INTO thuong_hieu(ten) VALUES ('Thương hiệu A'),('Thương hiệu B');
INSERT INTO san_pham(loai_san_pham_id,thuong_hieu_id,sku,ten,dung_tich,loai_bao_bi)
VALUES (1,1,'SP001','Nước ngọt vị cam 330ml','330ml','LON'),(2,2,'SP002','Nước suối 500ml','500ml','CHAI');
INSERT INTO so_luong_san_pham(san_pham_id) SELECT id FROM san_pham ON CONFLICT DO NOTHING;
INSERT INTO quy_cach_san_pham(san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban,gia_von)
VALUES (1,'Lon lẻ','LON',1,12000,8000),(1,'Lốc 6 lon','LOC',6,69000,48000),
       (1,'Thùng 24 lon','THUNG',24,270000,192000),
       (2,'Chai lẻ','CHAI',1,7000,4500),(2,'Thùng 24 chai','THUNG',24,160000,108000);
COMMIT;

-- KIEM TRA SAU KHI CHAY:
-- SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';
-- SELECT * FROM v_ton_theo_quy_cach;
-- SELECT v.ma_vai_tro,q.ma_quyen FROM vai_tro_quyen vq
-- JOIN vai_tro v ON v.id=vq.vai_tro_id JOIN quyen q ON q.id=vq.quyen_id
-- WHERE q.ma_quyen IN ('IMPORT_CREATE','IMPORT_RECEIVE','IMPORT_APPROVE') ORDER BY 1,2;

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

ALTER TABLE public.nha_cung_cap
  ADD COLUMN IF NOT EXISTS loai_nha_cung_cap varchar(30) NOT NULL DEFAULT 'DOANH_NGHIEP' CHECK (loai_nha_cung_cap IN ('DOANH_NGHIEP','HO_KINH_DOANH','CA_NHAN')),
  ADD COLUMN IF NOT EXISTS trang_thai_xac_minh varchar(30) NOT NULL DEFAULT 'CHUA_XAC_MINH' CHECK (trang_thai_xac_minh IN ('CHUA_XAC_MINH','DA_XAC_MINH','CAN_KIEM_TRA_LAI')),
  ADD COLUMN IF NOT EXISTS ghi_chu_xac_minh varchar(2000),
  ADD COLUMN IF NOT EXISTS nguoi_xac_minh_id bigint REFERENCES public.tai_khoan(id),
  ADD COLUMN IF NOT EXISTS thoi_diem_xac_minh timestamptz;


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

BEGIN;
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
   SELECT COALESCE(sum(c.so_luong_thuc_nhan::bigint+c.so_luong_loai),0) INTO accumulated
   FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang l ON l.id=c.lan_nhap_id
   WHERE c.ct_don_ncc_id=rec.ct_don_ncc_id AND (l.trang_thai='CONFIRMED' OR l.id=NEW.id);
   IF accumulated > rec.so_luong_dat THEN
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
-- Complete historical orders whose confirmed accepted + rejected quantities settle every line.
-- Stock, receipt amounts, debt and draft receipts are not rewritten.
UPDATE don_dat_hang_ncc p SET trang_thai='DA_NHAN_DU'
WHERE p.trang_thai IN ('DA_NHAN_MOT_PHAN','DA_DUYET','DANG_GIAO')
  AND EXISTS(SELECT 1 FROM chi_tiet_don_ncc d WHERE d.don_ncc_id=p.id)
  AND NOT EXISTS (
    SELECT 1 FROM chi_tiet_don_ncc d WHERE d.don_ncc_id=p.id AND d.so_luong_dat>(
      SELECT coalesce(sum(c.so_luong_thuc_nhan::bigint+c.so_luong_loai),0)
      FROM chi_tiet_lan_nhap c JOIN lan_nhap_hang r ON r.id=c.lan_nhap_id
      WHERE c.ct_don_ncc_id=d.id AND r.trang_thai='CONFIRMED'
    )
  );
INSERT INTO backend_schema_migration(version) VALUES ('20261104_receiving_disposition') ON CONFLICT DO NOTHING;

-- Retire post-stock supplier returns; receiving rejections stay in receipt lines.
DO $$ BEGIN
 IF to_regclass('public.phieu_tra_ncc') IS NOT NULL THEN
  IF EXISTS (SELECT 1 FROM phieu_tra_ncc WHERE trang_thai='DRAFT' OR so_tien_cho_hoan>so_tien_da_hoan) THEN
   RAISE EXCEPTION 'Cannot retire warehouse returns with unresolved quarantine or refunds';
  END IF;
 END IF;
END $$;
DROP TABLE IF EXISTS hoan_tien_tra_ncc,chi_tiet_tra_ncc,phieu_tra_ncc;
DROP FUNCTION IF EXISTS fn_protect_supplier_return_lines();
INSERT INTO backend_schema_migration(version) VALUES ('20261104_remove_warehouse_returns') ON CONFLICT DO NOTHING;

COMMIT;

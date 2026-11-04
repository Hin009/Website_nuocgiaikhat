package vn.drinkstore.management;

import jakarta.annotation.PostConstruct;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Additive upgrade for existing Docker volumes; the consolidated SQL includes the same columns. */
@Component
public class SupplierSchema {
    public static final String DDL = """
        ALTER TABLE public.nha_cung_cap
          ADD COLUMN IF NOT EXISTS loai_nha_cung_cap varchar(30) NOT NULL DEFAULT 'DOANH_NGHIEP' CHECK (loai_nha_cung_cap IN ('DOANH_NGHIEP','HO_KINH_DOANH','CA_NHAN')),
          ADD COLUMN IF NOT EXISTS trang_thai_xac_minh varchar(30) NOT NULL DEFAULT 'CHUA_XAC_MINH' CHECK (trang_thai_xac_minh IN ('CHUA_XAC_MINH','DA_XAC_MINH','CAN_KIEM_TRA_LAI')),
          ADD COLUMN IF NOT EXISTS ghi_chu_xac_minh varchar(2000),
          ADD COLUMN IF NOT EXISTS nguoi_xac_minh_id bigint REFERENCES public.tai_khoan(id),
          ADD COLUMN IF NOT EXISTS thoi_diem_xac_minh timestamptz;
        """;
    private final JdbcTemplate jdbc;
    public SupplierSchema(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    @PostConstruct public void upgrade() { jdbc.execute(DDL); }
}

package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for lan_nhap_hang; relationships use foreign key IDs. */
public record LanNhapHang(
    Long id,
    Long donNccId,
    Long nguoiNhanId,
    OffsetDateTime ngayNhap,
    String trangThai,
    OffsetDateTime ngayXacNhan,
    String ghiChu
) {}

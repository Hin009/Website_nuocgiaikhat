package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for nha_cung_cap; relationships use foreign key IDs. */
public record NhaCungCap(
    Long id,
    String ten,
    String maSoThue,
    String nguoiLienHe,
    String dienThoai,
    String email,
    String diaChi,
    String trangThai,
    OffsetDateTime ngayTao
) {}

package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for chi_tiet_gio_hang; relationships use foreign key IDs. */
public record ChiTietGioHang(
    Long id,
    Long gioHangId,
    Long quyCachId,
    Integer soLuong,
    BigDecimal giaTamTinh
) {}

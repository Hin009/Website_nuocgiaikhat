package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for chi_tiet_don_hang; relationships use foreign key IDs. */
public record ChiTietDonHang(
    Long id,
    Long donHangId,
    Long quyCachId,
    String tenSanPham,
    String tenQuyCach,
    Integer soLuong,
    Integer heSoQuyDoi,
    BigDecimal donGia,
    BigDecimal giaVonDonVi,
    BigDecimal thanhTien
) {}

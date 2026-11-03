package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for chi_tiet_hoa_don; relationships use foreign key IDs. */
public record ChiTietHoaDon(
    Long id,
    Long hoaDonId,
    Long chiTietDonHangId,
    String tenSanPham,
    String tenQuyCach,
    Integer soLuong,
    BigDecimal donGia,
    BigDecimal thanhTien
) {}

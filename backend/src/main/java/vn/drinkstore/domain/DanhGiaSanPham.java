package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for danh_gia_san_pham; relationships use foreign key IDs. */
public record DanhGiaSanPham(
    Long id,
    Long khachHangId,
    Long chiTietDonHangId,
    Integer soSao,
    String noiDung,
    String trangThai,
    OffsetDateTime ngayDanhGia
) {}

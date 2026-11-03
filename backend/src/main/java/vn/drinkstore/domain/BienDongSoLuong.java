package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for bien_dong_so_luong; relationships use foreign key IDs. */
public record BienDongSoLuong(
    Long id,
    Long sanPhamId,
    String loai,
    Long nguonId,
    Long soLuongThayDoi,
    Long soLuongTruoc,
    Long soLuongSau,
    OffsetDateTime thoiDiem
) {}

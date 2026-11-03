package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for nhat_ky_hoat_dong; relationships use foreign key IDs. */
public record NhatKyHoatDong(
    Long id,
    Long taiKhoanId,
    String hanhDong,
    String doiTuong,
    Long doiTuongId,
    String duLieuThayDoi,
    OffsetDateTime thoiDiem
) {}

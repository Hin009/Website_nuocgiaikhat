package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for lien_he_khach_hang; relationships use foreign key IDs. */
public record LienHeKhachHang(
    Long id,
    Long khachHangId,
    String hoTen,
    String email,
    String dienThoai,
    String noiDung,
    String phanHoi,
    Long nhanVienPhanHoiId,
    String trangThai,
    OffsetDateTime ngayTao,
    OffsetDateTime ngayPhanHoi
) {}

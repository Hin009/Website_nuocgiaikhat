package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for lich_su_trang_thai_don; relationships use foreign key IDs. */
public record LichSuTrangThaiDon(
    Long id,
    Long donHangId,
    Long taiKhoanThucHienId,
    String trangThaiCu,
    String trangThaiMoi,
    String ghiChu,
    OffsetDateTime thoiGian
) {}

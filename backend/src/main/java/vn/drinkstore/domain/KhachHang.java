package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for khach_hang; relationships use foreign key IDs. */
public record KhachHang(
    Long id,
    Long taiKhoanId,
    String hoTen,
    String dienThoai,
    String anhDaiDien,
    OffsetDateTime ngayTao
) {}

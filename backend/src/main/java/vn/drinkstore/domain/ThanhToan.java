package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for thanh_toan; relationships use foreign key IDs. */
public record ThanhToan(
    Long id,
    Long donHangId,
    String phuongThuc,
    String maGiaoDich,
    String idempotencyKey,
    BigDecimal soTien,
    String trangThai,
    OffsetDateTime thoiGian,
    String thongTinCong
) {}

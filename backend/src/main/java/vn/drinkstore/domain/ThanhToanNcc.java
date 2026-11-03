package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for thanh_toan_ncc; relationships use foreign key IDs. */
public record ThanhToanNcc(
    Long id,
    Long congNoId,
    BigDecimal soTien,
    String phuongThuc,
    String maThamChieu,
    OffsetDateTime ngayThanhToan
) {}

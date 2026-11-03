package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for hoa_don; relationships use foreign key IDs. */
public record HoaDon(
    Long id,
    Long donHangId,
    Long nguoiLapId,
    String maHoaDon,
    OffsetDateTime ngayLap,
    String kenhBan,
    BigDecimal tongThanhToan,
    BigDecimal phiVanChuyen,
    BigDecimal giamGia,
    String trangThai
) {}

package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for hoan_tien; relationships use foreign key IDs. */
public record HoanTien(
    Long id,
    Long thanhToanId,
    Long nguoiXuLyId,
    String lyDo,
    BigDecimal soTien,
    String trangThai,
    OffsetDateTime ngayYeuCau,
    OffsetDateTime ngayHoan
) {}

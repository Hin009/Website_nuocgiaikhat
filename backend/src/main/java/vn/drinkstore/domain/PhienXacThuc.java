package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for phien_xac_thuc; relationships use foreign key IDs. */
public record PhienXacThuc(
    Long id,
    Long taiKhoanId,
    String tokenHash,
    OffsetDateTime hetHan,
    Boolean daThuHoi,
    OffsetDateTime ngayTao
) {}

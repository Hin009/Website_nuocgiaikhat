package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

/** JDBC model for cong_no_ncc; relationships use foreign key IDs. */
public record CongNoNcc(
    Long id,
    Long lanNhapId,
    BigDecimal soTienPhaiTra,
    BigDecimal soTienConNo,
    LocalDate hanThanhToan,
    String trangThai
) {}

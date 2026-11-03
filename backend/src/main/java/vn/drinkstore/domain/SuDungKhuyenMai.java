package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for su_dung_khuyen_mai; relationships use foreign key IDs. */
public record SuDungKhuyenMai(
    Long id,
    Long khuyenMaiId,
    Long khachHangId,
    Long donHangId,
    BigDecimal soTienGiam,
    String trangThai,
    OffsetDateTime ngaySuDung
) {}

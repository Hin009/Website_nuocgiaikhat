package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for khuyen_mai; relationships use foreign key IDs. */
public record KhuyenMai(
    Long id,
    String maCode,
    String ten,
    String moTa,
    String loaiGiam,
    BigDecimal giaTriGiam,
    BigDecimal giamToiDa,
    BigDecimal donToiThieu,
    OffsetDateTime batDau,
    OffsetDateTime ketThuc,
    Integer gioiHanSuDung,
    Integer gioiHanMoiKhach,
    String phamViApDung,
    String trangThai
) {}

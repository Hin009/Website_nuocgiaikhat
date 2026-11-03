package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for tai_khoan; relationships use foreign key IDs. */
public record TaiKhoan(
    Long id,
    String email,
    String matKhauHash,
    String trangThai,
    Boolean emailDaXacThuc,
    Integer soLanDangNhapSai,
    OffsetDateTime khoaDen,
    OffsetDateTime ngayTao,
    OffsetDateTime ngayCapNhat
) {}

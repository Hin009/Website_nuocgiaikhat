package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for gio_hang; relationships use foreign key IDs. */
public record GioHang(
    Long id,
    Long khachHangId,
    OffsetDateTime ngayCapNhat
) {}

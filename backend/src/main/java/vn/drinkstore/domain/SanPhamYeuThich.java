package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for san_pham_yeu_thich; relationships use foreign key IDs. */
public record SanPhamYeuThich(
    Long khachHangId,
    Long sanPhamId,
    OffsetDateTime ngayThem
) {}

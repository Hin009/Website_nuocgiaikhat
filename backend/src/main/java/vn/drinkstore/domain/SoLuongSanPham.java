package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for so_luong_san_pham; relationships use foreign key IDs. */
public record SoLuongSanPham(
    Long sanPhamId,
    Long soLuongCoBan,
    Long nguongCanhBao,
    OffsetDateTime ngayCapNhat
) {}

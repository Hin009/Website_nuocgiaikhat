package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for dieu_chinh_so_luong; relationships use foreign key IDs. */
public record DieuChinhSoLuong(
    Long id,
    Long sanPhamId,
    Long quyCachId,
    Long nguoiDieuChinhId,
    Long soLuongTruoc,
    Long soLuongSau,
    Long chenhLech,
    String lyDo,
    OffsetDateTime thoiDiem
) {}

package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for quy_cach_san_pham; relationships use foreign key IDs. */
public record QuyCachSanPham(
    Long id,
    Long sanPhamId,
    String tenQuyCach,
    String donViTinh,
    Integer heSoQuyDoi,
    BigDecimal giaBan,
    BigDecimal giaVon,
    Boolean dangBan
) {}

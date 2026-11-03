package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for nha_cung_cap_san_pham; relationships use foreign key IDs. */
public record NhaCungCapSanPham(
    Long nhaCungCapId,
    Long sanPhamId,
    BigDecimal giaNhapThamKhao
) {}

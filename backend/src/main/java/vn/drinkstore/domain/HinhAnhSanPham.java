package vn.drinkstore.domain;


/** JDBC model for hinh_anh_san_pham; relationships use foreign key IDs. */
public record HinhAnhSanPham(
    Long id,
    Long sanPhamId,
    String duongDan,
    Boolean anhChinh,
    Integer thuTu
) {}

package vn.drinkstore.domain;


/** JDBC model for pham_vi_khuyen_mai; relationships use foreign key IDs. */
public record PhamViKhuyenMai(
    Long id,
    Long khuyenMaiId,
    Long sanPhamId,
    Long loaiSanPhamId,
    Long thuongHieuId
) {}

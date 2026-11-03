package vn.drinkstore.domain;


/** JDBC model for loai_san_pham; relationships use foreign key IDs. */
public record LoaiSanPham(
    Long id,
    String ten,
    String moTa,
    String hinhAnh,
    Boolean hienThi
) {}

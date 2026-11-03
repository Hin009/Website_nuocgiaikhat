package vn.drinkstore.domain;


/** JDBC model for thuong_hieu; relationships use foreign key IDs. */
public record ThuongHieu(
    Long id,
    String ten,
    String logo,
    String moTa,
    Boolean hienThi
) {}

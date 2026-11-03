package vn.drinkstore.domain;


/** JDBC model for quyen; relationships use foreign key IDs. */
public record Quyen(
    Long id,
    String maQuyen,
    String tenQuyen,
    String maChucNang,
    String hanhDong,
    String moTa
) {}

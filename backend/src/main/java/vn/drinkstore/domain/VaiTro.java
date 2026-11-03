package vn.drinkstore.domain;


/** JDBC model for vai_tro; relationships use foreign key IDs. */
public record VaiTro(
    Long id,
    String maVaiTro,
    String tenVaiTro,
    String moTa
) {}

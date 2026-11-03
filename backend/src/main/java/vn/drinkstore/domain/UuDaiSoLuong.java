package vn.drinkstore.domain;


/** JDBC model for uu_dai_so_luong; relationships use foreign key IDs. */
public record UuDaiSoLuong(
    Long id,
    Long khuyenMaiId,
    Long quyCachId,
    Integer soLuongMua,
    Integer soLuongTang,
    String ghiChuCombo
) {}

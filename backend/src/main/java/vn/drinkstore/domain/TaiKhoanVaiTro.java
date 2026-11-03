package vn.drinkstore.domain;


/** JDBC model for tai_khoan_vai_tro; relationships use foreign key IDs. */
public record TaiKhoanVaiTro(
    Long taiKhoanId,
    Long vaiTroId
) {}

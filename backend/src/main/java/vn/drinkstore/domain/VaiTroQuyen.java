package vn.drinkstore.domain;


/** JDBC model for vai_tro_quyen; relationships use foreign key IDs. */
public record VaiTroQuyen(
    Long vaiTroId,
    Long quyenId
) {}

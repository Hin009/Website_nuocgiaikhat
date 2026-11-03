package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for chi_tiet_don_ncc; relationships use foreign key IDs. */
public record ChiTietDonNcc(
    Long id,
    Long donNccId,
    Long quyCachId,
    Integer soLuongDat,
    Integer heSoQuyDoi,
    BigDecimal giaNhapDuKien
) {}

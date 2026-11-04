package vn.drinkstore.domain;

import java.math.BigDecimal;

/** JDBC model for chi_tiet_lan_nhap; relationships use foreign key IDs. */
public record ChiTietLanNhap(
    Long id,
    Long lanNhapId,
    Long donNccId,
    Long ctDonNccId,
    Integer soLuongThucNhan,
    Integer soLuongLoai,
    String lyDoLoai,
    java.time.LocalDate ngaySanXuat,
    java.time.LocalDate ngayHetHan,
    Integer chenhLech,
    BigDecimal giaNhapThucTe
) {}

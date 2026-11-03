package vn.drinkstore.domain;

import java.time.LocalDate;

/** JDBC model for giay_to_ncc; relationships use foreign key IDs. */
public record GiayToNcc(
    Long id,
    Long nhaCungCapId,
    String loaiGiay,
    String soGiay,
    LocalDate ngayCap,
    LocalDate ngayHetHan,
    String tepDinhKem
) {}

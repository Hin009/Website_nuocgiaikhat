package vn.drinkstore.domain;

import java.time.LocalDate;
import java.time.OffsetDateTime;

/** JDBC model for don_dat_hang_ncc; relationships use foreign key IDs. */
public record DonDatHangNcc(
    Long id,
    String maDonNhap,
    Long nhaCungCapId,
    Long nguoiLapId,
    Long nguoiDuyetId,
    OffsetDateTime ngayDat,
    LocalDate ngayGiaoDuKien,
    String trangThai,
    String lyDoTuChoi,
    String ghiChu,
    OffsetDateTime ngayDuyet
) {}

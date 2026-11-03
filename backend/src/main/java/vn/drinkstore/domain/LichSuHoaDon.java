package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for lich_su_hoa_don; relationships use foreign key IDs. */
public record LichSuHoaDon(
    Long id,
    Long hoaDonId,
    Long taiKhoanThucHienId,
    String trangThaiCu,
    String trangThaiMoi,
    String lyDo,
    OffsetDateTime thoiGian
) {}

package vn.drinkstore.domain;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** JDBC model for don_hang; relationships use foreign key IDs. */
public record DonHang(
    Long id,
    String maDon,
    String kenhBan,
    Long khachHangId,
    Long nhanVienXuLyId,
    OffsetDateTime ngayDat,
    OffsetDateTime ngayHoanTat,
    String trangThai,
    BigDecimal phiVanChuyen,
    BigDecimal giamGia,
    BigDecimal tongTien,
    String ghiChu,
    String tenNguoiNhan,
    String sdtNguoiNhan,
    String diaChiNhan,
    OffsetDateTime thoiGianNhanDuKien,
    Boolean daTruSoLuong,
    OffsetDateTime ngayCapNhat,
    Long khuyenMaiId
) {}

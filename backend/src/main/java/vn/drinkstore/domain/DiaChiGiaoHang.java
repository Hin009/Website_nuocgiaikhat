package vn.drinkstore.domain;


/** JDBC model for dia_chi_giao_hang; relationships use foreign key IDs. */
public record DiaChiGiaoHang(
    Long id,
    Long khachHangId,
    String tenNguoiNhan,
    String soDienThoai,
    String diaChi,
    String phuongXa,
    String quanHuyen,
    String tinhThanh,
    Boolean macDinh
) {}

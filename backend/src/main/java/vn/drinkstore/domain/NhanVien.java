package vn.drinkstore.domain;

import java.time.LocalDate;

/** JDBC model for nhan_vien; relationships use foreign key IDs. */
public record NhanVien(
    Long id,
    Long taiKhoanId,
    String maNhanVien,
    String hoTen,
    LocalDate ngaySinh,
    String gioiTinh,
    String dienThoai,
    String emailLienHe,
    String diaChi,
    String chucVu,
    LocalDate ngayVaoLam,
    String trangThai
) {}

package vn.drinkstore.domain;

import java.time.OffsetDateTime;

/** JDBC model for san_pham; relationships use foreign key IDs. */
public record SanPham(
    Long id,
    Long loaiSanPhamId,
    Long thuongHieuId,
    String sku,
    String ten,
    String moTa,
    String thanhPhan,
    String dinhDuong,
    String xuatXu,
    String dungTich,
    String loaiBaoBi,
    String huongVi,
    Integer soNgayHanDung,
    String huongDanBaoQuan,
    String trangThai,
    Boolean hienThi,
    OffsetDateTime ngayTao,
    OffsetDateTime ngayCapNhat
) {}

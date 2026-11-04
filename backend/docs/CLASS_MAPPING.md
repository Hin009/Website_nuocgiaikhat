# Ánh xạ schema 13UC hoàn chỉnh

Nguồn hiện tại: `database/beverage_store_13UC_HOAN_CHINH.sql` (43 bảng nghiệp vụ + `phien_xac_thuc`, tổng 44 bảng). Mỗi bảng có Java record cùng tên PascalCase trong `vn.drinkstore.domain`. Khóa ngoại biểu diễn bằng ID; các bảng nối giữ khóa ghép, không thêm ID giả. JDBC và trigger quản lý dữ liệu, không dùng ORM tự tạo schema.

| Lớp Java | Bảng |
|---|---|
| Quyen | `quyen` |
| VaiTro | `vai_tro` |
| TaiKhoan | `tai_khoan` |
| TaiKhoanVaiTro | `tai_khoan_vai_tro` |
| VaiTroQuyen | `vai_tro_quyen` |
| PhienXacThuc | `phien_xac_thuc` |
| KhachHang | `khach_hang` |
| NhanVien | `nhan_vien` |
| DiaChiGiaoHang | `dia_chi_giao_hang` |
| LienHeKhachHang | `lien_he_khach_hang` |
| NhatKyHoatDong | `nhat_ky_hoat_dong` |
| LoaiSanPham | `loai_san_pham` |
| ThuongHieu | `thuong_hieu` |
| SanPham | `san_pham` |
| HinhAnhSanPham | `hinh_anh_san_pham` |
| QuyCachSanPham | `quy_cach_san_pham` |
| SoLuongSanPham | `so_luong_san_pham` |
| DieuChinhSoLuong | `dieu_chinh_so_luong` |
| BienDongSoLuong | `bien_dong_so_luong` |
| SanPhamYeuThich | `san_pham_yeu_thich` |
| GioHang | `gio_hang` |
| ChiTietGioHang | `chi_tiet_gio_hang` |
| DonHang | `don_hang` |
| ChiTietDonHang | `chi_tiet_don_hang` |
| LichSuTrangThaiDon | `lich_su_trang_thai_don` |
| DanhGiaSanPham | `danh_gia_san_pham` |
| ThanhToan | `thanh_toan` |
| HoanTien | `hoan_tien` |
| HoaDon | `hoa_don` |
| ChiTietHoaDon | `chi_tiet_hoa_don` |
| LichSuHoaDon | `lich_su_hoa_don` |
| KhuyenMai | `khuyen_mai` |
| PhamViKhuyenMai | `pham_vi_khuyen_mai` |
| UuDaiSoLuong | `uu_dai_so_luong` |
| SuDungKhuyenMai | `su_dung_khuyen_mai` |
| NhaCungCap | `nha_cung_cap` |
| NhaCungCapSanPham | `nha_cung_cap_san_pham` |
| GiayToNcc | `giay_to_ncc` |
| DonDatHangNcc | `don_dat_hang_ncc` |
| ChiTietDonNcc | `chi_tiet_don_ncc` |
| LanNhapHang | `lan_nhap_hang` |
| ChiTietLanNhap | `chi_tiet_lan_nhap` |
| CongNoNcc | `cong_no_ncc` |
| ThanhToanNcc | `thanh_toan_ncc` |

Bổ sung duy nhất về cột ở backend là `don_hang.khuyen_mai_id` để giữ coupon chưa xác nhận. SQL khởi tạo hiện là snapshot đầy đủ xuất từ Docker, đã bao gồm phần bổ sung này. Nghiệp vụ ở AuthService, CartService, OrderService, PurchaseService và BillingService; trigger/hàm SQL chịu trách nhiệm tồn kho, công nợ, lịch sử và lập hóa đơn.

Sơ đồ SVG cũ trong thư mục docs thuộc phiên bản 35 bảng, không phải sơ đồ của SQL hiện tại.

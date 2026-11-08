# Backend cửa hàng nước giải khát

Java 21 + Spring Boot 3.4.4 + PostgreSQL 16. Database hiện tại là bản `beverage_store_13UC_HOAN_CHINH.sql` do bạn cung cấp, gồm **44 bảng**: 43 bảng nghiệp vụ và bảng phiên xác thực. Code và 44 model JDBC đã chuyển sang cấu trúc này.

## Chạy bằng Docker

Nếu chưa có `.env`, tạo bằng `Copy-Item .env.example .env`. Đặt `DB_PASSWORD` và `BOOTSTRAP_ADMIN_PASSWORD` (12–72 ký tự ASCII); giữ file `.env` hiện có nếu đã cấu hình.

```powershell
docker compose up -d --build
docker compose ps
docker compose logs -f api
```

API: `http://localhost:8080/api/v1`; kiểm tra `GET /health`. pgAdmin kết nối `localhost:15432`, database `beverage_store`, username/password từ `.env`. Trong Docker, API kết nối `db:5432`. `DB_URL` trong `.env` dành cho Java chạy ngoài Docker.

Đăng nhập `POST /api/v1/auth/login` với `{email,password}`. Email quản trị lấy từ `BOOTSTRAP_ADMIN_EMAIL` (mặc định `admin@example.com`), mật khẩu ban đầu từ `BOOTSTRAP_ADMIN_PASSWORD` trong `.env`. Backend tạo admin và mã nhân viên khi database mới chưa có admin; không ghi đè mật khẩu admin đã tồn tại.

## Một file SQL hoàn chỉnh

`database/beverage_store_13UC_HOAN_CHINH.sql` là bản xuất đầy đủ từ PostgreSQL Docker, gồm cấu trúc, dữ liệu thực tế và bộ đếm ID. Bản đồng bộ ngày 08/11/2026 lúc 15:35:06 (UTC+7) có 46 bảng, 709 dòng dữ liệu và 39 bộ đếm ID, được xuất từ cùng một snapshot nhất quán. Đã khôi phục thử trong PostgreSQL 16 riêng biệt và đối chiếu cấu trúc, số dòng cùng dấu kiểm dữ liệu của từng bảng và toàn bộ bộ đếm ID. Đã bao gồm các migration backend mới nhất và đã bỏ ba bảng trả hàng sau nhập kho. Compose chỉ nạp file này, không chạy extensions hoặc seed riêng.

Chỉ chạy SQL vào database trống. Script dùng một giao dịch, tạo bảng và nạp dữ liệu trước khi tạo trigger/ràng buộc liên quan để giữ nguyên số lượng và lịch sử đã lưu. Không chạy lên database đang sử dụng. Docker chỉ tự nạp khi volume trống; database/volume hiện tại được giữ nguyên.

Đây là snapshot riêng có dữ liệu khách hàng, hash mật khẩu và phiên xác thực; không push snapshot lên GitHub công khai. Người quản trị sau khôi phục dùng tài khoản/mật khẩu của database nguồn; bootstrap không ghi đè admin đã có.

Bản SQL trước khi thay, dump Docker gốc và báo cáo kiểm tra lần đồng bộ này nằm trong `.tools/sql-export-20261108-153506/` (Git bỏ qua); báo cáo là `verification.json`. Container PostgreSQL kiểm tra đã được dọn sau khi hoàn tất. Các bản SQL và ảnh sao lưu cũ vẫn nằm trong `.tools/sql-export-20261104/`.

SQL không chứa file ảnh nhị phân. `product_images.tar.gz` trong thư mục sao lưu là bản sao ảnh từ volume Docker. Khi chuyển máy, đưa file này sang máy mới, sau khi chạy Compose thực hiện tại `backend/`:

```powershell
docker compose cp ./product_images.tar.gz api:/tmp/product_images.tar.gz
docker compose exec api tar -xzf /tmp/product_images.tar.gz -C /app/uploads
```

Không cần chạy các lệnh này trên máy hiện tại vì volume ảnh đã có sẵn.

## Những thay đổi theo schema 13UC

- Giá và hệ số quy đổi nằm ở `quy_cach_san_pham`; tồn kho nằm ở `so_luong_san_pham`.
- Catalog trả `packages`; giỏ và dòng đơn nhập dùng `packageId`, không dùng ID sản phẩm.
- Tài khoản có thể có nhiều vai trò qua `tai_khoan_vai_tro`; quyền qua `vai_tro_quyen`. Mã vai trò cố định: KHACH_HANG, NHAN_VIEN, QUAN_TRI_VIEN.
- Nhân viên được nhận hàng nhưng không có quyền lập/duyệt đơn NCC theo seed mới.
- Đơn NCC dùng `don_dat_hang_ncc`/`chi_tiet_don_ncc`; công nợ tạo riêng cho từng lần nhập tại `cong_no_ncc`.
- Giấy tờ nhà cung cấp nằm ở `giay_to_ncc`; yêu thích/đánh giá dùng bảng riêng theo SQL mới.
- Chi tiết đơn lưu giá vốn tại thời điểm bán; đơn có kênh ONLINE/TAI_QUAY. API hiện có tiếp tục xử lý đơn online. SQL có hàm POS; chưa bổ sung màn hình/API POS mới trong lần thay database này.

Xem [API hiện tại](docs/API.md), [client TypeScript](examples/frontend/api.ts), [request mẫu](examples/api.http) và [44 lớp–bảng](docs/CLASS_MAPPING.md). Sơ đồ SVG cũ trong docs thuộc phiên bản trước; schema SQL mới là nguồn đối chiếu hiện tại.

## Chạy Java và kiểm thử

Cần JDK 21+. Chạy riêng PostgreSQL bằng `docker compose up -d db`, rồi `.\scripts\run.ps1`. Script này đọc `.env`; chạy từ IDE hoặc `java -jar` cần tự đặt biến môi trường.

```powershell
.\mvnw.cmd test
```

Unit test chạy mặc định. Để chạy integration test, tạo database PostgreSQL **trống, riêng biệt**, tên chứa `backend_test`, rồi:

```powershell
$env:BACKEND_TEST_DB_URL='jdbc:postgresql://localhost:15432/beverage_backend_test_13uc'
$env:BACKEND_TEST_DB_USER='drink_user'
$env:BACKEND_TEST_DB_PASSWORD='mật khẩu database'
.\mvnw.cmd test
```

Test dùng schema và dữ liệu mẫu riêng tại `src/test/resources/testdb/beverage_store_test.sql`, không dùng snapshot dữ liệu thật trong `database/`. Không dùng lại database kiểm thử của schema cũ. Dữ liệu từng test rollback. Không trỏ test vào database nghiệp vụ.


## Danh mục bổ sung, ảnh và điều chỉnh tồn

Danh mục và dữ liệu tồn kho thực tế đã có trong file SQL hoàn chỉnh. Không nạp thêm seed để tránh trùng hoặc ghi đè dữ liệu.

Ảnh JPG/PNG/WebP tối đa 5 MB được quản trị tải lên từ form sản phẩm. Docker lưu file tại `/app/uploads` trong volume `product_images`; Java chạy ngoài Docker dùng `UPLOAD_DIR` hoặc `./uploads`. Sao lưu volume ảnh cùng database để khôi phục đủ dữ liệu.

Quản trị viên được đặt lại số lượng từ form thêm/sửa sản phẩm, theo đơn vị cơ bản và có lý do. Backend dùng bảng `dieu_chinh_so_luong` và trigger để ghi lịch sử và cập nhật tồn đúng một lần, không sửa thẳng bảng tồn. Phiên bản tồn cũ bị từ chối để tránh ghi đè giao dịch mới. Nhân viên không được điều chỉnh qua form này.

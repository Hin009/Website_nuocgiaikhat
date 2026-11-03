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

## Database mới và dữ liệu cũ

- `database/beverage_store_13UC_HOAN_CHINH.sql`: bản sao nguyên gốc file SQL mới, được nạp đầu tiên.
- `database/backend_extensions.sql`: thêm khóa ngoại lưu coupon đang chọn trên đơn và đồng bộ trạng thái hóa đơn khi thu tiền.
- `compose.yaml` dùng volume mới `beverage_13uc_data`; volume `beverage_data` của bản cũ được giữ lại, không bị xóa và không tự di chuyển dữ liệu sang bản mới.

Docker chỉ tự nạp SQL khi volume còn trống. SQL gốc phải chạy trên database trống. Nếu dùng pgAdmin, tạo database trống rồi chạy SQL gốc, sau đó extensions. Không chạy đè SQL lên database cũ. `docker compose down` giữ dữ liệu; thêm `-v` sẽ xóa volume đang dùng.

SQL gốc gồm 3 vai trò, 30 quyền, 2 sản phẩm và 5 quy cách (script seed bổ sung thêm 25 sản phẩm); chưa có tồn kho, tài khoản, nhà cung cấp hay giao dịch. Admin được bootstrap khi ứng dụng chạy. Muốn thử mua bán: tạo nhà cung cấp → liên kết sản phẩm → lập/duyệt đơn NCC → nhận/xác nhận hàng → khách đặt hàng.

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

Test nạp chính hai file trong `database/`. Không dùng lại database kiểm thử của schema cũ. Dữ liệu từng test rollback. Không trỏ test vào database nghiệp vụ.


## Danh mục bổ sung, ảnh và điều chỉnh tồn

`database/seed_beverages.sql` bổ sung 25 sản phẩm và 22 thương hiệu khi chưa có, không ghi đè dữ liệu cũ. Giá là giá tham khảo, tồn khởi đầu 0, chưa có ảnh. Compose tự chạy sau schema/extensions khi volume mới trống. Với database đã có dữ liệu, chạy riêng script này bằng pgAdmin; không chạy lại schema gốc. Chạy seed nhiều lần không thêm trùng SKU.

Ảnh JPG/PNG/WebP tối đa 5 MB được quản trị tải lên từ form sản phẩm. Docker lưu file tại `/app/uploads` trong volume `product_images`; Java chạy ngoài Docker dùng `UPLOAD_DIR` hoặc `./uploads`. Sao lưu volume ảnh cùng database để khôi phục đủ dữ liệu.

Quản trị viên được đặt lại số lượng từ form thêm/sửa sản phẩm, theo đơn vị cơ bản và có lý do. Backend dùng bảng `dieu_chinh_so_luong` và trigger để ghi lịch sử và cập nhật tồn đúng một lần, không sửa thẳng bảng tồn. Phiên bản tồn cũ bị từ chối để tránh ghi đè giao dịch mới. Nhân viên không được điều chỉnh qua form này.

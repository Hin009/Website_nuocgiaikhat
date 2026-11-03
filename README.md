# Website cửa hàng nước giải khát

Mã nguồn gồm `backend/` (Java Spring Boot, PostgreSQL, Docker) và `frontend/` (React/Vite). Frontend mặc định gọi API thật để hiển thị dữ liệu PostgreSQL.

## Chạy trên máy mới

Cần Docker Desktop đang chạy và Node.js 22.12+ cùng npm. Không cần cài Java/PostgreSQL trên máy nếu chạy backend bằng Docker.

```powershell
git clone -b main https://github.com/Hin009/Website_nuocgiaikhat.git
cd Website_nuocgiaikhat
cd backend
Copy-Item .env.example .env
```

Mở `backend/.env`, đặt `DB_PASSWORD` và `BOOTSTRAP_ADMIN_PASSWORD` (12–72 ký tự). Email quản trị lấy từ `BOOTSTRAP_ADMIN_EMAIL`. File `.env` là cấu hình riêng từng máy và không đưa lên GitHub.

Sau đó chạy tại thư mục `backend`:

```powershell
docker compose up -d --build
```

API: http://localhost:8080/api/v1. Kiểm tra: http://localhost:8080/api/v1/health. PostgreSQL: `localhost:15432`.

Mở terminal khác tại thư mục gốc dự án:

```powershell
cd frontend
npm.cmd ci
npm.cmd run dev
```

Cửa hàng: http://127.0.0.1:5173/products. Quản lý: http://127.0.0.1:5173/admin. Đăng nhập quản trị bằng thông tin đã cấu hình trong `.env`; khách hàng đăng ký tại `/register`.

Vite chuyển tiếp `/api` đến backend tại `http://127.0.0.1:8080`. Frontend chạy riêng với npm; Compose hiện chạy backend và database.

## Database và ảnh

Khi tạo database lần đầu, Docker tự chạy theo thứ tự:

1. `backend/database/beverage_store_13UC_HOAN_CHINH.sql`: bảng, quan hệ, trigger và dữ liệu nền.
2. `backend/database/backend_extensions.sql`: bổ sung hỗ trợ backend.
3. `backend/database/seed_beverages.sql`: thêm 25 sản phẩm của 22 thương hiệu, chưa có ảnh, tồn ban đầu 0, giá tham khảo để quản trị chỉnh lại.

SQL khởi tạo chỉ tự chạy khi volume database trống. Script seed có thể chạy lại riêng mà không ghi đè dữ liệu cũ. Không chạy lại schema gốc lên database đang sử dụng.

Dữ liệu PostgreSQL và ảnh tải lên được giữ trong hai volume Docker. Git chỉ lưu code và dữ liệu khởi tạo; chuyển các tài khoản, đơn hàng, tồn kho hoặc ảnh hiện có sang máy khác cần sao lưu/khôi phục các volume tương ứng.

## Các chức năng đã kết nối

- Sản phẩm, danh mục, thương hiệu, giá quy cách và tồn kho từ PostgreSQL.
- Đăng ký, đăng nhập, giỏ hàng, đặt đơn, địa chỉ khách và lịch sử đơn hàng.
- Quản trị thêm/sửa sản phẩm, tải ảnh JPG/PNG/WebP tối đa 5 MB và điều chỉnh tồn kho kèm lý do, lưu lịch sử.
- Quản lý tài khoản và quy trình nhập/nhận hàng từ nhà cung cấp.
- Miễn phí giao hàng cho đơn mới; khách chọn COD hoặc chuyển khoản ngân hàng. Chuyển khoản được cửa hàng cung cấp thông tin và xác nhận thủ công.

## Kiểm tra và cập nhật

Tại `frontend/`:

```powershell
npm.cmd run lint
npm.cmd test
npm.cmd run build
```

Cập nhật code tại thư mục gốc:

```powershell
git pull origin main
```

Sau khi backend thay đổi, chạy lại `docker compose up -d --build` tại `backend/`. Giữ file `.env` và các volume hiện có.

Xem [hướng dẫn backend](backend/README.md), [hợp đồng API](backend/docs/API.md) và [hướng dẫn frontend](frontend/README.md).

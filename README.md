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

Docker hiện chỉ nạp **một file** `backend/database/beverage_store_13UC_HOAN_CHINH.sql`. File đã đồng bộ từ PostgreSQL Docker ngày 11/11/2026 lúc 12:32:59 (UTC+7): 54 bảng, 1.179 dòng dữ liệu, 42 bộ đếm ID, cùng các hàm, trigger và khóa ngoại. Bản xuất đã được khôi phục thử trong PostgreSQL riêng; cấu trúc, số dòng, dấu kiểm dữ liệu từng bảng và bộ đếm ID đều khớp. Phần bổ sung backend và các migration mới nhất đã có trong bản xuất, không cần chạy thêm SQL khác.

Chỉ khôi phục vào database/volume **trống**. Docker chỉ tự nạp file khi tạo volume lần đầu. Không chạy file này lên database đang có dữ liệu và không xóa volume hiện tại chỉ để nạp lại SQL.

Bản xuất chứa dữ liệu thật, bao gồm tài khoản, mật khẩu đã băm, khách hàng và phiên xác thực. Giữ riêng file SQL; không đưa bản snapshot này lên GitHub công khai. Tài khoản quản trị sau khôi phục dùng mật khẩu của database nguồn, không tự đổi theo BOOTSTRAP_ADMIN_PASSWORD nếu đã tồn tại.

SQL lưu đường dẫn ảnh; file ảnh nằm trong volume `product_images`. Ảnh và ba SQL cũ được sao lưu tại `backend/.tools/sql-export-20261104/` (ngoài Git). Xem hướng dẫn khôi phục trong [README backend](backend/README.md).

## Các chức năng đã kết nối

- Sản phẩm, danh mục, thương hiệu, giá quy cách và tồn kho từ PostgreSQL.
- Đăng ký, đăng nhập, giỏ hàng, đặt đơn, địa chỉ khách và lịch sử đơn hàng.
- Quản trị thêm/sửa sản phẩm, tải ảnh JPG/PNG/WebP tối đa 5 MB và điều chỉnh tồn kho kèm lý do, lưu lịch sử.
- Quản lý tài khoản, nhà cung cấp, mã khuyến mãi và quy trình nhập/nhận hàng. Nhà cung cấp được thêm tại mục quản lý riêng, rồi chọn trong đơn nhập.
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

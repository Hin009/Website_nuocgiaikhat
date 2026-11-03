# WaterBus frontend

React/Vite kết nối Spring Boot và PostgreSQL trong `../backend`.

## Chạy ứng dụng

Chạy backend trước tại thư mục gốc:

```powershell
cd backend
docker compose up -d --build
```

Mở terminal khác tại thư mục gốc, dùng Node.js 22.12+:

```powershell
cd frontend
npm.cmd ci
npm.cmd run dev
```

Cửa hàng: http://127.0.0.1:5173/products. Quản lý: http://127.0.0.1:5173/admin.
Đăng nhập quản lý bằng tài khoản cấu hình trong `backend/.env`. Khách hàng đăng ký tại `/register`.

Mặc định `VITE_DATA_MODE=api`, `VITE_API_BASE_URL=/api/v1` (xem `.env.example`). Vite chuyển tiếp `/api` đến `http://127.0.0.1:8080`. Đổi đích bằng biến môi trường `VITE_PROXY_TARGET` khi chạy Vite. Không đưa mật khẩu database hoặc thông tin bí mật vào biến `VITE_*`.

## Dữ liệu và thao tác

- Danh mục, sản phẩm, giá từng quy cách, ảnh có sẵn và tồn kho đọc từ API. Không tự thêm sản phẩm mẫu; database rỗng hiển thị trạng thái rỗng.
- Đăng ký/đăng nhập dùng backend. Bearer token lưu trong sessionStorage, đăng xuất thu hồi phiên trên server.
- Giỏ khách chưa đăng nhập lưu cục bộ; khi đăng nhập được ghép vào giỏ của tài khoản trên server. Dòng giỏ dùng ID quy cách thật.
- Đặt hàng COD hoặc chuyển khoản ngân hàng: backend tính lại giá, điều kiện khuyến mãi, phí giao hàng và tổng tiền. Hiện miễn phí giao hàng (0đ). Chỉ đặt các dòng đã chọn; dòng còn lại giữ trong giỏ.
- Đơn hàng và lịch sử trạng thái lấy từ PostgreSQL. Tồn kho chỉ trừ khi cửa hàng xác nhận chuẩn bị đơn, theo trigger database.
- Quản trị quản lý sản phẩm, danh mục và tài khoản. Giá sửa là giá của quy cách hiển thị; không tự tính giá lốc/thùng theo phần trăm mẫu.
- Nhập hàng gồm tạo nhà cung cấp, lập đơn nhập, duyệt đơn, tạo lần nhận nháp và xác nhận nhập. Xác nhận nhận hàng mới cộng tồn; quản trị viên cũng có thể sửa số lượng trên form sản phẩm kèm lý do điều chỉnh. Nhân viên có thể nhận hàng theo quyền backend.

Sản phẩm tồn bằng 0 không thể mua. Muốn tăng tồn, thực hiện quy trình nhập hàng hoặc để quản trị viên điều chỉnh số lượng kèm lý do. Các chức năng chưa có giao diện riêng: quản trị khuyến mãi, thanh toán trực tuyến và hoàn tiền.

## Kiểm tra

```powershell
npm.cmd run lint
npm.cmd test
npm.cmd run build
```

`tests/api-mappers.test.js` kiểm tra ánh xạ giá quy cách, tồn kho và ID từ API. Các test logic cũ nhập trực tiếp adapter mock để kiểm tra dữ liệu mẫu độc lập.

`npx.cmd playwright test -c playwright.api.config.js` kiểm tra Chrome với backend thử ở cổng **18080**, database dùng một lần có tên chứa `backend_test`, tài khoản `e2e-admin@test.invalid` / `TestPass123!` chỉ dành cho môi trường thử. Test có tạo nhà cung cấp, nhập hàng, tài khoản và đơn thử. Không đổi test sang API/database đang dùng ở cổng 8080. Backend thử cần cho phép CORS `http://127.0.0.1:5174`.

`npm.cmd run test:e2e` chạy bộ trình duyệt mẫu bằng `VITE_DATA_MODE=mock`. Nếu cổng 5173 đang được dùng, tắt Vite ở terminal đó trước khi chạy bộ test mẫu.

## Chế độ mẫu

Chỉ bật `VITE_DATA_MODE=mock` khi muốn xem giao diện mẫu độc lập, rồi khởi động lại Vite. Chế độ này dùng localStorage và tài khoản demo, có quy tắc giá/tồn khác backend và không đồng bộ PostgreSQL. Chế độ API không tự chuyển về dữ liệu mẫu khi server lỗi.

Adapter API nằm tại `src/services/api.js`, ánh xạ dữ liệu tại `mappers.js`, cấu hình HTTP tại `http.js`. Hợp đồng backend: [API.md](../backend/docs/API.md). Tài liệu thiết kế giao diện ban đầu tại `docs/IMPLEMENTATION.md` là tài liệu lịch sử của bản mock.


## Ảnh, tồn kho và danh mục khởi đầu

Form thêm/sửa sản phẩm có chọn ảnh JPG/PNG/WebP tối đa 5 MB, xem trước ảnh và ô URL ảnh. Chọn ảnh mới thay ảnh đang hiển thị; để trống giữ ảnh đã lưu. Ảnh tải lên lưu trong volume Docker `product_images`, không mất khi dựng lại container.

Quản trị viên được sửa số lượng tồn theo đơn vị cơ bản (lon/chai/hộp lẻ), cần lý do nếu thay đổi. Backend ghi người thực hiện và số lượng trước/sau vào lịch sử điều chỉnh; dữ liệu thay đổi trong lúc form đang mở sẽ bị chặn để tải lại. Nhân viên không được dùng chức năng này.

`backend/database/seed_beverages.sql` bổ sung 25 sản phẩm của 22 thương hiệu, không ảnh, tồn ban đầu 0, giá tham khảo cần chỉnh trước khi kinh doanh. Script chạy lại không ghi đè dữ liệu đang dùng.


Khách chọn COD hoặc chuyển khoản ở bước đặt hàng. Chuyển khoản hiện theo quy trình cửa hàng liên hệ cung cấp thông tin và xác nhận đã nhận tiền; tạo đơn không tự chuyển thanh toán sang thành công. Đơn đã đặt trước khi đổi phí ship giữ mức phí đã lưu.

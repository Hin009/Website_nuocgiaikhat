# Phạm vi và bàn giao frontend

## Căn cứ

Theo điều chỉnh yêu cầu: tạo frontend mới tại D:\NgocSon\WaterBus\frontend, không sử dụng hai thư mục soda-web và soda-db. Workspace ban đầu trống. Chưa có Controller Spring Boot, DTO, Entity, SecurityConfig, schema hay tài liệu 13 Use Case được chọn cho bản triển khai này.

Vì vậy không thể phân loại API đã có/thiếu trong backend thực tế. Tất cả module bên dưới dùng adapter mô phỏng và quyền tạm cho trải nghiệm UI. Không có backend/database hiện hữu nào được sửa.

## Ánh xạ màn hình, vai trò và dữ liệu

| Chức năng               | Route                 | Vai trò UI mẫu           | Service                        | API thật                              |
| ----------------------- | --------------------- | ------------------------ | ------------------------------ | ------------------------------------- |
| Trang chủ               | /                     | Công khai                | catalogService                 | Chưa được cung cấp                    |
| Tìm kiếm/lọc/phân trang | /products             | Công khai                | catalogService.list/categories | Chưa được cung cấp                    |
| Chi tiết/liên quan      | /products/:id         | Công khai                | catalogService.detail/list     | Chưa được cung cấp                    |
| Giỏ hàng                | /cart                 | Công khai                | CartContext                    | Giỏ cục bộ, cần xác minh khi checkout |
| Đăng nhập/đăng ký       | /login, /register     | Công khai                | authService                    | Chưa được cung cấp                    |
| Đăng nhập quản lý       | /admin                | Nhân viên, quản trị viên | authService                    | Chưa được cung cấp                    |
| Tạo đơn mẫu             | /checkout             | Đã đăng nhập             | orderService.create            | Chưa được cung cấp                    |
| Hồ sơ                   | /account              | Đã đăng nhập             | authService.update             | Chưa được cung cấp                    |
| Đơn hàng cá nhân        | /account/orders, /:id | Đã đăng nhập             | orderService.list/change       | Chưa được cung cấp                    |
| Dashboard               | /admin                | STAFF, ADMIN             | useAdmin/useOrders             | Chưa được cung cấp                    |
| Sản phẩm                | /admin/products       | ADMIN                    | adminService.all/save/remove   | Chưa được cung cấp                    |
| Danh mục                | /admin/categories     | STAFF, ADMIN             | adminService.all/save/remove   | Chưa được cung cấp                    |
| Nhập hàng               | /admin/stock-receipts | ADMIN                    | adminService.receipt           | Chưa được cung cấp                    |
| Xử lý đơn               | /admin/orders, /:id   | STAFF, ADMIN             | orderService                   | Chưa được cung cấp                    |
| Khách hàng              | /admin/customers      | STAFF, ADMIN             | adminService.all               | Chưa được cung cấp                    |
| Tài khoản/nhân viên     | /admin/users          | ADMIN                    | adminService.save              | Chưa được cung cấp                    |
| Báo cáo                 | /admin/reports        | STAFF, ADMIN             | Đọc đơn, sản phẩm, phiếu mẫu   | Chưa được cung cấp                    |

ADMIN kế thừa quyền STAFF qua hasRole; route và menu dùng cùng nguyên tắc. Đây chỉ là giới hạn điều hướng phía client. Khi tích hợp, backend phải kiểm tra quyền, đối tượng sở hữu và dữ liệu mọi request. Chưa khẳng định phân quyền của module theo 13 Use Case vì tài liệu đó chưa có.

## Đã thực hiện theo giai đoạn

1. Phạm vi: xác nhận frontend độc lập, xác định dữ liệu và API chưa có; không tái sử dụng dự án khác.
2. Khởi tạo: package.json, lockfile, Vite, Tailwind, alias, shadcn config, lint, unit test và E2E.
3. Layout: customer/admin/auth, header/footer, sidebar desktop/mobile, breadcrumb.
4. Khách hàng: trang chủ, catalog, chi tiết, giỏ, checkout mẫu, tài khoản và đơn hàng.
5. Quản lý: dashboard, sản phẩm, danh mục, nhập hàng, đơn, khách, tài khoản và báo cáo.
6. Tách service: mock seed/storage, Context, Query hooks, Axios và chế độ fail-closed khi chọn API chưa hỗ trợ.
7. Kiểm tra: npm install/build/lint/test, Chrome E2E; kết quả cuối tại VALIDATION.md.

## Quy tắc báo cáo mẫu

Doanh thu = tổng subtotal của đơn COMPLETED trong khoảng chọn; không bao gồm phí vận chuyển. Không có thống kê phần trăm tăng trưởng giả. Sản phẩm được yêu thích = tổng số lượng trong các dòng của đơn COMPLETED. Tổng sản phẩm = sản phẩm active, khách hàng = tài khoản role CUSTOMER. Báo cáo nhập kho = phiếu được tạo trong khoảng ngày.

Các chỉ số là số liệu mô phỏng trên trình duyệt. Đây không phải định nghĩa kế toán đã được nghiệp vụ chấp thuận.

## Những hợp đồng cần xác minh trước khi kết nối

- Base URL, cổng, prefix endpoint, CORS và Docker Compose.
- Cookie/session hay Bearer token, endpoint kiểm tra phiên, CSRF nếu cần.
- DTO đăng nhập, đăng ký, hồ sơ, quyền và enum vai trò.
- Sản phẩm, danh mục, đơn vị bán, giá, khuyến mãi, tồn kho và ảnh.
- Pagination (Page<T>, envelope hoặc mảng), filter, sort và JSON lỗi.
- DTO checkout, tính giá/phí ở backend, khóa tồn, idempotency và trạng thái thanh toán.
- Ownership đơn hàng; enum và chuyển trạng thái, quy tắc hủy/hoàn kho.
- Nhập hàng, nhà cung cấp, chi tiết phiếu, trạng thái, giao dịch cập nhật tồn.
- Phạm vi STAFF/ADMIN theo từng Use Case.
- Endpoint và cách tính báo cáo; múi giờ, tiền và khoảng ngày.

Không đặt sẵn URL như /api/products rồi tuyên bố tương thích. Các hàm service hiện là điểm nối giao diện, không phải hợp đồng REST.

## Chưa triển khai

Tích hợp Spring Boot; 13 Use Case; thanh toán online, upload ảnh, reset/đổi mật khẩu; đánh giá; module quản trị khuyến mãi riêng. Chỉ bổ sung khi có đặc tả hoặc yêu cầu tương ứng. Dữ liệu giá ưu đãi trong catalog hiện là seed.

Không gửi email, không gọi cổng thanh toán, không xuất hóa đơn hay giao hàng thực tế. Xác thực mock và lưu trữ browser không dùng cho production.

Khu quản lý dùng `/admin` làm điểm vào: chưa xác thực thì hiển thị form đăng nhập, STAFF/ADMIN đã xác thực thì hiển thị tổng quan. Truy cập trang con khi chưa xác thực sẽ về `/admin?redirect=...` và quay lại sau đăng nhập. `/quan-ly` chuyển hướng về `/admin`.
# Ghi chú bản tích hợp API

Tài liệu bên dưới mô tả bản frontend mock ban đầu. Frontend hiện mặc định đã kết nối Spring Boot/PostgreSQL; xem [README hiện tại](../README.md) và [hợp đồng API](../../backend/docs/API.md) để chạy và kiểm tra. Các nhận định bên dưới về API chưa tồn tại, giá và tồn mẫu chỉ áp dụng cho `VITE_DATA_MODE=mock`.

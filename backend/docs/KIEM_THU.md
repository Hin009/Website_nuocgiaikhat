# Kiểm thử schema 13UC

`mvnw.cmd test` chạy unit test. Đặt BACKEND_TEST_DB_URL/USER/PASSWORD để bật integration test PostgreSQL. Tạo database trống riêng, tên chứa `backend_test`. Không dùng lại database test schema cũ hoặc database nghiệp vụ.

Test nạp `database/beverage_store_13UC_HOAN_CHINH.sql` rồi `database/backend_extensions.sql` qua Maven test resources. Mỗi test rollback dữ liệu.

Bao phủ: catalog/quy cách, quy đổi số lượng và giá, nhận nhiều đợt/xác nhận lặp, công nợ từng lần nhập và thanh toán, trừ/hoàn tồn, hóa đơn/COD, coupon xác nhận/hủy, khóa đăng nhập, CORS, quyền và sở hữu đơn, thu hồi phiên khi gán vai trò, bảng nối quyền, nhân viên không được lập đơn NCC, CRUD sản phẩm, báo cáo và đánh giá.

Docker: `docker compose config --quiet`, `docker compose up -d --build`, kiểm tra health, đăng nhập admin, catalog/packages, phân quyền và logout. Database mới dùng volume `beverage_13uc_data`; volume cũ được giữ lại.

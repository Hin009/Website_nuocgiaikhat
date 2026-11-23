# Chuyển khoản ngân hàng bằng QR

Checkout hỗ trợ COD và `BANK_TRANSFER`. Với chuyển khoản, mã QR chỉ xuất hiện sau khi khách bấm đặt hàng và đơn đã được lưu. Số tiền lấy từ database sau giảm giá/phí giao hàng; nội dung chuyển khoản là `WB{orderId}`.

1. Khách đặt hàng, được đưa đến `/payments/bank-transfer/{id}` để quét QR hoặc dùng thông tin tài khoản.
2. Sau khi chuyển khoản, khách bấm **Xác nhận thanh toán** và xác nhận trong hộp thoại.
3. Backend kiểm tra đúng chủ đơn, phương thức và trạng thái đơn; lưu `customer_confirmed_at`. Thanh toán vẫn `PENDING`. Gửi lặp không tạo thêm thông báo/lịch sử.
4. Admin kiểm tra tài khoản ngân hàng rồi bấm **Xác nhận đơn**. Backend yêu cầu khách đã xác nhận, đúng số tiền và quyền admin trước khi ghi nhận thanh toán `SUCCESS`, xác nhận đơn và xuất tồn trong cùng giao dịch.

Khách chưa xác nhận thì nút xác nhận đơn bị vô hiệu hóa; gọi trực tiếp API cũng bị chặn. Nhân viên không có quyền xác nhận đơn chuyển khoản. COD vẫn theo quy trình thanh toán khi giao hàng.

## Cấu hình

Trong `backend/.env`, đặt `BANK_TRANSFER_BANK_ID`, `BANK_TRANSFER_BANK_NAME`, `BANK_TRANSFER_ACCOUNT_NUMBER`, `BANK_TRANSFER_ACCOUNT_NAME`. Thông tin này được phục vụ cho khách để chuyển khoản. Nếu thiếu thông tin tài khoản, checkout tắt lựa chọn chuyển khoản.

Sau khi thay cấu hình, chạy `docker compose up -d --build api` tại `backend/`. Không cần tunnel hay callback cho luồng thủ công này. Mã QR sử dụng ảnh từ VietQR; nếu ảnh không tải được, trang vẫn hiển thị ngân hàng, tài khoản, số tiền và nội dung để chuyển thủ công. Không có cơ chế tự xác minh ngân hàng; admin chịu trách nhiệm đối chiếu trước khi xác nhận.

## API

- `GET /api/v1/orders/{id}/bank-transfer`: chi tiết QR của khách sở hữu đơn.
- `POST /api/v1/orders/{id}/bank-transfer/confirm`: khách báo đã chuyển khoản; không nhận amount/customerId từ trình duyệt.
- `PATCH /api/v1/staff/orders/{id}/status` với `DANG_CHUAN_BI`: admin xác nhận đơn sau khi khách xác nhận thanh toán.
- `GET /api/v1/payments/notifications` và `GET /api/v1/payments/events`: thông báo cho người quản lý có quyền `ORDER_UPDATE`.

Migration `20261120_bank_transfer_confirmation.sql` tự bổ sung cột xác nhận trên database hiện tại. Giữ nguyên volume và lịch sử thanh toán đã có, không nạp lại SQL khởi tạo lên database đang sử dụng.

## Kiểm thử

Backend: cấu hình PostgreSQL riêng có tên chứa `backend_test`, dùng các biến `BACKEND_TEST_DB_URL`, `BACKEND_TEST_DB_USER`, `BACKEND_TEST_DB_PASSWORD`, rồi chạy:

```powershell
.\mvnw.cmd '-Dtest=BackendIntegrationTest#bankTransfer*+freeShipping*+saleConfirmation*+codRequires*' test
```

Frontend:

```powershell
npm.cmd run lint
npm.cmd test
npm.cmd run build
npx.cmd playwright test --config playwright.business.config.js checkout-browser.spec.js bank-transfer-browser.spec.js order-confirmation-browser.spec.js
```

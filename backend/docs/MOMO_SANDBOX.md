# Thanh toán MoMo Sandbox — WATERBUS

Tích hợp trực tiếp vào Spring Boot/PostgreSQL và React hiện có. Chỉ gọi `https://test-payment.momo.vn/v2/gateway/api/create`, `requestType=captureWallet`, `autoCapture=true`; không có lựa chọn endpoint production. Cấu hình môi trường khác `sandbox` không được sử dụng.

Tài liệu chính thức:

- https://developers.momo.vn/v3/vi/docs/payment/api/wallet/onetime/
- https://developers.momo.vn/v3/docs/payment/api/result-handling/notification/
- https://developers.momo.vn/v3/download

## Cấu hình cần bổ sung

Lấy **bộ thông tin tích hợp Sandbox của chính tài khoản merchant** trong cổng MoMo dành cho đối tác. Điền vào `backend/.env` đang được gitignore; không đưa khóa vào frontend, commit, ảnh chụp hoặc log.

```dotenv
MOMO_ENABLED=true
MOMO_ENVIRONMENT=sandbox
MOMO_PARTNER_CODE=<Partner Code Sandbox>
MOMO_ACCESS_KEY=<Access Key Sandbox>
MOMO_SECRET_KEY=<Secret Key Sandbox>
MOMO_REDIRECT_URL=http://localhost:5173/payments/momo/return
MOMO_IPN_URL=https://<public-backend-host>/api/v1/payments/momo/ipn
```

Các giá trị trên cần được thay bằng thông tin thật của **Sandbox**. Code không có khóa dự phòng. Nếu thiếu cấu hình, checkout hiển thị MoMo ở trạng thái chưa sẵn sàng, không cho chọn; COD vẫn sử dụng được và API tạo thanh toán MoMo từ chối thao tác. Sau khi sửa `.env`, phải tạo lại container API để cập nhật biến môi trường.

Khi chạy backend ngoài Docker, dùng `backend/scripts/run.ps1` để nạp `.env`. Spring Boot không tự đọc file dotenv.

## URL HTTPS cho IPN khi chạy local

Backend đang phục vụ cổng 8080. Dùng tunnel HTTPS của ngrok hoặc Cloudflare Tunnel, ví dụ với ngrok đã cài và cấu hình tài khoản:

```powershell
ngrok http 8080
```

Lấy địa chỉ Forwarding HTTPS, nối `/api/v1/payments/momo/ipn` và điền `MOMO_IPN_URL`. Giữ tunnel chạy trong suốt giao dịch. Endpoint này nhận POST JSON từ MoMo, không yêu cầu JWT; chữ ký HMAC-SHA256 và dữ liệu giao dịch được kiểm tra ở backend. Không đặt trang đăng nhập, CAPTCHA hoặc màn hình cảnh báo tunnel trước endpoint IPN.

`MOMO_REDIRECT_URL` là địa chỉ trình duyệt khách có thể truy cập. `localhost` phù hợp khi mở website trên máy đang chạy frontend. Nếu trình duyệt điện thoại cũng cần quay lại website, dùng URL HTTPS công khai cho frontend, thêm origin đó vào `CORS_ORIGINS` nếu frontend gọi API khác origin. Một URL tunnel mới chỉ áp dụng cho **giao dịch mới**: giao dịch đã tạo giữ URL và requestId ban đầu.

## Chạy ứng dụng

Từ thư mục gốc:

```powershell
cd backend
docker compose up -d db
docker compose up -d --build api
docker compose logs --tail 100 api
cd ../frontend
npm ci
npm run dev
```

Mở `http://localhost:5173`, đăng nhập tài khoản khách, thêm sản phẩm và vào checkout. `frontend/.env.local` phải chọn chế độ API (`VITE_DATA_MODE=api`); chế độ mock chỉ phục vụ demo giao diện. Vite proxy `/api` tới backend `http://127.0.0.1:8080` theo cấu hình có sẵn.

Docker giữ dữ liệu trong volume `beverage_13uc_data`, giữ ảnh trong `product_images`. Không dùng `docker compose down -v`. Không cần xóa hoặc khởi tạo lại database. Các đơn chuyển khoản cũ và bảng thanh toán hiện tại được giữ nguyên. Checkout mới chỉ chấp nhận COD và MoMo.

## Migration

SQL: `src/main/resources/db/migrations/20261110_momo_sandbox.sql`.

`MomoSchema` tự chạy migration trong transaction lúc khởi động, theo cơ chế `backend_schema_migration` hiện có và advisory lock. Không cần chạy SQL thủ công nếu đã chạy ứng dụng. Migration chỉ thêm bảng/index, không xóa bảng/cột/dữ liệu:

| Bảng | Mục đích |
| --- | --- |
| `momo_payment_attempt` | Từng lần tạo thanh toán; provider orderId/requestId duy nhất, số tiền, Sandbox, QR payload/payUrl, kết quả, transId, paid_at |
| `momo_ipn_history` | Lịch sử IPN đã xác thực và khớp dữ liệu, kể cả thông báo trùng |
| `payment_notification` | Thông báo quản lý bền vững, duy nhất theo payment |
| `checkout_request` | Khóa chống tạo đơn trùng theo khách và UUID requestKey |

Thanh toán tiếp tục nằm trong `thanh_toan`. Trạng thái thành công của schema hiện có là `SUCCESS`, hiển thị **Đã thanh toán**; không thêm một trạng thái `PAID` khác vào bảng này. Trigger cập nhật hóa đơn hiện có vẫn được sử dụng. IPN không thay đổi trạng thái xử lý đơn hoặc xuất kho.

## API

Tất cả đường dẫn có prefix `/api/v1`:

| Phương thức / đường dẫn | Quyền / hành vi |
| --- | --- |
| `GET /catalog/checkout-options` | Công khai; COD và MoMo khi cấu hình đầy đủ; không trả khóa |
| `POST /orders` | Khách; body cũ thêm `requestKey` UUID bắt buộc, `paymentMethod=COD` hoặc `MOMO`; tạo đơn chờ xác nhận và payment PENDING |
| `POST /payments/orders/{id}/momo` | Chủ đơn; tạo/khôi phục yêu cầu MoMo của đơn đã lưu, số tiền tính từ DB |
| `GET /payments/orders/{id}/status` | Chủ đơn; trả mã đơn, số tiền, phương thức, trạng thái, mã giao dịch và attempt hiện tại |
| `GET /payments/momo/return?orderId={MoMoOrderId}` | Chủ đơn; ánh xạ tham chiếu MoMo về đơn và trạng thái từ DB |
| `POST /payments/momo/ipn` | MoMo; kiểm tra HMAC, partnerCode, orderId, requestId, orderInfo, orderType, extraData và số tiền; HTTP 204 khi xử lý hợp lệ |
| `GET /staff/payment-notifications?page=0&size=20` | Nhân viên có ORDER_UPDATE hoặc quản trị viên; lịch sử thông báo |
| `GET /staff/orders/{id}` | Theo quyền hiện có; payment có `ma_giao_dich`, `paid_at`, `environment` |

`POST /orders` cùng khách + cùng requestKey + cùng nội dung trả lại đơn đã tạo. Dùng lại key với nội dung khác bị từ chối. Frontend giữ key trong sessionStorage đến khi nhận được đơn thành công. API tạo thanh toán lưu các tham chiếu trước khi gọi MoMo; việc quay lại trang hoặc tải lại không tạo đơn mới.

IPN sai chữ ký/dữ liệu bị từ chối; không ghi nhận thanh toán hoặc thông báo thành công. Lịch sử IPN trong DB chỉ chứa thông báo đã xác thực. `resultCode=0` mới đánh dấu thành công; `9000` chỉ là được cấp quyền, không coi là đã thanh toán. IPN thành công trùng không tạo thêm thông báo và không xuất kho. IPN thất bại đến sau thành công không làm hạ trạng thái.

## Kiểm tra bằng MoMo Test

1. Cài ứng dụng **MoMo Test** từ trang download chính thức, dùng tài khoản TEST theo hướng dẫn MoMo dành cho merchant. Không quét bằng ví MoMo thật.
2. Mở website trên máy tính, chọn **Ví điện tử MoMo (Sandbox)** và Đặt hàng.
3. Trang `/payments/momo/{id}` hiển thị mã đơn, số tiền và QR dựng bằng `qrcode.react` từ **dữ liệu** `qrCodeUrl` trả bởi MoMo. Không tải QR từ dịch vụ bên thứ ba.
4. Trên điện thoại, mở MoMo Test → Quét mã → xác nhận giao dịch thử.
5. Trang khách polling trạng thái mỗi 3 giây. Chỉ khi IPN hợp lệ được commit mới hiển thị Đã thanh toán và mã giao dịch. Redirect có `resultCode=0` không tự cập nhật DB.
6. Mở `/admin/orders` bằng tài khoản nhân viên/quản trị. Trang tự cập nhật mỗi 10 giây, hiển thị thông báo đã thanh toán và chi tiết Sandbox, transId, thời gian. Đơn vẫn **Chờ xác nhận** đến khi người có quyền xác nhận.
7. Đóng trình duyệt không dừng IPN. Mở lại đơn → Xem thanh toán MoMo để tiếp tục theo dõi.

Nếu tài khoản MoMo chỉ trả `payUrl`, trang hiển thị nút mở trang MoMo Sandbox để quét QR do MoMo cung cấp. Không tự tạo dữ liệu QR thanh toán khi API không trả `qrCodeUrl`. API hiện dùng không trả hạn hết hiệu lực trong response đã xử lý, nên giao diện không dựng đồng hồ hết hạn giả.

## Kiểm tra IPN và dữ liệu

Theo dõi request trong công cụ tunnel: POST đúng path, trả 204. Nếu thấy 400/404, kiểm tra chữ ký/bộ khóa, số tiền, requestId và tham chiếu đơn; nếu 401, kiểm tra path hoặc phiên bản API đang chạy. Request MoMo không cần header Authorization.

Chạy các câu SQL **chỉ đọc** trên PostgreSQL:

```sql
SELECT d.ma_don, d.trang_thai AS order_status,
       p.phuong_thuc, p.trang_thai AS payment_status, p.so_tien,
       a.environment, a.momo_order_id, a.request_id, a.trans_id, a.paid_at
FROM don_hang d JOIN thanh_toan p ON p.don_hang_id=d.id
LEFT JOIN momo_payment_attempt a ON a.payment_id=p.id
WHERE p.phuong_thuc='MOMO' ORDER BY d.id DESC, a.id DESC;

SELECT attempt_id, received_at, payload->>'resultCode' AS result_code
FROM momo_ipn_history ORDER BY id DESC LIMIT 20;

SELECT * FROM payment_notification ORDER BY id DESC LIMIT 20;
```

## Thất bại, timeout, hủy đơn

- Kết quả thất bại xác định: giữ đơn chưa thanh toán; khách có thể chọn Thanh toán lại, tạo attempt mới trên cùng đơn.
- Timeout/kết quả không rõ: giữ nguyên orderId/requestId; tải lại dùng cùng giao dịch. Không tự suy diễn thất bại rồi tạo khoản thu mới. Nếu MoMo chỉ phản hồi mã trùng mà không trả lại QR/payUrl, cần merchant đối soát giao dịch với MoMo; ứng dụng không tự mở thêm attempt.
- Không thanh toán: đơn vẫn chờ thanh toán, chưa xuất kho. Chưa có tác vụ tự hủy/đối soát theo lịch.
- Chỉ nhân viên có quyền/quản trị mới xác nhận xử lý; đơn MoMo chưa thanh toán bị chặn xác nhận. Xuất kho và hoàn kho do trigger hiện có thực hiện.
- Khách vẫn hủy được đơn chờ xác nhận. IPN thành công đến sau hủy vẫn ghi nhận tiền đã nhận và tạo thông báo cần đối soát/hoàn tiền; đơn không tự được mở lại.
- Nếu một attempt cũ bất ngờ thành công sau attempt khác đã trả tiền, lưu cả giao dịch và cảnh báo quản lý cần đối soát. Không tự tạo hoàn tiền.
- Hoàn tiền MoMo tự động chưa thuộc luồng này. API thu tiền/hoàn thủ công hiện có từ chối phương thức MOMO; cửa hàng phải xử lý qua MoMo và đối soát. Không có nút tự nhận đã thanh toán.

## Kiểm thử và giới hạn xác minh

`MomoClientTest` kiểm tra HMAC bằng kết quả độc lập từ Python, kiểm tra chữ ký IPN và chặn production/thiếu cấu hình. `BackendIntegrationTest` kiểm tra trên PostgreSQL riêng: COD/MoMo, migration, IPN hợp lệ/trùng/sai chữ ký/sai số tiền/sai request/partner, kết quả 9000/thất bại, quyền sở hữu, chặn thu thủ công/xác nhận chưa thanh toán, thanh toán sau hủy, thông báo và idempotency tạo đơn. Kiểm thử gateway timeout dùng mock, không gọi MoMo thật.

```powershell
cd backend
# BACKEND_TEST_DB_URL phải trỏ database RIÊNG có tên chứa backend_test.
# Nạp BACKEND_TEST_DB_USER và BACKEND_TEST_DB_PASSWORD qua môi trường.
./mvnw.cmd test
cd ../frontend
npm test
npm run build
npx playwright test --config playwright.business.config.js checkout-browser.spec.js
```

Hai ca trình duyệt dùng API fixture để kiểm tra nhập địa chỉ, tạo đơn, QR, polling và không tin redirect. Chúng **không chứng minh giao dịch Sandbox thật**. Chưa kiểm chứng quét QR bằng MoMo Test, MoMo gửi IPN qua tunnel thật, hoặc khởi động lại Docker với giao dịch Sandbox thật, do chưa có thông tin merchant và URL công khai.

Kết quả xác minh ngày 10/11/2026: toàn bộ lệnh backend `test` và `package -DskipTests` thành công; riêng lớp tích hợp PostgreSQL có 38 ca đạt, lớp kiểm thử MoMo/HMAC có 3 ca đạt. Frontend có 73 kiểm thử đơn vị đạt, 2 ca trình duyệt checkout đạt, build thành công. `docker compose config -q` hợp lệ. Các kiểm thử PostgreSQL chạy trên database riêng `beverage_backend_test_momo_20261110`.

## Các file của thay đổi

- Mới: `billing/MomoProperties.java`, `MomoClient.java`, `MomoService.java`, `MomoController.java`, `MomoSchema.java` trong `src/main/java/vn/drinkstore`; SQL migration; `src/test/java/vn/drinkstore/billing/MomoClientTest.java`; tài liệu này.
- Backend sửa: `catalog/CatalogController.java`, `sales/OrderService.java`, `sales/SalesController.java`, `security/Access.java`, `security/SecurityConfig.java`, `application.yml`, `.env.example`, `compose.yaml`, `README.md`, `BackendIntegrationTest.java`.
- Frontend mới: `src/pages/customer/MomoPaymentPage.jsx`.
- Frontend sửa: `src/App.jsx`, `src/pages/customer/ApiCheckoutPage.jsx`, `src/services/api.js`, `src/components/common/Orders.jsx`, `src/hooks/useData.js`, `src/utils/format.js`, `src/index.css`, `package.json`, `package-lock.json`, `tests/checkout-browser.spec.js`, `tests/api-browser.spec.js` (luồng backend thực tiếp tục kiểm thử COD).

Checkout dùng React hiện tại, không tạo website/app khác. Các tab SePay trong IDE không có file tương ứng trong checkout source tại thời điểm triển khai; không xóa các thành phần ngân hàng/chuyển khoản còn tồn tại. Chỉ bỏ chúng khỏi các lựa chọn checkout mới.

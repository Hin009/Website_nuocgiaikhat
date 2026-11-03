# Kết quả kiểm tra — 27/10/2026

Phạm vi: frontend độc lập tại D:\NgocSon\WaterBus\frontend. Không kết nối backend hoặc hai thư mục cùng cấp.

| Kiểm tra                 | Kết quả                                  |
| ------------------------ | ---------------------------------------- |
| npm.cmd install          | Thành công; có package-lock.json         |
| npm.cmd run build        | Thành công; tạo dist/                    |
| npm.cmd run lint         | Thành công, không lỗi/cảnh báo lint      |
| npm.cmd run format:check | Thành công                               |
| npm.cmd test             | 12/12 kiểm thử logic đạt                 |
| npm.cmd run test:e2e     | 10/10 kiểm thử Chrome đạt, khoảng 1 phút |
| npm.cmd audit --omit=dev | 0 lỗ hổng được báo cáo                   |

## Kiểm thử logic

- ADMIN kế thừa STAFF; STAFF không có quyền ADMIN; tài khoản inactive bị chặn.
- Redirect chỉ cho đường dẫn nội bộ, chặn URL ngoài/backslash/ký tự điều khiển.
- Số điện thoại Việt Nam, tồn kho không âm và chỉ COD trong checkout mẫu.
- Giá đơn lấy từ danh mục, không nhận giá tùy ý từ giỏ.
- Đặt vượt tồn bị từ chối, đơn mới chưa trừ kho.
- Xác nhận trừ kho; hủy xác nhận hoàn kho; lý do hủy bắt buộc; chặn chuyển trạng thái sai.
- Khách không thấy/hủy đơn của người khác.
- Kiểm tra đủ mọi dòng hàng trước khi trừ kho để tránh ghi dở dang.
- Phiếu nhập tăng kho đúng số lượng; danh mục có sản phẩm không được xóa.
- Sai mật khẩu không tạo phiên; đăng xuất xóa phiên.
- Đăng ký chỉ tạo CUSTOMER và không lưu mật khẩu nguyên văn.

## Kiểm thử Chrome

1. Trang chủ tải dữ liệu, không có pageerror; không tràn ngang ở 360, 768, 1024 và 1440px.
2. Tìm kiếm không dấu, lọc danh mục, mở sản phẩm và tab thông tin.
3. Thêm giỏ, đổi số lượng, chuyển đăng nhập rồi quay lại checkout, tạo đơn, xem chi tiết và hủy có lý do.
4. STAFF truy cập vận hành và bị chặn trang tài khoản quản trị.
5. ADMIN truy cập trang vận hành, thêm danh mục/sản phẩm có validation.
6. Nhập kho với xác nhận và xác nhận đơn hàng.
7. Tám trang quản lý tải được, không có pageerror, không tràn ngang ở 360, 768, 1280px.
8. Menu điện thoại, bộ lọc sản phẩm, sidebar quản lý trên viewport 390px.
9. Đăng ký kiểm tra mật khẩu xác nhận, tài khoản mới không có quyền vận hành.
10. Chặn ADMIN tự khóa, tạo nhân viên có xác nhận, đăng nhập được tài khoản nhân viên mới.

Hai vấn đề được phát hiện và sửa trước lượt chạy cuối: nhãn select trong phiếu nhập chưa được liên kết rõ ràng; phần tử nhãn ẩn trong bảng đơn hàng dùng vị trí tuyệt đối làm tràn khỏi vùng cuộn trên mobile. Field hiện có htmlFor/id/aria-describedby và vùng cuộn bảng có containing block riêng.

## Kiểm tra hình ảnh và bản build

Đã xem ảnh trang chủ desktop và dashboard; lưu ảnh kiểm tra tại:

- screenshots/home-1440.png
- screenshots/home-1024.png
- screenshots/home-768.png
- screenshots/home-360.png
- screenshots/dashboard-desktop.png
- screenshots/catalog-mobile.png

Trang quản lý và thư viện biểu đồ được tải theo route. Gói Dashboard riêng khoảng 385 kB trước gzip, không được tải cùng trang chủ. Build cuối không còn cảnh báo chunk vượt 500 kB.

## Giới hạn

- Chưa kiểm tra Spring Boot, API, CORS, Docker, database hay tài liệu 13 Use Case vì chưa có trong phạm vi được cung cấp.
- Chưa có thanh toán, email, giao hàng hoặc upload ảnh thật.
- Phân quyền client và mock auth không phải bảo mật production.
- Responsive kiểm tra bằng viewport Chrome desktop; chưa kiểm tra thiết bị vật lý, Safari hoặc Firefox.
- E2E chặn Google Fonts để kiểm tra với font fallback và không phụ thuộc mạng. Ảnh bao bì là SVG minh họa, không phải ảnh thật của nhà sản xuất.
- Dữ liệu mẫu chỉ nằm trong trình duyệt, không có cơ chế đa người dùng hay giao dịch đồng thời.

# Quên mật khẩu bằng OTP qua Gmail

Trang khách hàng: `/login` → **Quên mật khẩu?** → nhập email đã đăng ký → nhập OTP → đặt và xác nhận mật khẩu mới.

## Cấu hình gửi email thật

1. Chọn một Gmail của cửa hàng để gửi email. Bật xác minh hai bước và tạo **Mật khẩu ứng dụng** theo [hướng dẫn Google](https://support.google.com/mail/answer/185833?hl=en).
2. Thêm các dòng dưới vào `backend/.env` ở máy chạy Docker. Thay giá trị mẫu bằng thông tin của cửa hàng; không dùng mật khẩu đăng nhập Gmail thông thường.

```dotenv
MAIL_ENABLED=true
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=dia-chi-cua-hang@gmail.com
MAIL_PASSWORD=mat-khau-ung-dung
MAIL_FROM=dia-chi-cua-hang@gmail.com
MAIL_AUTH=true
MAIL_STARTTLS=true
```

3. Từ thư mục `backend`, chạy `docker compose up -d --build api`. Khi chỉ đổi cấu hình email sau khi đã build chức năng này, chạy `docker compose up -d api`.
4. Dùng email của tài khoản **khách hàng** đã đăng ký để thử. Kiểm tra cả thư rác. Nếu Google không cho tạo mật khẩu ứng dụng, cần dùng SMTP khác hoặc cấu hình tài khoản Google phù hợp.

File `.env` đã được Git bỏ qua. Không đưa mật khẩu ứng dụng vào mã nguồn, SQL hoặc cuộc trò chuyện. Khi chưa cấu hình, ứng dụng vẫn hoạt động; yêu cầu gửi OTP trả thông báo chức năng chưa được cấu hình.

`YOUR_NEW_APP_PASSWORD` chỉ là chữ giữ chỗ, không phải mật khẩu dùng được. Phải thay bằng mật khẩu ứng dụng do Google cấp. Các yêu cầu bị từ chối vì thiếu cấu hình không tính vào giới hạn gửi OTP; các lần bấm lại trong 60 giây cũng không trừ thêm lượt gửi trong giờ. Khi đạt giới hạn, thông báo cho biết số giây cần chờ.

## Quy tắc

- Chỉ tài khoản khách hàng đang hoạt động, hoặc bị khóa vì nhập sai mật khẩu quá nhiều, mới được khôi phục. Tài khoản nhân viên/quản trị hoặc bị vô hiệu hóa không dùng luồng này.
- OTP sáu chữ số có hiệu lực năm phút, tối đa năm lần nhập sai. Gửi lại sau ít nhất 60 giây; mã cũ hết hiệu lực khi cấp mã mới.
- Email tồn tại và không tồn tại nhận cùng thông báo để tránh lộ danh sách tài khoản. Chỉ email phù hợp mới nhận thư.
- Xác minh thành công mới cấp quyền đặt mật khẩu trong năm phút. OTP và quyền đặt mật khẩu chỉ dùng một lần; cơ sở dữ liệu chỉ lưu bản băm.
- Mật khẩu tối thiểu tám ký tự, tối đa 72 byte UTF-8. Đổi thành công sẽ thu hồi các phiên đăng nhập cũ; khách hàng đăng nhập lại bằng mật khẩu mới.
- Có giới hạn gửi/xác minh theo IP và email trong bộ nhớ của từng API instance. Khi triển khai nhiều instance cần thay bộ giới hạn này bằng kho dùng chung.
- SMTP gửi bất đồng bộ sau khi lưu yêu cầu. Lỗi gửi được ghi bằng mã yêu cầu, không ghi OTP hoặc mật khẩu. Người dùng có thể gửi lại sau thời gian chờ.

Migration `20261108_customer_password_reset` tự tạo bảng `password_reset_challenge` khi API khởi động. Không thay đổi mật khẩu hoặc dữ liệu khách hàng hiện có. Bản SQL trong project đã có cấu trúc bảng này, không chứa OTP thử nghiệm.

# WaterBus — Frontend cửa hàng nước giải khát

Frontend độc lập được xây dựng mới trong thư mục này. Không sử dụng mã nguồn của soda-web hoặc soda-db.

## Chạy trên máy

Yêu cầu Node.js 22.12+ (đã kiểm tra bằng Node 26) và npm.

```powershell
cd D:\NgocSon\WaterBus\frontend
npm.cmd install
npm.cmd run dev
```

Mở **http://127.0.0.1:5173**. Dùng npm.cmd trên PowerShell nếu npm.ps1 bị chặn bởi Execution Policy.

```powershell
npm.cmd run build
npm.cmd run preview
npm.cmd run lint
npm.cmd test
npm.cmd run test:e2e
npm.cmd run format:check
```

Preview bản build: http://127.0.0.1:4173. Nếu đưa lên hosting, cấu hình mọi đường dẫn ứng dụng trả về index.html để BrowserRouter hoạt động.

## Tài khoản trải nghiệm

Tại trang đăng nhập có ba nút điền nhanh. Mật khẩu chung: **Demo@123**.

| Vai trò       | Email                  |
| ------------- | ---------------------- |
| Khách hàng    | khach@waterbus.demo    |
| Nhân viên     | nhanvien@waterbus.demo |
| Quản trị viên | admin@waterbus.demo    |

Khách có thể đăng ký tài khoản mẫu. ADMIN có thể thêm tài khoản, đổi vai trò và khóa tài khoản mẫu. Không thể khóa/hạ quyền tài khoản quản trị đang sử dụng. Tài khoản mới do quản trị tạo đăng nhập bằng mật khẩu mẫu đã nhập.

**Đây không phải xác thực production.** Phiên mẫu dùng sessionStorage, dữ liệu nghiệp vụ dùng localStorage. Không nhập thông tin hoặc mật khẩu thật. Mã băm trong mock chỉ tránh lưu mật khẩu nguyên văn, không phải thiết kế bảo mật phía máy chủ.

## Chức năng

- Cửa hàng: trang chủ, tìm kiếm không dấu, danh mục, thương hiệu, mức giá, còn hàng, ưu đãi, sắp xếp và phân trang.
- Chi tiết: minh họa bao bì SVG, giá, tình trạng, số lượng, thông tin và sản phẩm cùng danh mục.
- Giỏ hàng: tăng/giảm số lượng, kiểm tra tồn mẫu, xác nhận xóa, tổng tiền và phí giao hàng mẫu.
- Đặt hàng: form có validation, chỉ COD mô phỏng, xác nhận trước khi tạo đơn; không thu tiền hoặc gửi đơn thật.
- Tài khoản: đăng nhập, đăng ký, đăng xuất, cập nhật thông tin, danh sách/chi tiết đơn của mình, hủy đơn chờ kèm lý do.
- Vận hành: dashboard, biểu đồ doanh thu, sản phẩm, danh mục, nhập hàng, đơn hàng, khách hàng, báo cáo theo thời gian.
- ADMIN: các chức năng STAFF, quản lý tài khoản, sản phẩm và tồn kho. Nhân viên không được sửa sản phẩm hoặc nhập kho.
- Responsive: menu điện thoại, bộ lọc thu gọn, sidebar thu gọn, bảng cuộn trong vùng riêng.
- UI: Radix/shadcn-style Button, Dialog, AlertDialog; trạng thái tải, skeleton, rỗng, lỗi, toast và focus bàn phím.

Quản lý ưu đãi riêng, đánh giá, upload ảnh thật, thanh toán online, khôi phục/đổi mật khẩu và tích hợp backend **chưa triển khai** do chưa có hợp đồng API hay Use Case để xác minh. Giá ưu đãi trên cửa hàng là dữ liệu mẫu.

## Công nghệ và cấu trúc

React 18, Vite, JavaScript JSX, Tailwind CSS 4, các primitive Radix theo cấu trúc shadcn/ui, Lucide, React Router, Axios, React Hook Form, Zod, TanStack Query, Recharts, Sonner. Có components.json và alias @ để bổ sung shadcn component.

- src/components/ui: Button, Dialog, AlertDialog trong mã nguồn dự án.
- src/components/common: form field có nhãn truy cập, trạng thái trang, bảng đơn hàng, phân trang.
- src/components/customer: thẻ sản phẩm, minh họa SVG tự chứa; không phụ thuộc ảnh bên ngoài.
- src/layouts: CustomerLayout, AdminLayout, AuthLayout.
- src/pages: màn hình khách hàng, đăng nhập và quản lý.
- src/contexts: AuthContext và CartContext.
- src/hooks: truy vấn/mutation, invalidation và thông báo lỗi.
- src/schemas: validation dùng chung.
- src/services: điểm truy cập dữ liệu và lớp Axios chờ tích hợp.
- src/mocks: dữ liệu và bộ lưu trữ cục bộ; không lấy dữ liệu từ backend khác.
- src/routes: ProtectedRoute, RoleGuard, PermissionGuard.
- tests: kiểm thử logic và Chrome E2E.
- docs: phạm vi, ánh xạ chức năng, hướng dẫn tích hợp, báo cáo kiểm tra và ảnh.

Toàn bộ ứng dụng nằm trong thư mục frontend/. Chạy các lệnh npm tại thư mục này; mã nguồn, tài nguyên, kiểm thử và cấu hình đều được đóng gói cùng nhau. Các trang ngoài trang chủ tải bằng lazy để không đưa biểu đồ vào gói khởi đầu.

## Dữ liệu mẫu và quy tắc thử nghiệm

Sản phẩm còn từ 20 trở xuống hiển thị tạm hết hàng và khóa mua; quản trị nhận cảnh báo sắp hết hàng. Quản trị được chỉnh số lượng; ngừng kinh doanh giữ nguyên sản phẩm trong danh sách để có thể bật bán lại.

Dữ liệu seed: 16 sản phẩm, 6 danh mục, 3 tài khoản và 18 đơn hàng mẫu. Dữ liệu chỉnh sửa giữ lại khi tải lại trang trên cùng trình duyệt/origin.

Phí mẫu: 20.000đ cho đơn có sản phẩm. Chỉ miễn phí giao hàng khi khách chọn voucher FREESHIP200 và tạm tính từ 200.000đ; không tự động miễn phí theo giá trị đơn. Tổng tiền luôn tính lại từ giá trong danh mục; không nhận giá do giỏ truyền vào.

Luồng đơn mẫu: PENDING → CONFIRMED → SHIPPING → COMPLETED. Có thể hủy trước hoàn thành, bắt buộc lý do. Tạo đơn trừ tồn kho ngay; xác nhận không trừ lại; hủy đơn chờ/xác nhận/giao hoàn lại số lượng đã giữ. Nhập hàng cộng kho mẫu sau xác nhận. Tất cả chỉ phục vụ frontend, không phải đặc tả nghiệp vụ backend đã xác minh.

Muốn khôi phục seed: mở DevTools → Application → Local Storage, xóa khóa waterbus.mock.v1 và waterbus.cart; xóa waterbus.mock.session trong Session Storage rồi tải lại. Chỉ thực hiện khi đồng ý mất các thay đổi mẫu.

Các tab cùng trình duyệt cập nhật sản phẩm/tồn kho qua sự kiện storage. Không đồng bộ giữa các trình duyệt/người dùng; localStorage không có giao dịch hoặc khóa đồng thời như database thật. Mất quyền lưu trữ có thể làm mất dữ liệu sau khi tải lại.

## Tích hợp backend sau này

Xem [báo cáo phạm vi và tích hợp](docs/IMPLEMENTATION.md). Không có API thật nào được tuyên bố là đã tồn tại. VITE_DATA_MODE=api hiện báo lỗi rõ ràng và không tự rơi về dữ liệu giả. Base URL đặt bằng VITE_API_BASE_URL; không đưa secrets vào biến VITE_*.

Cần thay service adapter bằng endpoint, request/response DTO, enum, cơ chế xác thực và quy tắc phân quyền đã xác minh. Axios hiện xử lý lỗi HTTP cơ bản nhưng chưa gắn token/cookie tự động khi chưa biết hợp đồng. Không lưu token backend trong localStorage.

## Kiểm tra giao diện

Playwright dùng Chrome đã cài trong máy (channel chrome), không tự tải browser. Có thể đổi channel sang msedge trong playwright.config.js nếu máy chỉ có Edge. Bộ kiểm tra tự khởi động và tắt Vite, dùng dữ liệu trình duyệt riêng, không ghi đè dữ liệu trải nghiệm của người dùng.

Font Be Vietnam Pro tải từ Google Fonts khi có mạng; nếu offline, trình duyệt dùng sans-serif hệ thống. Minh họa sản phẩm hoạt động offline.

Ảnh kiểm tra nằm ở docs/screenshots/. Kết quả thực tế được ghi trong docs/VALIDATION.md.

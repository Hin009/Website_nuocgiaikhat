# Ghép frontend với schema 13UC mới

Base URL `http://localhost:8080/api/v1`, đăng nhập/đăng ký bằng email. Dùng [client TypeScript](../examples/frontend/api.ts).

Catalog trả `packages` gồm ID quy cách, tên quy cách, đơn vị, hệ số, giá và lượng có thể mua. `gia_tu` là giá thấp nhất của quy cách đang bán. Giỏ và dòng nhập dùng **packageId**, không dùng productId. Yêu thích và chi tiết catalog vẫn dùng ID sản phẩm. Giá vốn không trả cho khách. Giá giỏ thay đổi cần cập nhật lại trước checkout.

Các trạng thái online giữ CHO_XAC_NHAN/DANG_CHUAN_BI/DANG_GIAO/DA_GIAO/DA_HUY/TU_CHOI. Tổng đơn `tong_tien`, tổng hóa đơn `tong_thanh_toan`. SQL có kênh ONLINE/TAI_QUAY nhưng API hiện có chỉ xử lý đơn online.

Vai trò là danh sách nhiều mã qua bảng nối; quyền trả danh sách mã. `/management/roles` trả roles/grants/permissions. Thêm vai trò không thay vai trò cũ. Cả thêm/gỡ đều thu hồi phiên; cần đăng nhập lại. Ba mã vai trò cố định, chỉ chỉnh tên hiển thị/mô tả và quyền. Nhân viên không có quyền lập/duyệt đơn NCC theo seed mới.

Công nợ mỗi dòng gắn với một lần nhập (`lan_nhap_id`), không gộp theo đơn NCC. Giấy tờ nhà cung cấp dùng resource `supplier-documents`. Liên kết nhà cung cấp–sản phẩm dùng hai ID ở endpoint chi tiết/xóa.

Xem [API](API.md) cho trường snake_case của CRUD. Xử lý HTTP 400/401/403/404/409. Kiểm tra quyền phía frontend chỉ phục vụ giao diện; server vẫn kiểm tra.

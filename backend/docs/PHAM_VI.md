# Phạm vi theo SQL 13UC hoàn chỉnh

Nguồn schema hiện tại: `database/beverage_store_13UC_HOAN_CHINH.sql`, gồm 44 bảng. [Ánh xạ lớp](CLASS_MAPPING.md), [API](API.md), [Docker](../README.md).

Các luồng đã chuyển: đăng nhập email, phân quyền qua bảng nối, catalog/quy cách, giỏ/đơn online, nhập hàng nhiều đợt, công nợ theo lần nhập, thanh toán thủ công, hóa đơn, hồ sơ/địa chỉ/yêu thích/đánh giá, CRUD quản trị và báo cáo.

Chưa bổ sung API mới cho POS, điều chỉnh tồn, liên hệ khách hàng hay ưu đãi số lượng dù SQL mới có bảng/hàm tương ứng. Chưa tích hợp cổng thanh toán, gửi email, lưu file ảnh hoặc di chuyển dữ liệu từ database cũ. Volume cũ được giữ lại; ứng dụng chuyển sang volume mới.

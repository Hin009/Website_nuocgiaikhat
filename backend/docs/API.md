# API với database 13UC hoàn chỉnh

Base `/api/v1`. Bearer token cho API ngoài catalog/health/login/register. Phân trang `page=0&size=20`, tối đa 100, trả `{items,page,size,total}`. Các ID lấy từ response.

## Đăng nhập và quản trị quyền

`POST /auth/register`: `{email,password,fullName}`. `POST /auth/login`: `{email,password}` → accessToken, expiresAt, user. `GET /auth/me`: account, roles (mã vai trò), permissions (mã quyền). `POST /auth/logout` thu hồi token; `PUT /auth/password`: `{oldPassword,newPassword}`, thu hồi mọi phiên.

Ba mã vai trò cố định KHACH_HANG/NHAN_VIEN/QUAN_TRI_VIEN; một tài khoản có thể được gán nhiều vai trò. `GET /management/roles` trả `roles`, `grants`, `permissions`. `PUT /management/roles/{id}`: `{name,description}` sửa tên hiển thị/mô tả, không đổi mã. Không tạo/xóa thêm vai trò ngoài ba vai trò do SQL quy định. `PUT /management/roles/{id}/permissions`: `{permissionIds:[...]}` cập nhật bảng nối quyền.

`PUT /management/accounts/{account}/roles/{role}` thêm vai trò; `DELETE` gỡ vai trò, phải giữ lại ít nhất một vai trò. Cần hồ sơ nhân viên ACTIVE trước khi gán NHAN_VIEN/QUAN_TRI_VIEN. Thay đổi vai trò thu hồi phiên. Không tự thay vai trò của tài khoản quản trị đang dùng.

## Catalog, giỏ và đơn

| Method | Endpoint | Nội dung |
|---|---|---|
| GET | `/catalog/products` | q, categoryId, brandId, inStock, sort=newest/name/priceAsc/priceDesc |
| GET | `/catalog/products/{id}` | Sản phẩm, tồn cơ bản, packages và images |
| GET | `/catalog/categories`, `/catalog/brands`, `/catalog/promotions` | Danh mục hiển thị |
| GET | `/catalog/products/{id}/reviews` | Đánh giá đã duyệt |
| GET | `/cart?couponCode=...` | Tính giá theo quy cách hiện tại |
| PUT | `/cart/items/{packageId}` | `{quantity}`; ID quy cách |
| DELETE | `/cart/items/{packageId}` | Bỏ quy cách |
| POST | `/orders/quote` | `{packageIds,couponCode}` → subtotal, discount, shippingFee, total |
| POST | `/orders` | `{addressId,paymentMethod,note,couponCode,packageIds?}`; bỏ packageIds để đặt toàn bộ giỏ |
| GET | `/orders`, `/orders/{id}` | Đơn của khách đăng nhập |
| POST | `/orders/{id}/cancel`, `/orders/{id}/reorder` | Hủy đơn chờ / mua lại |
| GET | `/staff/orders`, `/staff/orders/{id}` | ORDER_UPDATE; danh sách lọc status |
| PATCH | `/staff/orders/{id}/status` | `{status,note?}`; ORDER_UPDATE |

`packages` gồm id, san_pham_id, ten_quy_cach, don_vi_tinh, he_so_quy_doi, gia_ban, so_luong_co_the_mua. Giá vốn không trả cho khách. Giỏ dùng `quy_cach_id`; tổng đơn là `tong_tien`. Đơn online bắt đầu CHO_XAC_NHAN → DANG_CHUAN_BI → DANG_GIAO → DA_GIAO. Hủy DA_HUY trước khi giao xong; TU_CHOI chỉ khi chờ. Khách chỉ hủy đơn chờ. Xác nhận trừ tồn theo hệ số, ghi lượt coupon và trigger lập hóa đơn. Hủy hoàn tồn và đảo lượt coupon. Giá coupon tính theo phạm vi ALL/PRODUCT/CATEGORY/BRAND; ưu đãi số lượng/tặng hàng chưa được tính tại checkout.

## Nhập và công nợ

| Method | Endpoint | Nội dung |
|---|---|---|
| POST | `/purchases` | `{supplierId,expectedDate,items:[{packageId,quantity,unitCost}]}`; IMPORT_CREATE |
| GET | `/purchases`, `/purchases/{id}` | IMPORT_READ |
| PATCH | `/purchases/{id}/status` | `{status,reason}`; admin + IMPORT_APPROVE |
| POST | `/purchases/{id}/receipts` | `{items:[{purchaseLineId,quantity,actualCost}]}`; IMPORT_RECEIVE |
| GET | `/receipts/{id}` | IMPORT_RECEIVE |
| POST | `/receipts/{id}/confirm` | IMPORT_RECEIVE; xác nhận DRAFT |
| GET | `/debts` | admin; mỗi dòng ứng với một lần nhập |
| POST | `/debts/{id}/payments` | `{amount,method,reference}`; admin |

Đơn dùng CHO_DUYET/DA_DUYET/TU_CHOI/DANG_GIAO/DA_NHAN_MOT_PHAN/DA_NHAN_DU/DA_HUY. Từ chối cần reason. Lần nhận DRAFT/CONFIRMED/CANCELLED. `quantity` là số lượng thực nhận đủ điều kiện nhập của quy cách; quy đổi sang tồn cơ bản theo hệ số chụp trên dòng đơn NCC. Trigger kiểm tra không nhận vượt đơn, ghi biến động và tạo công nợ **theo từng lần nhập**, không gộp một dòng công nợ cho toàn đơn. Xác nhận lặp không ghi hai lần.

Seed mới: NHAN_VIEN được IMPORT_READ/IMPORT_RECEIVE, không được IMPORT_CREATE/IMPORT_APPROVE.

## Hóa đơn, thanh toán và khách hàng

`GET /orders/{id}/invoice` (khách sở hữu). `GET /staff/orders/{id}/invoice`, `/staff/invoices`: INVOICE_READ. `GET /staff/payments`, `POST /staff/payments/{id}/received` với `{reference}`: PAYMENT_READ. COD chỉ thu sau DA_GIAO; BANK_TRANSFER cần mã đối soát. Chưa tích hợp cổng thanh toán. `POST /management/payments/{id}/manual-refund`: `{reason}`, admin + REFUND_MANAGE, chỉ đơn hủy/từ chối đã thu tiền; ghi người xử lý và thời gian hoàn. Tổng hóa đơn `tong_thanh_toan`.

`GET/PUT /me/profile`: `{fullName,phone,avatar}`. `GET/POST /me/addresses`, `PUT/DELETE /me/addresses/{id}`: `{recipient,phone,province,district,ward,street,isDefault}`. `GET /me/favorites`, `PUT/DELETE /me/favorites/{productId}` vẫn dùng **ID sản phẩm**. `POST /me/reviews`: `{orderLineId,rating,comment}`, chỉ dòng đơn đã giao thuộc khách đó. `PATCH /staff/reviews/{id}` với `{visible}` duyệt/ẩn đánh giá. `GET /staff/customers`, `/staff/customers/{id}/orders`: CUSTOMER_READ.

## Quản lý dữ liệu

CRUD `/management/{resource}`: GET list, POST create; `/{id}`: GET detail, PATCH update, DELETE. Chỉ admin; trường snake_case trong allowlist `ManagementService.RESOURCES`.

| Resource | Bảng / trường cần lưu ý |
|---|---|
| products | san_pham; sku, loai_san_pham_id, thuong_hieu_id, ten, thông tin mô tả, trạng thái, hiển thị; không có giá/tồn ở đây |
| packages | quy_cach_san_pham; san_pham_id, ten_quy_cach, don_vi_tinh, he_so_quy_doi, gia_ban, gia_von, dang_ban |
| categories / brands / images | loai_san_pham / thuong_hieu / hinh_anh_san_pham |
| suppliers | nha_cung_cap; không còn giấy ATTP trực tiếp trên bảng |
| supplier-documents | giay_to_ncc; nha_cung_cap_id, loai_giay, so_giay, ngay_cap, ngay_het_han, tep_dinh_kem |
| supplier-products | nha_cung_cap_san_pham; khóa ghép nha_cung_cap_id + san_pham_id, gia_nhap_tham_khao |
| promotions | khuyen_mai; ma_code, ten, loai_giam, gia_tri_giam, thời hạn, giới hạn và pham_vi_ap_dung |
| promotion-scopes | pham_vi_khuyen_mai; khuyen_mai_id và đúng một trong san_pham_id/loai_san_pham_id/thuong_hieu_id |

`POST /management/supplier-products` tạo liên kết; `GET/DELETE /management/supplier-products/{supplierId}/{productId}` dùng hai ID vì bảng không có ID đơn. Danh sách vẫn dùng `GET /management/supplier-products`. Thay giá tham khảo có thể xóa rồi tạo lại liên kết. Quy cách đã có giao dịch không được đổi sản phẩm/hệ số. Không sửa tồn trực tiếp qua CRUD.

`GET/POST /management/employees`: tạo `{email,password,fullName,phone,position}`; mã nhân viên tự sinh. `PUT /management/employees/{id}` và `/staff/profile`: `{fullName,birthDate,gender,phone,address}`. `PATCH /management/employees/{id}/employment`: `{status,position}` ACTIVE/ON_LEAVE/RESIGNED. `GET /staff/profile`. Quản trị: `GET /management/accounts`; PATCH `/{id}/status` `{status}` ACTIVE/LOCKED/DISABLED; PUT `/{id}/password` `{password}`; `GET /management/audit`. Các quyền tương ứng được kiểm tra trong controller.

Báo cáo: `GET /staff/reports/stock?lowOnly=true`, `/staff/reports/purchases?from=...&to=...`; admin `/management/reports/revenue?from=...&to=...&group=day|week|month|quarter|year`, `/order-status`, `/promotions`, `/expiring-documents` (các đường dẫn cuối cùng thuộc `/management/reports`). Doanh thu tính đơn DA_GIAO/HOAN_TAT.

SQL mới có các bảng và hàm POS, liên hệ khách hàng, điều chỉnh tồn, ưu đãi số lượng; lần thay database này chưa thêm API mới cho các tính năng đó. Các API hiện có đã được sửa để chạy với schema mới.


## Endpoint hỗ trợ frontend

- `GET /receipts`: phân trang từng lần nhận kèm items và tên nhà cung cấp; cần IMPORT_READ.
- `GET /management/accounts`: hồ sơ/tên và mảng mã roles; không trả mật khẩu.
- `POST /management/account-editor`, `PUT /management/account-editor/{id}`: `{email,fullName,phone,role,active,password?}`. Vai trò dùng mã tiếng Việt. Tạo mới bắt buộc password; không đổi email cũ. Giữ các vai trò phụ khi vai trò chính không đổi; đổi vai trò chính thay danh sách bằng vai trò đã chọn. Đổi vai trò/trạng thái/mật khẩu thu hồi phiên. Cần quản trị và ROLE_MANAGE.
- `POST /management/product-editor`, `PUT /management/product-editor/{id}`: `{fullName,brand,categoryId,volume,description,price,active,packageId?,packaging}`; packaging LON/CHAI/HOP. Lưu sản phẩm/thương hiệu/giá trong một giao dịch; xem các trường ảnh và điều chỉnh tồn bổ sung bên dưới. Tạo mới có một quy cách hệ số 1. Cập nhật packageId thuộc sản phẩm để sửa giá quy cách đó; bỏ trống tạo quy cách lẻ. Cần quản trị và PRODUCT_MANAGE.
- Đăng ký nhận thêm phone tùy chọn. Hủy đơn nhận body `{note}` tùy chọn để ghi lịch sử.
- Quote/checkout chỉ dùng packageIds thuộc giỏ đăng nhập, không nhận giá frontend. Checkout chỉ xóa dòng đã chọn.


## Ảnh sản phẩm và tồn kho trong form quản trị

- `POST /management/product-images`: multipart `file`, cần admin và PRODUCT_MANAGE. Nhận JPG/PNG/WebP (kiểm tra nội dung đầu file), tối đa 5 MB. Trả `{url}` để đưa vào imageUrl khi lưu sản phẩm.
- `GET /media/products/{filename}`: đọc ảnh công khai. Tên file UUID do server sinh, không dùng tên file khách gửi.
- Product-editor nhận thêm `imageUrl?`, `stock?`, `expectedStock?`, `stockReason?`. imageUrl http/https hoặc đường dẫn ảnh đã tải lên; bỏ trống giữ ảnh cũ, URL mới thay ảnh chính và giữ các ảnh phụ.
- stock là tồn cơ bản, từ 0 đến 1.000.000.000. Khi sửa sản phẩm cũ, gửi expectedStock là tồn đã đọc lúc mở form; khác tồn hiện tại trả 409. Không thay tồn thì bỏ stock/null. Nếu đổi số lượng phải có stockReason.
- Việc lưu sản phẩm, giá, ảnh và điều chỉnh tồn nằm trong cùng một giao dịch. Ghi `dieu_chinh_so_luong` để trigger tạo `bien_dong_so_luong`; không cập nhật trực tiếp `so_luong_san_pham`. Mọi chỉnh tồn cần admin, PRODUCT_MANAGE và hồ sơ nhân viên ACTIVE.


## Tùy chọn thanh toán và miễn phí giao hàng

`GET /catalog/checkout-options` công khai trả `{shippingFee,paymentMethods:[{code,label,description}]}`. Mặc định `app.shipping-fee: 0`, frontend lấy cùng giá trị này để hiển thị miễn phí giao hàng. Quote và checkout dùng cùng cấu hình; không sửa phí của đơn cũ.

Checkout nhận `paymentMethod` COD hoặc BANK_TRANSFER. Cả hai tạo thanh toán PENDING với số tiền thực tế của đơn. Chuyển khoản là quy trình xác nhận thủ công của cửa hàng, yêu cầu mã đối soát khi xác nhận qua API billing; không tự đánh dấu đã thanh toán khi tạo đơn.

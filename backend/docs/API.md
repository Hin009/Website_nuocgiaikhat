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

`GET /catalog/checkout-options` trả thêm `bankTransfer` gồm `bankId`, `bankName`, `accountNumber`, `accountName`. Cấu hình trong `.env`: `BANK_TRANSFER_BANK_ID` (mã ngân hàng VietQR hoặc BIN), `BANK_TRANSFER_BANK_NAME`, `BANK_TRANSFER_ACCOUNT_NUMBER`, `BANK_TRANSFER_ACCOUNT_NAME`; khởi động lại API để áp dụng. Giao diện tạo ảnh QR theo [VietQR Quick Link](https://www.vietqr.io/qr-dong), hiển thị số tài khoản và tên tài khoản bên dưới. Nếu chưa cấu hình đủ thì hiển thị thông báo chưa có thông tin tài khoản. QR trước đặt hàng chỉ chứa tài khoản nhận; sau khi đặt thành công, QR có thêm số tiền và nội dung là mã đơn.

Checkout tự điền địa chỉ mặc định (hoặc địa chỉ đầu tiên), cho phép sửa trực tiếp các trường. Client dùng lại địa chỉ khớp thông tin đã nhập; khi sửa thông tin sẽ tạo địa chỉ mới không mặc định rồi dùng ID đó đặt đơn, giữ nguyên địa chỉ đã lưu trước đó.

`GET /catalog/promotions` trả thêm `pham_vi_ap_dung` và `scopes` (các ID sản phẩm/danh mục/thương hiệu áp dụng). Checkout đối chiếu với các dòng giỏ hàng đang chọn để làm mờ và khóa voucher không có sản phẩm phù hợp hoặc chưa đạt giá trị tối thiểu. Hạn sử dụng hiển thị `HSD: DD.MM.YYYY` theo múi giờ Việt Nam. API tính giá và đặt đơn vẫn kiểm tra đầy đủ điều kiện áp dụng trước khi giảm tiền.


## Trang quản trị nhà cung cấp và mã khuyến mãi

Các API dưới đây yêu cầu QUAN_TRI_VIEN, đồng thời SUPPLIER_MANAGE hoặc PROMOTION_MANAGE tương ứng:

- `POST /management/supplier-editor`, `PUT /management/supplier-editor/{id}` nhận `{fullName,taxCode?,contactName?,phone?,email?,address?,status,supplierType,productIds?}`. Status HOP_TAC/NGUNG_HOP_TAC. Không yêu cầu xác minh pháp lý. Trả dòng nhà cung cấp theo tên cột database. `PATCH /management/supplier-editor/{id}/status` nhận `{status}`, giữ nguyên các thông tin và lịch sử khác.
- Danh sách nhà cung cấp vẫn dùng `GET /management/suppliers`. Đơn nhập mới chỉ nhận nhà cung cấp HOP_TAC.
- `GET /management/promotion-editor`: phân trang, trả thêm `scope_ids` và `luot_da_dung` (APPLIED) trên mỗi dòng khuyến mãi.
- `POST /management/promotion-editor`, `PUT /management/promotion-editor/{id}` nhận `{code,fullName,description?,discountType,value,maxDiscount?,minimumOrder,startsAt,endsAt,totalLimit?,customerLimit?,scope,scopeIds,status}`. DiscountType PERCENT/FIXED; status ACTIVE/INACTIVE. StartsAt/endsAt là ISO có offset; kết thúc phải sau bắt đầu. Value > 0, phần trăm không vượt 100; tối đa hai chữ số thập phân. Mã chuẩn hóa chữ hoa, gồm chữ/số/gạch ngang/gạch dưới.
- Scope chỉ CATEGORY/BRAND; cần ít nhất một ID tồn tại. Mã dùng phạm vi cũ vẫn được đọc và bật/tắt; khi chỉnh sửa phải chọn phạm vi mới. Dữ liệu mã và phạm vi được lưu trong một transaction, không để trạng thái lưu dở khi một ID sai. Giới hạn lượt dùng null là không giới hạn, 0 là hết lượt.
- `PATCH /management/promotion-editor/{id}/status` nhận `{status}` để bật/ngừng mà không đổi phạm vi hay điều kiện. Không xóa lịch sử sử dụng mã.
- Form này quản lý mã giảm giá; quy tắc tặng hàng riêng trong uu_dai_so_luong không được ghi đè bằng form này.


### Hồ sơ pháp lý và điện thoại

- Form mới chọn `supplierType`: DOANH_NGHIEP / HO_KINH_DOANH. CA_NHAN được giữ để tương thích hồ sơ cũ.
- Mã số thuế có thể để trống; nếu nhập thì phải gồm đúng 10 chữ số ASCII, giữ nguyên số 0 đầu. Giao diện và API cùng kiểm tra định dạng. Ràng buộc không trùng mã trong database vẫn được giữ.
- `POST /management/supplier-tax-check` nhận `{supplierId?,supplierType,taxCode}`, trả `{taxCode,duplicate,message}`: chỉ kiểm tra định dạng và trùng lặp, không xác minh pháp lý tự động.
- Form nhà cung cấp đã bỏ hồ sơ pháp lý, liên kết tra cứu, nút kiểm tra riêng, trạng thái và ghi chú xác minh. Các cột xác minh cũ được giữ trong database để bảo toàn dữ liệu lịch sử; supplier-editor không cần và không ghi nhận xác nhận pháp lý mới.
- Địa chỉ nhà cung cấp chọn tỉnh/thành phố, phường/xã và nhập số nhà/tên đường. Giao diện ghép thành chuỗi `address` để lưu trong `dia_chi`; mở lại sẽ tách địa chỉ để điền các lựa chọn. Địa chỉ cũ chưa có tỉnh/phường được giữ trong ô số nhà/tên đường, không tự đoán vị trí. Đổi tỉnh sẽ xóa lựa chọn phường cũ.
- Điện thoại toàn hệ thống: đúng 10 hoặc 11 chữ số ASCII, không nhận `+84`, khoảng trắng, dấu gạch hoặc chữ. Trường vốn không bắt buộc vẫn được để trống; điện thoại giao hàng bắt buộc. API kiểm tra cả đăng ký, hồ sơ khách/nhân viên, quản trị tài khoản, nhà cung cấp và địa chỉ tại checkout. Dữ liệu lịch sử không tự sửa.
- API tự bổ sung cột pháp lý vào volume hiện có khi khởi động; SQL tổng hợp đã gồm cùng cấu trúc cho máy mới. Không xóa volume.

Nguồn định dạng/tra cứu: [Bộ Tài chính](https://mof.gov.vn/tin-tuc-tai-chinh/tin-tuc-su-kien-8/tu-17-dung-so-dinh-danh-ca-nhan-thay-ma-so-thue), [hướng dẫn Chính phủ](https://xaydungchinhsach.chinhphu.vn/huong-dan-tra-cuu-ma-so-thue-119260730155655352.htm).
## Hàng lỗi, trả nhà cung cấp và lãi gộp sản phẩm

- `POST /purchases/{id}/receipts`: mỗi dòng thêm `rejectedQuantity` và `rejectionReason`. `quantity` là lượng hàng đạt nhập kho; lượng lỗi có thể bằng toàn bộ lần giao. Tổng đạt + lỗi không vượt lượng còn chờ xử lý; có hàng lỗi phải ghi lý do. Hàng từ chối được giao trả ngay khi xác nhận lần nhận, không cộng tồn/công nợ. Cả hàng đạt và hàng lỗi đã trả đều tính vào số lượng đã xử lý: đặt 99, nhập 90, trả lỗi 9 → DA_NHAN_DU; không chờ giao bù phần đã trả.
- `GET /receipts`: mỗi dòng thêm `so_luong_co_the_tra` (đã trừ phiếu trả đang cách ly/đã xác nhận). Hàng từ chối tại cửa nhận không được trả lần nữa bằng phiếu trả kho.
- `GET /supplier-returns`: phân trang lịch sử chung, cần IMPORT_READ. Bao gồm `source=WAREHOUSE_RETURN` (phiếu trả từ kho) và `source=RECEIPT_REJECTION` (hàng lỗi trả ngay trong lần nhận CONFIRMED). Mỗi bản ghi có `history_key` duy nhất (`return-{id}` / `receipt-{id}`); ID số giữa hai nguồn có thể trùng. Hàng trả khi nhận có mã TRA-NHAN-{receiptId}, dòng lỗi/lý do, ngày xác nhận và giá trị hàng không nhập. Đây là lịch sử suy ra trực tiếp từ chứng từ kiểm nhận đã lưu, không ghi phiếu trả kho, trừ tồn, giảm công nợ hoặc tạo tiền hoàn thêm. Chỉ WAREHOUSE_RETURN được dùng với API thao tác phiếu/nhận hoàn tiền.
- Tất cả ghi sổ tồn/công nợ/phiếu trả/tiền hoàn nằm trong transaction, khóa đơn nhập → lần nhận → phiếu trả, khóa tồn theo ID sản phẩm tăng dần. Có nhật ký hoạt động; dòng phiếu và lịch sử hoàn tiền không được sửa/xóa.

`GET /management/reports/product-profit?from=YYYY-MM-DD&to=YYYY-MM-DD` cần admin + REPORT_ALL. Bỏ cả hai ngày để xem toàn bộ; có ngày phải gửi đủ hai, tối đa 5 năm. Ngày tính theo Asia/Ho_Chi_Minh. Trả từng sản phẩm, kể cả sản phẩm chưa giao dịch:

- `import_amount`: giá nhập thực tế × lượng hàng đạt của lần nhận đã xác nhận trong kỳ.
- `net_sales`: doanh thu đơn DA_GIAO/HOAN_TAT, lọc theo ngày đặt đơn, trừ giảm giá phân bổ tỷ lệ theo giá trị dòng; phần lẻ được dồn về dòng cuối để tổng khớp. Không gồm phí vận chuyển.
- `cost_of_goods`: số quy cách bán × giá vốn mỗi quy cách được chốt lúc xuất kho. Giá vốn bình quân cập nhật khi xác nhận nhập: `(tồn cơ bản trước × giá vốn cơ bản trước + giá trị nhập mới) / (tồn cơ bản trước + số cơ bản nhập mới)`; mọi quy cách cùng sản phẩm được cập nhật theo hệ số. Giá vốn đơn online chốt khi DANG_CHUAN_BI, POS chốt khi bán; không thay chứng từ bán cũ.
- `gross_profit = net_sales - cost_of_goods`; tỷ suất `% = gross_profit / net_sales × 100`. Đây là lãi gộp hàng đã bán, chưa trừ vận hành, thuế hay chênh lệch định giá khi trả hàng; không phải lãi ròng dòng tiền.
- `zero_cost_qty` cảnh báo hàng bán có giá vốn 0. Giá vốn tồn cũ vốn đã bằng 0 không tự suy đoán hoặc sửa chứng từ lịch sử; cần đối chiếu số liệu cũ để kết quả lãi đáng tin cậy. Tồn hiện tại không phải tồn cuối kỳ và không gồm hàng cách ly đang chờ trả.

Các ô nhập tiền dùng dấu chấm nhóm nghìn (`1.250.000`) và dấu phẩy cho phần lẻ (`10.000,50`), gửi API số gốc. Migration `20261104_supplier_returns_cost` nằm trong `PurchasingSchema`, tự chạy một lần trên volume hiện có; SQL tổng hợp có cùng DDL cho máy mới.

### Nhập lốc/thùng và xử lý hàng lỗi tại cửa nhận

- Quy cách đặt hàng chỉ chọn Thùng / Lốc / Lẻ. Thùng, lốc nhập hệ số đơn vị lẻ; server tái sử dụng quy cách đúng loại/hệ số đã có. Lẻ dùng quy cách hệ số 1, không xóa các quy cách lịch sử.
- Mỗi dòng `POST /purchases/{id}/receipts` thêm `manufacturedOn` và `expiresOn` (YYYY-MM-DD), bắt buộc cho request mới; lưu tại `chi_tiet_lan_nhap.ngay_san_xuat/ngay_het_han` và hiển thị NSX/HSD trong lịch sử. NSX không sau hôm nay, HSD không trước NSX. Hàng hết hạn chỉ được ghi trả lỗi (quantity=0); khi xác nhận kiểm tra lại hạn dùng của hàng đạt. Dữ liệu cũ để null, không tự đoán ngày.
- Đơn có phiếu DRAFT ẩn khỏi bảng đơn chờ nhận; backend khóa đơn và chặn tạo thêm phiếu nháp cho cùng đơn (409). Phiếu DRAFT luôn hiện ở bảng nhập dù ngoài khoảng lọc ngày. Sau xác nhận, đơn còn thiếu xuất hiện lại để nhận đợt tiếp; đơn nhận đủ chỉ còn lịch sử dưới bảng nhập.
- Migration `20261104_receiving_product_dates` thêm cột ngày, ràng buộc cặp ngày và chỉ mục tìm phiếu nháp; không sửa các số tồn/công nợ đã có.
- `PATCH /receipts/{id}/lines/{lineId}/dates` nhận `{manufacturedOn,expiresOn}` để ghi/sửa NSX/HSD ngay trên bảng của phiếu DRAFT, gồm phiếu cũ chưa có ngày. Cần quyền IMPORT_RECEIVE; khóa đơn/phiếu, chỉ sửa ngày và lưu nhật ký, từ chối sửa phiếu đã xác nhận/hủy. Giao diện chỉ bật xác nhận khi các dòng đã lưu đủ ngày.

- Bộ lọc đơn đặt hàng cho chọn “Ngày giao dự kiến” (mặc định) hoặc “Ngày đặt đơn”. Khi lọc lịch giao, đơn chưa hẹn không có ngày đối chiếu nên được loại khỏi khoảng lọc; xóa hai mốc sẽ hiện tất cả. Lựa chọn này chỉ áp dụng bảng đơn; lần nhập và phiếu trả vẫn lọc theo ngày thực tế của chúng.

- Đối chiếu lịch giao trên trang đặt hàng: đơn đã duyệt/đang giao/nhận một phần qua ngày hẹn có nhãn “Quá hạn giao N ngày”. Đơn nhận đủ so sánh ngày hẹn với ngày xác nhận cuối của các lần nhận CONFIRMED (dữ liệu cũ thiếu ngày xác nhận thì dùng ngày nhập); hiện nhận trễ/đúng hẹn/sớm và ngày nhận đủ. Không tính phiếu nháp/hủy, không tự suy đoán ngày nhận khi thiếu dữ liệu và không tính theo khoảng lọc. Số ngày tính theo lịch Việt Nam; vẫn cho phép nhận sớm/trễ và giữ nguyên ngày hẹn ban đầu.

- Trang “Đơn đặt hàng và nhập hàng” có bộ lọc Từ ngày–Đến ngày, gồm cả ngày cuối, theo múi giờ Việt Nam: đơn theo `ngay_dat`, lần nhập theo `ngay_nhap`, lịch sử trả theo `ngay_xac_nhan` hoặc `ngay_lap`. Để trống hai mốc để xem tất cả; hỗ trợ một mốc và báo lỗi khi khoảng ngày bị đảo.
- Form đặt hàng yêu cầu ngày giao dự kiến; `POST /purchases` gửi `expectedDate` dạng `YYYY-MM-DD`, lưu `ngay_giao_du_kien` và hiển thị trên danh sách. Ngày này phải từ hôm nay trở đi; API vẫn chấp nhận null cho client cũ. Ngày nhận thực tế được ghi riêng khi nhận hàng.

- Nhân viên có quyền `REPORT_STOCK` dùng `GET /staff/products?page=0&size=100` để xem sản phẩm, quy cách bán và tồn theo đơn vị lẻ, kể cả sản phẩm ngừng bán. Endpoint không trả giá vốn và không cấp quyền sửa sản phẩm.
- Quản trị viên có quyền `PRODUCT_MANAGE` dùng `PATCH /management/products/{id}/stock` với `{stock,expectedStock,reason}` để sửa tồn ngay trên danh sách. Khóa tồn trước khi ghi, trả 409 nếu tồn đã đổi, bắt buộc lý do và lưu chứng từ điều chỉnh cùng nhật ký. Endpoint chỉ sửa tồn, không sửa giá bán hay thông tin sản phẩm.

- Hồ sơ NCC: `GET /management/supplier-editor` trả `product_ids`. `POST /management/supplier-editor` và `PUT /management/supplier-editor/{id}` nhận `productIds: [id,...]`: `[]` bỏ toàn bộ, không gửi trường này thì giữ danh sách cũ. Thay đổi danh sách không xóa chứng từ nhập trước đó.
- `GET /management/supplier-editor/{id}/products` trả mảng ID sản phẩm NCC cung cấp. Form nhập yêu cầu chọn NCC trước và chỉ hiện sản phẩm đã gán. Lập đơn không tự thêm quan hệ NCC–sản phẩm; backend kiểm tra cả quy cách có sẵn lẫn lốc/thùng mới trước khi ghi đơn.

- Dòng `POST /purchases` chọn một trong hai cách: `{packageId,quantity,unitCost}` dùng quy cách có sẵn; hoặc `{productId,packaging,unitsPerPackage,quantity,unitCost}` với packaging LOC/THUNG, unitsPerPackage là số đơn vị lẻ trong mỗi lốc/thùng, từ 2 đến 1.000.000. Không gửi đồng thời hai cách. Giá là giá nguyên quy cách.
- Server tìm/tạo quy cách đúng sản phẩm, loại và hệ số; quy cách mới chỉ phục vụ nhập (`dang_ban=false`), không tự tạo giá bán lốc/thùng cho khách. Không sửa hệ số của quy cách đã giao dịch. Snapshot hệ số trên dòng đơn nhập dùng để quy đổi tồn và giá vốn.
- `GET /purchases/{id}` thêm `so_luong_da_nhan`, `so_luong_da_tra_loi`, `so_luong_con_lai` trên từng dòng, chỉ tính lần nhận CONFIRMED. Phần còn lại = lượng đặt − lượng đạt − lượng lỗi đã trả, không phải tồn kho.
- Form kiểm nhận nhập số giao đợt này và số lỗi trả ngay, tự tính lượng đạt. Khi xác nhận, chỉ hàng đạt cộng tồn và công nợ. Đủ tổng nhận/trả thì DA_NHAN_DU, không còn nút nhận tiếp; giao thiếu thực sự vẫn DA_NHAN_MOT_PHAN. Không cho nhận vượt tổng còn chờ xử lý.
- Migration `20261104_receiving_disposition` trong ReceivingWorkflowSchema cập nhật trigger và đóng các đơn cũ đã xử lý đủ theo hàng đạt + hàng lỗi đã xác nhận; không viết lại tồn, giá nhập, công nợ hoặc phiếu nháp.

### Bỏ trả hàng sau nhập kho

Chỉ hỗ trợ hàng lỗi trả ngay khi kiểm nhận. `GET /supplier-returns` là lịch sử đọc từ lần nhận CONFIRMED có số lượng loại; không tạo phiếu riêng và không có API lập/xác nhận/hủy/hoàn tiền trả từ kho.
Migration `20261104_remove_warehouse_returns` xóa ba bảng phieu_tra_ncc, chi_tiet_tra_ncc, hoan_tien_tra_ncc. Không hoàn tác tồn kho/công nợ đã ghi nhận và không xóa nhật ký biến động. Migration dừng nếu còn phiếu nháp cách ly hoặc tiền hoàn chưa đối soát. Báo cáo sản phẩm bỏ giá trị trả sau nhập và nhập ròng, giữ tiền nhập hàng đạt, doanh thu và lãi gộp.
# Chi tiết tồn kho sản phẩm

`GET /api/v1/staff/products/{id}/inventory-details` dành cho quản trị viên hoặc nhân viên có quyền `REPORT_STOCK`.
Trả về `batches` (NSX/HSD và số lượng lẻ đã nhận của từng lô nhập CONFIRMED, bỏ các dòng bị trả toàn bộ)
và `adjustments` (100 điều chỉnh mới nhất: trước/sau, chênh lệch, lý do, tên người sửa và thời gian).
NSX/HSD có thể trống với dữ liệu cũ. Số lượng theo lô là lượng đã nhận, không phải tồn còn lại của lô;
hệ thống hiện theo dõi tồn tổng sản phẩm, chưa phân bổ hàng bán theo lô.
# Tạo đơn nhập hàng trực tiếp

`POST /purchases` tạo đơn sẵn sàng nhận hàng, không cần thao tác duyệt riêng.
Trạng thái lưu trong DB vẫn dùng `DA_DUYET` để tương thích trigger, hiển thị “Chờ nhận hàng”.
Migration `20261104_direct_receiving` chuyển các đơn `CHO_DUYET` sang trạng thái này và cập nhật mặc định;
không ghi người/ngày duyệt giả, không cộng tồn hay công nợ. Nhận hàng và xác nhận nhập kho vẫn là hai bước riêng.
# Giá vốn bình quân và giá bán tự động

Khi phiếu nhận chuyển sang CONFIRMED, hệ thống cộng tiền hàng đạt và số đơn vị lẻ của toàn bộ
các dòng cùng sản phẩm trong phiếu, tính một lần:
`giá vốn mới = round((tồn cũ × giá vốn cũ + tiền nhập hàng đạt) / (tồn cũ + số lẻ nhập mới), 2)`.
Sau đó cập nhật mọi quy cách: `giá vốn quy cách = giá vốn mới × hệ số`,
`giá bán quy cách = ceil(giá vốn quy cách × 1.25 / 500) × 500`. Hàng lỗi không vào công thức.
Ví dụ 50 × 8.000 + 100 × 9.000 cho giá vốn 8.666,67 và giá bán lẻ làm tròn 11.000.
Các dòng cùng sản phẩm được gộp trước khi làm tròn; xác nhận lặp không tính lại.

`product-editor` không nhận `price`; gửi giá sẽ bị từ chối. Các API `packages` không nhận
`gia_ban` hay `gia_von`, kể cả quản trị viên. Quy cách mới lấy vốn hiện có của sản phẩm;
sản phẩm mới có tồn 0 và nhận hàng để ghi vốn. Không tăng tồn thủ công khi chưa có giá vốn.
Không tính lại giá của hàng hiện có tại thời điểm migration; áp dụng từ lần xác nhận nhập tiếp theo.
Các đơn bán trước đó giữ đơn giá và giá vốn đã chụp. Không có chi phí mua hàng bổ sung trong công thức này.

Giá bán được làm tròn lên bội 500đ, vốn vẫn giữ 2 chữ số thập phân. Migration `20261107_round_selling_prices_500` làm tròn các giá đã theo công thức tự động, không sửa giá vốn hay đơn hàng cũ. Ví dụ: 14.583,34 → 15.000; 72.916,66 → 73.000; 12.500 giữ nguyên.
# Khôi phục mật khẩu khách hàng bằng OTP email

Các endpoint công khai (POST):

| Endpoint | JSON yêu cầu | Kết quả |
| --- | --- | --- |
| `/api/v1/auth/password-reset/request` | `{ "email": "customer@example.com" }` | `challengeId`, `expiresInSeconds`, `retryAfterSeconds`, thông báo chung |
| `/api/v1/auth/password-reset/verify` | `{ "challengeId": "UUID", "code": "123456" }` | `resetToken`, `expiresInSeconds` |
| `/api/v1/auth/password-reset/complete` | `{ "challengeId": "UUID", "resetToken": "...", "newPassword": "..." }` | Thông báo đổi thành công; thu hồi phiên đăng nhập cũ |

OTP và quyền đặt mật khẩu hết hạn sau 5 phút, dùng một lần. OTP tối đa 5 lần sai, gửi lại sau 60 giây; có giới hạn theo email/IP. Không trả OTP trong API hoặc ghi mã vào log. Tài khoản nhân viên/quản trị không dùng luồng khách hàng này. Xem [cấu hình Gmail và quy tắc](GMAIL_OTP.md). Khi SMTP chưa cấu hình, endpoint yêu cầu OTP trả 503.

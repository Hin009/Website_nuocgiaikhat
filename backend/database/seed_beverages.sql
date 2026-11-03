-- Danh muc khoi dau: chi them thong tin, khong them anh hay ton kho.
-- Gia ban la GIA THAM KHAO de quan tri vien chinh lai truoc khi kinh doanh.
-- Chay lai an toan: khong ghi de san pham, gia, anh hoac so luong da co.
BEGIN;
INSERT INTO loai_san_pham(ten,mo_ta) VALUES
 ('Nước ngọt có ga','Các loại nước giải khát có ga, đóng lon hoặc chai.'),
 ('Nước suối','Nước uống đóng chai.'),
 ('Trà đóng chai','Trà đóng chai dùng sẵn.'),
 ('Nước tăng lực','Đồ uống tăng lực đóng lon hoặc chai.'),
 ('Nước thể thao','Các loại đồ uống thể thao.'),
 ('Nước trái cây','Đồ uống và nước ép trái cây đóng gói.'),
 ('Sữa và ca cao','Sữa và đồ uống ca cao dùng sẵn.')
ON CONFLICT(ten) DO NOTHING;

INSERT INTO thuong_hieu(ten,mo_ta) VALUES
 ('Coca-Cola','Thương hiệu nước giải khát Coca-Cola.'),
 ('Pepsi','Thương hiệu nước giải khát Pepsi.'),
 ('Sprite','Thương hiệu nước ngọt Sprite.'),
 ('Fanta','Thương hiệu nước ngọt Fanta.'),
 ('7Up','Thương hiệu nước ngọt 7Up.'),
 ('Mirinda','Thương hiệu nước ngọt Mirinda.'),
 ('Schweppes','Thương hiệu nước giải khát Schweppes.'),
 ('Sting','Thương hiệu nước tăng lực Sting.'),
 ('Red Bull','Thương hiệu nước tăng lực Red Bull.'),
 ('Number 1','Thương hiệu nước tăng lực Number 1.'),
 ('Aquafina','Thương hiệu nước uống đóng chai Aquafina.'),
 ('Dasani','Thương hiệu nước uống đóng chai Dasani.'),
 ('La Vie','Thương hiệu nước uống đóng chai La Vie.'),
 ('C2','Thương hiệu trà đóng chai C2.'),
 ('TEA+','Thương hiệu trà ô long TEA+.'),
 ('Không Độ','Thương hiệu trà đóng chai Không Độ.'),
 ('Revive','Thương hiệu nước uống thể thao Revive.'),
 ('Pocari Sweat','Thương hiệu nước uống Pocari Sweat.'),
 ('Vfresh','Thương hiệu đồ uống trái cây Vfresh.'),
 ('Vinamilk','Thương hiệu sữa Vinamilk.'),
 ('TH true MILK','Thương hiệu sữa TH true MILK.'),
 ('Milo','Thương hiệu đồ uống ca cao Milo.')
ON CONFLICT(ten) DO NOTHING;

WITH catalog(sku,ten,brand,category,volume,packaging,flavor,description) AS (VALUES
 ('CAT-COCA-330','Coca-Cola nguyên bản 330ml','Coca-Cola','Nước ngọt có ga','330ml','LON','Cola','Nước ngọt có ga vị cola, đóng lon. Dùng ngon hơn khi uống lạnh.'),
 ('CAT-COCA-ZERO-330','Coca-Cola Zero Sugar 330ml','Coca-Cola','Nước ngọt có ga','330ml','LON','Cola','Nước ngọt có ga Coca-Cola Zero Sugar, đóng lon.'),
 ('CAT-PEPSI-320','Pepsi Cola 320ml','Pepsi','Nước ngọt có ga','320ml','LON','Cola','Nước ngọt có ga Pepsi vị cola, đóng lon.'),
 ('CAT-PEPSI-ZERO-320','Pepsi không calo 320ml','Pepsi','Nước ngọt có ga','320ml','LON','Cola','Nước ngọt Pepsi không calo, đóng lon.'),
 ('CAT-SPRITE-330','Sprite chanh 330ml','Sprite','Nước ngọt có ga','330ml','LON','Chanh','Nước ngọt có ga Sprite hương chanh, đóng lon.'),
 ('CAT-FANTA-CAM-330','Fanta cam 330ml','Fanta','Nước ngọt có ga','330ml','LON','Cam','Nước ngọt có ga Fanta hương cam, đóng lon.'),
 ('CAT-7UP-320','7Up chanh 320ml','7Up','Nước ngọt có ga','320ml','LON','Chanh','Nước ngọt có ga 7Up hương chanh, đóng lon.'),
 ('CAT-MIRINDA-CAM-320','Mirinda cam 320ml','Mirinda','Nước ngọt có ga','320ml','LON','Cam','Nước ngọt có ga Mirinda hương cam, đóng lon.'),
 ('CAT-MIRINDA-SODA-320','Mirinda soda kem 320ml','Mirinda','Nước ngọt có ga','320ml','LON','Soda kem','Nước ngọt có ga Mirinda hương soda kem, đóng lon.'),
 ('CAT-SCHWEPPES-SODA-330','Schweppes Soda 330ml','Schweppes','Nước ngọt có ga','330ml','LON','Soda','Nước soda Schweppes đóng lon; có thể dùng trực tiếp hoặc pha đồ uống.'),
 ('CAT-STING-330','Sting dâu 330ml','Sting','Nước tăng lực','330ml','LON','Dâu','Nước tăng lực Sting hương dâu, đóng lon.'),
 ('CAT-REDBULL-250','Red Bull 250ml','Red Bull','Nước tăng lực','250ml','LON','Nguyên bản','Nước tăng lực Red Bull đóng lon.'),
 ('CAT-NUMBER1-330','Number 1 330ml','Number 1','Nước tăng lực','330ml','LON','Nguyên bản','Nước tăng lực Number 1 đóng lon.'),
 ('CAT-AQUAFINA-500','Aquafina 500ml','Aquafina','Nước suối','500ml','CHAI','Không vị','Nước uống Aquafina đóng chai, tiện mang theo.'),
 ('CAT-DASANI-500','Dasani 500ml','Dasani','Nước suối','500ml','CHAI','Không vị','Nước uống Dasani đóng chai.'),
 ('CAT-LAVIE-500','La Vie 500ml','La Vie','Nước suối','500ml','CHAI','Không vị','Nước uống La Vie đóng chai.'),
 ('CAT-C2-CHANH-455','C2 trà xanh hương chanh 455ml','C2','Trà đóng chai','455ml','CHAI','Chanh','Trà xanh C2 hương chanh, đóng chai dùng sẵn.'),
 ('CAT-TEAPLUS-455','TEA+ trà ô long 455ml','TEA+','Trà đóng chai','455ml','CHAI','Ô long','Trà ô long TEA+ đóng chai dùng sẵn.'),
 ('CAT-KHONGDO-500','Trà xanh Không Độ 500ml','Không Độ','Trà đóng chai','500ml','CHAI','Chanh','Trà xanh Không Độ đóng chai dùng sẵn.'),
 ('CAT-REVIVE-500','Revive 500ml','Revive','Nước thể thao','500ml','CHAI','Nguyên bản','Nước uống thể thao Revive đóng chai.'),
 ('CAT-POCARI-350','Pocari Sweat 350ml','Pocari Sweat','Nước thể thao','350ml','CHAI','Nguyên bản','Nước uống Pocari Sweat đóng chai.'),
 ('CAT-VFRESH-CAM-1000','Vfresh nước cam 1 lít','Vfresh','Nước trái cây','1 lít','HOP','Cam','Đồ uống trái cây Vfresh vị cam, đóng hộp.'),
 ('CAT-VINAMILK-180','Vinamilk sữa có đường 180ml','Vinamilk','Sữa và ca cao','180ml','HOP','Có đường','Sữa Vinamilk có đường đóng hộp dùng sẵn.'),
 ('CAT-TH-180','TH true MILK sữa có đường 180ml','TH true MILK','Sữa và ca cao','180ml','HOP','Có đường','Sữa TH true MILK có đường đóng hộp dùng sẵn.'),
 ('CAT-MILO-180','Milo ca cao 180ml','Milo','Sữa và ca cao','180ml','HOP','Ca cao','Đồ uống ca cao Milo đóng hộp dùng sẵn.')
)
INSERT INTO san_pham(sku,ten,thuong_hieu_id,loai_san_pham_id,dung_tich,loai_bao_bi,huong_vi,mo_ta,huong_dan_bao_quan)
SELECT c.sku,c.ten,b.id,l.id,c.volume,c.packaging,c.flavor,c.description,
 'Bảo quản theo hướng dẫn trên bao bì. Kiểm tra hạn sử dụng trước khi dùng.'
FROM catalog c JOIN thuong_hieu b ON b.ten=c.brand JOIN loai_san_pham l ON l.ten=c.category
ON CONFLICT(sku) DO NOTHING;

WITH prices(sku,price) AS (VALUES
 ('CAT-COCA-330',11000),('CAT-COCA-ZERO-330',12000),('CAT-PEPSI-320',10000),('CAT-PEPSI-ZERO-320',11000),
 ('CAT-SPRITE-330',10000),('CAT-FANTA-CAM-330',10000),('CAT-7UP-320',10000),('CAT-MIRINDA-CAM-320',10000),
 ('CAT-MIRINDA-SODA-320',10000),('CAT-SCHWEPPES-SODA-330',11000),('CAT-STING-330',12000),('CAT-REDBULL-250',13000),
 ('CAT-NUMBER1-330',11000),('CAT-AQUAFINA-500',6000),('CAT-DASANI-500',6000),('CAT-LAVIE-500',6000),
 ('CAT-C2-CHANH-455',10000),('CAT-TEAPLUS-455',12000),('CAT-KHONGDO-500',12000),('CAT-REVIVE-500',12000),
 ('CAT-POCARI-350',14000),('CAT-VFRESH-CAM-1000',45000),('CAT-VINAMILK-180',8000),('CAT-TH-180',9000),('CAT-MILO-180',9000)
)
INSERT INTO quy_cach_san_pham(san_pham_id,ten_quy_cach,don_vi_tinh,he_so_quy_doi,gia_ban)
SELECT s.id,CASE s.loai_bao_bi WHEN 'LON' THEN 'Lon lẻ' WHEN 'HOP' THEN 'Hộp lẻ' ELSE 'Chai lẻ' END,
 s.loai_bao_bi,1,p.price FROM prices p JOIN san_pham s ON s.sku=p.sku
WHERE NOT EXISTS (SELECT 1 FROM quy_cach_san_pham q WHERE q.san_pham_id=s.id);
COMMIT;

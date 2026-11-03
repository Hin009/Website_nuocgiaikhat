import { Link } from 'react-router-dom';
import { ArrowUpRight, Leaf, ShoppingBag, UserRound, PackageCheck } from 'lucide-react';
import { Breadcrumb, PageHeading } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { isMock } from '@/services';
export default function InfoPage({ type = 'about' }) {
  const title =
    type === 'guide'
      ? 'Mua sắm thật dễ dàng'
      : type === 'policy'
        ? 'Giao hàng & đổi trả'
        : 'Tươi mát, theo cách của bạn.';
  return (
    <div className="container info-page">
      <Breadcrumb
        items={[
          {
            label:
              type === 'guide' ? 'Hướng dẫn' : type === 'policy' ? 'Chính sách' : 'Về WaterBus',
          },
        ]}
      />
      <PageHeading eyebrow="WATERBUS / ĐỒ UỐNG & NIỀM VUI" title={title} />

      {type === 'about' ? (
        <div className="about-grid">
          <div className="about-art">
            <Leaf size={100} strokeWidth={0.8} />
            <strong>
              Ngụm nhỏ.
              <br />
              Niềm vui lớn.
            </strong>
            <span>waterbus.</span>
          </div>
          <div>
            <h2>Một trạm nhỏ cho ngày bận rộn.</h2>
            <p>
              Một chai nước mát sau giờ làm. Một lon nước ngọt cho buổi gặp bạn. Hay một hộp sữa để
              bắt đầu buổi sáng. Những điều nhỏ bé ấy là cảm hứng của WaterBus.
            </p>
            <p>
              Chúng tôi xây dựng trải nghiệm tìm và chọn đồ uống đơn giản, rõ ràng, dễ chịu. Từ
              những hương vị quen thuộc đến lựa chọn mới, mỗi người đều có thể tìm được thức uống
              hợp gu.
            </p>
            <Button asChild>
              <Link to="/products">
                Tìm vị yêu thích <ArrowUpRight size={17} />
              </Link>
            </Button>
          </div>
        </div>
      ) : type === 'guide' ? (
        <div className="guide-steps">
          {[
            [
              ShoppingBag,
              '01',
              'Chọn đồ uống yêu thích',
              'Tìm kiếm, lọc theo danh mục hoặc mức giá. Mở sản phẩm để xem thông tin và thêm vào giỏ.',
            ],
            [
              UserRound,
              '02',
              'Đăng nhập tài khoản',
              'Đăng nhập bằng tài khoản khách hàng hoặc đăng ký tài khoản mới.',
            ],
            [
              PackageCheck,
              '03',
              'Tạo và theo dõi đơn',
              'Kiểm tra giỏ hàng, nhập thông tin nhận hàng và xác nhận. Theo dõi trạng thái đơn trong tài khoản của bạn.',
            ],
          ].map(([Icon, number, heading, description]) => (
            <div className="form-card" key={number}>
              <span className="step-number">{number}</span>
              <Icon size={30} />
              <h3>{heading}</h3>
              <p>{description}</p>
            </div>
          ))}
        </div>
      ) : (
        <div className="policy-content">
          <section>
            <h2>Phí giao hàng</h2>
            <p>
              {isMock
                ? 'Phí giao hàng là 20.000đ. Chọn voucher FREESHIP200 tại trang thanh toán để được miễn phí giao hàng khi tiền hàng từ 200.000đ. Mỗi đơn dùng một voucher.'
                : 'Phí giao hàng và điều kiện mã giảm giá được tính khi đặt hàng.'}
            </p>
          </section>
          <section>
            <h2>Hủy đơn</h2>
            <p>
              Khách hàng có thể hủy đơn đang chờ xác nhận và cần nhập lý do. Nhân viên và quản trị
              viên có thể xử lý đơn trong khu quản lý.
            </p>
          </section>
        </div>
      )}
    </div>
  );
}

import { Outlet, Link } from 'react-router-dom';
import { ArrowLeft, Leaf } from 'lucide-react';
import { Brand } from './CustomerLayout';
import { HeroArtwork } from '@/components/customer/DrinkArt';
export default function AuthLayout({ management = false, children }) {
  return (
    <div className="auth-layout">
      <aside className="auth-visual">
        <Brand to={management ? '/admin' : '/'} />
        <div className="auth-pitch">
          <span className="eyebrow">
            <Leaf size={15} /> {management ? 'KHÔNG GIAN QUẢN LÝ' : 'MỘT NGỤM TƯƠI MỚI'}
          </span>
          <h1>
            {management ? 'Quản lý cửa hàng.' : 'Ngày thêm vui.'}
            <br />
            {management ? 'Vận hành hiệu quả.' : 'Vị thêm mới.'}
          </h1>
          <p>
            {management ? 'Theo dõi sản phẩm, đơn hàng' : 'Những thức uống yêu thích,'}
            <br />
            {management ? 'và hoạt động kinh doanh WaterBus.' : 'chỉ cách bạn một lần chạm.'}
          </p>
        </div>
        {!management && <HeroArtwork />}
      </aside>
      <main id="main-content" className="auth-main">
        <Link to="/" className="back-link">
          <ArrowLeft size={16} /> Về trang chủ
        </Link>
        <div className="auth-form-wrap">{children || <Outlet />}</div>
      </main>
    </div>
  );
}

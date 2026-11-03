import { useState } from 'react';
import { Link, NavLink, Outlet, useNavigate, useSearchParams } from 'react-router-dom';
import {
  Search,
  ShoppingBag,
  UserRound,
  Menu,
  X,
  ArrowUpRight,
  Leaf,
  Truck,
  ShieldCheck,
  Headphones,
  Instagram,
  Facebook,
  LogOut,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/contexts/AuthContext';
import { useCart } from '@/contexts/CartContext';
export function Brand({ light = false, to = '/' }) {
  return (
    <Link
      to={to}
      className={'brand ' + (light ? 'brand-light' : '')}
      aria-label={to === '/admin' ? 'WaterBus - Tổng quan quản lý' : 'WaterBus - Trang chủ'}
    >
      <span className="brand-mark">
        w<Leaf size={14} />
      </span>
      <span>
        waterbus<span className="brand-period">.</span>
        <small>TƯƠI MÁT MỖI NGÀY</small>
      </span>
    </Link>
  );
}
export default function CustomerLayout() {
  const [open, setOpen] = useState(false);
  const [params] = useSearchParams();
  const [search, setSearch] = useState(params.get('q') || '');
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { count } = useCart();
  const customer = user?.role === 'CUSTOMER' ? user : null;
  const submit = (e) => {
    e.preventDefault();
    navigate('/products' + (search ? '?q=' + encodeURIComponent(search) : ''));
    setOpen(false);
  };
  return (
    <>
      <div className="announcement">
        <span>Một ngụm tươi mới, một ngày hứng khởi.</span>
      </div>
      <header className="store-header">
        <div className="container header-main">
          <Brand />
          <form className="header-search" onSubmit={submit}>
            <Search size={19} />
            <input
              aria-label="Tìm đồ uống"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Hôm nay bạn muốn uống gì?"
            />
            <kbd>↵</kbd>
          </form>
          <div className="header-actions">
            <div className="account-menu">
              <Link to={customer ? '/account' : '/login'} className="account-link">
                <UserRound size={22} />
                <span>
                  <small>{customer ? 'Xin chào,' : 'Chào bạn,'}</small>
                  <strong>
                    {customer ? customer.name.split(' ').slice(-2).join(' ') : 'Đăng nhập'}
                  </strong>
                </span>
              </Link>
              {customer && (
                <div className="account-dropdown">
                  <Link to="/account">
                    <UserRound size={17} />
                    Thông tin cá nhân
                  </Link>
                  <Link to="/account/orders">
                    <ShoppingBag size={17} />
                    Đơn hàng
                  </Link>
                  <button type="button" onClick={logout}>
                    <LogOut size={17} />
                    Đăng xuất
                  </button>
                </div>
              )}
            </div>
            <Link to="/cart" className="cart-link" aria-label={'Giỏ hàng, ' + count + ' sản phẩm'}>
              <ShoppingBag size={23} />
              <span>{count}</span>
            </Link>
            <button
              className="icon-button mobile-menu-toggle"
              aria-label={open ? 'Đóng menu' : 'Mở menu'}
              onClick={() => setOpen(!open)}
            >
              {open ? <X /> : <Menu />}
            </button>
          </div>
        </div>
        <nav className={'store-nav ' + (open ? 'is-open' : '')}>
          <div className="container nav-inner">
            <div className="nav-links">
              {[
                ['/', 'Trang chủ'],
                ['/products', 'Tất cả sản phẩm'],
              ].map(([to, label]) => (
                <NavLink
                  key={to}
                  to={to}
                  end={to === '/'}
                  onClick={() => setOpen(false)}
                  className={({ isActive }) => (isActive ? 'active' : '')}
                >
                  {label}
                </NavLink>
              ))}
            </div>
          </div>
          <form className="mobile-search" onSubmit={submit}>
            <Search size={18} />
            <input
              aria-label="Tìm sản phẩm trên điện thoại"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm đồ uống…"
            />
            <Button type="submit" size="sm">
              Tìm
            </Button>
          </form>
          {customer && (
            <div className="mobile-user">
              <Link onClick={() => setOpen(false)} to="/account">
                Tài khoản của tôi
              </Link>
              <button onClick={logout}>
                <LogOut size={15} />
                Đăng xuất
              </button>
            </div>
          )}
        </nav>
      </header>
      <main id="main-content">
        <Outlet />
      </main>
      <section className="benefits-strip">
        <div className="container benefits-grid">
          {[
            [Truck, 'Giao hàng thuận tiện', 'Chọn đồ uống, nhận tận nơi'],
            [ShieldCheck, 'Mua sắm an tâm', 'Thông tin rõ ràng, dễ lựa chọn'],
            [Leaf, 'Đa dạng lựa chọn', 'Đồ uống cho mọi khoảnh khắc'],
            [Headphones, 'Luôn sẵn sàng hỗ trợ', 'Khám phá hướng dẫn mua hàng'],
          ].map(([Icon, title, description]) => (
            <div key={title}>
              <Icon size={29} strokeWidth={1.4} />
              <span>
                <strong>{title}</strong>
                <small>{description}</small>
              </span>
            </div>
          ))}
        </div>
      </section>
      <footer className="store-footer">
        <div className="container footer-grid">
          <div>
            <Brand light />
            <p>
              Mang sự tươi mát đến từng khoảnh khắc.
              <br />
              Đồ uống bạn yêu, luôn trong tầm tay.
            </p>
            <div className="social-links">
              <a
                href="https://www.facebook.com/"
                target="_blank"
                rel="noreferrer"
                aria-label="Mở Facebook"
              >
                <Facebook size={18} />
              </a>
              <a
                href="https://www.instagram.com/"
                target="_blank"
                rel="noreferrer"
                aria-label="Mở Instagram"
              >
                <Instagram size={18} />
              </a>
            </div>
          </div>
          <div>
            <h3>Khám phá</h3>
            <Link to="/products">Tất cả sản phẩm</Link>
            <Link to="/products?sale=1">Ưu đãi hôm nay</Link>
            <Link to="/about">Về WaterBus</Link>
          </div>
          <div>
            <h3>Hỗ trợ bạn</h3>
            <Link to="/shopping-guide">Hướng dẫn mua hàng</Link>
            <Link to="/shipping-returns">Giao hàng & đổi trả</Link>
            <Link to="/account/orders">Đơn hàng của tôi</Link>
          </div>
          <div className="footer-demo">
            <h3>Trải nghiệm WaterBus</h3>
            <p>Khám phá giao diện mua sắm và hệ thống quản lý cửa hàng.</p>
            <Link to="/admin">
              Vào khu vực quản lý <ArrowUpRight size={15} />
            </Link>
          </div>
        </div>
        <div className="container footer-bottom">
          <span>© 2026 WaterBus.</span>
          <span>Được chăm chút cho từng ngụm mát lành.</span>
        </div>
      </footer>
    </>
  );
}

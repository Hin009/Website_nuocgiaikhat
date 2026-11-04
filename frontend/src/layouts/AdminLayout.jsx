import { useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Building2,
  BadgePercent,
  Package,
  Shapes,
  ShoppingBag,
  Truck,
  UsersRound,
  UserRoundCog,
  ChartNoAxesCombined,
  ArrowUpRight,
  PanelLeftClose,
  PanelLeftOpen,
  LogOut,
  ChevronRight,
  Bell,
  Menu,
  X,
} from 'lucide-react';
import { Brand } from './CustomerLayout';
import { useAuth } from '@/contexts/AuthContext';
import { useOrders } from '@/hooks/useData';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { PermissionGuard } from '@/routes/Guards';
import { isMock } from '@/services';
import { roleLabels } from '@/utils/format';
const items = [
  { to: '/admin', label: 'Tổng quan', icon: LayoutDashboard, end: true },
  { to: '/admin/products', label: 'Sản phẩm', icon: Package },
  { to: '/admin/categories', label: 'Danh mục', icon: Shapes, adminOnly: !isMock },
  {
    to: '/admin/suppliers',
    label: 'Nhà cung cấp',
    icon: Building2,
    adminOnly: true,
    apiOnly: true,
  },
  {
    to: '/admin/promotions',
    label: 'Mã khuyến mãi',
    icon: BadgePercent,
    adminOnly: true,
    apiOnly: true,
  },
  { to: '/admin/orders', label: 'Đơn hàng', icon: ShoppingBag },
  { to: '/admin/stock-receipts', label: 'Tạo đơn nhập hàng', icon: Truck, adminOnly: isMock },
  { to: '/admin/customers', label: 'Khách hàng', icon: UsersRound },
  { to: '/admin/reports', label: 'Báo cáo & thống kê', icon: ChartNoAxesCombined },
];
export default function AdminLayout() {
  const { user, logout } = useAuth();
  const [collapsed, setCollapsed] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [notifications, setNotifications] = useState(false);
  const location = useLocation();
  const orders = useOrders(user);
  const pending = orders.data?.filter((o) => o.status === 'PENDING') || [];
  const title =
    items.find((i) => (i.end ? location.pathname === i.to : location.pathname.startsWith(i.to)))
      ?.label ||
    (location.pathname.includes('users')
      ? 'Tài khoản & nhân viên'
      : location.pathname === '/admin/profile'
        ? 'Thông tin cá nhân'
        : 'Quản lý');
  return (
    <div className={'admin-shell ' + (collapsed ? 'sidebar-collapsed' : '')}>
      {mobile && (
        <button
          className="sidebar-backdrop"
          aria-label="Đóng menu"
          onClick={() => setMobile(false)}
        />
      )}
      <aside className={'admin-sidebar ' + (mobile ? 'mobile-open' : '')}>
        <div className="sidebar-brand">
          <Brand light to="/admin" />
          <button
            className="icon-button mobile-only"
            aria-label="Đóng menu"
            onClick={() => setMobile(false)}
          >
            <X size={20} />
          </button>
        </div>
        <span className="sidebar-label">KHÔNG GIAN QUẢN LÝ</span>
        <nav>
          {items
            .filter(
              (item) => (!item.adminOnly || user.role === 'ADMIN') && (!item.apiOnly || !isMock),
            )
            .map((item) => (
              <NavLink
                end={item.end}
                to={item.to}
                key={item.to}
                title={item.label}
                onClick={() => setMobile(false)}
              >
                <item.icon size={20} />
                <span>{item.label}</span>
                {item.label === 'Đơn hàng' && pending.length > 0 && <b>{pending.length}</b>}
              </NavLink>
            ))}
          <PermissionGuard roles={['ADMIN']}>
            <div className="sidebar-divider" />
            <span className="sidebar-label">QUẢN TRỊ</span>
            <NavLink
              to="/admin/users"
              title="Tài khoản & nhân viên"
              onClick={() => setMobile(false)}
            >
              <UserRoundCog size={20} />
              <span>Tài khoản & nhân viên</span>
            </NavLink>
          </PermissionGuard>
        </nav>
        <div className="sidebar-bottom">
          <button className="sidebar-logout" onClick={logout}>
            <LogOut size={18} />
            <span>Đăng xuất</span>
          </button>
          <div className="sidebar-user">
            <span>{user.name.charAt(0)}</span>
            <div>
              <strong>{user.name}</strong>
              <small>{roleLabels[user.role]}</small>
            </div>
          </div>
        </div>
      </aside>
      <div className="admin-workspace">
        <header className="admin-header">
          <div>
            <button
              className="icon-button desktop-only"
              aria-label={collapsed ? 'Mở rộng thanh bên' : 'Thu gọn thanh bên'}
              onClick={() => setCollapsed(!collapsed)}
            >
              {collapsed ? <PanelLeftOpen size={20} /> : <PanelLeftClose size={20} />}
            </button>
            <button
              className="icon-button mobile-only"
              aria-label="Mở menu quản lý"
              onClick={() => setMobile(true)}
            >
              <Menu size={21} />
            </button>
            <span className="admin-breadcrumb">
              Quản lý <ChevronRight size={14} />
              <strong>{title}</strong>
            </span>
          </div>
          <div>
            <button
              className="notification-button"
              aria-label={'Thông báo, ' + pending.length + ' đơn chờ'}
              onClick={() => setNotifications(true)}
            >
              <Bell size={20} />
              {pending.length > 0 && <i />}
            </button>
            <Link className="header-avatar" to="/admin/profile" aria-label="Thông tin cá nhân">
              {user.name.charAt(0)}
            </Link>
          </div>
        </header>
        <main id="main-content" className="admin-main">
          <Outlet />
        </main>
        <footer className="admin-footer">Không gian quản lý WaterBus</footer>
      </div>
      <Dialog open={notifications} onOpenChange={setNotifications}>
        <DialogContent title="Thông báo đơn hàng" description="Các đơn hàng đang chờ xử lý.">
          {pending.length ? (
            <div className="notification-list">
              {pending.map((o) => (
                <Link
                  to={'/admin/orders/' + o.id}
                  key={o.id}
                  onClick={() => setNotifications(false)}
                >
                  <ShoppingBag size={19} />
                  <span>
                    <strong>Đơn #{o.id} chờ xác nhận</strong>
                    <small>{o.receiver}</small>
                  </span>
                  <ArrowUpRight size={17} />
                </Link>
              ))}
            </div>
          ) : (
            <p>Không có đơn hàng chờ xử lý.</p>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}

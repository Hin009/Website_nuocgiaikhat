import { lazy } from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { hasRole, authReturn } from '@/utils/access';
import { Loading, ErrorState, EmptyState } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { Link } from 'react-router-dom';
const AuthLayout = lazy(() => import('@/layouts/AuthLayout'));
const AuthPage = lazy(() => import('@/pages/auth/AuthPage'));

export function ManagementRoute() {
  const { user, loading, error } = useAuth();
  const location = useLocation();
  if (loading) return <Loading />;
  if (error) return <ErrorState error={{ message: error }} />;
  if (hasRole(user, ['STAFF'])) {
    const redirect = new URLSearchParams(location.search).get('redirect');
    if (redirect && ['/admin', '/admin/'].includes(location.pathname))
      return <Navigate to={authReturn(redirect, true)} replace />;
    return <Outlet />;
  }
  if (location.pathname !== '/admin' && location.pathname !== '/admin/')
    return (
      <Navigate
        to={'/admin?redirect=' + encodeURIComponent(location.pathname + location.search)}
        replace
      />
    );
  return (
    <AuthLayout management>
      <AuthPage key="management" management />
    </AuthLayout>
  );
}

export function ProtectedRoute() {
  const { user, loading, error } = useAuth();
  const location = useLocation();
  if (loading) return <Loading />;
  if (error) return <ErrorState error={{ message: error }} />;
  const allowed = hasRole(user, ['CUSTOMER']);
  return allowed ? (
    <Outlet />
  ) : (
    <Navigate
      to={'/login' + '?redirect=' + encodeURIComponent(location.pathname + location.search)}
      replace
    />
  );
}
export function RoleGuard({ roles, children }) {
  const { user } = useAuth();
  return hasRole(user, roles) ? children || <Outlet /> : <Navigate to="/unauthorized" replace />;
}
export function PermissionGuard({ roles, children, fallback = null }) {
  const { user } = useAuth();
  return hasRole(user, roles) ? children : fallback;
}
export function UnauthorizedPage() {
  return (
    <div className="container standalone-state">
      <EmptyState
        title="Bạn chưa có quyền truy cập"
        description="Khu vực này dành cho tài khoản có vai trò phù hợp."
        action={
          <Button asChild>
            <Link to="/">Về trang chủ</Link>
          </Button>
        }
      />
    </div>
  );
}
export function NotFoundPage() {
  return (
    <div className="container standalone-state">
      <EmptyState
        title="Không tìm thấy trang này"
        description="Đường dẫn có thể đã thay đổi. Hãy khám phá những đồ uống khác nhé."
        action={
          <Button asChild>
            <Link to="/products">Khám phá sản phẩm</Link>
          </Button>
        }
      />
    </div>
  );
}

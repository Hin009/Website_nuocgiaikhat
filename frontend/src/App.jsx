import { Component, useEffect, lazy, Suspense } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { Toaster } from 'sonner';
import CustomerLayout from '@/layouts/CustomerLayout';
const AdminLayout = lazy(() => import('@/layouts/AdminLayout'));
const AuthLayout = lazy(() => import('@/layouts/AuthLayout'));
import HomePage from '@/pages/customer/HomePage';
const CatalogPage = lazy(() => import('@/pages/customer/CatalogPage'));
const ProductPage = lazy(() => import('@/pages/customer/ProductPage'));
const CartPage = lazy(() => import('@/pages/customer/CartPage'));
const CheckoutPage = lazy(() => import('@/pages/customer/CheckoutPage'));
const AccountLayout = lazy(() => import('@/pages/customer/AccountPage'));
const ProfilePage = lazy(() =>
  import('@/pages/customer/AccountPage').then((m) => ({ default: m.ProfilePage })),
);
const InfoPage = lazy(() => import('@/pages/customer/InfoPage'));
const AuthPage = lazy(() => import('@/pages/auth/AuthPage'));
const ForgotPasswordPage = lazy(() => import('@/pages/auth/ForgotPasswordPage'));
const AdminProfilePage = lazy(() => import('@/pages/admin/ProfilePage'));
const DashboardPage = lazy(() => import('@/pages/admin/DashboardPage'));
const ProductsPage = lazy(() => import('@/pages/admin/ProductsPage'));
const SuppliersPage = lazy(() =>
  import('@/pages/admin/BusinessManagementPages').then((m) => ({ default: m.SuppliersPage })),
);
const PromotionsPage = lazy(() =>
  import('@/pages/admin/BusinessManagementPages').then((m) => ({ default: m.PromotionsPage })),
);
const CategoriesPage = lazy(() =>
  import('@/pages/admin/ManagementPages').then((m) => ({ default: m.CategoriesPage })),
);
const ReceiptsPage = lazy(() =>
  import('@/pages/admin/ManagementPages').then((m) => ({ default: m.ReceiptsPage })),
);
const UsersPage = lazy(() =>
  import('@/pages/admin/ManagementPages').then((m) => ({ default: m.UsersPage })),
);
const OrdersPage = lazy(() =>
  import('@/components/common/Orders').then((m) => ({ default: m.OrdersPage })),
);
const OrderDetailPage = lazy(() =>
  import('@/components/common/Orders').then((m) => ({ default: m.OrderDetailPage })),
);
import {
  ProtectedRoute,
  ManagementRoute,
  RoleGuard,
  UnauthorizedPage,
  NotFoundPage,
} from '@/routes/Guards';
import { isMock } from '@/services';
import { ErrorState, Loading } from '@/components/common/Shared';
class ErrorBoundary extends Component {
  state = { error: null };
  static getDerivedStateFromError(error) {
    return { error };
  }
  render() {
    return this.state.error ? (
      <div className="container standalone-state">
        <ErrorState
          error={{ message: 'Giao diện gặp sự cố. Hãy tải lại trang để thử lại.' }}
          retry={() => window.location.reload()}
        />
      </div>
    ) : (
      this.props.children
    );
  }
}
function ScrollToTop() {
  const { pathname } = useLocation();
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);
  return null;
}
export default function App() {
  return (
    <ErrorBoundary>
      <a className="skip-link" href="#main-content">
        Bỏ qua đến nội dung
      </a>
      <ScrollToTop />
      <Suspense fallback={<Loading />}>
        <Routes>
          <Route path="quan-ly" element={<Navigate to="/admin" replace />} />
          <Route element={<CustomerLayout />}>
            <Route index element={<HomePage />} />
            <Route path="products" element={<CatalogPage />} />
            <Route path="products/:id" element={<ProductPage />} />
            <Route path="cart" element={<CartPage />} />
            <Route path="about" element={<InfoPage />} />
            <Route path="shopping-guide" element={<InfoPage type="guide" />} />
            <Route path="shipping-returns" element={<InfoPage type="policy" />} />
            <Route path="unauthorized" element={<UnauthorizedPage />} />
            <Route element={<ProtectedRoute />}>
              <Route path="checkout" element={<CheckoutPage />} />
              <Route path="account" element={<AccountLayout />}>
                <Route index element={<ProfilePage />} />
                <Route path="orders" element={<OrdersPage />} />
                <Route path="orders/:id" element={<OrderDetailPage />} />
              </Route>
            </Route>
            <Route path="*" element={<NotFoundPage />} />
          </Route>
          <Route element={<AuthLayout />}>
            <Route path="login" element={<AuthPage key="customer" />} />
            <Route path="register" element={<AuthPage key="register" registerMode />} />
            <Route path="forgot-password" element={<ForgotPasswordPage />} />
          </Route>
          <Route element={<ManagementRoute />}>
            <Route element={<RoleGuard roles={['STAFF']} />}>
              <Route path="admin" element={<AdminLayout />}>
                <Route index element={<DashboardPage />} />
                <Route path="profile" element={<AdminProfilePage />} />
                <Route element={<RoleGuard roles={isMock ? ['STAFF'] : ['ADMIN']} />}>
                  <Route path="categories" element={<CategoriesPage />} />
                </Route>
                <Route path="orders" element={<OrdersPage admin />} />
                <Route path="orders/:id" element={<OrderDetailPage admin />} />
                <Route path="customers" element={<UsersPage customers />} />
                {!isMock && <Route path="stock-receipts" element={<ReceiptsPage />} />}
                <Route path="reports" element={<DashboardPage report />} />
                <Route path="products" element={<ProductsPage />} />
                <Route element={<RoleGuard roles={['ADMIN']} />}>
                  {!isMock && <Route path="suppliers" element={<SuppliersPage />} />}
                  {!isMock && <Route path="promotions" element={<PromotionsPage />} />}
                  {isMock && <Route path="stock-receipts" element={<ReceiptsPage />} />}
                  <Route path="users" element={<UsersPage />} />
                </Route>
                <Route path="*" element={<NotFoundPage />} />
              </Route>
            </Route>
          </Route>
        </Routes>
      </Suspense>
      <Toaster position="top-right" richColors closeButton duration={3500} />
    </ErrorBoundary>
  );
}

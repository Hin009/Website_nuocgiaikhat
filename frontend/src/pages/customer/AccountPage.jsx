import ChangePasswordForm from '@/components/common/ChangePasswordForm';
import { useState } from 'react';
import EmailChangeDialog from '@/components/common/EmailChangeDialog';
import { Link, NavLink, Outlet } from 'react-router-dom';
import { UserRound, ShoppingBag, LogOut, LayoutDashboard } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { Breadcrumb, PageHeading, Field } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { useForm, useWatch } from 'react-hook-form';
import { provinces, profileAddressDefaults } from '@/utils/address';
import { zodResolver } from '@hookform/resolvers/zod';
import { profileSchema, managementProfileSchema } from '@/schemas';
import { authService } from '@/services';
import { useAction } from '@/hooks/useData';
import { roleLabels, maskEmail } from '@/utils/format';
export default function AccountLayout() {
  const { user, logout } = useAuth();
  return (
    <div className="container account-page">
      <Breadcrumb items={[{ label: 'Tài khoản' }]} />
      <PageHeading
        title="Góc nhỏ của bạn"
        description="Quản lý thông tin và những đơn hàng yêu thích."
      />
      <div className="account-layout">
        <aside className="account-sidebar">
          <div className="account-avatar">{user.name.slice(0, 1)}</div>
          <h3>{user.name}</h3>
          <small>{roleLabels[user.role]}</small>
          <nav>
            <NavLink to="/account" end>
              <UserRound size={18} />
              Thông tin cá nhân
            </NavLink>
            <NavLink to="/account/orders">
              <ShoppingBag size={18} />
              Đơn hàng của tôi
            </NavLink>
            {user.role !== 'CUSTOMER' && (
              <Link to="/admin">
                <LayoutDashboard size={18} />
                Khu vực quản lý
              </Link>
            )}
            <button onClick={logout}>
              <LogOut size={18} />
              Đăng xuất
            </button>
          </nav>
        </aside>
        <section>
          <Outlet />
        </section>
      </div>
    </div>
  );
}
export function ProfilePage({ management = false }) {
  const { user, setUser } = useAuth();
  const [changingEmail, setChangingEmail] = useState(false);
  const {
    register,
    handleSubmit,
    control,
    setValue,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(management ? managementProfileSchema : profileSchema),
    defaultValues: { ...user, ...profileAddressDefaults(user) },
  });
  const provinceCode = useWatch({ control, name: 'provinceCode' });
  const selectedProvince = provinces.find((province) => province.code === provinceCode);
  const action = useAction((values) => authService.update(user.id, values), 'Đã lưu thông tin');
  return (
    <div className="form-card profile-card">
      <h2>Thông tin cá nhân</h2>
      <form
        className="form-stack"
        onSubmit={handleSubmit(async (values) => {
          try {
            setUser(await action.mutateAsync(values));
          } catch {
            /* toast từ useAction */
          }
        })}
        noValidate
      >
        <Field label="Họ và tên" error={errors.name}>
          <input autoComplete="name" {...register('name')} />
        </Field>
        <Field label="Email">
          <div className="profile-email-row">
            <output data-field-control className="profile-email-value">
              {maskEmail(user.email)}
            </output>
            <Button type="button" variant="outline" onClick={() => setChangingEmail(true)}>
              Thay đổi email
            </Button>
          </div>
        </Field>
        <Field label="Số điện thoại" error={errors.phone}>
          <input type="tel" inputMode="numeric" autoComplete="tel" {...register('phone')} />
        </Field>
        <>
          <div className="profile-address-selects">
            <Field label="Tỉnh/Thành phố" error={errors.provinceCode}>
              <select
                autoComplete="address-level1"
                {...register('provinceCode', {
                  onChange: () =>
                    setValue('wardCode', '', { shouldValidate: false, shouldDirty: true }),
                })}
              >
                <option value="">Chọn tỉnh/thành phố</option>
                {provinces.map((province) => (
                  <option key={province.code} value={province.code}>
                    {province.name}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Phường/Xã" error={errors.wardCode}>
              <select
                autoComplete="address-level2"
                disabled={!selectedProvince}
                {...register('wardCode')}
              >
                <option value="">
                  {selectedProvince ? 'Chọn phường/xã' : 'Chọn tỉnh/thành phố trước'}
                </option>
                {(selectedProvince?.wards || []).map((ward) => (
                  <option key={ward.code} value={ward.code}>
                    {ward.name}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <Field label="Số nhà, tên đường" error={errors.streetAddress}>
            <input
              autoComplete="address-line1"
              placeholder="Ví dụ: 12 Nguyễn Huệ"
              {...register('streetAddress')}
            />
          </Field>
        </>
        <Button type="submit" disabled={action.isPending}>
          {action.isPending ? 'Đang lưu…' : 'Lưu thông tin'}
        </Button>
      </form>
      <ChangePasswordForm management={management} />
      {changingEmail && (
        <EmailChangeDialog
          onClose={() => setChangingEmail(false)}
          onChanged={(email) => {
            setUser((previous) => ({ ...previous, email }));
            setValue('email', email);
          }}
        />
      )}
    </div>
  );
}

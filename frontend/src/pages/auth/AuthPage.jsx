import { useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Eye, EyeOff, ArrowRight, UserRound, ShieldCheck, BriefcaseBusiness } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Field } from '@/components/common/Shared';
import { useAuth } from '@/contexts/AuthContext';
import { loginSchema, registerSchema } from '@/schemas';
import { authReturn } from '@/utils/access';
import { isMock } from '@/services';
const demos = [
  { role: 'CUSTOMER', label: 'Khách hàng', email: 'khach@waterbus.demo', icon: UserRound },
  { role: 'STAFF', label: 'Nhân viên', email: 'nhanvien@waterbus.demo', icon: BriefcaseBusiness },
  { role: 'ADMIN', label: 'Quản trị', email: 'admin@waterbus.demo', icon: ShieldCheck },
];
export default function AuthPage({ registerMode = false, management = false }) {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const auth = useAuth();
  const [show, setShow] = useState(false);
  const [serverError, setServerError] = useState('');
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm({
    resolver: zodResolver(registerMode ? registerSchema : loginSchema),
    defaultValues: {
      email: isMock && management && params.get('demo') === 'admin' ? 'admin@waterbus.demo' : '',
      password: isMock && management && params.get('demo') === 'admin' ? 'Demo@123' : '',
      name: '',
      phone: '',
      confirmPassword: '',
    },
  });
  const submit = async (values) => {
    setServerError('');
    try {
      await auth.login(values, registerMode, management ? 'management' : 'customer');
      toast.success(registerMode ? 'Đã tạo tài khoản' : 'Đăng nhập thành công');
      navigate(authReturn(params.get('redirect') || (management ? '/admin' : '/'), management), {
        replace: true,
      });
    } catch (error) {
      setServerError(error.message);
    }
  };
  return (
    <>
      <span className="eyebrow">
        {management ? 'WATERBUS · KHU VỰC QUẢN LÝ' : 'CHÀO MỪNG ĐẾN WATERBUS'}
      </span>
      <h1>
        {management
          ? 'Đăng nhập quản lý.'
          : registerMode
            ? 'Bắt đầu ngày tươi mới.'
            : 'Rất vui gặp lại bạn.'}
      </h1>
      <p className="auth-subtitle">
        {management
          ? 'Dành cho nhân viên và quản trị viên WaterBus.'
          : registerMode
            ? 'Tạo tài khoản để trải nghiệm mua sắm cùng WaterBus.'
            : 'Đăng nhập để tiếp tục hành trình khám phá đồ uống.'}
      </p>

      {isMock && !registerMode && (
        <div className="demo-accounts">
          <span>Chọn tài khoản trải nghiệm</span>
          <div>
            {demos
              .filter((d) => (management ? d.role !== 'CUSTOMER' : d.role === 'CUSTOMER'))
              .map((d) => (
                <button
                  key={d.role}
                  type="button"
                  onClick={() => {
                    setValue('email', d.email, { shouldValidate: false });
                    setValue('password', 'Demo@123', { shouldValidate: false });
                  }}
                >
                  <d.icon size={18} />
                  {d.label}
                </button>
              ))}
          </div>
          <small>
            Mật khẩu: <code>Demo@123</code>
          </small>
        </div>
      )}
      <form className="form-stack" onSubmit={handleSubmit(submit)} noValidate>
        {registerMode && (
          <Field label="Họ và tên" error={errors.name}>
            <input autoComplete="name" {...register('name')} placeholder="Nguyễn Minh Anh" />
          </Field>
        )}
        <Field label="Địa chỉ email" error={errors.email}>
          <input
            autoComplete="email"
            type="email"
            {...register('email')}
            placeholder="ban@example.com"
          />
        </Field>
        {registerMode && (
          <Field label="Số điện thoại" error={errors.phone}>
            <input
              autoComplete="tel"
              type="tel"
              inputMode="numeric"
              autoComplete="tel"
              {...register('phone')}
              placeholder="0901234567"
            />
          </Field>
        )}
        <Field label="Mật khẩu" error={errors.password}>
          <div className="password-input">
            <input
              type={show ? 'text' : 'password'}
              autoComplete={registerMode ? 'new-password' : 'current-password'}
              {...register('password')}
              placeholder="Nhập mật khẩu"
            />
            <button
              type="button"
              aria-label={show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
              onClick={() => setShow(!show)}
            >
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </div>
        </Field>
        {registerMode && (
          <Field label="Nhập lại mật khẩu" error={errors.confirmPassword}>
            <input type="password" autoComplete="new-password" {...register('confirmPassword')} />
          </Field>
        )}
        {serverError && (
          <p className="form-error" role="alert">
            {serverError}
          </p>
        )}
        <Button type="submit" className="full-width" size="lg" disabled={isSubmitting}>
          {isSubmitting ? 'Đang xử lý…' : registerMode ? 'Tạo tài khoản' : 'Đăng nhập'}
          <ArrowRight size={18} />
        </Button>
      </form>
      {!management && (
        <p className="auth-switch">
          {registerMode ? 'Đã có tài khoản?' : 'Bạn chưa có tài khoản?'}{' '}
          <Link to={registerMode ? '/login' : '/register'}>
            {registerMode ? 'Đăng nhập' : 'Đăng ký ngay'}
          </Link>
        </p>
      )}
    </>
  );
}

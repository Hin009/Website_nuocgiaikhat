import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, ArrowRight, Mail, ShieldCheck, KeyRound, Eye, EyeOff } from 'lucide-react';
import { toast } from 'sonner';
import { z } from 'zod';
import { Button } from '@/components/ui/button';
import { Field } from '@/components/common/Shared';
import { passwordResetService } from '@/services/api';

const emailSchema = z.string().trim().email('Nhập email hợp lệ.').max(255);
export default function ForgotPasswordPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [challenge, setChallenge] = useState('');
  const [token, setToken] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [retryAt, setRetryAt] = useState(0);
  const [remaining, setRemaining] = useState(0);
  const [grantExpires, setGrantExpires] = useState(0);
  useEffect(() => {
    const tick = () => setRemaining(Math.max(0, Math.ceil((retryAt - Date.now()) / 1000)));
    tick();
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, [retryAt]);
  useEffect(() => {
    if (step !== 'password') return;
    const timer = setTimeout(
      () => {
        setToken('');
        setPassword('');
        setConfirm('');
        setCode('');
        setStep('email');
        setError('Phiên đổi mật khẩu đã hết hạn. Vui lòng gửi OTP mới.');
      },
      Math.max(0, grantExpires - Date.now()),
    );
    return () => clearTimeout(timer);
  }, [step, grantExpires]);
  const send = async () => {
    const parsed = emailSchema.safeParse(email);
    if (!parsed.success) throw new Error('Nhập email hợp lệ.');
    const result = await passwordResetService.request(parsed.data);
    setEmail(parsed.data);
    setChallenge(result.challengeId);
    setCode('');
    setToken('');
    setRetryAt(Date.now() + result.retryAfterSeconds * 1000);
    setNotice(result.message);
    setStep('otp');
  };
  const run = async (action) => {
    if (busy) return;
    setError('');
    setBusy(true);
    try {
      await action();
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy(false);
    }
  };
  const submit = (event) => {
    event.preventDefault();
    run(async () => {
      if (step === 'email') return send();
      if (step === 'otp') {
        if (!/^\d{6}$/.test(code)) throw new Error('Nhập đủ 6 chữ số OTP.');
        const result = await passwordResetService.verify(challenge, code);
        setToken(result.resetToken);
        setGrantExpires(Date.now() + result.expiresInSeconds * 1000);
        setCode('');
        setNotice('Email đã được xác minh. Bạn có thể đặt mật khẩu mới.');
        setStep('password');
        return;
      }
      if (password.length < 8 || new TextEncoder().encode(password).length > 72)
        throw new Error('Mật khẩu cần ít nhất 8 ký tự và tối đa 72 byte UTF-8.');
      if (password !== confirm) throw new Error('Mật khẩu xác nhận chưa khớp.');
      await passwordResetService.complete(challenge, token, password);
      setToken('');
      setPassword('');
      setConfirm('');
      toast.success('Đã đổi mật khẩu. Hãy đăng nhập bằng mật khẩu mới.');
      navigate('/login', { replace: true });
    });
  };
  const stage = ['email', 'otp', 'password'].indexOf(step);
  return (
    <>
      <span className="eyebrow">WATERBUS · KHÔI PHỤC TÀI KHOẢN</span>
      <h1>
        {step === 'email'
          ? 'Quên mật khẩu?'
          : step === 'otp'
            ? 'Kiểm tra email của bạn.'
            : 'Đặt mật khẩu mới.'}
      </h1>
      <p className="auth-subtitle">
        {step === 'email'
          ? 'Nhập email đã đăng ký tài khoản khách hàng để nhận mã OTP.'
          : step === 'otp'
            ? `Nhập mã 6 chữ số gửi tới ${email}. Mã có hiệu lực trong 5 phút.`
            : 'Chọn mật khẩu mới để tiếp tục mua sắm cùng WaterBus.'}
      </p>
      <ol className="password-reset-steps" aria-label="Các bước khôi phục">
        {[
          ['Email', Mail],
          ['Xác minh OTP', ShieldCheck],
          ['Mật khẩu mới', KeyRound],
        ].map(([label, Icon], index) => (
          <li
            key={label}
            className={index <= stage ? 'is-current' : ''}
            aria-current={index === stage ? 'step' : undefined}
          >
            <Icon size={16} />
            <span>{label}</span>
          </li>
        ))}
      </ol>
      <form className="form-stack" onSubmit={submit} noValidate>
        {step === 'email' && (
          <Field label="Email đăng ký">
            <input
              type="email"
              autoComplete="email"
              required
              maxLength={255}
              value={email}
              disabled={busy}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="ban@gmail.com"
            />
          </Field>
        )}
        {step === 'otp' && (
          <Field label="Mã OTP">
            <input
              className="otp-input"
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              required
              value={code}
              disabled={busy}
              onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))}
              placeholder="000000"
            />
          </Field>
        )}
        {step === 'password' && (
          <>
            <Field label="Mật khẩu mới">
              <div className="password-input">
                <input
                  type={show ? 'text' : 'password'}
                  autoComplete="new-password"
                  minLength={8}
                  maxLength={72}
                  required
                  value={password}
                  disabled={busy}
                  onChange={(event) => setPassword(event.target.value)}
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
            <Field label="Xác nhận mật khẩu mới">
              <input
                type="password"
                autoComplete="new-password"
                required
                value={confirm}
                disabled={busy}
                onChange={(event) => setConfirm(event.target.value)}
              />
            </Field>
          </>
        )}
        {notice && step !== 'email' && (
          <p className="reset-notice" role="status">
            {notice}
          </p>
        )}
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <Button type="submit" className="full-width" size="lg" disabled={busy}>
          {busy
            ? 'Đang xử lý…'
            : step === 'email'
              ? 'Gửi mã OTP'
              : step === 'otp'
                ? 'Xác minh OTP'
                : 'Lưu mật khẩu mới'}
          <ArrowRight size={18} />
        </Button>
        {step === 'otp' && (
          <div className="reset-secondary-actions">
            <button
              type="button"
              className="text-button"
              disabled={busy || remaining > 0}
              onClick={() => run(send)}
            >
              {remaining > 0 ? `Gửi lại sau ${remaining}s` : 'Gửi lại OTP'}
            </button>
            <button
              type="button"
              className="text-button"
              disabled={busy}
              onClick={() => {
                setStep('email');
                setError('');
                setNotice('');
                setCode('');
              }}
            >
              Đổi email
            </button>
          </div>
        )}
      </form>
      <p className="auth-switch">
        <Link to="/login">
          <ArrowLeft size={15} /> Quay lại đăng nhập
        </Link>
      </p>
    </>
  );
}

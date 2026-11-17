import { Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { useAuth } from '@/contexts/AuthContext';
import { authService } from '@/services';
import { Field } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';

export default function ChangePasswordForm({ management = false }) {
  const { logout } = useAuth();
  const navigate = useNavigate();
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [visible, setVisible] = useState({ old: false, next: false, confirm: false });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const submit = async (event) => {
    event.preventDefault();
    if (busy) return;
    setError('');
    if (!oldPassword) return setError('Vui lòng nhập mật khẩu hiện tại.');
    if (newPassword.length < 8 || new TextEncoder().encode(newPassword).length > 72)
      return setError('Mật khẩu mới cần ít nhất 8 ký tự và tối đa 72 byte UTF-8.');
    if (oldPassword === newPassword) return setError('Mật khẩu mới phải khác mật khẩu hiện tại.');
    if (newPassword !== confirmPassword) return setError('Mật khẩu xác nhận chưa khớp.');
    setBusy(true);
    try {
      await authService.changePassword({ oldPassword, newPassword });
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
      await logout();
      toast.success('Đã đổi mật khẩu. Vui lòng đăng nhập lại bằng mật khẩu mới.');
      navigate(management ? '/admin' : '/login', { replace: true });
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };
  return (
    <section className="profile-password-section" aria-label="Đổi mật khẩu của tôi">
      <h3>Đổi mật khẩu</h3>
      <p className="muted-note">
        Nhập mật khẩu hiện tại để tự đổi mật khẩu. Sau khi đổi thành công, bạn sẽ cần đăng nhập lại
        trên các thiết bị.
      </p>
      <form className="form-stack" onSubmit={submit} noValidate>
        {[
          {
            name: 'old',
            label: 'Mật khẩu hiện tại',
            toggleLabel: 'mật khẩu hiện tại',
            value: oldPassword,
            onChange: setOldPassword,
            autoComplete: 'current-password',
          },
          {
            name: 'next',
            label: 'Mật khẩu mới',
            toggleLabel: 'mật khẩu mới',
            value: newPassword,
            onChange: setNewPassword,
            autoComplete: 'new-password',
          },
          {
            name: 'confirm',
            label: 'Xác nhận mật khẩu mới',
            toggleLabel: 'mật khẩu xác nhận',
            value: confirmPassword,
            onChange: setConfirmPassword,
            autoComplete: 'new-password',
          },
        ].map(({ name, label, toggleLabel, value, onChange, autoComplete }) => (
          <Field key={name} label={label}>
            <div className="password-input">
              <input
                type={visible[name] ? 'text' : 'password'}
                autoComplete={autoComplete}
                maxLength={72}
                value={value}
                onChange={(event) => onChange(event.target.value)}
                disabled={busy}
              />
              <button
                type="button"
                aria-label={(visible[name] ? 'Ẩn ' : 'Hiện ') + toggleLabel}
                title={(visible[name] ? 'Ẩn ' : 'Hiện ') + toggleLabel}
                aria-pressed={visible[name]}
                onClick={() => setVisible((previous) => ({ ...previous, [name]: !previous[name] }))}
                disabled={busy}
              >
                {visible[name] ? (
                  <EyeOff size={18} aria-hidden="true" />
                ) : (
                  <Eye size={18} aria-hidden="true" />
                )}
              </button>
            </div>
          </Field>
        ))}
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <Button type="submit" disabled={busy}>
          {busy ? 'Đang đổi mật khẩu…' : 'Đổi mật khẩu'}
        </Button>
      </form>
    </section>
  );
}

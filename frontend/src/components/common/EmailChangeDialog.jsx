import { useEffect, useState } from 'react';
import { ShieldCheck, Mail, CheckCircle2, ArrowRight } from 'lucide-react';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Field } from '@/components/common/Shared';
import { emailChangeService } from '@/services/api';
import { isMock } from '@/services';
import { useAuth } from '@/contexts/AuthContext';
import { maskEmail } from '@/utils/format';
import { z } from 'zod';

const emailSchema = z.string().trim().email().max(255);
const steps = ['Xác minh email hiện tại', 'Nhập email mới', 'Xác minh email mới'];
export default function EmailChangeDialog({ onClose, onChanged }) {
  const { user } = useAuth();
  const [step, setStep] = useState(0);
  const [newEmail, setNewEmail] = useState('');
  const [code, setCode] = useState('');
  const [challengeId, setChallengeId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [retryAt, setRetryAt] = useState(0);
  const [expiresAt, setExpiresAt] = useState(0);
  const [verifiedUntil, setVerifiedUntil] = useState(0);
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);
  const remaining = Math.max(0, Math.ceil((retryAt - now) / 1000));
  const otpExpired = expiresAt > 0 && now >= expiresAt;
  const expired = verifiedUntil > 0 && now >= verifiedUntil && step >= 2 && step < 4;
  const otpStep = step === 1 || step === 3;
  const stage = step < 2 ? 0 : step === 2 ? 1 : 2;
  const run = async (fn) => {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      await fn();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };
  const accepted = (result, nextStep) => {
    setChallengeId(result.challengeId);
    if (nextStep === 3) setNewEmail(result.email);
    setCode('');
    setNow(Date.now());
    setExpiresAt(Date.now() + result.expiresInSeconds * 1000);
    setRetryAt(Date.now() + result.retryAfterSeconds * 1000);
    setNotice(result.message);
    setStep(nextStep);
  };
  const restart = async () => {
    if (challengeId) await emailChangeService.cancel(challengeId);
    setChallengeId('');
    setStep(0);
    setCode('');
    setNotice('');
    setExpiresAt(0);
    setVerifiedUntil(0);
    setNewEmail('');
  };
  const close = () =>
    run(async () => {
      if (challengeId && step !== 4) await emailChangeService.cancel(challengeId);
      onClose();
    });
  const submit = (event) => {
    event.preventDefault();
    run(async () => {
      if (expired) return;
      if (step === 0) {
        if (isMock) throw new Error('Chức năng đổi email không khả dụng trong chế độ trải nghiệm.');
        accepted(await emailChangeService.requestCurrent(), 1);
        return;
      }
      if (step === 2) {
        const parsed = emailSchema.safeParse(newEmail);
        if (!parsed.success) throw new Error('Vui lòng nhập địa chỉ email hợp lệ.');
        const next = parsed.data.toLowerCase();
        if (next === user.email.trim().toLowerCase())
          throw new Error('Email mới phải khác email hiện tại.');
        accepted(await emailChangeService.requestNew(next, challengeId), 3);
        return;
      }
      if (!/^\d{6}$/.test(code)) throw new Error('Vui lòng nhập đủ 6 chữ số OTP.');
      if (step === 1) {
        const result = await emailChangeService.verifyCurrent(challengeId, code);
        setVerifiedUntil(Date.now() + result.expiresInSeconds * 1000);
        setNow(Date.now());
        setCode('');
        setRetryAt(0);
        setNotice('Đã xác minh email hiện tại. Vui lòng nhập email mới.');
        setStep(2);
        return;
      }
      const result = await emailChangeService.verifyNew(challengeId, code);
      onChanged(result.email);
      setCode('');
      setNotice('');
      setStep(4);
    });
  };
  return (
    <Dialog open onOpenChange={(open) => !open && !busy && close()}>
      <DialogContent
        title={step === 4 ? 'Email được thay đổi thành công' : 'Thay đổi địa chỉ email'}
        description={
          step === 4
            ? 'Bạn có thể đăng nhập bằng địa chỉ email mới từ bây giờ.'
            : 'Xác minh email hiện tại trước khi nhập và xác minh email mới.'
        }
        className="email-change-dialog"
      >
        {step === 4 ? (
          <div className="email-change-success">
            <CheckCircle2 size={56} aria-hidden="true" />
            <p role="status">
              Đã đổi email thành <strong>{newEmail}</strong>.
            </p>
            <Button onClick={onClose}>Hoàn tất</Button>
          </div>
        ) : (
          <>
            <ol className="email-change-steps" aria-label="Các bước đổi email">
              {steps.map((label, i) => (
                <li
                  key={label}
                  className={i <= stage ? 'is-current' : ''}
                  aria-current={i === stage ? 'step' : undefined}
                >
                  {i + 1}. {label}
                </li>
              ))}
            </ol>
            {expired ? (
              <div className="form-stack">
                <p className="form-error" role="alert">
                  Phiên xác minh email đã hết hạn. Vui lòng bắt đầu lại.
                </p>
                <Button disabled={busy} onClick={() => run(restart)}>
                  Bắt đầu lại
                </Button>
              </div>
            ) : (
              <form className="form-stack" onSubmit={submit} noValidate>
                <div className="email-change-intro">
                  <ShieldCheck size={26} aria-hidden="true" />
                  <p>{steps[stage]}</p>
                </div>
                {step === 0 && (
                  <p>
                    Để bảo vệ tài khoản, hãy xác minh mã OTP gửi tới email hiện tại:{' '}
                    <strong>{maskEmail(user.email)}</strong>.
                  </p>
                )}
                {step === 2 && (
                  <Field label="Địa chỉ email mới">
                    <input
                      type="email"
                      autoComplete="email"
                      maxLength={255}
                      value={newEmail}
                      onChange={(e) => setNewEmail(e.target.value)}
                      disabled={busy}
                      placeholder="Nhập địa chỉ email mới"
                    />
                  </Field>
                )}
                {otpStep && (
                  <>
                    <p className="email-change-recipient">
                      <Mail size={18} aria-hidden="true" />
                      <span>
                        Mã xác nhận đã được yêu cầu gửi tới{' '}
                        <strong>{step === 1 ? maskEmail(user.email) : newEmail}</strong>. Vui lòng
                        kiểm tra hộp thư và thư rác.
                      </span>
                    </p>
                    <Field label={step === 1 ? 'Mã OTP email hiện tại' : 'Mã OTP email mới'}>
                      <input
                        key={step}
                        className="otp-input"
                        type="text"
                        inputMode="numeric"
                        autoComplete="one-time-code"
                        maxLength={6}
                        value={code}
                        onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                        disabled={busy}
                        placeholder="000000"
                      />
                    </Field>
                    <p className="muted-note">
                      {otpExpired
                        ? 'Mã OTP đã hết hạn. Vui lòng gửi lại mã.'
                        : 'OTP gồm 6 chữ số, hiệu lực tối đa 5 phút, chỉ dùng một lần.'}
                    </p>
                    <Button
                      type="button"
                      variant="outline"
                      disabled={busy || remaining > 0}
                      onClick={() =>
                        run(async () =>
                          accepted(await emailChangeService.resend(challengeId), step),
                        )
                      }
                    >
                      {remaining > 0 ? 'Gửi lại sau ' + remaining + 's' : 'Gửi lại OTP'}
                    </Button>
                  </>
                )}
                {notice && (
                  <p className="reset-notice" role="status">
                    {notice}
                  </p>
                )}
                {error && (
                  <p className="form-error" role="alert">
                    {error}
                  </p>
                )}
                <Button
                  type="submit"
                  disabled={
                    busy || (otpStep && otpExpired) || ((step === 0 || step === 2) && remaining > 0)
                  }
                >
                  {busy
                    ? 'Đang xử lý…'
                    : step === 0
                      ? remaining > 0
                        ? 'Gửi mã sau ' + remaining + 's'
                        : 'Gửi OTP tới email hiện tại'
                      : step === 1
                        ? 'Xác minh email hiện tại'
                        : step === 2
                          ? remaining > 0
                            ? 'Gửi mã sau ' + remaining + 's'
                            : 'Gửi OTP tới email mới'
                          : 'Xác nhận đổi email'}
                  <ArrowRight size={17} />
                </Button>
                {step === 3 && (
                  <Button
                    type="button"
                    variant="outline"
                    disabled={busy}
                    onClick={() => {
                      setStep(2);
                      setCode('');
                      setError('');
                      setNotice('');
                    }}
                  >
                    Nhập email mới khác
                  </Button>
                )}
                {challengeId && (
                  <button
                    className="text-button"
                    type="button"
                    disabled={busy}
                    onClick={() => run(restart)}
                  >
                    Bắt đầu lại
                  </button>
                )}
              </form>
            )}
            {expired && error && (
              <p className="form-error" role="alert">
                {error}
              </p>
            )}
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}

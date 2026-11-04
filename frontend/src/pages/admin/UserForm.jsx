import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { optionalPhoneSchema } from '@/schemas/phone';
import { useAuth } from '@/contexts/AuthContext';
import { useAction } from '@/hooks/useData';
import { adminService, authService, isMock } from '@/services';
import { digest, updateDb } from '@/mocks/database';
import { Field } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { roleLabels } from '@/utils/format';
const userSchema = z
  .object({
    name: z.string().trim().min(2, 'Nhập họ tên.').max(100),
    email: z
      .string()
      .trim()
      .email('Email không hợp lệ.')
      .transform((v) => v.toLowerCase()),
    phone: optionalPhoneSchema,
    role: z.enum(['CUSTOMER', 'STAFF', 'ADMIN']),
    active: z.boolean(),
    password: z.string().optional(),
  })
  .refine((v) => !v.password || v.password.length >= 8, {
    path: ['password'],
    message: 'Mật khẩu cần ít nhất 8 ký tự.',
  });
export default function UserForm({ item, onClose }) {
  const { user, setUser } = useAuth();
  const [pending, setPending] = useState(null);
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(userSchema),
    defaultValues: item
      ? { ...item, password: '' }
      : { name: '', email: '', phone: '', role: 'STAFF', active: true, password: '' },
  });
  const action = useAction(async (values) => {
    if (item?.id === user.id && (!values.active || values.role !== 'ADMIN'))
      throw new Error('Không thể khóa hoặc hạ quyền tài khoản đang sử dụng.');
    if (!item && !values.password) throw new Error('Nhập mật khẩu cho tài khoản mới.');
    const { password, ...payload } = values;
    const passwordDigest = isMock && password ? await digest(password) : null;
    const saved = await adminService.save('users', {
      ...item,
      ...payload,
      ...(!isMock ? { password } : {}),
    });
    if (passwordDigest)
      updateDb((db) => {
        const existing = db.registered.find((a) => a.email === payload.email);
        if (existing) existing.digest = passwordDigest;
        else db.registered.push({ email: payload.email, digest: passwordDigest });
      });
    if (saved.id === user.id) setUser(isMock ? saved : await authService.me());
    return saved;
  }, 'Đã lưu tài khoản');
  const save = async () => {
    try {
      await action.mutateAsync(pending);
      setPending(null);
      onClose();
    } catch {
      setPending(null);
    }
  };
  return (
    <>
      <form className="form-stack" onSubmit={handleSubmit(setPending)} noValidate>
        <Field label="Họ tên" error={errors.name}>
          <input {...register('name')} />
        </Field>
        <Field label="Email" error={errors.email}>
          <input type="email" readOnly={!!item} {...register('email')} />
        </Field>
        <Field label="Số điện thoại" error={errors.phone}>
          <input type="tel" inputMode="numeric" autoComplete="tel" {...register('phone')} />
        </Field>
        {!isMock && item?.roles?.length > 1 && (
          <p className="muted-note">
            Đổi vai trò sẽ thay danh sách vai trò hiện tại bằng vai trò được chọn.
          </p>
        )}
        <div className="form-grid">
          <Field label="Vai trò" error={errors.role}>
            <select {...register('role')}>
              {Object.entries(roleLabels).map(([id, label]) => (
                <option key={id} value={id}>
                  {label}
                </option>
              ))}
            </select>
          </Field>
          <label className="checkbox-field">
            <input type="checkbox" {...register('active')} />
            Đang hoạt động
          </label>
        </div>
        <Field
          label={item ? 'Mật khẩu mới (để trống nếu giữ nguyên)' : 'Mật khẩu'}
          error={errors.password}
        >
          <input type="password" autoComplete="new-password" {...register('password')} />
        </Field>
        <div className="dialog-actions">
          <Button type="button" variant="outline" onClick={onClose}>
            Hủy
          </Button>
          <Button type="submit" disabled={action.isPending}>
            Lưu tài khoản
          </Button>
        </div>
      </form>
      <ConfirmDialog
        open={!!pending}
        onOpenChange={(v) => !v && !action.isPending && setPending(null)}
        title={item ? 'Xác nhận cập nhật tài khoản?' : 'Tạo tài khoản?'}
        description={
          pending
            ? 'Vai trò: ' +
              roleLabels[pending.role] +
              '. Trạng thái: ' +
              (pending.active ? 'Hoạt động.' : 'Đã khóa.')
            : ''
        }
        onConfirm={save}
        pending={action.isPending}
      />
    </>
  );
}

import { z } from 'zod';
import { optionalPhoneSchema } from './phone';

export const supplierSchema = z
  .object({
    productIds: z
      .array(z.string().regex(/^[1-9][0-9]*$/))
      .max(5000)
      .default([]),
    supplierType: z.enum(['DOANH_NGHIEP', 'HO_KINH_DOANH', 'CA_NHAN']),
    verificationStatus: z.enum(['CHUA_XAC_MINH', 'DA_XAC_MINH', 'CAN_KIEM_TRA_LAI']),
    verificationNotes: z.string().trim().max(2000),
    verificationConfirmed: z.boolean(),
    fullName: z.string().trim().min(2, 'Nhập tên nhà cung cấp.').max(255),
    taxCode: z.string().trim().max(30),
    contactName: z.string().trim().max(150),
    phone: optionalPhoneSchema,
    email: z
      .string()
      .trim()
      .max(255)
      .refine((v) => !v || z.string().email().safeParse(v).success, 'Email không hợp lệ.'),
    address: z.string().trim().max(2000),
    status: z.enum(['HOP_TAC', 'NGUNG_HOP_TAC']),
  })
  .superRefine((v, ctx) => {
    const code = v.taxCode;
    const tax = /^[0-9]{10}(?:-?[0-9]{3})?$/.test(code);
    const personal = v.supplierType !== 'DOANH_NGHIEP' && /^[0-9]{12}$/.test(code);
    if (code && !tax && !personal)
      ctx.addIssue({
        code: 'custom',
        path: ['taxCode'],
        message:
          v.supplierType === 'DOANH_NGHIEP'
            ? 'Nhập mã số thuế 10 số hoặc 10 số-3 số.'
            : 'Nhập số định danh 12 số hoặc mã số thuế 10/13 số theo hồ sơ.',
      });
    if (v.verificationStatus === 'DA_XAC_MINH') {
      if (!code)
        ctx.addIssue({
          code: 'custom',
          path: ['taxCode'],
          message: 'Nhập mã số thuế / số định danh trước khi xác minh.',
        });
      if (!v.verificationConfirmed)
        ctx.addIssue({
          code: 'custom',
          path: ['verificationConfirmed'],
          message: 'Xác nhận đã đối chiếu hồ sơ và thông tin tra cứu.',
        });
    }
  });
const optionalNumber = (integer = false) =>
  z.preprocess(
    (v) => (v === '' || v == null ? null : Number(v)),
    (integer
      ? z.number().int().min(0).max(2147483647)
      : z.number().min(0).max(1e12).multipleOf(0.01)
    ).nullable(),
  );
export const promotionSchema = z
  .object({
    code: z
      .string()
      .trim()
      .min(1, 'Nhập mã khuyến mãi.')
      .max(60)
      .regex(/^[A-Za-z0-9_-]+$/, 'Mã chỉ gồm chữ, số, dấu gạch ngang hoặc gạch dưới.')
      .transform((v) => v.toUpperCase()),
    fullName: z.string().trim().min(2, 'Nhập tên chương trình.').max(150),
    description: z.string().trim().max(3000),
    discountType: z.enum(['PERCENT', 'FIXED']),
    value: z.coerce.number().min(0.01, 'Mức giảm phải lớn hơn 0.').max(1e12).multipleOf(0.01),
    maxDiscount: optionalNumber(),
    minimumOrder: z.coerce.number().min(0).max(1e12).multipleOf(0.01),
    startsAt: z
      .string()
      .min(1, 'Chọn thời gian bắt đầu.')
      .refine((v) => Number.isFinite(new Date(v).getTime()), 'Thời gian không hợp lệ.'),
    endsAt: z
      .string()
      .min(1, 'Chọn thời gian kết thúc.')
      .refine((v) => Number.isFinite(new Date(v).getTime()), 'Thời gian không hợp lệ.'),
    totalLimit: optionalNumber(true),
    customerLimit: optionalNumber(true),
    scope: z.enum(['CATEGORY', 'BRAND']),
    scopeIds: z.array(z.string()).max(500),
    status: z.enum(['ACTIVE', 'INACTIVE']),
  })
  .superRefine((v, ctx) => {
    if (v.discountType === 'PERCENT' && v.value > 100)
      ctx.addIssue({ code: 'custom', path: ['value'], message: 'Mức giảm không vượt quá 100%.' });
    if (new Date(v.endsAt) <= new Date(v.startsAt))
      ctx.addIssue({ code: 'custom', path: ['endsAt'], message: 'Kết thúc phải sau bắt đầu.' });
    if (v.scope !== 'ALL' && !v.scopeIds.length)
      ctx.addIssue({
        code: 'custom',
        path: ['scopeIds'],
        message: 'Chọn ít nhất một đối tượng áp dụng.',
      });
  });
export function localDateTime(value) {
  const d = new Date(value);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

import { z } from 'zod';
import { provinces, formatProfileAddress } from '@/utils/address';
export const loginSchema = z.object({
  email: z.string().email('Email chưa đúng định dạng.'),
  password: z.string().min(8, 'Mật khẩu cần ít nhất 8 ký tự.'),
});
export const phoneSchema = z.string().regex(/^(0|\+84)[0-9]{9,10}$/, 'Số điện thoại chưa hợp lệ.');
const profileFields = {
  name: z.string().trim().min(2, 'Vui lòng nhập họ tên.').max(100),
  phone: phoneSchema,
};
export const profileSchema = z
  .object({
    ...profileFields,
    provinceCode: z.string().min(1, 'Vui lòng chọn tỉnh/thành phố.'),
    wardCode: z.string().min(1, 'Vui lòng chọn phường/xã.'),
    streetAddress: z.string().trim().min(5, 'Vui lòng nhập số nhà và tên đường.').max(200),
  })
  .superRefine((values, ctx) => {
    const province = provinces.find((item) => item.code === values.provinceCode);
    if (values.provinceCode && !province) {
      ctx.addIssue({
        code: 'custom',
        path: ['provinceCode'],
        message: 'Tỉnh/thành phố không hợp lệ.',
      });
    }
    if (values.wardCode && !province?.wards.some((item) => item.code === values.wardCode)) {
      ctx.addIssue({
        code: 'custom',
        path: ['wardCode'],
        message: 'Vui lòng chọn phường/xã thuộc tỉnh/thành phố đã chọn.',
      });
    }
  })
  .transform((values) => ({ ...values, address: formatProfileAddress(values) }));
export const managementProfileSchema = z.object({
  ...profileFields,
  address: z.string().trim().max(300),
});
export const registerSchema = loginSchema
  .extend({
    name: z.string().trim().min(2, 'Vui lòng nhập họ tên.'),
    phone: phoneSchema,
    confirmPassword: z.string(),
  })
  .refine((v) => v.password === v.confirmPassword, {
    path: ['confirmPassword'],
    message: 'Mật khẩu xác nhận chưa khớp.',
  });
export const checkoutSchema = z.object({
  receiver: z.string().trim().min(2, 'Vui lòng nhập tên người nhận.').max(100),
  phone: phoneSchema,
  address: z.string().trim().min(10, 'Vui lòng nhập địa chỉ đầy đủ.').max(300),
  note: z.string().max(500).optional(),
  paymentMethod: z.literal('COD'),
});
export const productSchema = z.object({
  active: z.boolean().default(true),
  name: z.string().trim().min(2, 'Tên cần ít nhất 2 ký tự.').max(150),
  brand: z.string().trim().min(1, 'Vui lòng nhập thương hiệu.'),
  categoryId: z.string().min(1, 'Vui lòng chọn danh mục.'),
  volume: z.string().trim().min(1, 'Vui lòng nhập quy cách.'),
  price: z.coerce.number().min(0, 'Giá không được âm.').max(100000000),
  stock: z.coerce.number().int('Tồn kho phải là số nguyên.').min(0).max(1000000),
  description: z.string().max(3000),
  color: z.string(),
  art: z.enum(['can', 'bottle', 'water', 'carton']),
});

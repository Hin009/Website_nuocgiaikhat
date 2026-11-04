import { z } from 'zod';

export const phoneMessage = 'Số điện thoại phải gồm đúng 10 hoặc 11 chữ số.';
export const phoneSchema = z.string().regex(/^[0-9]{10,11}$/, phoneMessage);
export const optionalPhoneSchema = z.string().regex(/^(?:[0-9]{10,11})?$/, phoneMessage);

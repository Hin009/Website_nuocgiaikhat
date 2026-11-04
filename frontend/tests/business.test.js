import { describe, it, expect } from 'vitest';
import { promotionSchema, supplierSchema, localDateTime } from '../src/schemas/business';
const promotion = {
  code: 'test10',
  fullName: 'Test promotion',
  description: '',
  discountType: 'PERCENT',
  value: 10,
  maxDiscount: '',
  minimumOrder: 0,
  startsAt: '2026-11-04T09:00',
  endsAt: '2026-11-05T09:00',
  totalLimit: '',
  customerLimit: '',
  scope: 'CATEGORY',
  scopeIds: ['1'],
  status: 'ACTIVE',
};
describe('business management forms', () => {
  it('keeps blank limits unlimited and zero limits distinct', () => {
    expect(promotionSchema.parse(promotion)).toMatchObject({
      code: 'TEST10',
      maxDiscount: null,
      totalLimit: null,
      customerLimit: null,
    });
    expect(promotionSchema.parse({ ...promotion, totalLimit: '0' }).totalLimit).toBe(0);
  });
  it('rejects invalid discount percentages and dates', () => {
    expect(promotionSchema.safeParse({ ...promotion, value: 101 }).success).toBe(false);
    expect(promotionSchema.safeParse({ ...promotion, endsAt: promotion.startsAt }).success).toBe(
      false,
    );
  });
  it('requires scope selection for targeted promotions', () => {
    expect(promotionSchema.safeParse({ ...promotion, scopeIds: [] }).success).toBe(false);
    expect(
      promotionSchema.safeParse({ ...promotion, scope: 'BRAND', scopeIds: ['1'] }).success,
    ).toBe(true);
  });
  it('accepts fixed reductions greater than 100 dong', () => {
    expect(
      promotionSchema.safeParse({ ...promotion, discountType: 'FIXED', value: 20000 }).success,
    ).toBe(true);
  });
  it('round trips local date and time without changing the instant', () => {
    const instant = new Date('2026-11-04T02:31:20Z');
    expect(new Date(localDateTime(instant)).getTime()).toBe(instant.getTime());
  });
  it('validates supplier contact details and permits optional fields', () => {
    const supplier = {
      supplierType: 'DOANH_NGHIEP',
      verificationStatus: 'CHUA_XAC_MINH',
      verificationNotes: '',
      verificationConfirmed: false,
      fullName: 'Supplier',
      taxCode: '',
      contactName: '',
      phone: '',
      email: '',
      address: '',
      status: 'HOP_TAC',
    };
    expect(supplierSchema.safeParse(supplier).success).toBe(true);
    expect(supplierSchema.safeParse({ ...supplier, email: 'invalid' }).success).toBe(false);
    expect(supplierSchema.safeParse({ ...supplier, phone: '+84 900 000 000' }).success).toBe(false);
  });
});

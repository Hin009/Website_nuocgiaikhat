import { describe, it, expect } from 'vitest';
import { supplierSchema, promotionSchema } from '../src/schemas/business';
import { phoneSchema, optionalPhoneSchema } from '../src/schemas/phone';

const supplier = {
  fullName: 'Supplier',
  taxCode: '0123456789',
  contactName: '',
  phone: '0900000000',
  email: '',
  address: '',
  status: 'HOP_TAC',
  supplierType: 'DOANH_NGHIEP',
  verificationStatus: 'CHUA_XAC_MINH',
  verificationNotes: '',
  verificationConfirmed: false,
};
describe('supplier legal verification', () => {
  it('accepts each legal identifier only for the appropriate supplier type', () => {
    expect(supplierSchema.safeParse({ ...supplier, taxCode: '0123456789-001' }).success).toBe(true);
    expect(supplierSchema.safeParse({ ...supplier, taxCode: '012345678901' }).success).toBe(false);
    expect(
      supplierSchema.safeParse({ ...supplier, supplierType: 'CA_NHAN', taxCode: '012345678901' })
        .success,
    ).toBe(true);
    expect(supplierSchema.safeParse({ ...supplier, taxCode: '123' }).success).toBe(false);
  });
  it('requires a legal code and manual confirmation for verification', () => {
    expect(
      supplierSchema.safeParse({ ...supplier, verificationStatus: 'DA_XAC_MINH' }).success,
    ).toBe(false);
    expect(
      supplierSchema.safeParse({
        ...supplier,
        verificationStatus: 'DA_XAC_MINH',
        verificationConfirmed: true,
      }).success,
    ).toBe(true);
    expect(
      supplierSchema.safeParse({
        ...supplier,
        taxCode: '',
        verificationStatus: 'DA_XAC_MINH',
        verificationConfirmed: true,
      }).success,
    ).toBe(false);
    expect(supplierSchema.safeParse({ ...supplier, taxCode: '' }).success).toBe(true);
  });
});
describe('shared telephone validation', () => {
  it('keeps optionality but rejects anything other than 10 or 11 digits', () => {
    for (const phone of ['0900000000', '01234567890'])
      expect(phoneSchema.safeParse(phone).success).toBe(true);
    for (const phone of [
      '123456789',
      '123456789012',
      '+84900000000',
      '090 0000000',
      '090000000a',
      '',
    ])
      expect(phoneSchema.safeParse(phone).success).toBe(false);
    expect(optionalPhoneSchema.safeParse('').success).toBe(true);
  });
});
describe('promotion scope restriction', () => {
  it('rejects legacy product/all scope even when ids are supplied', () => {
    const value = {
      code: 'TEST',
      fullName: 'Test',
      description: '',
      discountType: 'PERCENT',
      value: 10,
      maxDiscount: '',
      minimumOrder: 0,
      startsAt: '2026-11-04T09:00',
      endsAt: '2026-11-05T09:00',
      totalLimit: '',
      customerLimit: '',
      scopeIds: ['1'],
      status: 'ACTIVE',
    };
    for (const scope of ['CATEGORY', 'BRAND'])
      expect(promotionSchema.safeParse({ ...value, scope }).success).toBe(true);
    for (const scope of ['ALL', 'PRODUCT'])
      expect(promotionSchema.safeParse({ ...value, scope }).success).toBe(false);
  });
});

import { describe, it, expect } from 'vitest';
import { supplierSchema, promotionSchema } from '../src/schemas/business';
import { phoneSchema, optionalPhoneSchema } from '../src/schemas/phone';
import { provinces } from '@/utils/address';

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
describe('supplier tax code format', () => {
  it('saves structured supplier addresses in the existing API field', () => {
    const city = provinces[0],
      ward = city.wards[0];
    const values = {
      ...supplier,
      provinceCode: city.code,
      wardCode: ward.code,
      streetAddress: '24/1 Kha Vạn Cân',
    };
    const result = supplierSchema.parse(values);
    expect(result.address).toBe(`24/1 Kha Vạn Cân, ${ward.name}, ${city.name}`);
    expect(result).not.toHaveProperty('provinceCode');
    expect(
      supplierSchema.safeParse({ ...values, wardCode: provinces[1].wards[0].code }).success,
    ).toBe(false);
    expect(supplierSchema.safeParse({ ...values, provinceCode: '', wardCode: '' }).success).toBe(
      false,
    );
  });
  it('preserves old free-text addresses and permits clearing an optional address', () => {
    const legacy = {
      ...supplier,
      address: '24/1 Kha Vạn Cân',
      streetAddress: '24/1 Kha Vạn Cân',
      provinceCode: '',
      wardCode: '',
    };
    expect(supplierSchema.parse(legacy).address).toBe(legacy.address);
    expect(supplierSchema.parse({ ...legacy, streetAddress: '' }).address).toBe('');
  });
  it('accepts ten digits for businesses and households, retaining leading zeroes', () => {
    for (const supplierType of ['DOANH_NGHIEP', 'HO_KINH_DOANH']) {
      const result = supplierSchema.parse({ ...supplier, supplierType });
      expect(result.taxCode).toBe('0123456789');
      expect(result).not.toHaveProperty('verificationStatus');
    }
  });
  it('rejects letters, missing digits and old 12/13 digit identifiers', () => {
    for (const taxCode of [
      '123',
      '012345678',
      '012345678901',
      '0123456789-001',
      '0123456789001',
      '012345678a',
    ])
      expect(supplierSchema.safeParse({ ...supplier, taxCode }).success).toBe(false);
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

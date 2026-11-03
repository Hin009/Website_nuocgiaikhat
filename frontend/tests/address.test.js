import { describe, it, expect } from 'vitest';
import { provinces, profileAddressDefaults, formatProfileAddress } from '@/utils/address';
import { profileSchema, managementProfileSchema } from '@/schemas';

describe('profile address', () => {
  it('separates the city in a legacy address without guessing a ward', () => {
    expect(profileAddressDefaults({ address: '12 Nguyễn Huệ, TP. Hồ Chí Minh' })).toEqual({
      provinceCode: '79',
      wardCode: '',
      streetAddress: '12 Nguyễn Huệ',
    });
  });
  it('keeps an unrecognized legacy address intact', () => {
    expect(profileAddressDefaults({ address: '12 Đường cũ, Địa phương cũ' }).streetAddress).toBe(
      '12 Đường cũ, Địa phương cũ',
    );
    expect(profileAddressDefaults({ address: '' }).provinceCode).toBe('');
  });
  it('round trips a full address and rejects a ward from another province', () => {
    const province = provinces[0];
    const ward = province.wards[0];
    const values = {
      name: 'Nguyễn Minh Anh',
      phone: '0901234567',
      provinceCode: province.code,
      wardCode: ward.code,
      streetAddress: '12 Nguyễn Huệ',
    };
    const result = profileSchema.parse(values);
    expect(result.address).toBe(`12 Nguyễn Huệ, ${ward.name}, ${province.name}`);
    expect(profileAddressDefaults({ address: result.address })).toEqual({
      provinceCode: province.code,
      wardCode: ward.code,
      streetAddress: '12 Nguyễn Huệ',
    });
    expect(formatProfileAddress(values)).toBe(result.address);
    expect(
      profileSchema.safeParse({ ...values, wardCode: provinces[1].wards[0].code }).success,
    ).toBe(false);
    expect(profileSchema.safeParse({ ...values, wardCode: '' }).success).toBe(false);
    expect(profileSchema.safeParse({ ...values, provinceCode: '', wardCode: '' }).success).toBe(
      false,
    );
    expect(profileSchema.safeParse({ ...values, streetAddress: '' }).success).toBe(false);
    expect(profileAddressDefaults(result)).toEqual({
      provinceCode: province.code,
      wardCode: ward.code,
      streetAddress: '12 Nguyễn Huệ',
    });
  });
  it('keeps management addresses optional', () => {
    expect(
      managementProfileSchema.safeParse({ name: 'Quản trị', phone: '0901234567', address: '' })
        .success,
    ).toBe(true);
  });
});

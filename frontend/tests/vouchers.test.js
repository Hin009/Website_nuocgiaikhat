import { describe, it, expect, beforeEach, vi } from 'vitest';
import { vouchers } from '@/data/vouchers';
import { evaluateVoucher, calculateOrderPricing } from '@/utils/vouchers';
import { orderService } from '@/services/mock';
import { readDb, resetDb } from '@/mocks/database';

beforeEach(() => {
  const storage = new Map();
  vi.stubGlobal('localStorage', {
    getItem: (key) => storage.get(key) ?? null,
    setItem: (key, value) => storage.set(key, value),
    removeItem: (key) => storage.delete(key),
  });
  resetDb();
});

it('applies 20 percent starting at 500000 without a discount cap', () => {
  const voucher = vouchers.find((item) => item.code === 'DONHANG20');
  expect(evaluateVoucher(voucher, 499999).eligible).toBe(false);
  expect(evaluateVoucher(voucher, 499999).reason).toContain('Cần mua thêm');
  expect(evaluateVoucher(voucher, 500000).discountAmount).toBe(100000);
  expect(evaluateVoucher(voucher, 1000000).discountAmount).toBe(200000);
  expect(evaluateVoucher(voucher, 0).eligible).toBe(false);
});

it('discounts only matching product lines, including pack prices, and excludes unselected lines', () => {
  const voucher = {
    code: 'TEST',
    type: 'product',
    value: 10,
    productIds: ['p01'],
    productNames: ['Coca-Cola'],
    minSubtotal: 0,
  };
  const items = [
    { productId: 'p01', lineTotal: 59400 },
    { productId: 'p02', lineTotal: 40000 },
    { productId: 'p01', lineTotal: 500000, selected: false },
  ];
  expect(evaluateVoucher(voucher, 99400, items)).toMatchObject({
    eligible: true,
    discountAmount: 5940,
  });
  expect(evaluateVoucher(voucher, 40000, [{ productId: 'p02', lineTotal: 40000 }]).eligible).toBe(
    false,
  );
  expect(evaluateVoucher(voucher, 0, []).eligible).toBe(false);
});

it('charges shipping on all nonempty orders unless the shipping voucher is applied', () => {
  expect(calculateOrderPricing(200000, 'FREESHIP200')).toMatchObject({
    shippingFee: 20000,
    shippingDiscountAmount: 20000,
    discountAmount: 0,
    total: 200000,
  });
  expect(() => calculateOrderPricing(199999, 'FREESHIP200')).toThrow('chưa đủ điều kiện');
  expect(calculateOrderPricing(300000, 'FREESHIP200')).toMatchObject({
    shippingFee: 20000,
    shippingDiscountAmount: 20000,
    total: 300000,
  });
  for (const subtotal of [199999, 200000, 299999, 300000, 500000, 1000000]) {
    expect(calculateOrderPricing(subtotal)).toMatchObject({
      shippingFee: 20000,
      shippingDiscountAmount: 0,
      total: subtotal + 20000,
    });
  }
  expect(calculateOrderPricing(0)).toMatchObject({ shippingFee: 0, total: 0 });
  expect(calculateOrderPricing(11000)).toMatchObject({
    discountAmount: 0,
    total: 31000,
    voucherCode: '',
  });
  expect(() => calculateOrderPricing(100000, 'UNKNOWN')).toThrow('không tồn tại');
});

const customer = { id: 'u1', role: 'CUSTOMER' };
const values = {
  receiver: 'Nguyễn Minh Anh',
  phone: '0901234567',
  address: '12 Nguyễn Huệ, TP. Hồ Chí Minh',
  paymentMethod: 'COD',
};

describe('voucher validation when creating orders', () => {
  it('calculates saved amounts from actual products rather than submitted totals', async () => {
    const order = await orderService.create(
      customer,
      {
        ...values,
        voucherCode: 'DONHANG20',
        total: 1,
        discountAmount: 999999,
        shippingFee: 20000,
        shippingDiscountAmount: 999999,
      },
      [{ productId: 'p01', quantity: 50 }],
    );
    expect(order).toMatchObject({
      voucherCode: 'DONHANG20',
      subtotal: 550000,
      discountAmount: 110000,
      shippingFee: 20000,
      shippingDiscountAmount: 0,
      total: 460000,
    });
    expect(readDb().orders[0]).toEqual(order);
  });
  it('saves the shipping discount separately', async () => {
    const order = await orderService.create(customer, { ...values, voucherCode: 'FREESHIP200' }, [
      { productId: 'p01', quantity: 20 },
    ]);
    expect(order).toMatchObject({
      subtotal: 220000,
      shippingFee: 20000,
      shippingDiscountAmount: 20000,
      discountAmount: 0,
      total: 220000,
    });
  });
  it('does not count unselected items toward the minimum', async () => {
    const count = readDb().orders.length;
    await expect(
      orderService.create(customer, { ...values, voucherCode: 'DONHANG20' }, [
        { productId: 'p01', quantity: 1 },
        { productId: 'p01', quantity: 50, selected: false },
      ]),
    ).rejects.toThrow('chưa đủ điều kiện');
    expect(readDb().orders).toHaveLength(count);
  });
});

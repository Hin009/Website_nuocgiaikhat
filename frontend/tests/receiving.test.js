import { describe, it, expect } from 'vitest';
import { remainingToReceive, receiptItems } from '../src/utils/receiving';
describe('receipt settlement at delivery', () => {
  const line = { id: 1, so_luong_dat: 99 };
  const confirmed = [
    {
      trang_thai: 'CONFIRMED',
      items: [{ ct_don_ncc_id: 1, so_luong_thuc_nhan: 90, so_luong_loai: 9 }],
    },
  ];
  it('counts accepted and rejected quantities as processed, never draft receipts', () => {
    expect(remainingToReceive(line, confirmed)).toBe(0);
    expect(remainingToReceive(line, [{ ...confirmed[0], trang_thai: 'DRAFT' }])).toBe(99);
    expect(remainingToReceive({ ...line, so_luong_con_lai: 3 }, confirmed)).toBe(3);
  });
  it('derives accepted quantity from delivered minus rejected', () => {
    expect(
      receiptItems([line], { 1: { delivered: '99', rejected: '9', reason: 'Bể', cost: '5000' } }),
    ).toEqual([
      {
        purchaseLineId: 1,
        quantity: 90,
        rejectedQuantity: 9,
        rejectionReason: 'Bể',
        actualCost: 5000,
      },
    ]);
    expect(
      receiptItems([line], {
        1: { delivered: '99', rejected: '99', reason: 'Hết hạn', cost: '5000' },
      })[0].quantity,
    ).toBe(0);
  });
  it('supports partial deliveries without replacing previously rejected goods', () => {
    const prior = [
      {
        trang_thai: 'CONFIRMED',
        items: [{ ct_don_ncc_id: 1, so_luong_thuc_nhan: 40, so_luong_loai: 9 }],
      },
    ];
    expect(remainingToReceive(line, prior)).toBe(50);
    expect(
      receiptItems(
        [line],
        { 1: { delivered: '50', rejected: '0', reason: '', cost: '5000' } },
        prior,
      )[0].quantity,
    ).toBe(50);
  });
  it('rejects over-delivery, fractional quantities, missing reasons and invalid costs', () => {
    const valid = { delivered: '99', rejected: '9', reason: 'Bể', cost: '5000' };
    for (const invalid of [
      { delivered: '100' },
      { rejected: '100' },
      { delivered: '1.5' },
      { reason: '' },
      { cost: '' },
      { cost: '-1' },
    ])
      expect(() => receiptItems([line], { 1: { ...valid, ...invalid } })).toThrow();
  });
});

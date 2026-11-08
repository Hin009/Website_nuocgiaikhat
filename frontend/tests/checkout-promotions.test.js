import { describe, it, expect } from 'vitest';
import { promotionExpiry, promotionUnavailableReason } from '../src/utils/checkout-promotions';

describe('checkout promotion eligibility', () => {
  const items = [{ productId: '1', categoryId: '2', brandId: '3' }];
  it.each([
    ['PRODUCT', 'san_pham_id', 1],
    ['CATEGORY', 'loai_san_pham_id', 2],
    ['BRAND', 'thuong_hieu_id', 3],
  ])('matches %s restrictions to selected products', (scope, field, id) => {
    const promotion = { pham_vi_ap_dung: scope, scopes: [{ [field]: id }] };
    expect(promotionUnavailableReason(promotion, items, 50000)).toBe('');
    expect(
      promotionUnavailableReason({ ...promotion, scopes: [{ [field]: 99 }] }, items, 50000),
    ).toContain('chưa có sản phẩm');
    expect(promotionUnavailableReason(promotion, [], 50000)).toContain('chưa có sản phẩm');
  });
  it('keeps unrestricted offers and enforces minimum spend', () => {
    expect(promotionUnavailableReason({ pham_vi_ap_dung: 'ALL' }, items, 50000)).toBe('');
    expect(
      promotionUnavailableReason({ pham_vi_ap_dung: 'ALL', don_toi_thieu: 100000 }, items, 50000),
    ).toContain('giá trị tối thiểu');
  });
  it('formats expiry as DD.MM.YYYY in Vietnam time without a time', () => {
    expect(promotionExpiry('2026-12-02T10:30:00Z')).toBe('02.12.2026');
    expect(promotionExpiry('2026-12-01T18:00:00Z')).toBe('02.12.2026');
    expect(promotionExpiry('')).toBe('');
  });
});

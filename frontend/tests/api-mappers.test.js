import { describe, it, expect } from 'vitest';
import { mapProduct, mapOrder, mapCart } from '../src/services/mappers';
import { canPurchase } from '../src/utils/inventory';
import { purchaseUnits } from '../src/utils/purchase';

describe('PostgreSQL data displayed on the storefront', () => {
  it('uses actual package prices and allows stock below the mock threshold', () => {
    const p = mapProduct({ id: 1, ten: 'Cola', trang_thai: 'DANG_BAN', so_luong_co_ban: 6 }, [
      { id: 2, ten_quy_cach: 'Thùng', he_so_quy_doi: 24, gia_ban: 257000, dang_ban: true },
      { id: 1, ten_quy_cach: 'Lon', he_so_quy_doi: 1, gia_ban: 12000, dang_ban: true },
    ]);
    expect(purchaseUnits(p).map((q) => q.price)).toEqual([12000, 257000]);
    expect(canPurchase(p)).toBe(true);
    expect(
      mapCart({ items: [{ san_pham_id: 1, quy_cach_id: 2, so_luong: 3, price_changed: true }] }),
    ).toEqual([
      {
        productId: '1',
        categoryId: null,
        brandId: null,
        packageId: '2',
        unit: 'package-2',
        quantity: 3,
        selected: true,
        priceChanged: true,
      },
    ]);
  });
  it('keeps account and customer IDs separate and uses server order totals', () => {
    const order = mapOrder({
      id: 5,
      khach_hang_id: 8,
      tai_khoan_khach_id: 12,
      trang_thai: 'DANG_CHUAN_BI',
      tong_tien: 285000,
      giam_gia: 2000,
      phi_van_chuyen: 30000,
      items: [
        {
          id: 1,
          san_pham_id: 1,
          quy_cach_id: 2,
          so_luong: 1,
          he_so_quy_doi: 24,
          don_gia: 257000,
          thanh_tien: 257000,
        },
      ],
    });
    expect(order).toMatchObject({
      id: '5',
      userId: '12',
      customerId: '8',
      status: 'CONFIRMED',
      total: 285000,
      subtotal: 257000,
    });
    expect(order.items[0]).toMatchObject({
      quantity: 24,
      purchaseQuantity: 1,
      purchasePrice: 257000,
    });
  });
});

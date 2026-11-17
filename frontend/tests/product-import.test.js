import { describe, it, expect } from 'vitest';
import { importHeaders, parseProductRows, templateSheets } from '../src/utils/product-import';
const categories = [{ id: '1', name: 'Nước ngọt' }];
const row = ['Nước cam', 'Cam Việt', 'Nước ngọt', 'Lon 330ml', 'Lon', '', 'Có'];
describe('product Excel validation', () => {
  it('maps reordered headers, skips blank lines and preserves Excel row numbers', () => {
    const headers = [...importHeaders].reverse();
    const result = parseProductRows([headers, [], [...row].reverse()], categories);
    expect(result[0]).toMatchObject({
      rowNumber: 3,
      errors: [],
      product: { fullName: 'Nước cam', categoryId: '1', packaging: 'LON', active: true },
    });
  });
  it('rejects missing, duplicate and unsupported columns, empty and oversized files', () => {
    for (const matrix of [
      [],
      [importHeaders],
      [['Tên sản phẩm']],
      [[...importHeaders, 'Giá']],
      [[...importHeaders, 'Tên sản phẩm']],
      [importHeaders, ...Array(201).fill(row)],
    ])
      expect(() => parseProductRows(matrix, categories)).toThrow();
  });
  it('reports unknown categories, packaging and invalid status without silently defaulting', () => {
    const bad = [...row];
    bad[2] = 'Không có';
    bad[4] = 'Túi';
    bad[6] = 'Sai';
    expect(parseProductRows([importHeaders, bad], categories)[0].errors).toHaveLength(3);
  });
  it('blocks duplicate rows and existing products; retains inactive flag', () => {
    const inactive = [...row];
    inactive[6] = 'Không';
    const result = parseProductRows([importHeaders, inactive, row], categories);
    expect(result[0].product.active).toBe(false);
    expect(result[1].errors.join()).toContain('Trùng');
    expect(
      parseProductRows([importHeaders, row], categories, [
        { name: row[0], brand: row[1], categoryId: '1', volume: row[3] },
      ])[0].errors.join(),
    ).toContain('Trùng');
  });
  it('rejects ambiguous category names and data beyond declared columns', () => {
    expect(
      parseProductRows([importHeaders, [...row, '100']], categories)[0].errors.join(),
    ).toContain('tiêu đề');
    expect(
      parseProductRows(
        [importHeaders, row],
        [...categories, { id: '2', name: 'Nước ngọt' }],
      )[0].errors.join(),
    ).toContain('không rõ');
  });
  it('creates a blank import sheet and documents real category names separately', () => {
    const sheets = templateSheets(categories);
    expect(sheets[0].data).toHaveLength(1);
    expect(sheets[0].data[0].map((c) => c.value)).toEqual(importHeaders);
    expect(sheets[1].data.flat().map((c) => c.value)).toContain('Nước ngọt');
  });
});

import { describe, expect, it } from 'vitest';
import {
  createReportPeriod,
  reportPeriodBounds,
  sortReportRows,
  isWithinReportPeriod,
} from '../src/utils/reports';

describe('report calendar periods', () => {
  const base = { type: 'all', day: '2026-11-11', month: '2026-11', year: '2026', quarter: '4' };
  it('initializes at the store timezone across UTC midnight boundaries', () => {
    expect(createReportPeriod(new Date('2026-12-31T18:00:00Z'))).toEqual({
      type: 'all',
      day: '2027-01-01',
      month: '2027-01',
      year: '2027',
      quarter: '1',
    });
  });
  it.each([
    [{ type: 'all' }, { valid: true }],
    [{ type: 'day' }, { valid: true, from: '2026-11-11', to: '2026-11-11' }],
    [
      { type: 'month', month: '2024-02' },
      { valid: true, from: '2024-02-01', to: '2024-02-29' },
    ],
    [
      { type: 'month', month: '2026-02' },
      { valid: true, from: '2026-02-01', to: '2026-02-28' },
    ],
    [
      { type: 'quarter', quarter: '1' },
      { valid: true, from: '2026-01-01', to: '2026-03-31' },
    ],
    [
      { type: 'quarter', quarter: '2' },
      { valid: true, from: '2026-04-01', to: '2026-06-30' },
    ],
    [
      { type: 'quarter', quarter: '3' },
      { valid: true, from: '2026-07-01', to: '2026-09-30' },
    ],
    [{ type: 'quarter' }, { valid: true, from: '2026-10-01', to: '2026-12-31' }],
    [{ type: 'year' }, { valid: true, from: '2026-01-01', to: '2026-12-31' }],
  ])('computes inclusive bounds for %j', (overrides, expected) => {
    expect(reportPeriodBounds({ ...base, ...overrides })).toEqual(expected);
  });
  it.each([
    { type: 'day', day: '' },
    { type: 'day', day: '2026-02-30' },
    { type: 'month', month: '2026-13' },
    { type: 'year', year: '' },
    { type: 'year', year: '2026.5' },
    { type: 'year', year: '1899' },
    { type: 'quarter', quarter: '5' },
  ])('does not query invalid or incomplete selections %j', (overrides) => {
    expect(reportPeriodBounds({ ...base, ...overrides }).valid).toBe(false);
  });
});

describe('report sorting', () => {
  const rows = [
    { product_id: 1, product_name: 'Cam 10', gross_profit: '20', margin_percent: null },
    { product_id: 2, product_name: 'Cam 2', gross_profit: '-100', margin_percent: '9' },
    { product_id: 3, product_name: 'Đào', gross_profit: '100', margin_percent: '20' },
  ];
  it('sorts decimal strings and negative amounts numerically without mutating query data', () => {
    expect(sortReportRows(rows, 'gross_profit', 'asc').map((r) => r.product_id)).toEqual([2, 1, 3]);
    expect(sortReportRows(rows, 'gross_profit', 'desc').map((r) => r.product_id)).toEqual([
      3, 1, 2,
    ]);
    expect(rows.map((r) => r.product_id)).toEqual([1, 2, 3]);
  });
  it('sorts names naturally and keeps undefined margins last in both directions', () => {
    expect(sortReportRows(rows, 'product_name', 'asc').map((r) => r.product_id)).toEqual([2, 1, 3]);
    expect(sortReportRows(rows, 'margin_percent', 'asc').map((r) => r.product_id)).toEqual([
      2, 3, 1,
    ]);
    expect(sortReportRows(rows, 'margin_percent', 'desc').map((r) => r.product_id)).toEqual([
      3, 2, 1,
    ]);
  });
});

describe('order date filtering in Vietnam time', () => {
  const bounds = { valid: true, from: '2026-11-01', to: '2026-11-30' };
  it('includes the first and last millisecond of the selected period', () => {
    expect(isWithinReportPeriod('2026-10-31T17:00:00Z', bounds)).toBe(true);
    expect(isWithinReportPeriod('2026-11-30T16:59:59.999Z', bounds)).toBe(true);
    expect(isWithinReportPeriod('2026-10-31T16:59:59.999Z', bounds)).toBe(false);
    expect(isWithinReportPeriod('2026-11-30T17:00:00Z', bounds)).toBe(false);
    expect(isWithinReportPeriod('invalid', bounds)).toBe(false);
    expect(isWithinReportPeriod('2026-11-11', { valid: false })).toBe(false);
    expect(isWithinReportPeriod('2026-11-11', { valid: true })).toBe(true);
  });
});

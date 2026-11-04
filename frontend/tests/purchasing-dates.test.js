import { describe, it, expect } from 'vitest';
import { purchasingDate, inPurchasingDateRange } from '../src/utils/purchasing-dates';

describe('purchasing dates in Vietnam', () => {
  it('uses Vietnam calendar dates at UTC midnight boundaries', () => {
    expect(purchasingDate('2026-01-01T17:00:00Z')).toBe('2026-01-02');
    expect(purchasingDate('2026-01-01T16:59:59Z')).toBe('2026-01-01');
    expect(purchasingDate('2026-01-02')).toBe('2026-01-02');
  });
  it('includes the whole final day, including a single-day range', () => {
    expect(inPurchasingDateRange('2026-01-02T16:59:59Z', '2026-01-02', '2026-01-02')).toBe(true);
    expect(inPurchasingDateRange('2026-01-02T17:00:00Z', '2026-01-02', '2026-01-02')).toBe(false);
  });
  it('supports either or both empty boundaries', () => {
    expect(inPurchasingDateRange('2026-12-01', '2026-01-01', '')).toBe(true);
    expect(inPurchasingDateRange('2025-12-31', '', '2026-01-01')).toBe(true);
    expect(inPurchasingDateRange(null, '', '')).toBe(true);
  });
  it('rejects reversed ranges and invalid timestamps when filtering', () => {
    expect(inPurchasingDateRange('2026-01-02', '2026-01-03', '2026-01-01')).toBe(false);
    expect(inPurchasingDateRange(null, '2026-01-01', '')).toBe(false);
    expect(inPurchasingDateRange(undefined, '2026-01-01', '')).toBe(false);
    expect(inPurchasingDateRange('bad-date', '', '2026-01-01')).toBe(false);
  });
});

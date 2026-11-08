import { describe, it, expect } from 'vitest';
import { sortByExpiry } from '../src/utils/expiry';

describe('expiry priority in the customer catalog', () => {
  it('orders valid dates first and leaves expired, unknown and out-of-stock products after them', () => {
    const products = [
      { id: 'unknown', stock: 10 },
      { id: 'later', stock: 10, nextExpiry: '2026-12-01' },
      { id: 'expired', stock: 10, nextExpiry: '2026-11-06' },
      { id: 'empty', stock: 0, nextExpiry: '2026-11-07' },
      { id: 'soon', stock: 10, nextExpiry: '2026-11-10' },
      { id: 'today', stock: 10, nextExpiry: '2026-11-07' },
    ];
    expect(
      sortByExpiry(products, '2026-11-07')
        .slice(0, 3)
        .map((p) => p.id),
    ).toEqual(['today', 'soon', 'later']);
    expect(products[0].id).toBe('unknown');
  });
});

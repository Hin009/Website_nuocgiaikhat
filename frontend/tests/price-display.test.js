import { it, expect } from 'vitest';
import { money } from '../src/utils/format';
it('displays calculated selling prices with fractional dong without rounding them away', () => {
  expect(money(10833.34)).toContain('10.833,34');
  expect(money(10000)).toContain('10.000');
});

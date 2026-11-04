import { describe, it, expect } from 'vitest';
import { formatMoneyInput, parseMoneyInput } from '../src/utils/money-input';
describe('Vietnamese money entry', () => {
  it('formats thousands while keeping an unformatted value for APIs', () => {
    expect(formatMoneyInput('10000')).toBe('10.000');
    expect(formatMoneyInput('1234567.50')).toBe('1.234.567,50');
    expect(parseMoneyInput('1.234.567,50')).toBe('1234567.50');
    expect(Number(parseMoneyInput('10.000'))).toBe(10000);
  });
  it('preserves empty, zero and decimal drafts without accepting invalid amounts', () => {
    expect(formatMoneyInput('')).toBe('');
    expect(parseMoneyInput('')).toBe('');
    expect(formatMoneyInput(0)).toBe('0');
    expect(formatMoneyInput('1000.')).toBe('1.000,');
    expect(parseMoneyInput('0001')).toBe('1');
    for (const value of ['-10', '12abc', '1,234', '1,2.3', '1e6'])
      expect(parseMoneyInput(value)).toBeNull();
  });
});

export function createReportPeriod(now = new Date()) {
  const today = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }).format(now);
  return {
    type: 'all',
    day: today,
    month: today.slice(0, 7),
    year: today.slice(0, 4),
    quarter: String(Math.ceil(Number(today.slice(5, 7)) / 3)),
  };
}

export function reportPeriodBounds(period) {
  if (period.type === 'all') return { valid: true };
  const invalid = { valid: false };
  const year = Number(period.year);
  const yearValid = /^\d{4}$/.test(period.year) && year >= 1900 && year <= 9998;
  const endOfMonth = (y, month) => new Date(Date.UTC(y, month, 0)).toISOString().slice(0, 10);
  if (period.type === 'day') {
    const day = period.day;
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(day) ||
      Number(day.slice(0, 4)) < 1900 ||
      Number(day.slice(0, 4)) > 9998
    )
      return invalid;
    const date = new Date(day + 'T00:00:00Z');
    if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== day) return invalid;
    return { valid: true, from: day, to: day };
  }
  if (period.type === 'month') {
    if (
      !/^(19\d{2}|[2-9]\d{3})-(0[1-9]|1[0-2])$/.test(period.month) ||
      period.month.startsWith('9999')
    )
      return invalid;
    return {
      valid: true,
      from: period.month + '-01',
      to: endOfMonth(Number(period.month.slice(0, 4)), Number(period.month.slice(5))),
    };
  }
  if (!yearValid) return invalid;
  if (period.type === 'year')
    return { valid: true, from: `${period.year}-01-01`, to: `${period.year}-12-31` };
  if (period.type === 'quarter' && /^[1-4]$/.test(period.quarter)) {
    const endMonth = Number(period.quarter) * 3;
    return {
      valid: true,
      from: `${period.year}-${String(endMonth - 2).padStart(2, '0')}-01`,
      to: endOfMonth(year, endMonth),
    };
  }
  return invalid;
}

export function sortReportRows(rows, key, direction) {
  const sign = direction === 'asc' ? 1 : -1;
  return [...rows].sort((a, b) => {
    const left = a[key],
      right = b[key];
    // An undefined margin (no sales) stays last in either direction.
    if (left == null && right != null) return 1;
    if (left != null && right == null) return -1;
    const comparison =
      key === 'product_name'
        ? String(left ?? '').localeCompare(String(right ?? ''), 'vi', {
            numeric: true,
            sensitivity: 'base',
          })
        : Number(left ?? 0) - Number(right ?? 0);
    return comparison * sign || Number(a.product_id) - Number(b.product_id);
  });
}

export function isWithinReportPeriod(value, bounds) {
  if (!bounds.valid) return false;
  if (!bounds.from && !bounds.to) return true;
  const timestamp = new Date(value).getTime();
  return (
    Number.isFinite(timestamp) &&
    timestamp >= new Date(bounds.from + 'T00:00:00+07:00').getTime() &&
    timestamp <= new Date(bounds.to + 'T23:59:59.999+07:00').getTime()
  );
}

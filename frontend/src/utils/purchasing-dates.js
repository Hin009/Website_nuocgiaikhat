const businessDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Ho_Chi_Minh',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

export function purchasingDate(value = new Date()) {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  if (value == null || value === '') return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  const parts = Object.fromEntries(
    businessDate.formatToParts(parsed).map((p) => [p.type, p.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function inPurchasingDateRange(value, from, to) {
  if (from && to && from > to) return false;
  if (!from && !to) return true;
  if (value == null || value === '') return false;
  const key = purchasingDate(value);
  return !!key && (!from || key >= from) && (!to || key <= to);
}

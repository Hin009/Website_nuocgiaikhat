import { purchasingDate } from './purchasing-dates';

const elapsedDays = (from, to) =>
  Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000);

export function supplierDeliveryStatus(order, today = purchasingDate()) {
  const expected = purchasingDate(order.ngay_giao_du_kien ?? null);
  if (!expected || ['DA_HUY', 'TU_CHOI', 'CHO_DUYET'].includes(order.trang_thai)) return null;
  if (order.trang_thai === 'DA_NHAN_DU') {
    const dates = (order.receipts || [])
      .filter((r) => r.trang_thai === 'CONFIRMED')
      .map((r) => purchasingDate(r.ngay_xac_nhan || r.ngay_nhap || null))
      .filter(Boolean)
      .sort();
    const completedOn = dates.at(-1);
    // Never substitute today when a historical order has no confirmed receiving date.
    if (!completedOn) return null;
    const days = elapsedDays(expected, completedOn);
    return {
      kind: days > 0 ? 'late' : days < 0 ? 'early' : 'on-time',
      days: Math.abs(days),
      completedOn,
      label:
        days > 0
          ? `Đã nhận trễ ${days} ngày`
          : days < 0
            ? `Đã nhận sớm ${-days} ngày`
            : 'Đã nhận đúng hẹn',
    };
  }
  if (!['DA_DUYET', 'DANG_GIAO', 'DA_NHAN_MOT_PHAN'].includes(order.trang_thai)) return null;
  const days = elapsedDays(expected, today);
  return days > 0 ? { kind: 'overdue', days, label: `Quá hạn giao ${days} ngày` } : null;
}

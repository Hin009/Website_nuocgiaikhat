import { describe, it, expect } from 'vitest';
import { supplierDeliveryStatus } from '../src/utils/supplier-delivery';

const order = { ngay_giao_du_kien: '2026-11-14', trang_thai: 'DA_DUYET' };
const received = (day, status = 'CONFIRMED') => ({
  trang_thai: status,
  ngay_xac_nhan: `${day}T08:00:00+07:00`,
});

describe('supplier delivery schedule', () => {
  it('only marks approved, in-transit and partial orders overdue after the due date', () => {
    for (const trang_thai of ['DA_DUYET', 'DANG_GIAO', 'DA_NHAN_MOT_PHAN']) {
      expect(supplierDeliveryStatus({ ...order, trang_thai }, '2026-11-16')?.label).toBe(
        'Quá hạn giao 2 ngày',
      );
      expect(supplierDeliveryStatus({ ...order, trang_thai }, '2026-11-14')).toBeNull();
      expect(supplierDeliveryStatus({ ...order, trang_thai }, '2026-11-04')).toBeNull();
    }
  });
  it('does not warn for cancelled, rejected, pending or undated orders', () => {
    for (const trang_thai of ['DA_HUY', 'TU_CHOI', 'CHO_DUYET'])
      expect(supplierDeliveryStatus({ ...order, trang_thai }, '2026-11-16')).toBeNull();
    expect(supplierDeliveryStatus({ trang_thai: 'DA_DUYET' }, '2026-11-16')).toBeNull();
  });
  it('uses the final confirmed receipt across partial deliveries and freezes completed lateness', () => {
    const completed = {
      ...order,
      trang_thai: 'DA_NHAN_DU',
      receipts: [
        received('2026-11-16'),
        received('2026-11-13'),
        received('2026-11-20', 'DRAFT'),
        received('2026-11-21', 'CANCELLED'),
      ],
    };
    expect(supplierDeliveryStatus(completed, '2026-12-01')).toMatchObject({
      kind: 'late',
      days: 2,
      completedOn: '2026-11-16',
      label: 'Đã nhận trễ 2 ngày',
    });
  });
  it('reports early and on-time completion without preventing receiving', () => {
    expect(
      supplierDeliveryStatus({
        ...order,
        trang_thai: 'DA_NHAN_DU',
        receipts: [received('2026-11-04')],
      })?.label,
    ).toBe('Đã nhận sớm 10 ngày');
    expect(
      supplierDeliveryStatus({
        ...order,
        trang_thai: 'DA_NHAN_DU',
        receipts: [received('2026-11-14')],
      })?.label,
    ).toBe('Đã nhận đúng hẹn');
  });
  it('uses Vietnam calendar days across months and years', () => {
    expect(
      supplierDeliveryStatus({
        ...order,
        ngay_giao_du_kien: '2025-12-31',
        trang_thai: 'DA_NHAN_DU',
        receipts: [{ trang_thai: 'CONFIRMED', ngay_xac_nhan: '2026-01-01T17:00:00Z' }],
      })?.days,
    ).toBe(2);
  });
  it('does not guess completion dates and falls back to receipt date for older data', () => {
    expect(
      supplierDeliveryStatus({
        ...order,
        trang_thai: 'DA_NHAN_DU',
        receipts: [received('2026-11-16', 'DRAFT')],
      }),
    ).toBeNull();
    expect(
      supplierDeliveryStatus({
        ...order,
        trang_thai: 'DA_NHAN_DU',
        receipts: [{ trang_thai: 'CONFIRMED', ngay_nhap: '2026-11-15T10:00:00+07:00' }],
      })?.days,
    ).toBe(1);
  });
});

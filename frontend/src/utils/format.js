export const money = (value) =>
  new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 2,
  }).format(value ?? 0);
export const date = (value) =>
  new Intl.DateTimeFormat('vi-VN', { dateStyle: 'medium' }).format(new Date(value));
export const statusLabels = {
  PENDING: 'Chờ xác nhận',
  CONFIRMED: 'Đã xác nhận',
  SHIPPING: 'Đang giao',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Đã hủy',
  REJECTED: 'Từ chối',
};
export const roleLabels = { CUSTOMER: 'Khách hàng', STAFF: 'Nhân viên', ADMIN: 'Quản trị viên' };
export const normalize = (text) =>
  String(text)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();

export const paymentMethodLabels = {
  COD: 'Thanh toán khi nhận hàng (COD)',
  MOMO: 'Ví điện tử MoMo (Sandbox)',
  BANK_TRANSFER: 'Chuyển khoản ngân hàng',
};

export function maskEmail(email) {
  const value = String(email || '').trim();
  const at = value.lastIndexOf('@');
  if (at < 1 || at === value.length - 1) return '—';
  const local = Array.from(value.slice(0, at));
  const visible = Math.min(2, Math.max(0, local.length - 1));
  return local.slice(0, visible).join('') + '*'.repeat(local.length - visible) + value.slice(at);
}

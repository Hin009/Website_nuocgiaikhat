import { vouchers } from '@/data/vouchers';
import { money } from '@/utils/format';

const shippingFor = (subtotal) => (subtotal > 0 ? 20000 : 0);

export function evaluateVoucher(voucher, subtotal, items = []) {
  const missing = Math.max(0, voucher.minSubtotal - subtotal);
  const applicableItems =
    voucher.type === 'product'
      ? items.filter(
          (item) => item.selected !== false && voucher.productIds.includes(item.productId),
        )
      : [];
  const applicableSubtotal = applicableItems.reduce((sum, item) => sum + item.lineTotal, 0);
  const shippingFee = shippingFor(subtotal);
  let reason = '';
  if (subtotal <= 0) reason = 'Vui lòng chọn sản phẩm để sử dụng voucher.';
  else if (missing > 0) reason = `Cần mua thêm ${money(missing)} tiền hàng để sử dụng.`;
  else if (voucher.type === 'product' && !voucher.productIds.length)
    reason = 'Voucher đang chờ cập nhật danh sách sản phẩm áp dụng.';
  else if (voucher.type === 'product' && applicableSubtotal <= 0)
    reason =
      'Đơn hàng chưa có sản phẩm thuộc danh sách áp dụng. Hãy thêm ít nhất một sản phẩm áp dụng và chọn sản phẩm đó để thanh toán.';

  const eligible = !reason;
  const discountBase = voucher.type === 'product' ? applicableSubtotal : subtotal;
  const discountAmount =
    eligible && voucher.type !== 'shipping'
      ? Math.min(subtotal, Math.floor((discountBase * voucher.value) / 100))
      : 0;
  let conditions;
  if (voucher.type === 'product') {
    const names = voucher.productNames?.join(', ');
    conditions = `Giảm ${voucher.value}% tiền của các sản phẩm áp dụng trong đơn, không giảm các sản phẩm khác.${names ? ` Sản phẩm áp dụng: ${names}.` : ' Danh sách sản phẩm áp dụng đang được cập nhật.'} Không yêu cầu giá trị đơn tối thiểu.`;
  } else if (voucher.type === 'shipping') {
    conditions = `Miễn phí giao hàng cho đơn có tiền hàng từ ${money(voucher.minSubtotal)}. Cần chọn voucher này tại trang thanh toán để được miễn phí giao hàng.`;
  } else {
    conditions = `Giảm ${voucher.value}% trên tiền hàng cho đơn từ ${money(voucher.minSubtotal)}. Không giới hạn số tiền giảm. Không tính phí giao hàng.`;
  }
  return {
    eligible,
    reason,
    conditions: conditions + ' Mỗi đơn dùng một voucher.',
    discountAmount,
    shippingDiscountAmount: eligible && voucher.type === 'shipping' ? shippingFee : 0,
  };
}

export function calculateOrderPricing(subtotal, voucherCode = '', items = []) {
  const shippingFee = shippingFor(subtotal);
  const voucher = voucherCode ? vouchers.find((item) => item.code === voucherCode) : null;
  if (voucherCode && !voucher) throw new Error('Voucher không tồn tại. Vui lòng chọn lại.');
  const evaluation = voucher ? evaluateVoucher(voucher, subtotal, items) : null;
  if (evaluation && !evaluation.eligible)
    throw new Error(`Voucher ${voucherCode} chưa đủ điều kiện sử dụng. ${evaluation.reason}`);
  const discountAmount = evaluation?.discountAmount || 0;
  const shippingDiscountAmount = evaluation?.shippingDiscountAmount || 0;
  return {
    shippingFee,
    discountAmount,
    shippingDiscountAmount,
    voucherCode: voucher?.code || '',
    total: subtotal + shippingFee - discountAmount - shippingDiscountAmount,
  };
}

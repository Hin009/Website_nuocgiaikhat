export function promotionExpiry(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const parts = new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).formatToParts(date);
  return ['day', 'month', 'year']
    .map((type) => parts.find((part) => part.type === type).value)
    .join('.');
}

export function promotionUnavailableReason(promotion, items, subtotal) {
  const fields = {
    PRODUCT: ['san_pham_id', 'productId'],
    CATEGORY: ['loai_san_pham_id', 'categoryId'],
    BRAND: ['thuong_hieu_id', 'brandId'],
  };
  const scope = promotion.pham_vi_ap_dung || 'ALL';
  if (scope !== 'ALL') {
    const pair = fields[scope];
    const matches =
      pair &&
      items.some((item) =>
        (promotion.scopes || []).some(
          (rule) =>
            rule[pair[0]] != null &&
            item[pair[1]] != null &&
            String(rule[pair[0]]) === String(item[pair[1]]),
        ),
      );
    if (!matches) return 'Giỏ hàng chưa có sản phẩm thuộc phạm vi áp dụng mã này.';
  }
  if (subtotal != null && Number(subtotal) < Number(promotion.don_toi_thieu || 0)) {
    return 'Đơn hàng chưa đạt giá trị tối thiểu.';
  }
  return '';
}

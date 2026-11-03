export const vouchers = [
  {
    code: 'DONHANG20',
    title: 'Giảm 20% đơn hàng',
    type: 'percent',
    value: 20,
    minSubtotal: 500000,
  },
  {
    code: 'SANPHAM10',
    title: 'Giảm 10% sản phẩm áp dụng',
    type: 'product',
    value: 10,
    minSubtotal: 0,
    productIds: [],
  },
  { code: 'FREESHIP200', title: 'Miễn phí giao hàng', type: 'shipping', minSubtotal: 200000 },
];

export const LOW_STOCK_THRESHOLD = 20;
export const isLowStock = (product) =>
  Number.isFinite(product?.stock) && product.stock <= LOW_STOCK_THRESHOLD;
export const canPurchase = (product) =>
  !!product &&
  product.active !== false &&
  Number.isSafeInteger(product.stock) &&
  product.stock > LOW_STOCK_THRESHOLD;

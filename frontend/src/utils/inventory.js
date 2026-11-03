export const LOW_STOCK_THRESHOLD = 20;
export const isLowStock = (product) =>
  Number.isFinite(product?.stock) && product.stock <= (product.source === 'api' ? (product.lowStockThreshold ?? 0) : LOW_STOCK_THRESHOLD);
export const canPurchase = (product) =>
  !!product &&
  product.active !== false &&
  Number.isSafeInteger(product.stock) &&
  (product.source === 'api' ? product.purchasable && product.packages.some(q => q.available && q.size <= product.stock) && product.stock > 0 : product.stock > LOW_STOCK_THRESHOLD);

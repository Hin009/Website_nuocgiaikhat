import { canPurchase } from '@/utils/inventory';
export const lineKey = (line) => line.productId + ':' + (line.unit || 'single');
export function purchaseUnits(product) {
  const single = product.volume?.startsWith('Lon')
    ? 'Lon'
    : product.volume?.startsWith('Hộp')
      ? 'Hộp'
      : 'Chai';
  const singlePrice = product.price || 0;
  const packPrice = Math.round(singlePrice * 6 * 0.9);
  const casePrice = Math.round(packPrice * 4 * 0.9);
  return [
    { id: 'single', label: single, size: 1, discount: 0 },
    { id: 'pack', label: 'Lốc', size: 6, discount: 0.1 },
    { id: 'case', label: 'Thùng', size: 24, discount: 0.19 },
  ].map((unit) => ({
    ...unit,
    price: unit.id === 'single' ? singlePrice : unit.id === 'pack' ? packPrice : casePrice,
  }));
}
export function purchaseUnit(product, id = 'single') {
  const unit = purchaseUnits(product).find((u) => u.id === id);
  if (!unit) throw new Error('Đơn vị mua không hợp lệ.');
  return unit;
}
export function requiredStock(lines, products) {
  return lines.reduce((totals, line) => {
    const product = products.find((p) => p.id === line.productId);
    if (!product) throw new Error('Sản phẩm không còn khả dụng.');
    const size = purchaseUnit(product, line.unit).size;
    totals[line.productId] = (totals[line.productId] || 0) + line.quantity * size;
    return totals;
  }, {});
}
export function maxLineQuantity(product, lines, line) {
  if (!canPurchase(product)) return 0;
  const used = lines
    .filter((l) => l.productId === product.id && lineKey(l) !== lineKey(line))
    .reduce((n, l) => n + l.quantity * purchaseUnit(product, l.unit).size, 0);
  return Math.max(0, Math.floor((product.stock - used) / purchaseUnit(product, line.unit).size));
}

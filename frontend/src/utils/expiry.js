import { purchasingDate } from './purchasing-dates';

export function sortByExpiry(products, today = purchasingDate()) {
  const expiry = (product) => {
    const value = product.nextExpiry?.slice(0, 10);
    return product.stock > 0 && value && value >= today ? value : '9999-12-31';
  };
  return [...products].sort(
    (a, b) =>
      expiry(a).localeCompare(expiry(b)) ||
      String(b.createdAt || '').localeCompare(String(a.createdAt || '')) ||
      String(a.id).localeCompare(String(b.id)),
  );
}

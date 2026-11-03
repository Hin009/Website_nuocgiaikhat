import { canPurchase } from '@/utils/inventory';
import { createContext, useContext, useEffect, useState } from 'react';
import { toast } from 'sonner';
import { lineKey, maxLineQuantity } from '@/utils/purchase';
import { isMock } from '@/services';
import { ApiCartProvider, useApiCart } from './ApiCartContext';
const CartContext = createContext(null);
function initial() {
  try {
    const parsed = JSON.parse(localStorage.getItem('waterbus.cart'));
    return Array.isArray(parsed)
      ? parsed
          .filter(
            (p) =>
              typeof p.productId === 'string' &&
              Number.isSafeInteger(p.quantity) &&
              p.quantity > 0 &&
              ['single', 'pack', 'case'].includes(p.unit || 'single'),
          )
          .map((p) => ({ ...p, unit: p.unit || 'single', selected: p.selected !== false }))
      : [];
  } catch {
    return [];
  }
}
function MockCartProvider({ children }) {
  const [items, setItems] = useState(initial);
  useEffect(() => {
    try {
      localStorage.setItem('waterbus.cart', JSON.stringify(items));
    } catch {
      /* bộ nhớ bị chặn */
    }
  }, [items]);
  const add = (product, quantity = 1, unit = 'single') => {
    if (!canPurchase(product)) {
      toast.error('Sản phẩm tạm hết hàng. Vui lòng chọn sản phẩm khác.');
      return;
    }
    const candidate = { productId: product.id, unit };
    const key = lineKey(candidate);
    const current = items.find((p) => lineKey(p) === key)?.quantity || 0;
    if (
      !Number.isSafeInteger(quantity) ||
      quantity < 1 ||
      current + quantity > maxLineQuantity(product, items, candidate)
    ) {
      toast.error('Số lượng vượt quá tồn kho.');
      return;
    }
    setItems((prev) =>
      prev.some((p) => lineKey(p) === key)
        ? prev.map((p) =>
            lineKey(p) === key ? { ...p, quantity: p.quantity + quantity, selected: true } : p,
          )
        : [...prev, { ...candidate, quantity, selected: true }],
    );
    toast.success('Đã thêm vào giỏ hàng');
  };
  const update = (key, quantity, max) => {
    if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > max) return;
    setItems((prev) => prev.map((p) => (lineKey(p) === key ? { ...p, quantity } : p)));
  };
  const remove = (key) => setItems((prev) => prev.filter((p) => lineKey(p) !== key));
  const removePurchased = (purchased) => {
    const keys = new Set(purchased.map(lineKey));
    setItems((prev) => prev.filter((p) => !keys.has(lineKey(p))));
  };
  const select = (key, selected) =>
    setItems((prev) => prev.map((p) => (lineKey(p) === key ? { ...p, selected } : p)));
  const selectAll = (selected) => setItems((prev) => prev.map((p) => ({ ...p, selected })));
  return (
    <CartContext.Provider
      value={{
        items,
        add,
        update,
        remove,
        removePurchased,
        select,
        selectAll,
        selectedItems: items.filter((p) => p.selected),
        count: items.reduce((n, p) => n + p.quantity, 0),
      }}
    >
      {children}
    </CartContext.Provider>
  );
}
export function CartProvider({ children }) {
  return isMock ? (
    <MockCartProvider>{children}</MockCartProvider>
  ) : (
    <ApiCartProvider>{children}</ApiCartProvider>
  );
}
export function useCart() {
  const mock = useContext(CartContext);
  const api = useApiCart();
  return isMock ? mock : api;
}

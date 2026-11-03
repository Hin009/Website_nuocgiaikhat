import { createContext, useContext, useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from './AuthContext';
import { cartService, catalogService } from '@/services/api';
import { purchaseUnit, lineKey } from '@/utils/purchase';
import { canPurchase } from '@/utils/inventory';
const Context = createContext(null);
const guestKey = 'waterbus.api.guest-cart';
function read(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key)) || fallback;
  } catch {
    return fallback;
  }
}
function store(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* Browser storage can be unavailable. */
  }
}
export function ApiCartProvider({ children }) {
  const { user } = useAuth();
  const customer = user?.role === 'CUSTOMER' ? user.id : null;
  const [items, setItems] = useState(() => read(guestKey, []));
  const [loading, setLoading] = useState(false);
  const current = useRef(items);
  const queue = useRef(Promise.resolve());
  const commit = (next) => {
    current.current = next;
    setItems(next);
  };
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const load = async () => {
      if (!customer) {
        if (!cancelled) commit(user?.role ? [] : read(guestKey, []));
        return;
      }
      let server = await cartService.list();
      if (cancelled) return;
      const guest = read(guestKey, []);
      for (const line of guest) {
        if (cancelled) return;
        const product = await catalogService.detail(line.productId);
        if (cancelled) return;
        const unit = purchaseUnit(product, line.unit);
        const existing = server.find((l) => l.packageId === unit.packageId);
        server = await cartService.put(
          unit.packageId,
          Math.max(existing?.quantity || 0, line.quantity),
        );
      }
      if (cancelled) return;
      store(guestKey, []);
      const selected = read(`waterbus.api.selection.${customer}`, {});
      commit(server.map((l) => ({ ...l, selected: selected[l.packageId] !== false })));
    };
    load()
      .catch((e) => {
        if (!cancelled) {
          commit([]);
          toast.error(e.message);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [customer, user?.role]);
  useEffect(() => {
    if (loading || current.current !== items) return;
    if (customer)
      store(
        `waterbus.api.selection.${customer}`,
        Object.fromEntries(items.map((l) => [l.packageId, l.selected])),
      );
    else if (!user) store(guestKey, items);
  }, [items, customer, user, loading]);
  const synchronize = (server) =>
    server.map((l) => ({
      ...l,
      selected: current.current.find((old) => old.packageId === l.packageId)?.selected ?? true,
    }));
  const run = (operation) => {
    const task = queue.current.then(operation);
    queue.current = task.catch(() => {});
    return task.catch((e) => {
      toast.error(e.message);
    });
  };
  const add = (product, quantity = 1, unitId = 'single') =>
    run(async () => {
      if (loading) throw new Error('Đang tải giỏ hàng, vui lòng thử lại.');
      if (user && !customer) throw new Error('Vui lòng dùng tài khoản khách hàng để mua sắm.');
      if (!canPurchase(product)) throw new Error('Sản phẩm hiện không đủ hàng.');
      const unit = purchaseUnit(product, unitId);
      const line = {
        productId: product.id,
        packageId: unit.packageId,
        unit: unit.id,
        quantity,
        selected: true,
      };
      const existing = current.current.find((l) => l.packageId === unit.packageId);
      const nextQuantity = (existing?.quantity || 0) + quantity;
      if (!Number.isSafeInteger(nextQuantity) || nextQuantity < 1)
        throw new Error('Số lượng không hợp lệ.');
      if (customer) commit(synchronize(await cartService.put(unit.packageId, nextQuantity)));
      else {
        const others = current.current.filter(
          (l) => l.productId === product.id && l.packageId !== unit.packageId,
        );
        const required =
          others.reduce((sum, l) => sum + l.quantity * purchaseUnit(product, l.unit).size, 0) +
          nextQuantity * unit.size;
        if (required > product.stock) throw new Error('Số lượng vượt quá tồn kho.');
        commit(
          existing
            ? current.current.map((l) =>
                l.packageId === unit.packageId
                  ? { ...l, quantity: nextQuantity, selected: true }
                  : l,
              )
            : [...current.current, line],
        );
      }
      toast.success('Đã thêm vào giỏ hàng');
    });
  const update = (key, quantity, max) =>
    run(async () => {
      if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > max) return;
      const line = current.current.find((l) => lineKey(l) === key);
      if (!line) return;
      if (customer) commit(synchronize(await cartService.put(line.packageId, quantity)));
      else commit(current.current.map((l) => (lineKey(l) === key ? { ...l, quantity } : l)));
    });
  const remove = (key) =>
    run(async () => {
      const line = current.current.find((l) => lineKey(l) === key);
      if (line && customer) await cartService.remove(line.packageId);
      commit(current.current.filter((l) => lineKey(l) !== key));
    });
  const select = (key, selected) =>
    commit(current.current.map((l) => (lineKey(l) === key ? { ...l, selected } : l)));
  const selectAll = (selected) => commit(current.current.map((l) => ({ ...l, selected })));
  const removePurchased = async () => {
    if (customer) commit(synchronize(await cartService.list()));
  };
  return (
    <Context.Provider
      value={{
        items,
        loading,
        add,
        update,
        remove,
        select,
        selectAll,
        removePurchased,
        selectedItems: items.filter((l) => l.selected),
        count: items.reduce((n, l) => n + l.quantity, 0),
      }}
    >
      {children}
    </Context.Provider>
  );
}
export const useApiCart = () => useContext(Context);

import { beforeEach, describe, expect, it, vi } from 'vitest';
import { canPurchase, isLowStock } from '@/utils/inventory';
import { maxLineQuantity } from '@/utils/purchase';
import { adminService, orderService } from '@/services/mock';
import { readDb, resetDb, updateDb } from '@/mocks/database';

beforeEach(() => {
  const storage = () => {
    const values = new Map();
    return {
      getItem: (key) => values.get(key) ?? null,
      setItem: (key, value) => values.set(key, String(value)),
      removeItem: (key) => values.delete(key),
    };
  };
  vi.stubGlobal('localStorage', storage());
  vi.stubGlobal('sessionStorage', storage());
  resetDb();
});
const customer = { id: 'u1', role: 'CUSTOMER' };
const admin = { id: 'u3', role: 'ADMIN' };
const values = {
  receiver: 'Khách hàng',
  phone: '0901234567',
  address: '12 Nguyễn Huệ',
  paymentMethod: 'COD',
};
it('blocks purchases at 20 and below, and permits 21', () => {
  for (const stock of [0, 1, 19, 20]) {
    expect(canPurchase({ stock, active: true })).toBe(false);
    expect(isLowStock({ stock })).toBe(true);
  }
  expect(canPurchase({ stock: 21, active: true })).toBe(true);
  expect(canPurchase({ stock: 100, active: false })).toBe(false);
  expect(maxLineQuantity({ stock: 20, price: 10000 }, [], { productId: 'p01' })).toBe(0);
});
it('reserves stock immediately, blocks the next order at 20, and restores a cancelled pending order once', async () => {
  updateDb((db) => {
    db.products[0].stock = 21;
  });
  const order = await orderService.create(customer, values, [{ productId: 'p01', quantity: 1 }]);
  expect(readDb().products[0].stock).toBe(20);
  await expect(
    orderService.create(customer, values, [{ productId: 'p01', quantity: 1 }]),
  ).rejects.toThrow('tồn kho');
  await orderService.change(customer, order.id, 'CANCELLED', 'Đổi ý');
  expect(readDb().products[0].stock).toBe(21);
  await expect(orderService.change(customer, order.id, 'CANCELLED', 'Lặp lại')).rejects.toThrow();
  expect(readDb().products[0].stock).toBe(21);
});
it('still confirms and cancels legacy pending orders that have not reserved stock', async () => {
  const order = readDb().orders.find((order) => order.status === 'PENDING');
  const before = readDb().products.find((p) => p.id === order.items[0].productId).stock;
  await orderService.change(admin, order.id, 'CONFIRMED', '');
  expect(readDb().products.find((p) => p.id === order.items[0].productId).stock).toBe(
    before - order.items[0].quantity,
  );
  await orderService.change(admin, order.id, 'CANCELLED', 'Đổi ý');
  expect(readDb().products.find((p) => p.id === order.items[0].productId).stock).toBe(before);
});
describe('product management permissions and retention', () => {
  it('rejects staff and unauthenticated product or inventory mutations', async () => {
    const product = readDb().products[0];
    for (const id of ['', 'u2', 'u1']) {
      sessionStorage.setItem('waterbus.mock.session', id);
      await expect(adminService.save('products', { ...product, stock: 999 })).rejects.toThrow(
        'quản trị viên',
      );
      await expect(adminService.remove('products', product.id)).rejects.toThrow('quản trị viên');
      await expect(
        adminService.receipt({ productId: product.id, quantity: 10, cost: 1 }),
      ).rejects.toThrow('quản trị viên');
    }
    expect(readDb().products[0]).toEqual(product);
  });
  it('allows admins to edit quantity, retains discontinued products and their history, and permits selling again', async () => {
    sessionStorage.setItem('waterbus.mock.session', 'u3');
    const product = readDb().products[0];
    const history = readDb().orders;
    const count = readDb().products.length;
    await adminService.save('products', { ...product, stock: 20 });
    expect(readDb().products[0].stock).toBe(20);
    await adminService.remove('products', product.id);
    expect(readDb().products.length).toBe(count);
    expect(readDb().products[0].active).toBe(false);
    await adminService.save('products', { ...readDb().products[0], stock: 40 });
    expect(readDb().products[0]).toMatchObject({ active: false, stock: 40 });
    await adminService.save('products', { ...readDb().products[0], active: true });
    expect(canPurchase(readDb().products[0])).toBe(true);
    expect(readDb().orders).toEqual(history);
    await expect(adminService.save('products', { ...product, stock: -1 })).rejects.toThrow();
  });
});

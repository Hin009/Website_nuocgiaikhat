import { purchaseUnit } from '../src/utils/purchase';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { hasRole, safeReturn, authReturn } from '../src/utils/access';
import { phoneSchema, checkoutSchema, productSchema } from '../src/schemas';
import { resetDb, readDb, updateDb } from '../src/mocks/database';
import { orderService, authService, adminService } from '../src/services/mock';
class MemoryStorage {
  store = {};
  getItem(k) {
    return this.store[k] ?? null;
  }
  setItem(k, v) {
    this.store[k] = String(v);
  }
  removeItem(k) {
    delete this.store[k];
  }
  clear() {
    this.store = {};
  }
}
const customer = { id: 'u1', role: 'CUSTOMER' };
const admin = { id: 'u3', role: 'ADMIN' };
const values = {
  receiver: 'Nguyễn Minh Anh',
  phone: '0901234567',
  address: '12 Nguyễn Huệ, TP. Hồ Chí Minh',
  paymentMethod: 'COD',
  note: '',
};
beforeEach(() => {
  vi.stubGlobal('localStorage', new MemoryStorage());
  vi.stubGlobal('sessionStorage', new MemoryStorage());
  resetDb();
});
describe('Quyền truy cập', () => {
  it('ADMIN kế thừa STAFF, không mở quyền quản trị cho STAFF', () => {
    expect(hasRole(admin, ['STAFF'])).toBe(true);
    expect(hasRole({ role: 'STAFF' }, ['ADMIN'])).toBe(false);
    expect(hasRole(customer, ['STAFF'])).toBe(false);
    expect(hasRole({ role: 'ADMIN', active: false }, ['ADMIN'])).toBe(false);
  });
  it('Chặn URL điều hướng ngoài và đường dẫn dùng backslash', () => {
    expect(safeReturn('//evil.test')).toBe('/');
    expect(safeReturn('https://evil.test')).toBe('/');
    expect(safeReturn('/\\\\evil.test')).toBe('/');
    expect(safeReturn('/checkout')).toBe('/checkout');
  });
});
describe('Biểu mẫu', () => {
  it('Nhận số điện thoại Việt Nam và từ chối dữ liệu sai', () => {
    expect(phoneSchema.safeParse('0901234567').success).toBe(true);
    expect(phoneSchema.safeParse('01234567890').success).toBe(true);
    for (const phone of ['123456789', '123456789012', '+84901234567', '090 1234567', '090123456a'])
      expect(phoneSchema.safeParse(phone).success).toBe(false);
    expect(phoneSchema.safeParse('abc').success).toBe(false);
  });
  it('Chặn phương thức thanh toán chưa hỗ trợ và tồn kho âm', () => {
    expect(checkoutSchema.safeParse({ ...values, paymentMethod: 'VNPAY' }).success).toBe(false);
    expect(
      productSchema.safeParse({
        name: 'Nước mẫu',
        brand: 'Mẫu',
        categoryId: 'soda',
        volume: 'Lon',
        price: 10000,
        stock: -1,
        description: '',
        color: '#aaa',
        art: 'can',
      }).success,
    ).toBe(false);
  });
});
describe('Đơn hàng và kho mẫu', () => {
  it('Lấy giá từ danh mục và trừ kho khi tạo đơn chờ', async () => {
    const before = readDb().products[0];
    const order = await orderService.create(customer, values, [
      { productId: before.id, quantity: 2, price: 1 },
    ]);
    expect(order.subtotal).toBe(before.price * 2);
    expect(order.total).toBe(before.price * 2 + 20000);
    expect(order.status).toBe('PENDING');
    expect(readDb().products[0].stock).toBe(before.stock - 2);
  });
  it('Từ chối mua vượt tồn kho và không tạo đơn lỗi', async () => {
    const count = readDb().orders.length;
    await expect(
      orderService.create(customer, values, [{ productId: 'p12', quantity: 1 }]),
    ).rejects.toThrow('tồn kho');
    expect(readDb().orders).toHaveLength(count);
  });
  it('Xác nhận không trừ kho lần hai, hủy đơn hoàn kho và bắt buộc lý do', async () => {
    const before = readDb().products[0].stock;
    const order = await orderService.create(customer, values, [{ productId: 'p01', quantity: 2 }]);
    await orderService.change(admin, order.id, 'CONFIRMED', '');
    expect(readDb().products[0].stock).toBe(before - 2);
    await expect(orderService.change(admin, order.id, 'CANCELLED', '')).rejects.toThrow('lý do');
    await orderService.change(admin, order.id, 'CANCELLED', 'Khách đổi ý');
    expect(readDb().products[0].stock).toBe(before);
    await expect(orderService.change(admin, order.id, 'CONFIRMED', '')).rejects.toThrow(
      'Trạng thái',
    );
  });
  it('Khách chỉ thấy và hủy đơn chờ của mình', async () => {
    expect(await orderService.list({ id: 'khac', role: 'CUSTOMER' })).toHaveLength(0);
    const order = await orderService.create(customer, values, [{ productId: 'p01', quantity: 1 }]);
    await expect(
      orderService.change({ id: 'khac', role: 'CUSTOMER' }, order.id, 'CANCELLED', 'Hủy'),
    ).rejects.toThrow('Không thể');
    await expect(orderService.change(customer, order.id, 'CONFIRMED', '')).rejects.toThrow(
      'Không thể',
    );
  });
  it('Không ghi kho dở dang khi một sản phẩm tạm hết hàng', async () => {
    updateDb((db) => {
      db.products.find((p) => p.id === 'p02').stock = 20;
    });
    const stock = readDb().products[0].stock;
    const count = readDb().orders.length;
    await expect(
      orderService.create(customer, values, [
        { productId: 'p01', quantity: 2 },
        { productId: 'p02', quantity: 2 },
      ]),
    ).rejects.toThrow('tồn kho');
    expect(readDb().products[0].stock).toBe(stock);
    expect(readDb().orders).toHaveLength(count);
  });
  it('Phiếu nhập tăng đúng số lượng và danh mục có sản phẩm không được xóa', async () => {
    sessionStorage.setItem('waterbus.mock.session', 'u3');
    const stock = readDb().products[0].stock;
    const r = await adminService.receipt({
      productId: 'p01',
      quantity: 24,
      cost: 7000,
      supplier: 'NCC mẫu',
      note: '',
    });
    expect(r.total).toBe(168000);
    expect(readDb().products[0].stock).toBe(stock + 24);
    await expect(adminService.remove('categories', 'soda')).rejects.toThrow('đang có sản phẩm');
  });
});
describe('Tài khoản mẫu', () => {
  it('Sai mật khẩu không tạo phiên, đăng xuất xóa phiên', async () => {
    await expect(
      authService.login({ email: 'admin@waterbus.demo', password: 'sai' }),
    ).rejects.toThrow('không đúng');
    expect(await authService.me()).toBeNull();
    const u = await authService.login(
      { email: 'admin@waterbus.demo', password: 'Demo@123' },
      'management',
    );
    expect(u.role).toBe('ADMIN');
    authService.logout();
    expect(await authService.me()).toBeNull();
  });
  it('Đăng ký giữ vai trò khách, không lưu mật khẩu nguyên văn', async () => {
    const user = await authService.register({
      name: 'Khách Mới',
      email: 'moi@example.test',
      password: 'ThuNghiem@123',
      role: 'ADMIN',
    });
    expect(user.role).toBe('CUSTOMER');
    expect(JSON.stringify(readDb())).not.toContain('ThuNghiem@123');
    expect(
      (await authService.login({ email: 'moi@example.test', password: 'ThuNghiem@123' })).id,
    ).toBe(user.id);
  });
});

describe('Login portals', () => {
  it('rejects the wrong role before creating a session', async () => {
    for (const email of ['nhanvien@waterbus.demo', 'admin@waterbus.demo']) {
      await expect(authService.login({ email, password: 'Demo@123' })).rejects.toThrow(
        'khách hàng',
      );
      expect(await authService.me()).toBeNull();
    }
    await expect(
      authService.login({ email: 'khach@waterbus.demo', password: 'Demo@123' }, 'management'),
    ).rejects.toThrow('nhân viên');
    expect(await authService.me()).toBeNull();
    expect(
      (
        await authService.login(
          { email: 'nhanvien@waterbus.demo', password: 'Demo@123' },
          'management',
        )
      ).role,
    ).toBe('STAFF');
  });
  it('keeps return URLs inside the appropriate portal', () => {
    expect(authReturn('/admin/orders', true)).toBe('/admin/orders');
    expect(authReturn('/checkout', true)).toBe('/admin');
    expect(authReturn('/admin', false)).toBe('/');
    expect(authReturn('/admin?tab=1', false)).toBe('/');
    expect(authReturn('/checkout', false)).toBe('/checkout');
    expect(authReturn('/admin', true)).toBe('/admin');
    expect(authReturn('//evil.test', true)).toBe('/admin');
  });
});

describe('Package purchasing', () => {
  it('prices packages from catalog and confirms/cancels the base stock quantity', async () => {
    const before = readDb().products.find((p) => p.id === 'p01');
    const order = await orderService.create(customer, values, [
      { productId: 'p01', quantity: 2, unit: 'pack', unitSize: 999, price: 1 },
      { productId: 'p01', quantity: 1, unit: 'case' },
      { productId: 'p01', quantity: 3 },
      { productId: 'p02', quantity: 1, selected: false },
    ]);
    expect(order.items).toHaveLength(3);
    expect(order.items.map((i) => i.quantity)).toEqual([12, 24, 3]);
    expect(order.items[0].purchaseQuantity).toBe(2);
    expect(order.subtotal).toBe(365640);
    expect(order.items[0].purchasePrice).toBe(59400);
    expect(order.items[1].purchasePrice).toBe(213840);
    expect(order.shippingFee).toBe(20000);
    await orderService.change(admin, order.id, 'CONFIRMED', '');
    expect(readDb().products.find((p) => p.id === 'p01').stock).toBe(before.stock - 39);
    await orderService.change(admin, order.id, 'CANCELLED', 'Khách yêu cầu');
    expect(readDb().products.find((p) => p.id === 'p01').stock).toBe(before.stock);
  });
  it('checks aggregate stock across multiple package types', async () => {
    const count = readDb().orders.length;
    await expect(
      orderService.create(customer, values, [
        { productId: 'p01', quantity: 10, unit: 'case' },
        { productId: 'p01', quantity: 1, unit: 'pack' },
      ]),
    ).rejects.toThrow('tồn kho');
    expect(readDb().orders).toHaveLength(count);
  });
  it('rejects invalid units, quantities and empty selections', async () => {
    await expect(
      orderService.create(customer, values, [{ productId: 'p01', quantity: 1, unit: 'invalid' }]),
    ).rejects.toThrow('Đơn vị mua');
    for (const quantity of [0, -1, 1.5, NaN, Infinity])
      await expect(
        orderService.create(customer, values, [{ productId: 'p01', quantity }]),
      ).rejects.toThrow();
    await expect(
      orderService.create(customer, values, [{ productId: 'p01', quantity: 1, selected: false }]),
    ).rejects.toThrow('trống');
  });
});

describe('Package prices', () => {
  it('discounts packs by 10% and cases by another 10%', () => {
    const product = { price: 11000, volume: 'Lon 320ml' };
    expect(purchaseUnit(product).price).toBe(11000);
    expect(purchaseUnit(product, 'pack').price).toBe(59400);
    expect(purchaseUnit(product, 'case').price).toBe(213840);
    expect(purchaseUnit(product, 'case').price).toBe(purchaseUnit(product, 'pack').price * 4 * 0.9);
    expect(purchaseUnit({ price: 10001 }, 'pack').price).toBe(54005);
    expect(purchaseUnit({ price: 10001 }, 'case').price).toBe(194418);
  });
});

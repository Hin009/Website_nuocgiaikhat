import { canPurchase } from '@/utils/inventory';
import { productSchema } from '@/schemas';
import { calculateOrderPricing } from '@/utils/vouchers';
import { purchaseUnit, requiredStock } from '@/utils/purchase';
import { readDb, updateDb, uid, digest } from '@/mocks/database';
const isMock = true;
export const transitions = {
  PENDING: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['SHIPPING', 'CANCELLED'],
  SHIPPING: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};
function ensureMock() {
  if (!isMock)
    throw new Error(
      'Chưa có adapter API. Cần đối chiếu Controller và DTO Spring Boot trước khi bật kết nối thật.',
    );
}
function requireProductManager(db) {
  const id = sessionStorage.getItem('waterbus.mock.session');
  const manager = db.users.find((user) => user.id === id && user.active);
  if (manager?.role !== 'ADMIN')
    throw new Error('Chỉ quản trị viên được quản lý sản phẩm và tồn kho.');
}
async function run(fn) {
  ensureMock();
  await new Promise((resolve) => setTimeout(resolve, 180));
  return fn();
}
export const catalogService = {
  list: () => run(() => readDb().products.filter((p) => p.active)),
  detail: (id) =>
    run(() => {
      const p = readDb().products.find((p) => p.id === id && p.active);
      if (!p) throw new Error('Sản phẩm không tồn tại hoặc đã ngừng kinh doanh.');
      return {
        ...p,
        description: p.description?.replace(
          ' Dữ liệu mô tả và bao bì trên giao diện là mẫu, cần đối chiếu thông tin nhà sản xuất khi kinh doanh.',
          '',
        ),
      };
    }),
  categories: () => run(() => readDb().categories),
};
export const authService = {
  me: () =>
    run(() => {
      try {
        const id = sessionStorage.getItem('waterbus.mock.session');
        return readDb().users.find((u) => u.id === id && u.active) || null;
      } catch {
        return null;
      }
    }),
  login: (values, portal = 'customer') =>
    run(async () => {
      const db = readDb();
      const user = db.users.find(
        (u) => u.email.toLowerCase() === values.email.toLowerCase() && u.active,
      );
      const registered = db.registered.find((u) => u.email === values.email.toLowerCase());
      const valid = registered
        ? registered.digest === (await digest(values.password))
        : ['u1', 'u2', 'u3'].includes(user?.id) && values.password === 'Demo@123';
      if (!user || !valid) throw new Error('Email hoặc mật khẩu không đúng.');
      const allowed =
        portal === 'management' ? ['STAFF', 'ADMIN'].includes(user.role) : user.role === 'CUSTOMER';
      if (!allowed)
        throw new Error(
          portal === 'management'
            ? 'Trang này chỉ dành cho nhân viên và quản trị viên.'
            : 'Trang này chỉ dành cho khách hàng. Vui lòng dùng trang đăng nhập quản lý.',
        );
      sessionStorage.setItem('waterbus.mock.session', user.id);
      return user;
    }),
  register: (values) =>
    run(async () => {
      const email = values.email.toLowerCase();
      const passwordDigest = await digest(values.password);
      return updateDb((db) => {
        if (db.users.some((u) => u.email.toLowerCase() === email))
          throw new Error('Email này đã được sử dụng.');
        const user = {
          id: uid('u'),
          name: values.name,
          email,
          role: 'CUSTOMER',
          phone: values.phone || '',
          address: '',
          active: true,
        };
        db.users.push(user);
        db.registered.push({ email, digest: passwordDigest });
        sessionStorage.setItem('waterbus.mock.session', user.id);
        return user;
      });
    }),
  logout: () => {
    sessionStorage.removeItem('waterbus.mock.session');
  },
  update: (id, values) =>
    run(() =>
      updateDb((db) => {
        const user = db.users.find((u) => u.id === id);
        if (!user) throw new Error('Không tìm thấy tài khoản.');
        Object.assign(user, { name: values.name, phone: values.phone, address: values.address });
        if (values.provinceCode !== undefined) {
          Object.assign(user, {
            provinceCode: values.provinceCode,
            wardCode: values.wardCode,
            streetAddress: values.streetAddress,
          });
        }
        return user;
      }),
    ),
};
export const orderService = {
  list: (user) =>
    run(() =>
      readDb()
        .orders.filter((o) => (user.role === 'CUSTOMER' ? o.userId === user.id : true))
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
    ),
  create: (user, values, cart) =>
    run(() =>
      updateDb((db) => {
        cart = cart.filter((line) => line.selected !== false);
        if (!user || !cart.length) throw new Error('Giỏ hàng đang trống.');
        const required = requiredStock(cart, db.products);
        const items = cart.map((line) => {
          const product = db.products.find((p) => p.id === line.productId && p.active);
          if (
            !canPurchase(product) ||
            !Number.isSafeInteger(line.quantity) ||
            line.quantity < 1 ||
            product.stock < required[line.productId]
          )
            throw new Error(
              'Sản phẩm hoặc số lượng tồn kho đã thay đổi. Hãy kiểm tra lại giỏ hàng.',
            );
          return {
            productId: product.id,
            name: product.name,
            price: purchaseUnit(product, line.unit).price / purchaseUnit(product, line.unit).size,
            purchasePrice: purchaseUnit(product, line.unit).price,
            lineTotal: purchaseUnit(product, line.unit).price * line.quantity,
            quantity: line.quantity * purchaseUnit(product, line.unit).size,
            purchaseQuantity: line.quantity,
            purchaseUnit: purchaseUnit(product, line.unit).label,
            unitSize: purchaseUnit(product, line.unit).size,
            color: product.color,
            accent: product.accent,
            art: product.art,
            label: product.label,
            volume: product.volume,
          };
        });
        const subtotal = items.reduce((s, p) => s + p.lineTotal, 0);
        const pricing = calculateOrderPricing(subtotal, values.voucherCode, items);
        const order = {
          ...values,
          id: uid('WB').toUpperCase(),
          userId: user.id,
          items,
          subtotal,
          ...pricing,
          status: 'PENDING',
          createdAt: new Date().toISOString(),
          history: [{ status: 'PENDING', at: new Date().toISOString(), note: 'Tạo đơn hàng' }],
        };
        for (const [productId, quantity] of Object.entries(required)) {
          db.products.find((product) => product.id === productId).stock -= quantity;
        }
        order.stockReserved = true;
        db.orders.unshift(order);
        return order;
      }),
    ),
  change: (user, id, status, note) =>
    run(() =>
      updateDb((db) => {
        const order = db.orders.find((o) => o.id === id);
        if (!order) throw new Error('Không tìm thấy đơn hàng.');
        const customer = user.role === 'CUSTOMER';
        if (
          customer &&
          (order.userId !== user.id || order.status !== 'PENDING' || status !== 'CANCELLED')
        )
          throw new Error('Không thể cập nhật đơn hàng này.');
        if (!transitions[order.status]?.includes(status))
          throw new Error('Trạng thái đơn đã thay đổi. Vui lòng tải lại.');
        if (status === 'CANCELLED' && !note?.trim()) throw new Error('Vui lòng nhập lý do hủy.');
        if (status === 'CONFIRMED' && !order.stockReserved) {
          const required = {};
          for (const item of order.items)
            required[item.productId] = (required[item.productId] || 0) + item.quantity;
          for (const [id, quantity] of Object.entries(required)) {
            const p = db.products.find((p) => p.id === id);
            if (!p || p.stock < quantity) throw new Error('Không đủ tồn kho để xác nhận đơn.');
          }
          order.items.forEach((item) => {
            db.products.find((p) => p.id === item.productId).stock -= item.quantity;
          });
          order.stockReserved = true;
        }
        if (
          status === 'CANCELLED' &&
          (order.stockReserved || ['CONFIRMED', 'SHIPPING'].includes(order.status))
        ) {
          order.items.forEach((item) => {
            const product = db.products.find((product) => product.id === item.productId);
            if (product) product.stock += item.quantity;
          });
          order.stockReserved = false;
        }
        order.status = status;
        order.history.push({ status, at: new Date().toISOString(), note: note || '' });
        return order;
      }),
    ),
};
export const adminService = {
  all: (key) => run(() => readDb()[key]),
  save: (key, values) =>
    run(() =>
      updateDb((db) => {
        if (key === 'products') {
          requireProductManager(db);
          values = { ...values, ...productSchema.parse(values) };
        }
        if (!['products', 'categories', 'users'].includes(key))
          throw new Error('Module không hợp lệ.');
        if (key === 'users' && db.users.some((u) => u.email === values.email && u.id !== values.id))
          throw new Error('Email đã tồn tại.');
        if (
          key === 'categories' &&
          db.categories.some(
            (c) => c.name.toLowerCase() === values.name.toLowerCase() && c.id !== values.id,
          )
        )
          throw new Error('Tên danh mục đã tồn tại.');
        if (values.id) {
          const item = db[key].find((p) => p.id === values.id);
          if (!item) throw new Error('Dữ liệu không còn tồn tại.');
          Object.assign(item, values);
          return item;
        }
        const item = {
          ...values,
          id: uid(key),
          createdAt: new Date().toISOString(),
          active: values.active ?? true,
        };
        db[key].push(item);
        return item;
      }),
    ),
  remove: (key, id) =>
    run(() =>
      updateDb((db) => {
        if (key === 'categories' && db.products.some((p) => p.categoryId === id))
          throw new Error('Danh mục đang có sản phẩm, không thể xóa.');
        if (key === 'products') {
          requireProductManager(db);
          const p = db.products.find((p) => p.id === id);
          if (p) p.active = false;
        } else if (key === 'categories') {
          db.categories = db.categories.filter((p) => p.id !== id);
        } else throw new Error('Thao tác không được hỗ trợ.');
      }),
    ),
  receipt: (values) =>
    run(() =>
      updateDb((db) => {
        requireProductManager(db);
        if (
          !Number.isInteger(values.quantity) ||
          values.quantity < 1 ||
          !Number.isFinite(values.cost) ||
          values.cost < 0
        )
          throw new Error('Số lượng hoặc giá nhập không hợp lệ.');
        const product = db.products.find((p) => p.id === values.productId && p.active);
        if (!product) throw new Error('Sản phẩm không còn kinh doanh.');
        const receipt = {
          ...values,
          id: uid('PN').toUpperCase(),
          productName: product.name,
          total: values.quantity * values.cost,
          createdAt: new Date().toISOString(),
        };
        product.stock += values.quantity;
        db.receipts.unshift(receipt);
        return receipt;
      }),
    ),
};

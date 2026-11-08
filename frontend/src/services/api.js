import { get, post, put, patch, del, allPages } from './http';
import { accessToken, readSession, saveSession } from './session';
import {
  mapProduct,
  mapCategory,
  mapOrder,
  mapCart,
  roleCodes,
  roleOf,
  statusCodes,
} from './mappers';
import { provinces } from '@/utils/address';
export const transitions = {
  PENDING: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['SHIPPING', 'CANCELLED'],
  SHIPPING: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
  REJECTED: [],
};
const numeric = (id) => Number(id);
export const passwordResetService = {
  request: (email) => post('/auth/password-reset/request', { email }),
  verify: (challengeId, code) => post('/auth/password-reset/verify', { challengeId, code }),
  complete: (challengeId, resetToken, newPassword) => post('/auth/password-reset/complete', { challengeId, resetToken, newPassword }),
};
export const catalogService = {
  checkoutOptions: () => get('/catalog/checkout-options'),
  async list() {
    const [rows, brands] = await Promise.all([
      allPages('/catalog/products'),
      get('/catalog/brands'),
    ]);
    return Promise.all(
      rows.map(async (r) => {
        const detail = await get(`/catalog/products/${r.id}`);
        return mapProduct(detail, detail.packages, brands);
      }),
    );
  },
  async detail(id) {
    const [r, b] = await Promise.all([get(`/catalog/products/${id}`), get('/catalog/brands')]);
    return mapProduct(r, r.packages, b);
  },
  async categories() {
    return (await get('/catalog/categories')).map(mapCategory);
  },
  promotions: () => get('/catalog/promotions'),
};
async function profile(payload) {
  const roles = payload.roles;
  const management = readSession()?.portal === 'management';
  const role = management
    ? roleOf(roles)
    : roles.includes('KHACH_HANG')
      ? 'CUSTOMER'
      : roleOf(roles);
  const details = await get(role === 'CUSTOMER' ? '/me/profile' : '/staff/profile');
  const addresses = role === 'CUSTOMER' ? await get('/me/addresses') : [];
  const address = addresses.find((a) => a.mac_dinh) || addresses[0];
  const province = provinces.find((p) => p.name === address?.tinh_thanh);
  const ward = province?.wards.find((w) => w.name === address?.phuong_xa);
  return {
    source: 'api',
    id: String(payload.account.id),
    name: details.ho_ten,
    email: payload.account.email,
    role,
    roles,
    permissions: payload.permissions,
    active: payload.account.trang_thai === 'ACTIVE',
    phone: details.dien_thoai || '',
    address:
      role === 'CUSTOMER'
        ? address
          ? [address.dia_chi, address.phuong_xa, address.quan_huyen, address.tinh_thanh]
              .filter(Boolean)
              .join(', ')
          : ''
        : details.dia_chi || '',
    customerId: role === 'CUSTOMER' ? String(details.id) : null,
    employeeId: role !== 'CUSTOMER' ? String(details.id) : null,
    provinceCode: province?.code || '',
    wardCode: ward?.code || '',
    streetAddress: address?.dia_chi || '',
    addresses,
    rawProfile: details,
  };
}
export const authService = {
  async me() {
    if (!accessToken()) return null;
    try {
      return await profile(await get('/auth/me'));
    } catch (e) {
      if (e.status === 401) return null;
      throw e;
    }
  },
  async login(values, portal = 'customer') {
    const result = await post('/auth/login', { email: values.email, password: values.password });
    saveSession({ token: result.accessToken, portal });
    const allowed =
      portal === 'management'
        ? result.user.roles.some((r) => ['NHAN_VIEN', 'QUAN_TRI_VIEN'].includes(r))
        : result.user.roles.includes('KHACH_HANG');
    if (!allowed) {
      await authService.logout();
      throw new Error(
        portal === 'management'
          ? 'Tài khoản này không có quyền quản lý.'
          : 'Vui lòng đăng nhập tại khu vực quản lý.',
      );
    }
    try {
      return await profile(result.user);
    } catch (e) {
      await authService.logout();
      throw e;
    }
  },
  async register(v) {
    await post('/auth/register', {
      email: v.email,
      password: v.password,
      fullName: v.name,
      phone: v.phone,
    });
    return authService.login(v);
  },
  async logout() {
    try {
      if (accessToken()) await post('/auth/logout');
    } finally {
      saveSession(null);
    }
  },
  async update(id, v) {
    const current = await authService.me();
    if (!current || current.id !== id) throw new Error('Vui lòng đăng nhập lại.');
    if (current.role === 'CUSTOMER') {
      await put('/me/profile', {
        fullName: v.name,
        phone: v.phone,
        avatar: current.rawProfile.anh_dai_dien,
      });
      const province = provinces.find((p) => p.code === v.provinceCode);
      const ward = province?.wards.find((w) => w.code === v.wardCode);
      if (!province || !ward) throw new Error('Vui lòng chọn tỉnh/thành và phường/xã.');
      const address = current.addresses.find((a) => a.mac_dinh) || current.addresses[0];
      const body = {
        recipient: v.name,
        phone: v.phone,
        province: province.name,
        ward: ward.name,
        street: v.streetAddress,
        isDefault: true,
      };
      if (address) await put(`/me/addresses/${address.id}`, body);
      else await post('/me/addresses', body);
    } else {
      await put('/staff/profile', {
        fullName: v.name,
        phone: v.phone,
        address: v.address,
        birthDate: current.rawProfile.ngay_sinh,
        gender: current.rawProfile.gioi_tinh,
      });
    }
    return authService.me();
  },
};
export const cartService = {
  async list() {
    return mapCart(await get('/cart'));
  },
  async put(packageId, quantity) {
    return mapCart(await put(`/cart/items/${packageId}`, { quantity }));
  },
  remove: (packageId) => del(`/cart/items/${packageId}`),
  quote: (packageIds, couponCode = '') =>
    post('/orders/quote', { packageIds: packageIds.map(numeric), couponCode: couponCode || null }),
};
export const orderService = {
  async list(user) {
    const prefix = user.role === 'CUSTOMER' ? '/orders' : '/staff/orders';
    const rows = await allPages(prefix);
    return Promise.all(rows.map(async (o) => mapOrder(await get(`${prefix}/${o.id}`))));
  },
  async create(user, values, cart) {
    if (!cart.length) throw new Error('Chưa chọn sản phẩm.');
    // Reuse a saved address only when it matches the editable checkout fields.
    const saved = user.addresses?.find(
      (address) =>
        address.ten_nguoi_nhan === values.receiver &&
        address.so_dien_thoai === values.phone &&
        address.dia_chi === values.address &&
        address.tinh_thanh === values.province &&
        (address.phuong_xa || '') === (values.ward || ''),
    );
    let addressId = saved?.id;
    if (!addressId) {
      const address = await post('/me/addresses', {
        recipient: values.receiver,
        phone: values.phone,
        province: values.province,
        ward: values.ward || '',
        street: values.address,
        isDefault: false,
      });
      addressId = address.id;
    }
    return mapOrder(
      await post('/orders', {
        addressId: numeric(addressId),
        paymentMethod: values.paymentMethod || 'COD',
        note: values.note || '',
        couponCode: values.voucherCode || null,
        packageIds: cart.map((l) => numeric(l.packageId)),
      }),
    );
  },
  async change(user, id, status, note) {
    const result =
      user.role === 'CUSTOMER'
        ? await post(`/orders/${id}/cancel`, { note })
        : await patch(`/staff/orders/${id}/status`, { status: statusCodes[status], note });
    return mapOrder(result);
  },
};
const mapUser = (row) => ({
  source: 'api',
  id: String(row.tai_khoan_id ?? row.id),
  name: row.ho_ten || row.email,
  email: row.email,
  phone: row.dien_thoai || '',
  address: row.dia_chi || '',
  role: row.roles ? roleOf(row.roles) : 'CUSTOMER',
  roles: row.roles || ['KHACH_HANG'],
  active: row.trang_thai === 'ACTIVE',
  customerId:
    row.khach_hang_id == null
      ? row.tai_khoan_id
        ? String(row.id)
        : null
      : String(row.khach_hang_id),
  employeeId: row.nhan_vien_id == null ? null : String(row.nhan_vien_id),
  createdAt: row.ngay_tao,
});
export const purchasingService = {
  returns: () => allPages('/supplier-returns'),
  receipts: () => allPages('/receipts'),
  updateReceiptDates: (receipt, line, dates) =>
    patch(`/receipts/${receipt}/lines/${line}/dates`, dates),
  orders: () => allPages('/purchases'),
  detail: (id) => get(`/purchases/${id}`),
  suppliers: () => allPages('/management/suppliers'),
  async create(v) {
    return post('/purchases', {
      supplierId: numeric(v.supplierId),
      expectedDate: v.expectedDate || null,
      items: [
        {
          ...(v.packaging
            ? {
                productId: numeric(v.productId),
                packaging: v.packaging,
                unitsPerPackage: numeric(v.unitsPerPackage),
              }
            : { packageId: numeric(v.packageId) }),
          quantity: numeric(v.quantity),
          unitCost: numeric(v.cost),
        },
      ],
    });
  },
  decide: (id, status, reason) => patch(`/purchases/${id}/status`, { status, reason }),
  async receive(id, items) {
    return post(`/purchases/${id}/receipts`, { items });
  },
  confirm: (id) => post(`/receipts/${id}/confirm`),
};
export const adminService = {
  inventoryDetails: (id) => get(`/staff/products/${id}/inventory-details`),
  adjustStock: (product, values) => patch(`/management/products/${product.id}/stock`, values),
  async uploadImage(file) {
    const data = new FormData();
    data.append('file', file);
    return (await post('/management/product-images', data)).url;
  },
  async all(key) {
    const management = readSession()?.portal === 'management';
    if (!management) throw new Error('Vui lòng đăng nhập quản lý.');
    const user = await authService.me();
    if (key === 'orders') return orderService.list(user);
    if (key === 'categories')
      return (
        await (user.role === 'ADMIN'
          ? allPages('/management/categories')
          : get('/catalog/categories'))
      ).map(mapCategory);
    if (key === 'users')
      return (
        await allPages(user.role === 'ADMIN' ? '/management/accounts' : '/staff/customers')
      ).map(mapUser);
    if (key === 'suppliers') return purchasingService.suppliers();
    if (key === 'receipts')
      return (await allPages('/receipts'))
        .filter((r) => r.trang_thai === 'CONFIRMED')
        .map((r) => ({
          id: String(r.id),
          orderId: String(r.don_ncc_id),
          productName: r.items.map((l) => `${l.ten_san_pham} (${l.ten_quy_cach})`).join(', '),
          supplier: r.nha_cung_cap,
          quantity: r.items.reduce((s, l) => s + Number(l.so_luong_thuc_nhan), 0),
          total: r.items.reduce(
            (s, l) => s + Number(l.so_luong_thuc_nhan) * Number(l.gia_nhap_thuc_te),
            0,
          ),
          cost: r.items.length === 1 ? Number(r.items[0].gia_nhap_thuc_te) : null,
          createdAt: r.ngay_xac_nhan || r.ngay_nhap,
          note: r.ghi_chu || '',
          items: r.items,
        }));
    if (key === 'products') {
      if (user.role !== 'ADMIN') {
        const [rows, brands] = await Promise.all([
          allPages('/staff/products'),
          get('/catalog/brands'),
        ]);
        return rows.map((r) => mapProduct(r, r.packages, brands, r));
      }
      const [rows, packages, brands, stock, images] = await Promise.all([
        allPages('/management/products'),
        allPages('/management/packages'),
        allPages('/management/brands'),
        allPages('/staff/reports/stock'),
        allPages('/management/images'),
      ]);
      return rows.map((r) =>
        mapProduct(
          {
            ...r,
            images: images
              .filter((i) => i.san_pham_id === r.id)
              .sort(
                (a, b) =>
                  Number(b.anh_chinh) - Number(a.anh_chinh) || a.thu_tu - b.thu_tu || a.id - b.id,
              ),
          },
          packages.filter((q) => q.san_pham_id === r.id),
          brands,
          stock.find((s) => s.san_pham_id === r.id),
        ),
      );
    }
    throw new Error('Chức năng không được hỗ trợ.');
  },
  async save(key, v) {
    if (key === 'categories') {
      const row = v.id
        ? await patch(`/management/categories/${v.id}`, { ten: v.name, mo_ta: v.description })
        : await post('/management/categories', { ten: v.name, mo_ta: v.description });
      return mapCategory(row);
    }
    if (key === 'products') {
      const body = {
        fullName: v.name,
        brand: v.brand,
        categoryId: numeric(v.categoryId),
        volume: v.volume,
        description: v.description,
        active: v.active,
        packageId: v.packageId ? numeric(v.packageId) : null,
        packaging: v.art === 'can' ? 'LON' : v.art === 'carton' ? 'HOP' : 'CHAI',
        imageUrl: v.imageUrl || null,
        stock: !v.id || Number(v.stock) !== Number(v.expectedStock) ? Number(v.stock) : null,
        expectedStock: v.id ? Number(v.expectedStock) : null,
        stockReason: v.stockReason || '',
      };
      if (v.id) await put(`/management/product-editor/${v.id}`, body);
      else await post('/management/product-editor', body);
      return v;
    }
    if (key === 'users') {
      const body = {
        email: v.email,
        fullName: v.name,
        phone: v.phone,
        role: roleCodes[v.role],
        active: v.active,
        password: v.password || null,
      };
      const result = v.id
        ? await put(`/management/account-editor/${v.id}`, body)
        : await post('/management/account-editor', body);
      return mapUser(result);
    }
    throw new Error('Chức năng không được hỗ trợ.');
  },
  async remove(key, id) {
    if (key === 'products')
      return patch(`/management/products/${id}`, {
        trang_thai: 'NGUNG_KINH_DOANH',
        hien_thi: false,
      });
    if (key === 'categories') return del(`/management/categories/${id}`);
    throw new Error('Thao tác không được hỗ trợ.');
  },
};

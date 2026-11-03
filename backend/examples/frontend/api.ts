// Copy into your React/Vue/Angular project's src/lib/api.ts.
// Set baseUrl using your frontend's environment mechanism. Never put DB credentials in frontend.
export const baseUrl = 'http://localhost:8080/api/v1';
let bearerToken: string | null = null;
export function setAccessToken(value: string | null) { bearerToken = value; }

export interface Page<T> { items: T[]; page: number; size: number; total: number }
export interface Product { id: number; sku: string; ten: string; loai_san_pham_id: number; thuong_hieu_id: number; so_luong_co_ban: number; gia_tu?: number }
export interface Package { id: number; san_pham_id: number; ten_quy_cach: string; don_vi_tinh: string; he_so_quy_doi: number; gia_ban: number; so_luong_co_the_mua: number }
export interface ProductDetail extends Product { packages: Package[]; images: { id: number; duong_dan: string; thu_tu: number }[] }
export interface User { account: { id: number; email: string }; roles: string[]; permissions: string[] }
export interface LoginResult { accessToken: string; tokenType: 'Bearer'; expiresAt: string; user: User }
export interface CartLine { id: number; quy_cach_id: number; san_pham_id: number; ten: string; ten_quy_cach: string; so_luong: number; gia_ban: number; price_changed: boolean; available: boolean }
export interface Cart { items: CartLine[]; subtotal: number; discount: number; total: number }
export type OrderStatus = 'CHO_XAC_NHAN' | 'DANG_CHUAN_BI' | 'DANG_GIAO' | 'DA_GIAO' | 'DA_HUY' | 'TU_CHOI';
export interface Order { id: number; ma_don: string; trang_thai: OrderStatus; tong_tien: number }
export class ApiError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers);
  if (options.body) headers.set('Content-Type', 'application/json');
  if (bearerToken) headers.set('Authorization', `Bearer ${bearerToken}`);
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  if (response.status === 204) return undefined as T;
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401) setAccessToken(null);
    throw new ApiError(response.status, data.message || `HTTP ${response.status}`);
  }
  return data as T;
}
export const api = {
  async login(email: string, password: string) {
    const result = await request<LoginResult>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
    setAccessToken(result.accessToken); return result;
  },
  register: (email: string, password: string, fullName: string) => request('/auth/register', { method: 'POST', body: JSON.stringify({ email, password, fullName }) }),
  me: () => request<User>('/auth/me'),
  async logout() { try { await request('/auth/logout', { method: 'POST' }); } finally { setAccessToken(null); } },
  products: (params = new URLSearchParams()) => request<Page<Product>>(`/catalog/products?${params}`),
  product: (id: number) => request<ProductDetail>(`/catalog/products/${id}`),
  cart: (couponCode?: string) => request<Cart>(`/cart${couponCode ? `?couponCode=${encodeURIComponent(couponCode)}` : ''}`),
  setQuantity: (packageId: number, quantity: number) => request<Cart>(`/cart/items/${packageId}`, { method: 'PUT', body: JSON.stringify({ quantity }) }),
  removeItem: (packageId: number) => request<void>(`/cart/items/${packageId}`, { method: 'DELETE' }),
  checkout: (addressId: number, paymentMethod: 'COD' | 'BANK_TRANSFER', note?: string, couponCode?: string) => request<Order>('/orders', { method: 'POST', body: JSON.stringify({ addressId, paymentMethod, note, couponCode }) }),
  orders: (page = 0) => request<Page<Order>>(`/orders?page=${page}`),
  cancelOrder: (id: number) => request<Order>(`/orders/${id}/cancel`, { method: 'POST' }),
  staffSetStatus: (id: number, status: Exclude<OrderStatus, 'CHO_XAC_NHAN'>) => request<Order>(`/staff/orders/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) }),
};

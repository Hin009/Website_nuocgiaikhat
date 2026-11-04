export const roleCodes = { CUSTOMER: 'KHACH_HANG', STAFF: 'NHAN_VIEN', ADMIN: 'QUAN_TRI_VIEN' };
export const roleOf = (roles = []) =>
  roles.includes('QUAN_TRI_VIEN') ? 'ADMIN' : roles.includes('NHAN_VIEN') ? 'STAFF' : 'CUSTOMER';
export const statuses = {
  CHO_XAC_NHAN: 'PENDING',
  DANG_CHUAN_BI: 'CONFIRMED',
  DANG_GIAO: 'SHIPPING',
  DA_GIAO: 'COMPLETED',
  HOAN_TAT: 'COMPLETED',
  DA_HUY: 'CANCELLED',
  TU_CHOI: 'REJECTED',
};
export const statusCodes = {
  CONFIRMED: 'DANG_CHUAN_BI',
  SHIPPING: 'DANG_GIAO',
  COMPLETED: 'DA_GIAO',
  CANCELLED: 'DA_HUY',
};
export function mapCategory(row) {
  return {
    id: String(row.id),
    name: row.ten,
    description: row.mo_ta || '',
    color: '#e8efdf',
    icon: 'cup',
    active: row.hien_thi,
  };
}
export function mapProduct(row, packages = [], brands = [], stock) {
  const sorted = [...packages].sort((a, b) => a.he_so_quy_doi - b.he_so_quy_doi || a.id - b.id);
  const primary = sorted.find((q) => q.dang_ban !== false) || sorted[0];
  const brand = brands.find((b) => Number(b.id) === Number(row.thuong_hieu_id));
  return {
    source: 'api',
    id: String(row.id),
    sku: row.sku,
    name: row.ten,
    categoryId: String(row.loai_san_pham_id),
    brand: brand?.ten || '',
    brandId: String(row.thuong_hieu_id),
    volume: row.dung_tich || '',
    price: Number(primary?.gia_ban || 0),
    stock: Number(stock?.so_luong_co_ban ?? row.so_luong_co_ban ?? 0),
    lowStockThreshold: stock?.nguong_canh_bao == null ? null : Number(stock.nguong_canh_bao),
    description: row.mo_ta || '',
    active: row.trang_thai !== 'NGUNG_KINH_DOANH' && row.hien_thi !== false,
    purchasable: row.trang_thai === 'DANG_BAN',
    createdAt: row.ngay_tao,
    packageId: primary ? String(primary.id) : null,
    art: row.loai_bao_bi === 'LON' ? 'can' : row.loai_bao_bi === 'HOP' ? 'carton' : 'bottle',
    color: '#61846b',
    accent: '#edf2df',
    label: brand?.ten || row.ten,
    imageUrl: row.images?.find((i) => i.anh_chinh)?.duong_dan || row.images?.[0]?.duong_dan || '',
    packages: sorted.map((q) => ({
      id: `package-${q.id}`,
      packageId: String(q.id),
      label: q.ten_quy_cach,
      size: Number(q.he_so_quy_doi),
      unit: q.don_vi_tinh,
      price: Number(q.gia_ban),
      available: q.dang_ban !== false,
    })),
  };
}
export function mapOrder(row) {
  const items = (row.items || []).map((l) => ({
    productId: String(l.san_pham_id),
    packageId: String(l.quy_cach_id),
    id: String(l.id),
    name: l.ten_san_pham,
    purchaseUnit: l.ten_quy_cach,
    purchaseQuantity: Number(l.so_luong),
    quantity: Number(l.so_luong) * Number(l.he_so_quy_doi),
    unitSize: Number(l.he_so_quy_doi),
    price: Number(l.don_gia) / Number(l.he_so_quy_doi),
    purchasePrice: Number(l.don_gia),
    lineTotal: Number(l.thanh_tien),
    color: '#61846b',
    accent: '#edf2df',
    label: l.ten_san_pham,
    art: 'bottle',
  }));
  return {
    source: 'api',
    id: String(row.id),
    code: row.ma_don,
    customerId: row.khach_hang_id == null ? null : String(row.khach_hang_id),
    userId: row.tai_khoan_khach_id == null ? null : String(row.tai_khoan_khach_id),
    items,
    receiver: row.ten_nguoi_nhan || '',
    phone: row.sdt_nguoi_nhan || '',
    address: row.dia_chi_nhan || '',
    note: row.ghi_chu || '',
    subtotal: items.reduce((sum, l) => sum + l.lineTotal, 0),
    discountAmount: Number(row.giam_gia),
    shippingFee: Number(row.phi_van_chuyen),
    total: Number(row.tong_tien),
    status: statuses[row.trang_thai] || row.trang_thai,
    rawStatus: row.trang_thai,
    channel: row.kenh_ban,
    createdAt: row.ngay_dat,
    history: (row.history || []).map((h) => ({
      status: statuses[h.trang_thai_moi] || h.trang_thai_moi,
      at: h.thoi_gian,
      note: h.ghi_chu || '',
    })),
    paymentMethod: row.payments?.[0]?.phuong_thuc || '',
    payments: row.payments || [],
  };
}
export const mapCart = (row) =>
  row.items.map((l) => ({
    productId: String(l.san_pham_id),
    packageId: String(l.quy_cach_id),
    unit: `package-${l.quy_cach_id}`,
    quantity: Number(l.so_luong),
    selected: true,
    priceChanged: l.price_changed,
  }));

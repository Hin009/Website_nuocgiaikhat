import { useQuery } from '@tanstack/react-query';
import { CalendarDays, History } from 'lucide-react';
import { adminService, isMock } from '@/services';

const calendarDate = (value) =>
  value ? String(value).slice(0, 10).split('-').reverse().join('/') : 'Chưa ghi';
const timestamp = (value) =>
  new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(value));

export default function ProductInventoryDetails({ product }) {
  const query = useQuery({
    queryKey: ['product-inventory-details', product.id],
    queryFn: () =>
      isMock ? { batches: [], adjustments: [] } : adminService.inventoryDetails(product.id),
  });
  if (query.isPending) return <p className="muted-note">Đang tải chi tiết sản phẩm…</p>;
  if (query.isError)
    return (
      <p role="alert">
        Không tải được dữ liệu.{' '}
        <button type="button" onClick={() => query.refetch()}>
          Thử lại
        </button>
      </p>
    );
  const batches = [...query.data.batches].sort(
    (a, b) =>
      String(b.ngay_nhap || '').localeCompare(String(a.ngay_nhap || '')) ||
      Number(b.receipt_id) - Number(a.receipt_id) ||
      Number(b.id) - Number(a.id),
  );
  const adjustments = query.data.adjustments;
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' }).format(
    new Date(),
  );
  return (
    <div className="product-inventory-grid">
      <section className="product-inventory-details" aria-label="Lịch sử sửa đổi">
        <div className="inventory-panel-heading">
          <h3>
            <History size={17} />
            Lịch sử sửa đổi
          </h3>
          <span>
            {adjustments.length}
            {adjustments.length === 100 ? '+' : ''} lần
          </span>
        </div>
        {!adjustments.length ? (
          <p className="inventory-empty">Chưa có điều chỉnh số lượng.</p>
        ) : (
          <>
            <small className="inventory-scroll-hint">
              Mới nhất trước · Cuộn xem lịch sử · Đơn vị lẻ
            </small>
            <ul tabIndex={0} aria-label={`Các lần sửa số lượng ${product.name}`}>
              {adjustments.map((a) => (
                <li key={a.id}>
                  <strong>
                    {Number(a.so_luong_truoc).toLocaleString('vi-VN')} →{' '}
                    {Number(a.so_luong_sau).toLocaleString('vi-VN')}{' '}
                    <span className="inventory-change">
                      ({Number(a.chenh_lech) > 0 ? '+' : ''}
                      {Number(a.chenh_lech).toLocaleString('vi-VN')})
                    </span>
                  </strong>
                  <span>
                    {a.adjusted_by} · {timestamp(a.thoi_diem)}
                  </span>
                  <p className="adjustment-reason">Lý do: {a.ly_do}</p>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
      <section className="product-inventory-details" aria-label="Hạn sử dụng theo lô">
        <div className="inventory-panel-heading">
          <h3>
            <CalendarDays size={17} />
            Hạn sử dụng
          </h3>
          <span>{batches.length} lô nhập</span>
        </div>
        {!batches.length ? (
          <p className="inventory-empty">Chưa có lô nhập xác nhận.</p>
        ) : (
          <>
            <small className="inventory-scroll-hint">Lô mới nhất trước · Cuộn xem lô cũ</small>
            <ul tabIndex={0} aria-label={`Các lô nhập ${product.name}`}>
              {batches.map((b) => (
                <li key={b.id}>
                  <strong>
                    Phiếu #{b.receipt_id} · {Number(b.received_units).toLocaleString('vi-VN')} đơn
                    vị lẻ
                  </strong>
                  <div className="inventory-batch-dates">
                    <span>NSX: {calendarDate(b.ngay_san_xuat)}</span>
                    <span>HSD: {calendarDate(b.ngay_het_han)}</span>
                  </div>
                  {b.ngay_het_han && String(b.ngay_het_han).slice(0, 10) < today && (
                    <span className="stock-warning">Lô đã hết hạn</span>
                  )}
                </li>
              ))}
            </ul>
            <small className="inventory-scroll-hint">
              Số lượng đã nhận theo lô, chưa trừ hàng bán.
            </small>
          </>
        )}
      </section>
    </div>
  );
}

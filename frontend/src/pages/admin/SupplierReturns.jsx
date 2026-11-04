import { useQuery } from '@tanstack/react-query';
import { purchasingService } from '@/services/api';
import { QueryState, EmptyState } from '@/components/common/Shared';
import { inPurchasingDateRange } from '@/utils/purchasing-dates';
import { money, date } from '@/utils/format';

export default function SupplierReturns({ from = '', to = '' }) {
  const query = useQuery({ queryKey: ['supplier-returns'], queryFn: purchasingService.returns });
  const rows = (query.data || []).filter(
    (r) =>
      r.source === 'RECEIPT_REJECTION' &&
      inPurchasingDateRange(r.ngay_xac_nhan || r.ngay_lap, from, to),
  );
  if (query.isSuccess && !query.data?.length) return null;
  return (
    <section className="supplier-returns-section">
      <h2>Lịch sử hàng lỗi trả ngay khi nhận</h2>
      <p className="muted-note">
        Chỉ hiển thị lần kiểm nhận đã xác nhận. Hàng lỗi không nhập kho và không tính vào công nợ.
      </p>
      <QueryState query={query}>
        {rows.length ? (
          <div className="data-panel table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Lần trả / Nhà cung cấp</th>
                  <th>Hàng lỗi / Lý do</th>
                  <th>Giá trị hàng lỗi</th>
                  <th>Đối soát</th>
                  <th>Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.history_key || `receipt-${r.id}`}>
                    <td>
                      <strong>{r.ma_phieu}</strong>
                      <small>
                        {r.nha_cung_cap} · Lần nhập #{r.lan_nhap_id}
                      </small>
                      <small>{date(r.ngay_xac_nhan || r.ngay_lap)}</small>
                    </td>
                    <td>
                      {r.items.map((l) => (
                        <div key={l.id}>
                          {l.ten_san_pham} — {l.ten_quy_cach} × {l.so_luong}
                          <small>{l.ly_do}</small>
                        </div>
                      ))}
                    </td>
                    <td>{money(r.tong_tien)}</td>
                    <td>
                      Không tính công nợ: {money(r.tong_tien)}
                      <small>Hàng lỗi không nhập kho · Không phát sinh tiền hoàn</small>
                    </td>
                    <td>
                      <span className="pill pill-gray">Đã trả khi kiểm nhận</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState title="Không có hàng lỗi trả ngay khi nhận trong khoảng ngày đã chọn" />
        )}
      </QueryState>
    </section>
  );
}

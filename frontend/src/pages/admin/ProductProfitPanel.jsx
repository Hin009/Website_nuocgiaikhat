import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { get } from '@/services/http';
import { QueryState, EmptyState } from '@/components/common/Shared';
import { money, normalize } from '@/utils/format';

export default function ProductProfitPanel({ from, to }) {
  const [search, setSearch] = useState('');
  const query = useQuery({
    queryKey: ['product-profit', from, to],
    queryFn: () => get('/management/reports/product-profit', from && to ? { from, to } : {}),
  });
  const rows = (query.data || []).filter((r) =>
    normalize(r.product_name + ' ' + r.sku).includes(normalize(search)),
  );
  const sum = (key) => rows.reduce((total, r) => total + Number(r[key] || 0), 0);
  return (
    <section className="product-profit-section">
      <div className="panel-heading">
        <div>
          <h2>Tiền nhập, tiền bán và lãi theo sản phẩm</h2>
          <p>Lãi gộp = Doanh thu sau giảm giá − Giá vốn của lượng đã bán</p>
        </div>
      </div>
      <p className="muted-note">
        Tiền nhập chỉ gồm hàng đạt đã xác nhận. Hàng lỗi trả ngay lúc nhận không tính vào tiền nhập.
        Doanh thu gồm đơn đã giao/hoàn tất, lọc theo ngày đặt đơn; phân bổ giảm giá theo giá trị mỗi
        dòng, không gồm phí giao hàng. Lãi gộp chưa trừ chi phí vận hành và thuế.
      </p>
      <label className="profit-search">
        Tìm sản phẩm
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Tên sản phẩm hoặc SKU…"
        />
      </label>
      <QueryState query={query}>
        <div className="profit-totals">
          {[
            ['Tổng tiền nhập', 'import_amount'],
            ['Doanh thu sau giảm giá', 'net_sales'],
            ['Giá vốn đã bán', 'cost_of_goods'],
            ['Lãi gộp', 'gross_profit'],
          ].map(([label, key]) => (
            <div className="metric-card" key={key}>
              <span>{label}</span>
              <strong>{money(sum(key))}</strong>
            </div>
          ))}
        </div>
        {rows.some((r) => Number(r.zero_cost_qty) > 0) && (
          <p className="finance-warning" role="status">
            Có hàng đã bán ghi nhận giá vốn bằng 0. Hãy đối chiếu dữ liệu cũ trước khi dùng số lãi
            này; hệ thống giữ nguyên chứng từ lịch sử.
          </p>
        )}
        {rows.length ? (
          <div className="data-panel table-scroll">
            <table className="profit-table">
              <thead>
                <tr>
                  <th>Sản phẩm</th>
                  <th>SL nhập</th>
                  <th>Tiền nhập</th>
                  <th>SL bán</th>
                  <th>Doanh thu sau giảm giá</th>
                  <th>Giá vốn đã bán</th>
                  <th>Lãi gộp / Tỷ suất</th>
                  <th>Tồn hiện tại</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.product_id}>
                    <td>
                      <strong>{r.product_name}</strong>
                      <small>{r.sku}</small>
                    </td>
                    <td>{Number(r.imported_qty).toLocaleString('vi-VN')}</td>
                    <td>{money(r.import_amount)}</td>
                    <td>{Number(r.sold_qty).toLocaleString('vi-VN')}</td>
                    <td>
                      {money(r.net_sales)}
                      <small>Giảm giá: {money(r.discount)}</small>
                    </td>
                    <td>{money(r.cost_of_goods)}</td>
                    <td
                      className={Number(r.gross_profit) < 0 ? 'profit-negative' : 'profit-positive'}
                    >
                      <strong>{money(r.gross_profit)}</strong>
                      <small>
                        {r.margin_percent == null
                          ? '—'
                          : Number(r.margin_percent).toLocaleString('vi-VN') + '%'}
                      </small>
                    </td>
                    <td>{Number(r.current_stock).toLocaleString('vi-VN')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState title="Không có sản phẩm phù hợp" />
        )}
        <p className="muted-note">
          Số lượng quy về đơn vị cơ bản. Tồn hiện tại là lượng có thể bán ở thời điểm xem, đã trừ
          hàng đang cách ly. Giá vốn bình quân được cập nhật khi xác nhận nhập; giá vốn bán được
          chốt khi xuất hàng. Tổng tiền nhập ròng không được trừ hết vào doanh thu khi hàng còn tồn.
        </p>
      </QueryState>
    </section>
  );
}

import { useState } from 'react';
import {
  ArrowUp,
  ArrowDown,
  ArrowUpDown,
  FileSpreadsheet,
  FileDown,
  Printer,
  LoaderCircle,
} from 'lucide-react';
import ReportPeriodFilter from './ReportPeriodFilter';
import { sortReportRows } from '@/utils/reports';
import { useQuery } from '@tanstack/react-query';
import { get } from '@/services/http';
import { QueryState, EmptyState } from '@/components/common/Shared';
import { money, normalize } from '@/utils/format';
import { Button } from '@/components/ui/button';
import { createExportReport, exportExcel, exportPdf, printReport } from '@/utils/report-export';

export default function ProductProfitPanel({ from, to, period, onPeriodChange, valid = true }) {
  const [search, setSearch] = useState('');
  const [exporting, setExporting] = useState('');
  const [exportError, setExportError] = useState('');
  const [sort, setSort] = useState({ key: 'gross_profit', direction: 'desc' });
  const sortButton = (key, label) => {
    const active = sort.key === key;
    const Icon = active ? (sort.direction === 'asc' ? ArrowUp : ArrowDown) : ArrowUpDown;
    return (
      <button
        type="button"
        className="profit-sort"
        aria-label={`Sắp xếp theo ${label}`}
        title={`Sắp xếp ${active && sort.direction === 'asc' ? 'giảm' : 'tăng'} dần`}
        onClick={() =>
          setSort({ key, direction: active && sort.direction === 'asc' ? 'desc' : 'asc' })
        }
      >
        {label}
        <Icon size={14} aria-hidden="true" />
      </button>
    );
  };
  const ariaSort = (key) =>
    sort.key === key ? (sort.direction === 'asc' ? 'ascending' : 'descending') : 'none';
  const query = useQuery({
    queryKey: ['product-profit', from, to],
    enabled: valid,
    queryFn: () => get('/management/reports/product-profit', from && to ? { from, to } : {}),
  });
  const rows = sortReportRows(
    (query.data || []).filter((r) =>
      normalize(r.product_name + ' ' + r.sku).includes(normalize(search)),
    ),
    sort.key,
    sort.direction,
  );
  const sum = (key) => rows.reduce((total, r) => total + Number(r[key] || 0), 0);
  const exportReport = async (format) => {
    if (exporting || !valid || !query.isSuccess || query.isFetching || !rows.length) return;
    setExportError('');
    setExporting(format);
    // Snapshot current filters and order before loading the export libraries.
    const report = createExportReport({ rows, from, to, search, sort });
    try {
      await { excel: exportExcel, pdf: exportPdf, print: printReport }[format](report);
    } catch {
      setExportError('Không thể xuất hoặc in báo cáo. Vui lòng thử lại.');
    } finally {
      setExporting('');
    }
  };
  return (
    <section className="product-profit-section">
      <div className="profit-toolbar">
        <label className="profit-search">
          Tìm sản phẩm
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tên sản phẩm hoặc SKU…"
          />
        </label>
        <ReportPeriodFilter value={period} onChange={onPeriodChange} />
      </div>
      <div
        className="report-export-actions"
        role="group"
        aria-label="Xuất và in báo cáo"
        aria-busy={Boolean(exporting)}
      >
        {[
          ['excel', 'Xuất Excel', FileSpreadsheet],
          ['pdf', 'Xuất PDF', FileDown],
          ['print', 'In báo cáo', Printer],
        ].map(([format, label, Icon]) => (
          <Button
            key={format}
            type="button"
            variant="outline"
            onClick={() => exportReport(format)}
            disabled={
              Boolean(exporting) || !valid || !query.isSuccess || query.isFetching || !rows.length
            }
          >
            {exporting === format ? (
              <LoaderCircle size={16} className="report-export-spinner" aria-hidden="true" />
            ) : (
              <Icon size={16} aria-hidden="true" />
            )}
            {exporting === format ? 'Đang xử lý…' : label}
          </Button>
        ))}
      </div>
      {exportError && (
        <p className="form-error" role="alert">
          {exportError}
        </p>
      )}
      {!valid && (
        <p className="form-error" role="alert">
          Chọn thời gian hợp lệ (năm từ 1900 đến 9998).
        </p>
      )}
      {valid && (
        <QueryState query={query}>
          <div className="profit-totals">
            {[
              ['Tổng tiền nhập', 'import_amount'],
              ['Doanh thu', 'net_sales'],
              ['Giảm giá', 'discount'],
              ['Giá vốn', 'cost_of_goods'],
              ['Lãi gộp', 'gross_profit'],
            ].map(([label, key]) => (
              <div className="metric-card" key={key}>
                <span>{label}</span>
                <strong>{money(sum(key))}</strong>
              </div>
            ))}
          </div>
          {rows.length ? (
            <div className="data-panel table-scroll">
              <table className="profit-table">
                <thead>
                  <tr>
                    <th scope="col" aria-sort={ariaSort('product_name')}>
                      {sortButton('product_name', 'Sản phẩm')}
                    </th>
                    <th scope="col" aria-sort={ariaSort('imported_qty')}>
                      {sortButton('imported_qty', 'SL nhập')}
                    </th>
                    <th scope="col" aria-sort={ariaSort('import_amount')}>
                      {sortButton('import_amount', 'Tiền nhập')}
                    </th>
                    <th scope="col" aria-sort={ariaSort('sold_qty')}>
                      {sortButton('sold_qty', 'SL bán')}
                    </th>
                    <th scope="col" aria-sort={ariaSort('net_sales')}>
                      {sortButton('net_sales', 'Doanh thu')}
                    </th>
                    <th scope="col" aria-sort={ariaSort('cost_of_goods')}>
                      {sortButton('cost_of_goods', 'Giá vốn')}
                    </th>
                    <th
                      scope="col"
                      aria-sort={ariaSort(
                        sort.key === 'margin_percent' ? 'margin_percent' : 'gross_profit',
                      )}
                    >
                      <div className="profit-sort-pair">
                        {sortButton('gross_profit', 'Lãi gộp')}
                        <span>/</span>
                        {sortButton('margin_percent', 'Tỷ suất')}
                      </div>
                    </th>
                    <th scope="col" aria-sort={ariaSort('current_stock')}>
                      {sortButton('current_stock', 'Tồn hiện tại')}
                    </th>
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
                        className={
                          Number(r.gross_profit) < 0 ? 'profit-negative' : 'profit-positive'
                        }
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
        </QueryState>
      )}
    </section>
  );
}

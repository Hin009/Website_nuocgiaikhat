import { isLowStock, LOW_STOCK_THRESHOLD } from '@/utils/inventory';
import { PermissionGuard } from '@/routes/Guards';
import { Link } from 'react-router-dom';
import { useMemo, useState } from 'react';
import {
  ArrowUpRight,
  ArrowRight,
  Package,
  ShoppingBag,
  Wallet,
  UsersRound,
  Clock,
  TrendingUp,
  CalendarDays,
} from 'lucide-react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  CartesianGrid,
  XAxis,
  YAxis,
  Tooltip,
  BarChart,
  Bar,
} from 'recharts';
import { useAdmin, useOrders } from '@/hooks/useData';
import { useAuth } from '@/contexts/AuthContext';
import { PageHeading, QueryState, StatusBadge, EmptyState } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { isMock } from '@/services';
import { money, date } from '@/utils/format';
const monthKey = (value) => value.slice(0, 7);
export default function DashboardPage({ report = false }) {
  const { user } = useAuth();
  const orders = useOrders(user);
  const products = useAdmin('products');
  const users = useAdmin('users');
  const receipts = useAdmin('receipts');
  const [range, setRange] = useState('all');
  const [from, setFrom] = useState('2026-01-01');
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));
  const endDate = new Date(to + 'T23:59:59');
  const startDate =
    range === 'custom'
      ? new Date(from + 'T00:00:00')
      : range === 'all'
        ? new Date(0)
        : new Date(endDate.getTime() - Number(range) * 86400000);
  const invalid = range === 'custom' && from > to;
  const filtered = (orders.data || []).filter(
    (o) => !invalid && new Date(o.createdAt) >= startDate && new Date(o.createdAt) <= endDate,
  );
  const completed = filtered.filter((o) => o.status === 'COMPLETED');
  const revenue = completed.reduce((s, o) => s + o.subtotal, 0);
  const received = (receipts.data || []).filter(
    (r) => new Date(r.createdAt) >= startDate && new Date(r.createdAt) <= endDate,
  );
  const stockLow = products.data?.filter((p) => p.active && isLowStock(p)) || [];
  const chart = useMemo(() => {
    const groups = {};
    for (const order of completed) {
      const key = monthKey(order.createdAt);
      groups[key] = (groups[key] || 0) + order.subtotal;
    }
    return Object.entries(groups)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([month, total]) => ({ name: 'T' + Number(month.slice(5)), total }));
  }, [completed]);
  const best = useMemo(() => {
    const sums = {};
    for (const order of completed)
      for (const line of order.items)
        sums[line.productId] = (sums[line.productId] || 0) + line.quantity;
    return Object.entries(sums)
      .sort((a, b) => b[1] - a[1])
      .map(([id, quantity]) => ({ product: products.data?.find((p) => p.id === id), quantity }))
      .filter((p) => p.product)
      .slice(0, 4);
  }, [completed, products.data]);
  const metrics = [
    [Wallet, 'Doanh thu sản phẩm', money(revenue)],
    [
      ShoppingBag,
      'Đơn hàng',
      filtered.length,
      filtered.filter((o) => o.status === 'PENDING').length + ' đơn đang chờ xác nhận',
      'peach',
    ],
    [
      Package,
      'Sản phẩm',
      products.data?.filter((p) => p.active).length || 0,
      'Sản phẩm đang kinh doanh',
      'blue',
    ],
    [
      UsersRound,
      'Khách hàng',
      users.data?.filter((u) => u.role === 'CUSTOMER').length || 0,
      'Tài khoản khách hàng',
      'purple',
    ],
  ];
  return (
    <>
      <PageHeading
        eyebrow={report ? 'DỮ LIỆU & GÓC NHÌN' : 'KHÔNG GIAN VẬN HÀNH'}
        title={
          report
            ? 'Báo cáo & thống kê'
            : 'Chào ' + user.name.split(' ').slice(-1) + ', ngày mới tốt lành!'
        }
        description={
          report
            ? 'Theo dõi doanh thu và kết quả kinh doanh.'
            : 'Cùng chăm chút cửa hàng và những đơn hàng hôm nay.'
        }
      />
      <div className="dashboard-date">
        <span>
          <CalendarDays size={16} />
          {date(new Date())}
        </span>
        <div className="range-buttons">
          {[
            ['all', 'Toàn bộ'],
            ['30', '30 ngày'],
            ['7', '7 ngày'],
            ['custom', 'Tùy chọn'],
          ].map(([value, label]) => (
            <button
              key={value}
              onClick={() => setRange(value)}
              className={range === value ? 'active' : ''}
            >
              {label}
            </button>
          ))}
        </div>
      </div>
      {range === 'custom' && (
        <div className="date-filter">
          <label>
            Từ ngày
            <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label>
            Đến ngày
            <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
          </label>
          {invalid && <p className="form-error">Ngày bắt đầu phải trước ngày kết thúc.</p>}
        </div>
      )}
      <QueryState query={orders}>
        <div className="metrics-grid">
          {metrics.map(([Icon, label, value, note, color]) => (
            <div className="metric-card" key={label}>
              <div className="metric-top">
                <span>{label}</span>
                <span className={'metric-icon ' + color}>
                  <Icon size={20} />
                </span>
              </div>
              <strong>{value}</strong>
              <small>{note}</small>
            </div>
          ))}
        </div>
        <div className="dashboard-charts">
          <section className="data-panel revenue-panel">
            <div className="panel-heading">
              <div>
                <h3>{report ? 'Doanh thu theo tháng' : 'Nhịp tăng trưởng cửa hàng'}</h3>
                <p>Giá sản phẩm trong đơn hoàn thành · chưa gồm phí giao hàng</p>
              </div>
            </div>
            {chart.length ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={260}>
                  <AreaChart data={chart} margin={{ top: 15, right: 15, bottom: 0, left: 0 }}>
                    <defs>
                      <linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#56876c" stopOpacity={0.28} />
                        <stop offset="100%" stopColor="#56876c" stopOpacity={0.01} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid vertical={false} strokeDasharray="4 5" stroke="#e9ede8" />
                    <XAxis
                      dataKey="name"
                      axisLine={false}
                      tickLine={false}
                      tick={{ fontSize: 12, fill: '#8d9690' }}
                      dy={10}
                    />
                    <YAxis
                      axisLine={false}
                      tickLine={false}
                      tick={{ fontSize: 11, fill: '#8d9690' }}
                      tickFormatter={(v) => (v >= 1000 ? v / 1000 + 'k' : v)}
                      width={45}
                    />
                    <Tooltip
                      formatter={(v) => [money(v), 'Doanh thu']}
                      contentStyle={{ borderRadius: 12, border: '1px solid #e1e8df' }}
                    />
                    <Area
                      type="monotone"
                      dataKey="total"
                      stroke="#3a7254"
                      strokeWidth={2.5}
                      fill="url(#revenueFill)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <EmptyState
                title="Chưa có doanh thu trong khoảng này"
                description="Doanh thu chỉ tính từ đơn đã hoàn thành."
              />
            )}
          </section>
          <section className="data-panel top-products">
            <div className="panel-heading">
              <div>
                <h3>Đồ uống được yêu thích</h3>
                <p>Theo số lượng trong đơn hoàn thành</p>
              </div>
              <TrendingUp size={18} />
            </div>
            {best.length ? (
              best.map(({ product, quantity }, i) => (
                <div className="top-product" key={product.id}>
                  <span className="ranking">{String(i + 1).padStart(2, '0')}</span>
                  <div className="mini-art" style={{ background: product.accent }}>
                    <DrinkArt product={product} />
                  </div>
                  <div>
                    <Link to={'/products/' + product.id}>{product.name}</Link>
                    <small>{product.volume}</small>
                  </div>
                  <strong>
                    {quantity}
                    <small>đã bán</small>
                  </strong>
                </div>
              ))
            ) : (
              <EmptyState
                title="Chưa có dữ liệu"
                description="Thay đổi bộ lọc thời gian để xem thêm."
              />
            )}
            <PermissionGuard roles={['ADMIN']}>
              <Link className="text-link top-products-link" to="/admin/products">
                Quản lý sản phẩm <ArrowRight size={15} />
              </Link>
            </PermissionGuard>
          </section>
        </div>
        {report && (
          <section className="data-panel import-report">
            <div className="panel-heading">
              <div>
                <h3>Thống kê nhập hàng</h3>
                <p>
                  {received.length} phiếu · {money(received.reduce((s, r) => s + r.total, 0))} tổng
                  giá trị
                </p>
              </div>
              <PermissionGuard roles={['ADMIN']}>
                <Link className="text-link" to="/admin/stock-receipts">
                  Xem phiếu nhập <ArrowRight size={16} />
                </Link>
              </PermissionGuard>
            </div>
            {received.length ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart
                    data={received
                      .slice(0, 15)
                      .map((r) => ({ name: r.productName, total: r.total }))}
                  >
                    <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                    <YAxis tickFormatter={(v) => v / 1000 + 'k'} />
                    <Tooltip formatter={(v) => money(v)} />
                    <Bar dataKey="total" fill="#6d9273" radius={[5, 5, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <EmptyState
                title="Chưa có phiếu nhập trong khoảng này"
                description="Tạo phiếu nhập để thử thống kê."
              />
            )}
          </section>
        )}
        <div className="dashboard-bottom">
          <section className="data-panel recent-orders">
            <div className="panel-heading">
              <div>
                <h3>Những đơn hàng gần đây</h3>
                <p>Cập nhật tình hình đơn hàng</p>
              </div>
              <Link className="text-link" to="/admin/orders">
                Tất cả đơn hàng <ArrowRight size={15} />
              </Link>
            </div>
            {filtered.length ? (
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Mã đơn</th>
                      <th>Khách hàng</th>
                      <th>Tổng tiền</th>
                      <th>Trạng thái</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.slice(0, 5).map((o) => (
                      <tr key={o.id}>
                        <td>
                          <Link className="order-id" to={'/admin/orders/' + o.id}>
                            #{o.id}
                          </Link>
                          <small>{date(o.createdAt)}</small>
                        </td>
                        <td>{o.receiver}</td>
                        <td>
                          <strong>{money(o.total)}</strong>
                        </td>
                        <td>
                          <StatusBadge status={o.status} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <EmptyState
                title="Không có đơn hàng"
                description="Không tìm thấy đơn trong khoảng thời gian này."
              />
            )}
          </section>
          <aside className="operations-card">
            <div className="operations-icon">
              <Clock size={23} />
            </div>
            <span className="eyebrow">ĐỪNG BỎ LỠ</span>
            <h3>
              Một chút chăm sóc,
              <br />
              cửa hàng thêm tốt.
            </h3>
            <p>
              <strong>{filtered.filter((o) => o.status === 'PENDING').length} đơn</strong> đang chờ
              xác nhận.
              <br />
              <strong>{stockLow.length} sản phẩm</strong> sắp hết hàng{' '}
              {isMock ? '(tồn kho từ ' : 'theo ngưỡng cảnh báo '}{' '}
              {isMock ? LOW_STOCK_THRESHOLD + ' trở xuống).' : 'của từng sản phẩm.'}
            </p>
            <Button asChild variant="secondary">
              <Link to="/admin/orders?status=PENDING">
                Xử lý đơn hàng <ArrowUpRight size={17} />
              </Link>
            </Button>
          </aside>
        </div>
      </QueryState>
      {[products, users, receipts].some((q) => q.isError) && (
        <p className="form-error" role="alert">
          Một số số liệu chưa tải được. Hãy tải lại trang để thử lại.
        </p>
      )}
    </>
  );
}

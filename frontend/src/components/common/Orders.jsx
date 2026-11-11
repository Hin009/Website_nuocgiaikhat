import { Fragment, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { get } from '@/services/http';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { ChevronDown, Search, ShoppingBag, ArrowLeft, PackageCheck } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useOrders, useAction } from '@/hooks/useData';
import { orderService, transitions, isMock } from '@/services';
import { QueryState, EmptyState, PageHeading, StatusBadge, Pagination, Field } from './Shared';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { money, date, statusLabels, paymentMethodLabels } from '@/utils/format';
export function OrdersPage({ admin = false }) {
  const { user } = useAuth();
  const query = useOrders(user);
  const notifications = useQuery({
    queryKey: ['payment-notifications', user?.id],
    queryFn: () => get('/staff/payment-notifications'),
    enabled: admin && !isMock,
    refetchInterval: 10000,
  });
  const [q, setQ] = useState('');
  const [params] = useSearchParams();
  const [status, setStatus] = useState(
    statusLabels[params.get('status')] ? params.get('status') : '',
  );
  const [page, setPage] = useState(1);
  const [expandedId, setExpandedId] = useState(null);
  const toggleOrder = (id) => setExpandedId((previous) => (previous === id ? null : id));
  const orders = (query.data || []).filter(
    (o) =>
      (o.id + ' ' + o.receiver).toLowerCase().includes(q.toLowerCase()) &&
      (!status || o.status === status),
  );
  const current = Math.min(page, Math.max(1, Math.ceil(orders.length / 8)));
  return (
    <>
      <PageHeading
        title={admin ? 'Quản lý đơn hàng' : 'Đơn hàng của tôi'}
        description="Theo dõi và xem chi tiết các đơn hàng."
      />
      {admin && notifications.data?.items?.length > 0 && (
        <section className="form-card" aria-label="Thông báo thanh toán">
          <h2>Thông báo thanh toán MoMo</h2>
          {notifications.data.items.map((n) => (
            <p key={n.id}>
              <Link to={`/admin/orders/${n.order_id}`}>{n.message}</Link> · {date(n.created_at)}
            </p>
          ))}
        </section>
      )}
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              aria-label="Tìm đơn hàng"
              placeholder="Tìm mã đơn, người nhận…"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
                setExpandedId(null);
              }}
            />
          </div>
          <select
            aria-label="Lọc trạng thái"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
              setExpandedId(null);
            }}
          >
            <option value="">Tất cả trạng thái</option>
            {Object.entries(statusLabels).map(([id, label]) => (
              <option key={id} value={id}>
                {label}
              </option>
            ))}
          </select>
        </div>
        <QueryState query={query}>
          {orders.length ? (
            <>
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Mã đơn hàng</th>
                      {admin && <th>Khách hàng</th>}
                      <th>Ngày đặt</th>
                      <th>Tổng tiền</th>
                      <th>Trạng thái</th>
                      <th>
                        <span className="sr-only">Chi tiết</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {orders.slice((current - 1) * 8, current * 8).map((o) => (
                      <Fragment key={o.id}>
                        <tr>
                          <td>
                            <button
                              type="button"
                              className="order-id order-toggle"
                              onClick={() => toggleOrder(o.id)}
                              aria-expanded={expandedId === o.id}
                              aria-controls={'order-details-' + o.id}
                            >
                              #{o.id}
                            </button>
                            <small>{o.items.reduce((s, i) => s + i.quantity, 0)} sản phẩm</small>
                          </td>
                          {admin && (
                            <td>
                              {o.receiver}
                              <small>{o.phone}</small>
                            </td>
                          )}
                          <td>{date(o.createdAt)}</td>
                          <td>
                            <strong>{money(o.total)}</strong>
                          </td>
                          <td>
                            <StatusBadge status={o.status} />
                          </td>
                          <td>
                            <button
                              type="button"
                              className="icon-button order-expand"
                              aria-label={'Chi tiết đơn ' + o.id}
                              aria-expanded={expandedId === o.id}
                              aria-controls={'order-details-' + o.id}
                              onClick={() => toggleOrder(o.id)}
                            >
                              <ChevronDown size={18} />
                            </button>
                          </td>
                        </tr>
                        {expandedId === o.id && (
                          <tr className="order-expanded-row">
                            <td colSpan={admin ? 6 : 5}>
                              <section
                                id={'order-details-' + o.id}
                                className="order-inline-details"
                                aria-label={'Chi tiết đơn ' + o.id}
                              >
                                <OrderDetails id={o.id} admin={admin} inline />
                              </section>
                            </td>
                          </tr>
                        )}
                      </Fragment>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination
                page={current}
                pages={Math.ceil(orders.length / 8)}
                onChange={(nextPage) => {
                  setPage(nextPage);
                  setExpandedId(null);
                }}
              />
            </>
          ) : (
            <EmptyState
              icon={ShoppingBag}
              title="Chưa có đơn hàng phù hợp"
              description="Thử thay đổi bộ lọc hoặc tạo đơn hàng."
            />
          )}
        </QueryState>
      </div>
    </>
  );
}
export function OrderDetailPage({ admin = false }) {
  const { id } = useParams();
  return <OrderDetails key={id} id={id} admin={admin} />;
}
function OrderDetails({ id, admin = false, inline = false }) {
  const { user } = useAuth();
  const query = useOrders(user);
  const [next, setNext] = useState('');
  const [note, setNote] = useState('');
  const [reasonError, setReasonError] = useState(false);
  const action = useAction(
    (values) => orderService.change(user, id, values.status, values.note),
    'Đã cập nhật trạng thái đơn',
  );
  const order = query.data?.find((o) => o.id === id);
  const allowed = order
    ? admin
      ? order.channel === 'TAI_QUAY'
        ? []
        : transitions[order.status] || []
      : order.status === 'PENDING'
        ? ['CANCELLED']
        : []
    : [];
  const confirm = async () => {
    if (next === 'CANCELLED' && !note.trim()) {
      setReasonError(true);
      return;
    }
    try {
      await action.mutateAsync({ status: next, note });
      setNext('');
      setNote('');
    } catch {
      /* lỗi đã có toast */
    }
  };
  return (
    <QueryState query={query}>
      {order ? (
        <>
          {!inline && (
            <Link to={admin ? '/admin/orders' : '/account/orders'} className="back-link">
              <ArrowLeft size={16} />
              Danh sách đơn hàng
            </Link>
          )}
          <PageHeading
            headingLevel={inline ? 'h2' : 'h1'}
            title={'Đơn hàng #' + order.id}
            description={'Đặt ngày ' + date(order.createdAt)}
            action={<StatusBadge status={order.status} />}
          />

          <div className="order-detail-grid">
            <div>
              <div className="form-card">
                <h3>Sản phẩm trong đơn</h3>
                {order.items.map((item) => (
                  <div
                    className="order-detail-item"
                    key={item.id || item.packageId || item.productId}
                  >
                    <div className="mini-art" style={{ background: item.accent }}>
                      <DrinkArt product={item} />
                    </div>
                    <div>
                      <strong>{item.name}</strong>
                      <small>
                        {item.volume} · Số lượng {item.purchaseQuantity || item.quantity}{' '}
                        {item.purchaseUnit?.toLowerCase() || 'sản phẩm'}
                      </small>
                    </div>
                    <strong>{money(item.lineTotal ?? item.price * item.quantity)}</strong>
                  </div>
                ))}
                <div className="order-totals">
                  <p>
                    <span>Tạm tính</span>
                    {money(order.subtotal)}
                  </p>
                  {order.discountAmount > 0 && (
                    <p className="order-discount">
                      <span>Giảm giá ({order.voucherCode})</span>
                      <strong>-{money(order.discountAmount)}</strong>
                    </p>
                  )}
                  <p>
                    <span>Phí giao hàng</span>
                    {money(order.shippingFee)}
                  </p>
                  {order.shippingDiscountAmount > 0 && (
                    <p className="order-shipping-discount">
                      <span>Giảm phí giao hàng ({order.voucherCode})</span>
                      <strong>-{money(order.shippingDiscountAmount)}</strong>
                    </p>
                  )}
                  <p>
                    <strong>Tổng cộng</strong>
                    <strong>{money(order.total)}</strong>
                  </p>
                </div>
              </div>
              <div className="form-card">
                <h3>
                  <PackageCheck size={20} />
                  Lịch sử đơn hàng
                </h3>
                {order.history.length ? (
                  order.history.map((h, i) => (
                    <div className="timeline-item" key={i}>
                      <i />
                      <div>
                        <strong>{statusLabels[h.status]}</strong>
                        <small>{new Date(h.at).toLocaleString('vi-VN')}</small>
                        {h.note && <p>{h.note}</p>}
                      </div>
                    </div>
                  ))
                ) : (
                  <p>Đơn hàng chưa có thông tin sản phẩm chi tiết.</p>
                )}
              </div>
            </div>
            <aside>
              <div className="form-card">
                <h3>Thông tin nhận hàng</h3>
                <strong>{order.receiver}</strong>
                <p>{order.phone}</p>
                <p>{order.address}</p>
                {order.note && <p>Ghi chú: {order.note}</p>}
                <hr />
                <h3>Thanh toán</h3>
                <p>
                  {paymentMethodLabels[order.paymentMethod] ||
                    order.paymentMethod ||
                    'Thanh toán khi nhận hàng (COD)'}
                </p>
                {!isMock &&
                  order.payments.map((payment) => (
                    <div key={payment.id}>
                      <p>
                        {{
                          PENDING: 'Chờ thanh toán',
                          SUCCESS: 'Đã thanh toán',
                          FAILED: 'Thanh toán thất bại',
                          CANCELLED: 'Đã hủy',
                          REFUNDED: 'Đã hoàn tiền',
                        }[payment.trang_thai] || payment.trang_thai}
                      </p>
                      {payment.environment && <p>Môi trường: {payment.environment}</p>}
                      {payment.ma_giao_dich && <p>Mã giao dịch: {payment.ma_giao_dich}</p>}
                      {payment.paid_at && (
                        <p>Thanh toán lúc: {new Date(payment.paid_at).toLocaleString('vi-VN')}</p>
                      )}
                    </div>
                  ))}
                {!admin &&
                  order.paymentMethod === 'MOMO' &&
                  !['CANCELLED', 'REJECTED'].includes(order.status) && (
                    <Link to={`/payments/momo/${order.id}`}>Xem thanh toán MoMo</Link>
                  )}
                {isMock && <small>Không phản ánh thanh toán thực tế.</small>}
              </div>
              {allowed.length > 0 && (
                <div className="form-card">
                  <h3>{admin ? 'Xử lý đơn hàng' : 'Thao tác'}</h3>
                  <div className="form-stack">
                    {allowed.map((status) => (
                      <Button
                        key={status}
                        variant={status === 'CANCELLED' ? 'outline' : 'default'}
                        onClick={() => {
                          setNext(status);
                          setReasonError(false);
                        }}
                      >
                        {
                          {
                            CONFIRMED: 'Xác nhận đơn',
                            SHIPPING: 'Bắt đầu giao hàng',
                            COMPLETED: 'Hoàn thành đơn',
                            CANCELLED: 'Hủy đơn hàng',
                          }[status]
                        }
                      </Button>
                    ))}
                  </div>
                </div>
              )}
            </aside>
          </div>
          <ConfirmDialog
            open={!!next}
            onOpenChange={(v) => !v && !action.isPending && setNext('')}
            title={'Chuyển sang “' + (statusLabels[next] || '') + '”?'}
            description={
              isMock
                ? 'Tồn kho đã được giữ khi đặt đơn. Hủy đơn sẽ hoàn lại số lượng đã giữ.'
                : 'Xác nhận đơn sẽ giữ số lượng hàng. Hủy đơn đã xác nhận sẽ hoàn lại số lượng. Vui lòng kiểm tra trước khi tiếp tục.'
            }
            pending={action.isPending}
            onConfirm={confirm}
          >
            {next === 'CANCELLED' && (
              <Field label="Lý do hủy đơn" error={reasonError ? 'Vui lòng nhập lý do hủy.' : null}>
                <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={3} />
              </Field>
            )}
          </ConfirmDialog>
        </>
      ) : (
        <EmptyState
          title="Không tìm thấy đơn hàng"
          description="Đơn hàng không tồn tại hoặc không thuộc tài khoản của bạn."
        />
      )}
    </QueryState>
  );
}

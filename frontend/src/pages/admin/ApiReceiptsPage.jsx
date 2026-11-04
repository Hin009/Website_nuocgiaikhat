import { useState, useEffect } from 'react';
import SupplierReturns from './SupplierReturns';
import PurchaseOrderForm from './PurchaseOrderForm';
import ReceiptAcceptanceForm from './ReceiptAcceptanceForm';
import { remainingToReceive } from '@/utils/receiving';
import { inPurchasingDateRange, purchasingDate } from '@/utils/purchasing-dates';
import { supplierDeliveryStatus } from '@/utils/supplier-delivery';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from '@/contexts/AuthContext';
import { useAdmin, useAction } from '@/hooks/useData';
import { purchasingService } from '@/services/api';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { PageHeading, QueryState, EmptyState } from '@/components/common/Shared';
import { money, date } from '@/utils/format';
const labels = {
  CHO_DUYET: 'Chờ duyệt',
  DA_DUYET: 'Đã duyệt',
  TU_CHOI: 'Từ chối',
  DANG_GIAO: 'Đang giao',
  DA_NHAN_MOT_PHAN: 'Đã nhận một phần',
  DA_NHAN_DU: 'Đã nhận đủ',
  DA_HUY: 'Đã hủy',
};
function DeliverySchedule({ order, today }) {
  const status = supplierDeliveryStatus(order, today);
  return (
    <>
      {order.ngay_giao_du_kien ? date(`${order.ngay_giao_du_kien}T12:00:00+07:00`) : 'Chưa hẹn'}
      {status && (
        <small
          className={`delivery-status ${['overdue', 'late'].includes(status.kind) ? 'delivery-late' : 'delivery-on-time'}`}
        >
          {status.label}
        </small>
      )}
      {status?.completedOn && (
        <small>Nhận đủ: {date(`${status.completedOn}T12:00:00+07:00`)}</small>
      )}
    </>
  );
}
export default function ApiReceiptsPage() {
  const { user } = useAuth();
  const admin = user.role === 'ADMIN';
  const [today, setToday] = useState(() => purchasingDate());
  useEffect(() => {
    const timer = setInterval(() => setToday(purchasingDate()), 60000);
    return () => clearInterval(timer);
  }, []);
  const orders = useQuery({
    queryKey: ['purchase-orders'],
    queryFn: async () =>
      Promise.all((await purchasingService.orders()).map((o) => purchasingService.detail(o.id))),
  });
  const receipts = useQuery({
    queryKey: ['purchase-receipts'],
    queryFn: purchasingService.receipts,
  });
  const suppliers = useQuery({
    queryKey: ['admin', 'suppliers'],
    queryFn: purchasingService.suppliers,
    enabled: admin,
  });
  const products = useAdmin('products');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [orderDateField, setOrderDateField] = useState('ngay_giao_du_kien');
  const invalidRange = !!(from && to && from > to);
  const filteredOrders = (orders.data || []).filter((o) =>
    inPurchasingDateRange(o[orderDateField], from, to),
  );
  const filteredReceipts = (receipts.data || []).filter((r) =>
    inPurchasingDateRange(r.ngay_nhap, from, to),
  );
  const [dialog, setDialog] = useState(null);
  const [pending, setPending] = useState(null);
  const action = useAction((task) => task(), 'Đã lưu thay đổi');
  const supplierName = (id) => suppliers.data?.find((s) => s.id === id)?.ten || `#${id}`;
  const packageName = (id) => {
    for (const p of products.data || []) {
      const q = p.packages.find((q) => Number(q.packageId) === Number(id));
      if (q) return `${p.name} — ${q.label}`;
    }
    return `Quy cách #${id}`;
  };
  const remaining = (line) => remainingToReceive(line, receipts.data || []);
  const confirm = async () => {
    try {
      await action.mutateAsync(pending.run);
      setPending(null);
      setDialog(null);
    } catch {
      setPending(null);
    }
  };
  return (
    <>
      <PageHeading
        title="Đơn đặt hàng và nhập hàng"
        description="Theo dõi đơn đặt hàng nhà cung cấp, lịch giao dự kiến và từng lần nhập hàng."
        action={
          admin && (
            <div className="row-actions">
              <Button onClick={() => setDialog({ type: 'order' })}>Lập đơn đặt hàng</Button>
            </div>
          )
        }
      />
      <div className="date-filter" aria-label="Lọc ngày đặt hàng và nhập hàng">
        <label>
          Lọc đơn đặt hàng theo
          <select value={orderDateField} onChange={(e) => setOrderDateField(e.target.value)}>
            <option value="ngay_giao_du_kien">Ngày giao dự kiến</option>
            <option value="ngay_dat">Ngày đặt đơn</option>
          </select>
        </label>
        <label>
          Từ ngày
          <input
            type="date"
            value={from}
            max={to || undefined}
            onChange={(e) => setFrom(e.target.value)}
          />
        </label>
        <label>
          Đến ngày
          <input
            type="date"
            value={to}
            min={from || undefined}
            onChange={(e) => setTo(e.target.value)}
          />
        </label>
        {(from || to) && (
          <Button
            variant="outline"
            onClick={() => {
              setFrom('');
              setTo('');
            }}
          >
            Xóa bộ lọc ngày
          </Button>
        )}
      </div>
      <p className="muted-note">
        Đơn đặt hàng lọc theo{' '}
        {orderDateField === 'ngay_giao_du_kien' ? 'ngày giao dự kiến' : 'ngày đặt đơn'}. Các lần
        nhập hàng lọc theo ngày nhập; phiếu trả lọc theo ngày xác nhận/lập phiếu. Để trống hai mốc
        để xem tất cả.
        {orderDateField === 'ngay_giao_du_kien' &&
          (from || to) &&
          ' Đơn chưa hẹn ngày giao không xuất hiện trong khoảng lọc này; chọn Ngày đặt đơn để tra cứu.'}
      </p>
      {invalidRange && (
        <p className="form-error" role="alert">
          Từ ngày phải nhỏ hơn hoặc bằng Đến ngày.
        </p>
      )}
      <QueryState query={orders}>
        {filteredOrders.length ? (
          <div className="data-panel table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Mã đơn</th>
                  <th>Nhà cung cấp</th>
                  <th>Ngày giao dự kiến</th>
                  <th>Trạng thái</th>
                  <th>Sản phẩm</th>
                  <th>Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {filteredOrders.map((o) => (
                  <tr key={o.id}>
                    <td>
                      {o.ma_don_nhap}
                      <small>{date(o.ngay_dat)}</small>
                    </td>
                    <td>{supplierName(o.nha_cung_cap_id)}</td>
                    <td>
                      <DeliverySchedule order={o} today={today} />
                    </td>
                    <td>{labels[o.trang_thai]}</td>
                    <td>
                      {o.items.map((l) => (
                        <div key={l.id}>
                          {packageName(l.quy_cach_id)} × {l.so_luong_dat}
                          <small>
                            Nhập kho: {Number(l.so_luong_da_nhan || 0).toLocaleString('vi-VN')} ·
                            Trả lỗi: {Number(l.so_luong_da_tra_loi || 0).toLocaleString('vi-VN')} ·
                            Chờ nhận: {remaining(l).toLocaleString('vi-VN')}
                          </small>
                        </div>
                      ))}
                    </td>
                    <td>
                      <div className="row-actions">
                        {admin && o.trang_thai === 'CHO_DUYET' && (
                          <Button
                            onClick={() =>
                              setPending({
                                title: 'Duyệt đơn đặt hàng?',
                                run: () => purchasingService.decide(o.id, 'DA_DUYET'),
                              })
                            }
                          >
                            Duyệt đơn
                          </Button>
                        )}
                        {['DA_DUYET', 'DANG_GIAO', 'DA_NHAN_MOT_PHAN'].includes(o.trang_thai) &&
                          o.items.some((l) => remaining(l) > 0) && (
                            <Button onClick={() => setDialog({ type: 'receive', order: o })}>
                              Nhận hàng
                            </Button>
                          )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title={
              from || to
                ? 'Không có đơn đặt hàng trong khoảng ngày đã chọn'
                : 'Chưa có đơn đặt hàng'
            }
            description="Đơn nhà cung cấp sẽ xuất hiện tại đây sau khi được lập."
          />
        )}
      </QueryState>
      <h2>Các lần nhập hàng</h2>
      <QueryState query={receipts}>
        {filteredReceipts.length ? (
          <div className="data-panel table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Lần nhập</th>
                  <th>Nhà cung cấp</th>
                  <th>Chi tiết</th>
                  <th>Trạng thái</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {filteredReceipts.map((r) => (
                  <tr key={r.id}>
                    <td>
                      #{r.id}
                      <small>{date(r.ngay_nhap)}</small>
                    </td>
                    <td>{r.nha_cung_cap}</td>
                    <td>
                      {r.items.map((l) => (
                        <div key={l.id}>
                          {l.ten_san_pham} — {l.ten_quy_cach}: {l.so_luong_thuc_nhan} ×{' '}
                          {money(l.gia_nhap_thuc_te)}
                          {l.so_luong_loai > 0 && (
                            <small className="finance-warning">
                              {r.trang_thai === 'CONFIRMED'
                                ? 'Đã trả lỗi NCC'
                                : 'Sẽ trả lỗi khi xác nhận'}
                              : {l.so_luong_loai} — {l.ly_do_loai}
                            </small>
                          )}
                        </div>
                      ))}
                    </td>
                    <td>
                      {r.trang_thai === 'CONFIRMED'
                        ? r.items.some((l) => Number(l.so_luong_loai) > 0)
                          ? 'Đã nhận và trả hàng lỗi'
                          : 'Đã nhập kho'
                        : r.trang_thai === 'DRAFT'
                          ? 'Nháp'
                          : 'Đã hủy'}
                    </td>
                    <td>
                      {r.trang_thai === 'DRAFT' && (
                        <Button
                          onClick={() =>
                            setPending({
                              title: 'Xác nhận hàng đạt nhập kho và hàng lỗi trả NCC?',
                              run: () => purchasingService.confirm(r.id),
                            })
                          }
                        >
                          {r.items.some((l) => Number(l.so_luong_loai) > 0)
                            ? 'Xác nhận nhận / trả hàng'
                            : 'Xác nhận nhập'}
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title={
              from || to
                ? 'Không có lần nhập hàng trong khoảng ngày đã chọn'
                : 'Chưa có lần nhập hàng'
            }
          />
        )}
      </QueryState>
      <SupplierReturns from={from} to={to} />
      <Dialog open={!!dialog} onOpenChange={(v) => !v && setDialog(null)}>
        <DialogContent
          title={
            dialog?.type === 'receive'
              ? 'Kiểm nhận và trả hàng lỗi'
              : 'Lập đơn đặt hàng nhà cung cấp'
          }
        >
          {dialog?.type === 'order' && (
            <PurchaseOrderForm
              suppliers={suppliers}
              products={products}
              onSubmit={(values) =>
                setPending({
                  title: 'Lập đơn đặt hàng chờ duyệt?',
                  run: () => purchasingService.create(values),
                })
              }
            />
          )}
          {dialog?.type === 'receive' && (
            <ReceiptAcceptanceForm
              order={dialog.order}
              receipts={receipts.data || []}
              packageName={packageName}
              onSubmit={(items) =>
                setPending({
                  title: 'Lưu phiếu kiểm nhận và hàng lỗi trả NCC?',
                  run: () => purchasingService.receive(dialog.order.id, items),
                })
              }
            />
          )}
        </DialogContent>
      </Dialog>
      <ConfirmDialog
        open={!!pending}
        onOpenChange={(v) => !v && !action.isPending && setPending(null)}
        title={pending?.title || ''}
        description="Vui lòng kiểm tra thông tin trước khi xác nhận."
        pending={action.isPending}
        onConfirm={confirm}
      />
    </>
  );
}

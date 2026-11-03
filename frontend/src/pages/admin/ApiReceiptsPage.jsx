import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from '@/contexts/AuthContext';
import { useAdmin, useAction } from '@/hooks/useData';
import { purchasingService } from '@/services/api';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { PageHeading, QueryState, EmptyState, Field } from '@/components/common/Shared';
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
export default function ApiReceiptsPage() {
  const { user } = useAuth();
  const admin = user.role === 'ADMIN';
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
  const [dialog, setDialog] = useState(null);
  const [productId, setProductId] = useState('');
  const [pending, setPending] = useState(null);
  const action = useAction((task) => task(), 'Đã lưu thay đổi');
  const product = products.data?.find((p) => p.id === productId);
  const supplierName = (id) => suppliers.data?.find((s) => s.id === id)?.ten || `#${id}`;
  const packageName = (id) => {
    for (const p of products.data || []) {
      const q = p.packages.find((q) => Number(q.packageId) === Number(id));
      if (q) return `${p.name} — ${q.label}`;
    }
    return `Quy cách #${id}`;
  };
  const remaining = (line) =>
    line.so_luong_dat -
    (receipts.data || [])
      .filter((r) => r.trang_thai === 'CONFIRMED')
      .flatMap((r) => r.items)
      .filter((l) => l.ct_don_ncc_id === line.id)
      .reduce((sum, l) => sum + l.so_luong_thuc_nhan, 0);
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
        title="Đơn nhập và nhận hàng"
        description="Theo dõi đơn nhà cung cấp và từng lần nhận hàng."
        action={
          admin && (
            <div className="row-actions">
              <Button variant="outline" onClick={() => setDialog({ type: 'supplier' })}>
                Thêm nhà cung cấp
              </Button>
              <Button onClick={() => setDialog({ type: 'order' })}>Lập đơn nhập</Button>
            </div>
          )
        }
      />
      <QueryState query={orders}>
        {orders.data?.length ? (
          <div className="data-panel table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Mã đơn</th>
                  <th>Nhà cung cấp</th>
                  <th>Trạng thái</th>
                  <th>Sản phẩm</th>
                  <th>Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {orders.data.map((o) => (
                  <tr key={o.id}>
                    <td>
                      {o.ma_don_nhap}
                      <small>{date(o.ngay_dat)}</small>
                    </td>
                    <td>{supplierName(o.nha_cung_cap_id)}</td>
                    <td>{labels[o.trang_thai]}</td>
                    <td>
                      {o.items.map((l) => (
                        <div key={l.id}>
                          {packageName(l.quy_cach_id)} × {l.so_luong_dat}
                        </div>
                      ))}
                    </td>
                    <td>
                      <div className="row-actions">
                        {admin && o.trang_thai === 'CHO_DUYET' && (
                          <Button
                            onClick={() =>
                              setPending({
                                title: 'Duyệt đơn nhập?',
                                run: () => purchasingService.decide(o.id, 'DA_DUYET'),
                              })
                            }
                          >
                            Duyệt đơn
                          </Button>
                        )}
                        {['DA_DUYET', 'DANG_GIAO', 'DA_NHAN_MOT_PHAN'].includes(o.trang_thai) && (
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
            title="Chưa có đơn nhập"
            description="Đơn nhà cung cấp sẽ xuất hiện tại đây sau khi được lập."
          />
        )}
      </QueryState>
      <h2>Các lần nhận hàng</h2>
      <QueryState query={receipts}>
        {receipts.data?.length ? (
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
                {receipts.data.map((r) => (
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
                        </div>
                      ))}
                    </td>
                    <td>
                      {r.trang_thai === 'CONFIRMED'
                        ? 'Đã nhập'
                        : r.trang_thai === 'DRAFT'
                          ? 'Nháp'
                          : 'Đã hủy'}
                    </td>
                    <td>
                      {r.trang_thai === 'DRAFT' && (
                        <Button
                          onClick={() =>
                            setPending({
                              title: 'Xác nhận nhận hàng và cập nhật tồn kho?',
                              run: () => purchasingService.confirm(r.id),
                            })
                          }
                        >
                          Xác nhận nhập
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState title="Chưa có lần nhận hàng" />
        )}
      </QueryState>
      <Dialog open={!!dialog} onOpenChange={(v) => !v && setDialog(null)}>
        <DialogContent
          title={
            dialog?.type === 'supplier'
              ? 'Nhà cung cấp mới'
              : dialog?.type === 'receive'
                ? 'Lập lần nhận hàng'
                : 'Lập đơn nhà cung cấp'
          }
        >
          {dialog?.type === 'supplier' && (
            <form
              className="form-stack"
              onSubmit={(e) => {
                e.preventDefault();
                const d = new FormData(e.currentTarget);
                setPending({
                  title: 'Tạo nhà cung cấp?',
                  run: () =>
                    purchasingService.addSupplier({
                      name: d.get('name'),
                      phone: d.get('phone'),
                      email: d.get('email'),
                    }),
                });
              }}
            >
              <Field label="Tên nhà cung cấp">
                <input name="name" required maxLength={255} />
              </Field>
              <Field label="Điện thoại">
                <input name="phone" maxLength={25} />
              </Field>
              <Field label="Email">
                <input name="email" type="email" />
              </Field>
              <Button type="submit">Lưu nhà cung cấp</Button>
            </form>
          )}
          {dialog?.type === 'order' && (
            <form
              className="form-stack"
              onSubmit={(e) => {
                e.preventDefault();
                const d = new FormData(e.currentTarget);
                setPending({
                  title: 'Lập đơn nhập chờ duyệt?',
                  run: () =>
                    purchasingService.create({
                      supplierId: d.get('supplier'),
                      productId,
                      packageId: d.get('package'),
                      quantity: d.get('quantity'),
                      cost: d.get('cost'),
                    }),
                });
              }}
            >
              <Field label="Nhà cung cấp">
                <select name="supplier" required>
                  <option value="">Chọn nhà cung cấp</option>
                  {suppliers.data
                    ?.filter((s) => s.trang_thai === 'HOP_TAC')
                    .map((s) => (
                      <option value={s.id} key={s.id}>
                        {s.ten}
                      </option>
                    ))}
                </select>
              </Field>
              {suppliers.isError && <p className="form-error">{suppliers.error.message}</p>}
              <Field label="Sản phẩm">
                <select required value={productId} onChange={(e) => setProductId(e.target.value)}>
                  <option value="">Chọn sản phẩm</option>
                  {products.data?.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Quy cách">
                <select key={productId} name="package" required>
                  <option value="">Chọn quy cách</option>
                  {product?.packages.map((q) => (
                    <option key={q.packageId} value={q.packageId}>
                      {q.label}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Số lượng quy cách">
                <input name="quantity" type="number" min="1" max="1000000" required />
              </Field>
              <Field label="Giá nhập mỗi quy cách (đ)">
                <input name="cost" type="number" min="0" step="0.01" required />
              </Field>
              <p className="muted-note">
                Đơn mới ở trạng thái chờ duyệt; chỉ cộng tồn sau khi xác nhận nhận hàng.
              </p>
              <Button type="submit">Lập đơn nhập</Button>
            </form>
          )}
          {dialog?.type === 'receive' && (
            <form
              className="form-stack"
              onSubmit={(e) => {
                e.preventDefault();
                const d = new FormData(e.currentTarget);
                const items = dialog.order.items
                  .map((l) => ({
                    purchaseLineId: l.id,
                    quantity: Number(d.get(`qty-${l.id}`)),
                    actualCost: Number(d.get(`cost-${l.id}`)),
                  }))
                  .filter((l) => l.quantity > 0);
                setPending({
                  title: 'Tạo lần nhận hàng nháp?',
                  run: () => {
                    if (!items.length) throw new Error('Nhập ít nhất một số lượng lớn hơn 0.');
                    return purchasingService.receive(dialog.order.id, items);
                  },
                });
              }}
            >
              {dialog.order.items.map((l) => (
                <div key={l.id}>
                  <strong>{packageName(l.quy_cach_id)}</strong>
                  <Field label={`Số lượng nhận (còn ${remaining(l)})`}>
                    <input
                      name={`qty-${l.id}`}
                      type="number"
                      min="0"
                      max={remaining(l)}
                      defaultValue={remaining(l)}
                      required
                    />
                  </Field>
                  <Field label="Giá thực tế mỗi quy cách (đ)">
                    <input
                      name={`cost-${l.id}`}
                      type="number"
                      min="0"
                      step="0.01"
                      defaultValue={l.gia_nhap_du_kien}
                      required
                    />
                  </Field>
                </div>
              ))}
              <Button type="submit">Lưu lần nhận nháp</Button>
            </form>
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

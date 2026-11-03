import { useState } from 'react';
import { Plus, Search, Pencil, Trash2, Eye, UsersRound, Truck, Shapes } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useAdmin, useAction } from '@/hooks/useData';
import UserForm from './UserForm';
import { adminService } from '@/services';

import { PageHeading, QueryState, EmptyState, Field, Pagination } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { money, date, roleLabels, normalize } from '@/utils/format';
const categorySchema = z.object({
  name: z.string().trim().min(2, 'Tên cần ít nhất 2 ký tự.').max(100),
  description: z.string().max(200),
  color: z.string(),
});
function CategoryForm({ item, onClose }) {
  const action = useAction(
    (values) => adminService.save('categories', { ...item, ...values, icon: item?.icon || 'cup' }),
    'Đã lưu danh mục',
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(categorySchema),
    defaultValues: item || { name: '', description: '', color: '#e8efdf' },
  });
  return (
    <form
      className="form-stack"
      onSubmit={handleSubmit(async (values) => {
        try {
          await action.mutateAsync(values);
          onClose();
        } catch {
          /* toast */
        }
      })}
      noValidate
    >
      <Field label="Tên danh mục" error={errors.name}>
        <input {...register('name')} />
      </Field>
      <Field label="Mô tả ngắn" error={errors.description}>
        <input {...register('description')} />
      </Field>
      <Field label="Màu đại diện">
        <input type="color" {...register('color')} />
      </Field>
      <div className="dialog-actions">
        <Button type="button" variant="outline" onClick={onClose}>
          Hủy
        </Button>
        <Button disabled={action.isPending} type="submit">
          Lưu danh mục
        </Button>
      </div>
    </form>
  );
}
export function CategoriesPage() {
  const query = useAdmin('categories');
  const products = useAdmin('products');
  const [edit, setEdit] = useState(undefined);
  const [remove, setRemove] = useState(null);
  const [q, setQ] = useState('');
  const action = useAction((id) => adminService.remove('categories', id), 'Đã xóa danh mục');
  const data = (query.data || []).filter((c) => normalize(c.name).includes(normalize(q)));
  return (
    <>
      <PageHeading
        title="Quản lý danh mục"
        description="Sắp xếp từng nhóm đồ uống để khách dễ tìm hơn."
        action={
          <Button onClick={() => setEdit(null)}>
            <Plus size={17} />
            Thêm danh mục
          </Button>
        }
      />
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Tìm danh mục…"
              aria-label="Tìm danh mục"
            />
          </div>
        </div>
        <QueryState query={query}>
          {data.length ? (
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Danh mục</th>
                    <th>Mô tả</th>
                    <th>Số sản phẩm</th>
                    <th>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {data.map((c) => (
                    <tr key={c.id}>
                      <td>
                        <div className="category-table-name">
                          <span style={{ background: c.color }}>
                            <Shapes size={19} />
                          </span>
                          <strong>{c.name}</strong>
                        </div>
                      </td>
                      <td>{c.description || '—'}</td>
                      <td>{products.data?.filter((p) => p.categoryId === c.id).length || 0}</td>
                      <td>
                        <div className="row-actions">
                          <button
                            className="icon-button"
                            onClick={() => setEdit(c)}
                            aria-label={'Sửa danh mục ' + c.name}
                          >
                            <Pencil size={16} />
                          </button>
                          <button
                            className="icon-button"
                            onClick={() => setRemove(c)}
                            aria-label={'Xóa danh mục ' + c.name}
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState title="Không tìm thấy danh mục" />
          )}
        </QueryState>
      </div>
      <p className="muted-note">
        Danh mục có sản phẩm liên quan sẽ không thể xóa, kể cả sản phẩm đã ngừng bán.
      </p>
      <Dialog open={edit !== undefined} onOpenChange={(v) => !v && setEdit(undefined)}>
        <DialogContent title={edit ? 'Chỉnh sửa danh mục' : 'Thêm danh mục'}>
          <CategoryForm key={edit?.id || 'new'} item={edit} onClose={() => setEdit(undefined)} />
        </DialogContent>
      </Dialog>
      <ConfirmDialog
        open={!!remove}
        onOpenChange={(v) => !v && !action.isPending && setRemove(null)}
        title="Xóa danh mục?"
        description={
          'Bạn đang xóa danh mục ' +
          remove?.name +
          '. Thao tác chỉ hợp lệ khi không còn sản phẩm liên quan.'
        }
        pending={action.isPending}
        onConfirm={async () => {
          try {
            await action.mutateAsync(remove.id);
            setRemove(null);
          } catch {
            /* toast */
          }
        }}
      />
    </>
  );
}
const receiptSchema = z.object({
  productId: z.string().min(1, 'Chọn sản phẩm.'),
  quantity: z.coerce.number().int().min(1, 'Số lượng cần lớn hơn 0.').max(100000),
  cost: z.coerce.number().min(0, 'Giá nhập không được âm.').max(100000000),
  supplier: z.string().trim().min(2, 'Vui lòng nhập nhà cung cấp.').max(150),
  note: z.string().max(500),
});
function ReceiptForm({ products, onClose }) {
  const [pending, setPending] = useState(null);
  const action = useAction(
    (values) => adminService.receipt(values),
    'Đã ghi phiếu nhập và cập nhật tồn kho',
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(receiptSchema),
    defaultValues: { productId: '', quantity: 24, cost: 7000, supplier: '', note: '' },
  });
  return (
    <>
      <form className="form-stack" onSubmit={handleSubmit(setPending)} noValidate>
        <Field label="Sản phẩm" error={errors.productId}>
          <select {...register('productId')}>
            <option value="">Chọn sản phẩm</option>
            {products
              .filter((p) => p.active)
              .map((p) => (
                <option value={p.id} key={p.id}>
                  {p.name}
                </option>
              ))}
          </select>
        </Field>
        <div className="form-grid">
          <Field label="Số lượng nhập" error={errors.quantity}>
            <input type="number" min="1" {...register('quantity')} />
          </Field>
          <Field label="Đơn giá nhập (đ)" error={errors.cost}>
            <input type="number" min="0" {...register('cost')} />
          </Field>
        </div>
        <Field label="Nhà cung cấp" error={errors.supplier}>
          <input {...register('supplier')} placeholder="Tên nhà cung cấp" />
        </Field>
        <Field label="Ghi chú" error={errors.note}>
          <textarea {...register('note')} rows={2} />
        </Field>
        <p className="muted-note">
          Mỗi phiếu nhập gồm một sản phẩm. Xác nhận phiếu sẽ cập nhật tồn kho.
        </p>
        <div className="dialog-actions">
          <Button type="button" variant="outline" onClick={onClose}>
            Hủy
          </Button>
          <Button type="submit">Kiểm tra phiếu nhập</Button>
        </div>
      </form>
      <ConfirmDialog
        open={!!pending}
        onOpenChange={(v) => !v && !action.isPending && setPending(null)}
        title="Ghi nhận phiếu nhập?"
        description={
          pending
            ? 'Nhập ' +
              pending.quantity +
              ' sản phẩm. Tổng giá trị ' +
              money(pending.quantity * pending.cost) +
              '.'
            : ''
        }
        pending={action.isPending}
        onConfirm={async () => {
          try {
            await action.mutateAsync(pending);
            setPending(null);
            onClose();
          } catch {
            /* toast */
          }
        }}
      />
    </>
  );
}
export function ReceiptsPage() {
  const query = useAdmin('receipts');
  const products = useAdmin('products');
  const [open, setOpen] = useState(false);
  const [detail, setDetail] = useState(null);
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const data = (query.data || []).filter((r) =>
    normalize(r.id + ' ' + r.productName + ' ' + r.supplier).includes(normalize(q)),
  );
  const current = Math.min(page, Math.max(1, Math.ceil(data.length / 8)));
  return (
    <>
      <PageHeading
        title="Quản lý nhập hàng"
        description="Thử tạo phiếu và theo dõi lịch sử nhập kho."
        action={
          <Button onClick={() => setOpen(true)}>
            <Plus size={17} />
            Tạo phiếu nhập
          </Button>
        }
      />
      <div className="small-metrics">
        <div>
          <span>Số phiếu nhập</span>
          <strong>{query.data?.length || 0}</strong>
        </div>
        <div>
          <span>Tổng số lượng nhập</span>
          <strong>{query.data?.reduce((s, r) => s + r.quantity, 0) || 0}</strong>
        </div>
        <div>
          <span>Tổng giá trị nhập</span>
          <strong>{money(query.data?.reduce((s, r) => s + r.total, 0))}</strong>
        </div>
      </div>
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
              placeholder="Tìm mã phiếu, sản phẩm, nhà cung cấp…"
              aria-label="Tìm phiếu nhập"
            />
          </div>
        </div>
        <QueryState query={query}>
          {data.length ? (
            <>
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Mã phiếu</th>
                      <th>Sản phẩm</th>
                      <th>Nhà cung cấp</th>
                      <th>Số lượng</th>
                      <th>Tổng giá trị</th>
                      <th>Ngày nhập</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {data.slice((current - 1) * 8, current * 8).map((r) => (
                      <tr key={r.id}>
                        <td>
                          <strong>{r.id}</strong>
                        </td>
                        <td>{r.productName}</td>
                        <td>{r.supplier}</td>
                        <td>{r.quantity}</td>
                        <td>{money(r.total)}</td>
                        <td>{date(r.createdAt)}</td>
                        <td>
                          <button
                            className="icon-button"
                            aria-label={'Xem phiếu ' + r.id}
                            onClick={() => setDetail(r)}
                          >
                            <Eye size={17} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination page={current} pages={Math.ceil(data.length / 8)} onChange={setPage} />
            </>
          ) : (
            <EmptyState
              icon={Truck}
              title="Kho hàng đang chờ chuyến mới"
              description="Tạo phiếu nhập đầu tiên để thử quy trình và cập nhật tồn kho."
              action={
                <Button onClick={() => setOpen(true)}>
                  <Plus size={16} />
                  Tạo phiếu nhập
                </Button>
              }
            />
          )}
        </QueryState>
      </div>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent
          title="Tạo phiếu nhập"
          description="Nhập sản phẩm, số lượng và thông tin nhà cung cấp."
        >
          {open && <ReceiptForm products={products.data || []} onClose={() => setOpen(false)} />}
        </DialogContent>
      </Dialog>
      <Dialog open={!!detail} onOpenChange={(v) => !v && setDetail(null)}>
        <DialogContent
          title={'Phiếu nhập ' + (detail?.id || '')}
          description="Các phiếu nhập hàng đã ghi nhận."
        >
          {detail && (
            <dl className="spec-list">
              {[
                ['Sản phẩm', detail.productName],
                ['Nhà cung cấp', detail.supplier],
                ['Số lượng', detail.quantity],
                ['Đơn giá', money(detail.cost)],
                ['Tổng giá trị', money(detail.total)],
                ['Ngày nhập', date(detail.createdAt)],
                ['Ghi chú', detail.note || '—'],
              ].map(([k, v]) => (
                <div key={k}>
                  <dt>{k}</dt>
                  <dd>{v}</dd>
                </div>
              ))}
            </dl>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
export function UsersPage({ customers = false }) {
  const query = useAdmin('users');
  const orders = useAdmin('orders');
  const [q, setQ] = useState('');
  const [role, setRole] = useState('');
  const [page, setPage] = useState(1);
  const [edit, setEdit] = useState(undefined);
  const [detail, setDetail] = useState(null);
  const data = (query.data || []).filter(
    (u) =>
      (!customers || u.role === 'CUSTOMER') &&
      (!role || u.role === role) &&
      normalize(u.name + ' ' + u.email + ' ' + u.phone).includes(normalize(q)),
  );
  const current = Math.min(page, Math.max(1, Math.ceil(data.length / 8)));
  return (
    <>
      <PageHeading
        title={customers ? 'Khách hàng' : 'Tài khoản & nhân viên'}
        description={
          customers
            ? 'Tìm hiểu thông tin và lịch sử mua sắm.'
            : 'Quản lý tài khoản, vai trò và trạng thái hoạt động.'
        }
        action={
          !customers && (
            <Button onClick={() => setEdit(null)}>
              <Plus size={17} />
              Thêm tài khoản
            </Button>
          )
        }
      />
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              aria-label="Tìm tài khoản"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
              placeholder="Tìm tên, email, số điện thoại…"
            />
          </div>
          {!customers && (
            <select
              aria-label="Lọc vai trò"
              value={role}
              onChange={(e) => {
                setRole(e.target.value);
                setPage(1);
              }}
            >
              <option value="">Tất cả vai trò</option>
              {Object.entries(roleLabels).map(([id, label]) => (
                <option key={id} value={id}>
                  {label}
                </option>
              ))}
            </select>
          )}
        </div>
        <QueryState query={query}>
          {data.length ? (
            <>
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Họ tên</th>
                      <th>Email</th>
                      <th>Số điện thoại</th>
                      <th>{customers ? 'Đơn hàng' : 'Vai trò'}</th>
                      <th>Trạng thái</th>
                      <th>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.slice((current - 1) * 8, current * 8).map((u) => (
                      <tr key={u.id}>
                        <td>
                          <div className="table-user">
                            <span>{u.name.charAt(0)}</span>
                            <strong>{u.name}</strong>
                          </div>
                        </td>
                        <td>{u.email}</td>
                        <td>{u.phone || '—'}</td>
                        <td>
                          {customers
                            ? orders.data?.filter((o) => o.userId === u.id).length || 0
                            : roleLabels[u.role]}
                        </td>
                        <td>
                          <span className={'pill ' + (u.active ? 'pill-green' : 'pill-gray')}>
                            {u.active ? 'Hoạt động' : 'Đã khóa'}
                          </span>
                        </td>
                        <td>
                          <div className="row-actions">
                            <button
                              className="icon-button"
                              aria-label={'Xem ' + u.name}
                              onClick={() => setDetail(u)}
                            >
                              <Eye size={17} />
                            </button>
                            {!customers && (
                              <button
                                className="icon-button"
                                aria-label={'Sửa ' + u.name}
                                onClick={() => setEdit(u)}
                              >
                                <Pencil size={16} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination page={current} pages={Math.ceil(data.length / 8)} onChange={setPage} />
            </>
          ) : (
            <EmptyState
              icon={UsersRound}
              title="Không tìm thấy tài khoản"
              description="Thử tìm bằng tên hoặc email khác."
            />
          )}
        </QueryState>
      </div>
      <Dialog open={edit !== undefined} onOpenChange={(v) => !v && setEdit(undefined)}>
        <DialogContent title={edit ? 'Chỉnh sửa tài khoản' : 'Thêm tài khoản'}>
          <UserForm key={edit?.id || 'new'} item={edit} onClose={() => setEdit(undefined)} />
        </DialogContent>
      </Dialog>
      <Dialog open={!!detail} onOpenChange={(v) => !v && setDetail(null)}>
        <DialogContent
          title={detail?.name || 'Thông tin tài khoản'}
          description="Thông tin khách hàng và lịch sử mua sắm."
        >
          {detail && (
            <>
              <dl className="spec-list">
                {[
                  ['Email', detail.email],
                  ['Điện thoại', detail.phone || '—'],
                  ['Địa chỉ', detail.address || 'Chưa có'],
                  ['Vai trò', roleLabels[detail.role]],
                ].map(([k, v]) => (
                  <div key={k}>
                    <dt>{k}</dt>
                    <dd>{v}</dd>
                  </div>
                ))}
              </dl>
              <h3 className="history-heading">Lịch sử đơn hàng</h3>
              {orders.data?.filter((o) => o.userId === detail.id).length ? (
                orders.data
                  .filter((o) => o.userId === detail.id)
                  .map((o) => (
                    <div className="checkout-line" key={o.id}>
                      <span>
                        #{o.id} · {date(o.createdAt)}
                      </span>
                      <strong>{money(o.total)}</strong>
                    </div>
                  ))
              ) : (
                <p>Chưa có đơn hàng.</p>
              )}
            </>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}

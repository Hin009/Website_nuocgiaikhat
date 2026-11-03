import { isLowStock } from '@/utils/inventory';
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { Plus, Search, Pencil, Archive, Package } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { productSchema } from '@/schemas';
import { useAdmin, useCategories, useAction } from '@/hooks/useData';
import { adminService } from '@/services';
import { PageHeading, QueryState, EmptyState, Field, Pagination } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { money, normalize } from '@/utils/format';
function ProductForm({ item, categories, onClose }) {
  const action = useAction(
    (values) =>
      adminService.save('products', {
        ...item,
        ...values,
        label: item?.label || values.brand,
        accent: item?.accent || '#edf2df',
        originalPrice: item?.originalPrice || null,
        tag: item?.tag || '',
        active: values.active,
      }),
    'Đã lưu sản phẩm',
  );
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(productSchema),
    defaultValues: item || {
      name: '',
      brand: '',
      categoryId: categories[0]?.id || '',
      volume: 'Lon 320ml',
      price: 10000,
      stock: 0,
      active: true,
      description: '',
      color: '#61846b',
      art: 'can',
    },
  });
  return (
    <form
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
      <div className="form-grid">
        <Field label="Tên sản phẩm" error={errors.name} className="span-two">
          <input {...register('name')} />
        </Field>
        <Field label="Thương hiệu" error={errors.brand}>
          <input {...register('brand')} />
        </Field>
        <Field label="Danh mục" error={errors.categoryId}>
          <select {...register('categoryId')}>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Quy cách" error={errors.volume}>
          <input {...register('volume')} />
        </Field>
        <Field label="Giá bán (đ)" error={errors.price}>
          <input type="number" min="0" {...register('price')} />
        </Field>
        <Field label="Số lượng tồn kho" error={errors.stock}>
          <input type="number" min="0" {...register('stock')} />
        </Field>
        <Field label="Dạng bao bì" error={errors.art}>
          <select {...register('art')}>
            <option value="can">Lon</option>
            <option value="bottle">Chai</option>
            <option value="water">Chai nước</option>
            <option value="carton">Hộp</option>
          </select>
        </Field>
        <Field label="Màu minh họa" error={errors.color}>
          <input type="color" {...register('color')} />
        </Field>
        <label className="checkbox-row span-two">
          <input type="checkbox" {...register('active')} />
          Đang kinh doanh
        </label>
        <Field className="span-two" label="Mô tả" error={errors.description}>
          <textarea {...register('description')} rows={3} />
        </Field>
      </div>
      <div className="dialog-actions">
        <Button type="button" variant="outline" onClick={onClose}>
          Hủy
        </Button>
        <Button type="submit" disabled={action.isPending}>
          {action.isPending ? 'Đang lưu…' : 'Lưu sản phẩm'}
        </Button>
      </div>
    </form>
  );
}
export default function ProductsPage() {
  const query = useAdmin('products');
  const categories = useCategories();
  const [params] = useSearchParams();
  const [q, setQ] = useState(params.get('q') || '');
  const [category, setCategory] = useState('');
  const [state, setState] = useState('all');
  const [page, setPage] = useState(1);
  const [edit, setEdit] = useState(undefined);
  const [remove, setRemove] = useState(null);
  const action = useAction(
    (id) => adminService.remove('products', id),
    'Đã ngừng kinh doanh sản phẩm',
  );
  const data = (query.data || []).filter(
    (p) =>
      normalize(p.name + ' ' + p.brand).includes(normalize(q)) &&
      (!category || p.categoryId === category) &&
      (state === 'all' || (state === 'active' ? p.active : !p.active)),
  );
  const current = Math.min(page, Math.max(1, Math.ceil(data.length / 7)));
  return (
    <>
      <PageHeading
        title="Quản lý sản phẩm"
        description="Chăm chút danh mục đồ uống của cửa hàng."
        action={
          <Button onClick={() => setEdit(null)} disabled={!categories.data?.length}>
            <Plus size={18} />
            Thêm sản phẩm
          </Button>
        }
      />
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              aria-label="Tìm sản phẩm quản lý"
              placeholder="Tìm tên, thương hiệu…"
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <select
            aria-label="Lọc danh mục"
            value={category}
            onChange={(e) => {
              setCategory(e.target.value);
              setPage(1);
            }}
          >
            <option value="">Tất cả danh mục</option>
            {categories.data?.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          <select
            aria-label="Lọc tình trạng"
            value={state}
            onChange={(e) => {
              setState(e.target.value);
              setPage(1);
            }}
          >
            <option value="active">Đang kinh doanh</option>
            <option value="inactive">Ngừng kinh doanh</option>
            <option value="all">Tất cả tình trạng</option>
          </select>
        </div>
        <QueryState query={query}>
          {data.length ? (
            <>
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Sản phẩm</th>
                      <th>Danh mục</th>
                      <th>Giá bán</th>
                      <th>Tồn kho</th>
                      <th>Trạng thái</th>
                      <th>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.slice((current - 1) * 7, current * 7).map((p) => (
                      <tr key={p.id}>
                        <td>
                          <div className="table-product">
                            <div className="mini-art" style={{ background: p.accent }}>
                              <DrinkArt product={p} />
                            </div>
                            <div>
                              <strong>{p.name}</strong>
                              <small>
                                {p.brand} · {p.volume}
                              </small>
                            </div>
                          </div>
                        </td>
                        <td>{categories.data?.find((c) => c.id === p.categoryId)?.name || '—'}</td>
                        <td>
                          <strong>{money(p.price)}</strong>
                        </td>
                        <td>
                          <span className={isLowStock(p) ? 'stock-warning' : ''}>{p.stock}</span>
                          {isLowStock(p) && (
                            <small className="stock-warning">Sắp hết hàng — cần nhập thêm</small>
                          )}
                        </td>
                        <td>
                          <span className={'pill ' + (p.active ? 'pill-green' : 'pill-gray')}>
                            {p.active ? 'Đang bán' : 'Ngừng bán'}
                          </span>
                        </td>
                        <td>
                          <div className="row-actions">
                            <button
                              className="icon-button"
                              aria-label={'Sửa ' + p.name}
                              onClick={() => setEdit(p)}
                            >
                              <Pencil size={16} />
                            </button>
                            {p.active && (
                              <button
                                className="icon-button"
                                aria-label={'Ngừng bán ' + p.name}
                                onClick={() => setRemove(p)}
                              >
                                <Archive size={16} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination page={current} pages={Math.ceil(data.length / 7)} onChange={setPage} />
            </>
          ) : (
            <EmptyState
              icon={Package}
              title="Không có sản phẩm phù hợp"
              description="Thay đổi từ khóa, bộ lọc hoặc thêm sản phẩm mới."
            />
          )}
        </QueryState>
      </div>
      <Dialog open={edit !== undefined} onOpenChange={(v) => !v && setEdit(undefined)}>
        <DialogContent
          title={edit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm'}
          description="Nhập thông tin sản phẩm và kiểm tra trước khi lưu."
        >
          <ProductForm
            key={edit?.id || 'new'}
            item={edit}
            categories={categories.data || []}
            onClose={() => setEdit(undefined)}
          />
        </DialogContent>
      </Dialog>
      <ConfirmDialog
        open={!!remove}
        onOpenChange={(v) => !v && !action.isPending && setRemove(null)}
        title="Ngừng kinh doanh sản phẩm?"
        description={
          remove?.name +
          ' sẽ ngừng bán tại cửa hàng và vẫn được giữ trong danh sách quản lý để chỉnh sửa hoặc kinh doanh lại. Dữ liệu các đơn cũ được giữ lại.'
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

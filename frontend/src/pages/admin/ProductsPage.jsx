import { isLowStock } from '@/utils/inventory';
import ProductInventoryDetails from './ProductInventoryDetails';
import { Fragment, useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useSearchParams } from 'react-router-dom';
import { Plus, Search, Pencil, Archive, Package, ChevronDown } from 'lucide-react';
import { useForm, Controller } from 'react-hook-form';
import { MoneyInput } from '@/components/common/MoneyInput';
import { zodResolver } from '@hookform/resolvers/zod';
import { productSchema } from '@/schemas';
import { useAdmin, useAction } from '@/hooks/useData';
import { adminService, isMock } from '@/services';
import { PageHeading, QueryState, EmptyState, Field, Pagination } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { money, normalize } from '@/utils/format';
function ProductForm({ item, categories, onClose }) {
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState('');
  useEffect(() => {
    if (!file) {
      setPreview('');
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  const action = useAction(async (values) => {
    if (!isMock && Number(values.stock) !== Number(item?.stock || 0) && !values.stockReason?.trim())
      throw new Error('Nhập lý do điều chỉnh số lượng.');
    if (file && file.size > 5 * 1024 * 1024) throw new Error('Ảnh không được vượt quá 5 MB.');
    const imageUrl = file ? await adminService.uploadImage(file) : values.imageUrl;
    return adminService.save('products', {
      ...item,
      ...values,
      imageUrl,
      expectedStock: item?.stock || 0,
      label: item?.label || values.brand,
      accent: item?.accent || '#edf2df',
      originalPrice: item?.originalPrice || null,
      tag: item?.tag || '',
      active: values.active,
    });
  }, 'Đã lưu sản phẩm');
  const {
    register,
    control,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(productSchema),
    defaultValues: item
      ? { ...item, stockReason: '', imageUrl: item.imageUrl || '' }
      : {
          imageUrl: '',
          stockReason: '',
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
        <Controller
          name="price"
          control={control}
          render={({ field }) => (
            <Field label="Giá bán (đ)" error={errors.price}>
              <MoneyInput data-field-control {...field} />
            </Field>
          )}
        />
        <Field label="Số lượng tồn kho" error={errors.stock}>
          <input type="number" min="0" {...register('stock')} />
        </Field>
        {!isMock && (
          <p className="muted-note span-two">
            Số lượng tính theo đơn vị lẻ, không phải số thùng/lốc. Khi điều chỉnh cần ghi lý do; hệ
            thống lưu lịch sử thay đổi. Giá bán áp dụng cho quy cách nhỏ nhất hiện có.
          </p>
        )}
        {!isMock && Number(watch('stock')) !== Number(item?.stock || 0) && (
          <Field className="span-two" label="Lý do điều chỉnh số lượng" error={errors.stockReason}>
            <input
              {...register('stockReason')}
              placeholder="Ví dụ: kiểm kê thực tế hoặc nhập tồn ban đầu"
            />
          </Field>
        )}
        {!isMock && (
          <>
            <Field className="span-two" label="Ảnh sản phẩm (JPG, PNG, WebP — tối đa 5 MB)">
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                disabled={action.isPending}
                onChange={(e) => setFile(e.target.files?.[0] || null)}
              />
            </Field>
            <Field className="span-two" label="Hoặc đường dẫn ảnh" error={errors.imageUrl}>
              <input
                {...register('imageUrl')}
                disabled={!!file}
                placeholder="https://... hoặc đường dẫn ảnh đã tải lên"
              />
            </Field>
            {(preview || watch('imageUrl')) && (
              <div className="span-two">
                <img
                  src={preview || watch('imageUrl')}
                  alt="Xem trước ảnh sản phẩm"
                  style={{ height: 160, maxWidth: '100%', objectFit: 'contain' }}
                />
              </div>
            )}
            <p className="muted-note span-two">
              Chọn ảnh mới để thay ảnh hiện tại. Để trống nếu muốn giữ ảnh đã lưu.
            </p>
          </>
        )}
        <Field label="Dạng bao bì" error={errors.art}>
          <select {...register('art')}>
            <option value="can">Lon</option>
            <option value="bottle">Chai</option>
            <option value="water">Chai nước</option>
            <option value="carton">Hộp</option>
          </select>
        </Field>
        {isMock && (
          <Field label="Màu minh họa" error={errors.color}>
            <input type="color" {...register('color')} />
          </Field>
        )}
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
function StockCell({ product, editable, reload }) {
  const [stock, setStock] = useState(String(product.stock));
  const [reason, setReason] = useState('');
  const changed = stock !== '' && Number(stock) !== Number(product.stock);
  const action = useAction(
    (values) =>
      isMock
        ? adminService.save('products', {
            ...product,
            stock: values.stock,
            stockReason: values.reason,
          })
        : adminService.adjustStock(product, values),
    'Đã cập nhật tồn kho',
  );
  if (!editable) return <span>{product.stock.toLocaleString('vi-VN')}</span>;
  return (
    <form
      className="inline-stock-form"
      onSubmit={async (e) => {
        e.preventDefault();
        if (!changed) return;
        try {
          await action.mutateAsync({ stock: Number(stock), expectedStock: product.stock, reason });
        } catch {
          /* Error displayed below and in toast. */
        }
      }}
    >
      <input
        aria-label={`Tồn kho ${product.name}`}
        type="number"
        min="0"
        max="1000000000"
        step="1"
        required
        value={stock}
        disabled={action.isPending}
        onChange={(e) => setStock(e.target.value)}
      />
      {changed && (
        <>
          <input
            aria-label={`Lý do điều chỉnh ${product.name}`}
            placeholder="Lý do điều chỉnh"
            maxLength={1000}
            required
            value={reason}
            disabled={action.isPending}
            onChange={(e) => setReason(e.target.value)}
          />
          <div className="row-actions">
            <Button type="submit" disabled={action.isPending}>
              {action.isPending ? 'Đang lưu…' : 'Lưu số lượng'}
            </Button>
            <Button
              type="button"
              variant="outline"
              disabled={action.isPending}
              onClick={() => {
                setStock(String(product.stock));
                setReason('');
                action.reset();
              }}
            >
              Hủy
            </Button>
          </div>
        </>
      )}
      {action.isError && (
        <p className="form-error" role="alert">
          {action.error.message}{' '}
          <button type="button" onClick={reload}>
            Tải lại danh sách
          </button>
        </p>
      )}
    </form>
  );
}
export default function ProductsPage() {
  const { user } = useAuth();
  const editable = user?.role === 'ADMIN';
  const query = useAdmin('products');
  const categories = useAdmin('categories');
  const [params] = useSearchParams();
  const [q, setQ] = useState(params.get('q') || '');
  const [category, setCategory] = useState('');
  const [state, setState] = useState('all');
  const [page, setPage] = useState(1);
  const [edit, setEdit] = useState(undefined);
  const [remove, setRemove] = useState(null);
  const [expanded, setExpanded] = useState(null);
  const toggleInventory = (id) => setExpanded((previous) => (previous === id ? null : id));
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
        description={
          editable
            ? 'Sửa số lượng ngay trên danh sách; tính theo đơn vị lẻ, không phải thùng/lốc.'
            : 'Xem sản phẩm và số lượng tồn kho theo đơn vị lẻ.'
        }
        action={
          editable && (
            <Button onClick={() => setEdit(null)} disabled={!categories.data?.length}>
              <Plus size={18} />
              Thêm sản phẩm
            </Button>
          )
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
                      {editable && <th>Thao tác</th>}
                      <th aria-label="Chi tiết sản phẩm" />
                    </tr>
                  </thead>
                  <tbody>
                    {data.slice((current - 1) * 7, current * 7).map((p) => (
                      <Fragment key={p.id}>
                        <tr className={expanded === p.id ? 'product-row-expanded' : undefined}>
                          <td>
                            <div className="table-product">
                              <div className="mini-art" style={{ background: p.accent }}>
                                <DrinkArt product={p} />
                              </div>
                              <div>
                                <button
                                  type="button"
                                  className="product-details-toggle"
                                  title="Xem hoặc thu gọn chi tiết sản phẩm"
                                  aria-expanded={expanded === p.id}
                                  aria-controls={`product-inventory-${p.id}`}
                                  onClick={() => toggleInventory(p.id)}
                                >
                                  <strong>{p.name}</strong>
                                </button>
                                <small>
                                  {p.brand} · {p.volume}
                                </small>
                              </div>
                            </div>
                          </td>
                          <td>
                            {categories.data?.find((c) => c.id === p.categoryId)?.name || '—'}
                          </td>
                          <td>
                            <strong>{money(p.price)}</strong>
                          </td>
                          <td>
                            <StockCell
                              key={`${p.id}:${p.stock}`}
                              product={p}
                              editable={editable}
                              reload={query.refetch}
                            />
                            {isLowStock(p) && (
                              <small className="stock-warning">Sắp hết hàng — cần nhập thêm</small>
                            )}
                          </td>
                          <td>
                            <span className={'pill ' + (p.active ? 'pill-green' : 'pill-gray')}>
                              {p.active ? 'Đang bán' : 'Ngừng bán'}
                            </span>
                          </td>
                          {editable && (
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
                          )}
                          <td className="product-expand-cell">
                            <button
                              type="button"
                              className="icon-button product-expand-button"
                              aria-label={`Chi tiết ${p.name}`}
                              aria-expanded={expanded === p.id}
                              aria-controls={`product-inventory-${p.id}`}
                              onClick={() => toggleInventory(p.id)}
                            >
                              <ChevronDown size={20} />
                            </button>
                          </td>
                        </tr>
                        {expanded === p.id && (
                          <tr className="product-inventory-row">
                            <td colSpan={editable ? 7 : 6}>
                              <div id={`product-inventory-${p.id}`}>
                                <ProductInventoryDetails product={p} />
                              </div>
                            </td>
                          </tr>
                        )}
                      </Fragment>
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
      <Dialog open={editable && edit !== undefined} onOpenChange={(v) => !v && setEdit(undefined)}>
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
        open={editable && !!remove}
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

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Plus, Search, Pencil, Building2, BadgePercent } from 'lucide-react';
import { useForm, Controller } from 'react-hook-form';
import { MoneyInput } from '@/components/common/MoneyInput';
import { zodResolver } from '@hookform/resolvers/zod';
import { supplierSchema, promotionSchema, localDateTime } from '@/schemas/business';
import { supplierService, promotionService } from '@/services/business';
import { useAction, useAdmin } from '@/hooks/useData';
import {
  PageHeading,
  QueryState,
  EmptyState,
  Field,
  Pagination,
  ErrorState,
  Loading,
} from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { normalize, money, date } from '@/utils/format';

const scopeLabels = {
  CATEGORY: 'Loại sản phẩm',
  BRAND: 'Thương hiệu được chọn',
};
function FormActions({ pending, onClose, label }) {
  return (
    <div className="dialog-actions">
      <Button type="button" variant="outline" disabled={pending} onClick={onClose}>
        Hủy
      </Button>
      <Button type="submit" disabled={pending}>
        {pending ? 'Đang lưu…' : label}
      </Button>
    </div>
  );
}
const supplierTypes = {
  DOANH_NGHIEP: 'Doanh nghiệp',
  HO_KINH_DOANH: 'Hộ kinh doanh',
  CA_NHAN: 'Cá nhân',
};
const verificationLabels = {
  CHUA_XAC_MINH: 'Chưa xác minh',
  DA_XAC_MINH: 'Đã xác minh',
  CAN_KIEM_TRA_LAI: 'Cần kiểm tra lại',
};
function SupplierForm({ item, onClose }) {
  const products = useAdmin('products');
  const [productSearch, setProductSearch] = useState('');
  const [taxCheck, setTaxCheck] = useState(null);
  const [checkingTax, setCheckingTax] = useState(false);
  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(supplierSchema),
    defaultValues: {
      productIds: (item?.product_ids || []).map(String),
      supplierType: item?.loai_nha_cung_cap || 'DOANH_NGHIEP',
      verificationStatus: item?.trang_thai_xac_minh || 'CHUA_XAC_MINH',
      verificationNotes: item?.ghi_chu_xac_minh || '',
      verificationConfirmed: false,
      fullName: item?.ten || '',
      taxCode: item?.ma_so_thue || '',
      contactName: item?.nguoi_lien_he || '',
      phone: item?.dien_thoai || '',
      email: item?.email || '',
      address: item?.dia_chi || '',
      status: item?.trang_thai || 'HOP_TAC',
    },
  });
  const productIds = watch('productIds');
  const verification = watch('verificationStatus');
  const supplierType = watch('supplierType');
  const invalidateVerification = () => {
    setTaxCheck(null);
    setValue('verificationConfirmed', false);
    if (watch('verificationStatus') === 'DA_XAC_MINH')
      setValue('verificationStatus', 'CAN_KIEM_TRA_LAI');
  };
  const action = useAction((v) => supplierService.save(item?.id, v), 'Đã lưu nhà cung cấp');
  const submit = async (v) => {
    try {
      await action.mutateAsync(v);
      onClose();
    } catch {
      /* Toast is handled by useAction. */
    }
  };
  return (
    <form className="form-stack" noValidate onSubmit={handleSubmit(submit)}>
      <ol className="supplier-workflow" aria-label="Quy trình hồ sơ nhà cung cấp">
        <li>
          <b>1</b>Thông tin liên hệ
        </li>
        <li>
          <b>2</b>Hồ sơ pháp lý
        </li>
        <li>
          <b>3</b>Kiểm tra & xác minh
        </li>
      </ol>
      <Field label="Tên nhà cung cấp" error={errors.fullName}>
        <input {...register('fullName', { onChange: invalidateVerification })} />
      </Field>
      <div className="form-grid">
        <Field label="Người liên hệ" error={errors.contactName}>
          <input {...register('contactName')} />
        </Field>
        <Field label="Số điện thoại" error={errors.phone}>
          <input type="tel" inputMode="numeric" autoComplete="tel" {...register('phone')} />
        </Field>
        <Field label="Email" error={errors.email}>
          <input type="email" {...register('email')} />
        </Field>
      </div>
      <Field label="Địa chỉ" error={errors.address}>
        <textarea rows={3} {...register('address', { onChange: invalidateVerification })} />
      </Field>
      <section className="supplier-legal" aria-label="Thông tin pháp lý và xác minh">
        <h3>Hồ sơ pháp lý</h3>
        <div className="form-grid">
          <Field label="Loại nhà cung cấp" error={errors.supplierType}>
            <select {...register('supplierType', { onChange: invalidateVerification })}>
              {Object.entries(supplierTypes).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Mã số thuế / Số định danh" error={errors.taxCode}>
            <input
              {...register('taxCode', { onChange: invalidateVerification })}
              inputMode="numeric"
              placeholder={
                supplierType === 'DOANH_NGHIEP'
                  ? '10 số hoặc 10 số-3 số'
                  : 'Số định danh 12 số / mã số thuế'
              }
            />
          </Field>
        </div>
        <p className="muted-note">
          Nhập theo hồ sơ pháp lý. Có thể để trống khi chưa có thông tin; hồ sơ chưa có mã không
          được đánh dấu đã xác minh.
        </p>
        {supplierType !== 'DOANH_NGHIEP' && (
          <p className="muted-note">
            Số định danh cá nhân gồm 12 số. Mã số thuế 10/13 số vẫn có thể nhập theo hồ sơ thuộc
            trường hợp sử dụng mã do cơ quan thuế cấp.
          </p>
        )}
        <a
          className="tax-lookup-link"
          href="https://tracuunnt.gdt.gov.vn/tcnnt/mstdn.jsp"
          target="_blank"
          rel="noopener noreferrer"
        >
          Tra cứu trên Cổng thông tin người nộp thuế ↗
        </a>
        <div>
          <Button
            type="button"
            variant="outline"
            disabled={checkingTax}
            onClick={async () => {
              setCheckingTax(true);
              try {
                setTaxCheck(
                  await supplierService.checkTax({
                    supplierId: item?.id,
                    supplierType: watch('supplierType'),
                    taxCode: watch('taxCode'),
                  }),
                );
              } catch (error) {
                setTaxCheck({ duplicate: true, message: error.message });
              } finally {
                setCheckingTax(false);
              }
            }}
          >
            {checkingTax ? 'Đang kiểm tra…' : 'Kiểm tra định dạng và trùng mã'}
          </Button>
          {taxCheck && (
            <p className={taxCheck.duplicate ? 'form-error' : 'muted-note'} role="status">
              {taxCheck.message}
            </p>
          )}
        </div>
        <p className="muted-note">
          Đối chiếu tên, mã số và địa chỉ với hồ sơ. Hệ thống kiểm tra định dạng và trùng mã khi
          lưu; kết quả đó chưa xác minh danh tính pháp lý.
        </p>
        <Field label="Trạng thái xác minh" error={errors.verificationStatus}>
          <select
            {...register('verificationStatus', {
              onChange: () => setValue('verificationConfirmed', false),
            })}
          >
            {Object.entries(verificationLabels).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </Field>
        {verification === 'DA_XAC_MINH' && (
          <Field label="Xác nhận đối chiếu" error={errors.verificationConfirmed}>
            <label className="verification-confirm">
              <input type="checkbox" {...register('verificationConfirmed')} />
              <span>Tôi đã đối chiếu hồ sơ và thông tin trên cổng tra cứu.</span>
            </label>
          </Field>
        )}
        <Field label="Ghi chú xác minh" error={errors.verificationNotes}>
          <textarea
            rows={2}
            {...register('verificationNotes')}
            placeholder="Nguồn hồ sơ, kết quả đối chiếu hoặc nội dung cần kiểm tra lại…"
          />
        </Field>
        {item?.thoi_diem_xac_minh && (
          <p className="muted-note">Lần xác minh được ghi nhận: {date(item.thoi_diem_xac_minh)}</p>
        )}
      </section>
      <fieldset className="promotion-targets">
        <legend>Sản phẩm được cung cấp</legend>
        <div className="target-toolbar">
          <input
            aria-label="Tìm sản phẩm cung cấp"
            placeholder="Tìm tên sản phẩm, thương hiệu…"
            value={productSearch}
            onChange={(e) => setProductSearch(e.target.value)}
          />
          <span>Đã chọn {productIds.length} sản phẩm</span>
        </div>
        <p className="muted-note">
          Chỉ các sản phẩm được chọn mới có thể lập đơn đặt hàng từ nhà cung cấp này. Bỏ chọn không
          xóa lịch sử nhập hàng.
        </p>
        <QueryState query={products}>
          <div className="promotion-target-grid">
            {products.data
              ?.filter((p) => normalize(`${p.name} ${p.brand}`).includes(normalize(productSearch)))
              .map((p) => (
                <label
                  key={p.id}
                  className={`promotion-target ${productIds.includes(String(p.id)) ? 'is-selected' : ''}`}
                >
                  <input type="checkbox" value={String(p.id)} {...register('productIds')} />
                  <span>
                    {p.name}
                    <small className="muted-note"> · {p.brand}</small>
                  </span>
                </label>
              ))}
          </div>
        </QueryState>
        {!productIds.length && (
          <p className="muted-note">Chưa chọn sản phẩm: NCC này chưa thể lập đơn đặt hàng mới.</p>
        )}
      </fieldset>
      <Field label="Trạng thái hợp tác" error={errors.status}>
        <select {...register('status')}>
          <option value="HOP_TAC">Đang hợp tác</option>
          <option value="NGUNG_HOP_TAC">Ngừng hợp tác</option>
        </select>
      </Field>
      <FormActions pending={action.isPending} onClose={onClose} label="Lưu nhà cung cấp" />
    </form>
  );
}
function PromotionForm({ item, onClose }) {
  const categories = useAdmin('categories');
  const brands = useQuery({ queryKey: ['admin', 'brands'], queryFn: promotionService.brands });
  const {
    register,
    control,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(promotionSchema),
    defaultValues: {
      code: item?.ma_code || '',
      fullName: item?.ten || '',
      description: item?.mo_ta || '',
      discountType: item?.loai_giam || 'PERCENT',
      value: item?.gia_tri_giam ?? 10,
      maxDiscount: item?.giam_toi_da ?? '',
      minimumOrder: item?.don_toi_thieu ?? 0,
      startsAt: localDateTime(item?.bat_dau || new Date()),
      endsAt: localDateTime(item?.ket_thuc || Date.now() + 7 * 86400000),
      totalLimit: item?.gioi_han_su_dung ?? '',
      customerLimit: item?.gioi_han_moi_khach ?? '',
      scope: item?.pham_vi_ap_dung === 'BRAND' ? 'BRAND' : 'CATEGORY',
      scopeIds: ['CATEGORY', 'BRAND'].includes(item?.pham_vi_ap_dung)
        ? (item?.scope_ids || []).map(String)
        : [],
      status: item?.trang_thai || 'ACTIVE',
    },
  });
  const [scopeSearch, setScopeSearch] = useState('');
  const scope = watch('scope');
  const selectedIds = watch('scopeIds');
  const percent = watch('discountType') === 'PERCENT';
  const optionsQuery = scope === 'CATEGORY' ? categories : brands;
  const options =
    scope === 'BRAND'
      ? (brands.data || []).map((b) => ({ id: b.id, name: b.ten }))
      : optionsQuery.data || [];
  const visibleOptions = options.filter((o) => normalize(o.name).includes(normalize(scopeSearch)));
  const action = useAction((v) => promotionService.save(item?.id, v), 'Đã lưu mã khuyến mãi');
  const submit = async (v) => {
    try {
      await action.mutateAsync(v);
      onClose();
    } catch {
      /* Toast is handled by useAction. */
    }
  };
  return (
    <form className="form-stack" noValidate onSubmit={handleSubmit(submit)}>
      <div className="form-grid">
        <Field label="Mã khuyến mãi" error={errors.code}>
          <input {...register('code')} placeholder="VD: WATERBUS10" />
        </Field>
        <Field label="Tên chương trình" error={errors.fullName}>
          <input {...register('fullName')} />
        </Field>
        <Field label="Loại giảm giá" error={errors.discountType}>
          <select {...register('discountType')}>
            <option value="PERCENT">Phần trăm (%)</option>
            <option value="FIXED">Số tiền (đ)</option>
          </select>
        </Field>
        <Controller
          name="value"
          control={control}
          render={({ field }) => (
            <Field label={percent ? 'Mức giảm (%)' : 'Mức giảm (đ)'} error={errors.value}>
              {percent ? (
                <input type="number" step="0.01" min="0.01" max="100" {...field} />
              ) : (
                <MoneyInput data-field-control {...field} />
              )}
            </Field>
          )}
        />
        <Controller
          name="maxDiscount"
          control={control}
          render={({ field }) => (
            <Field label="Giảm tối đa (đ, để trống nếu không giới hạn)" error={errors.maxDiscount}>
              <MoneyInput data-field-control {...field} />
            </Field>
          )}
        />
        <Controller
          name="minimumOrder"
          control={control}
          render={({ field }) => (
            <Field label="Giá trị đơn tối thiểu (đ)" error={errors.minimumOrder}>
              <MoneyInput data-field-control {...field} />
            </Field>
          )}
        />
        <Field label="Bắt đầu" error={errors.startsAt}>
          <input type="datetime-local" step="1" {...register('startsAt')} />
        </Field>
        <Field label="Kết thúc" error={errors.endsAt}>
          <input type="datetime-local" step="1" {...register('endsAt')} />
        </Field>
        <Field label="Tổng lượt dùng tối đa" error={errors.totalLimit}>
          <input type="number" min="0" step="1" {...register('totalLimit')} />
        </Field>
        <Field label="Lượt tối đa mỗi khách" error={errors.customerLimit}>
          <input type="number" min="0" step="1" {...register('customerLimit')} />
        </Field>
      </div>
      <p className="muted-note">
        Để trống giới hạn lượt dùng nếu không giới hạn. Nhập 0 để không cho sử dụng mã.
      </p>
      <Field label="Phạm vi áp dụng" error={errors.scope}>
        <select
          {...register('scope', {
            onChange: () => {
              setValue('scopeIds', []);
              setScopeSearch('');
            },
          })}
        >
          {Object.entries(scopeLabels).map(([key, label]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
      </Field>
      {item && !['CATEGORY', 'BRAND'].includes(item.pham_vi_ap_dung) && (
        <p className="muted-note">
          Mã này dùng phạm vi cũ. Chọn loại sản phẩm hoặc thương hiệu trước khi lưu chỉnh sửa.
        </p>
      )}
      <fieldset className="promotion-targets">
        <legend>Chọn đối tượng áp dụng</legend>
        <div className="target-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              aria-label="Tìm đối tượng áp dụng"
              placeholder={scope === 'CATEGORY' ? 'Tìm loại sản phẩm…' : 'Tìm thương hiệu…'}
              value={scopeSearch}
              onChange={(e) => setScopeSearch(e.target.value)}
            />
          </div>
          <span className="target-count">Đã chọn {selectedIds.length}</span>
        </div>
        <div className="target-actions">
          <button
            type="button"
            onClick={() =>
              setValue(
                'scopeIds',
                [...new Set([...selectedIds, ...visibleOptions.map((o) => String(o.id))])],
                { shouldValidate: true },
              )
            }
          >
            Chọn tất cả kết quả
          </button>
          <button
            type="button"
            disabled={!selectedIds.length}
            onClick={() => setValue('scopeIds', [], { shouldValidate: true })}
          >
            Bỏ chọn tất cả
          </button>
        </div>
        {optionsQuery.isPending ? (
          <Loading />
        ) : optionsQuery.isError ? (
          <ErrorState error={optionsQuery.error} retry={optionsQuery.refetch} />
        ) : (
          <div className="promotion-target-grid">
            {visibleOptions.length ? (
              visibleOptions.map((o) => (
                <label
                  className={`promotion-target ${selectedIds.includes(String(o.id)) ? 'is-selected' : ''}`}
                  key={o.id}
                >
                  <input type="checkbox" value={String(o.id)} {...register('scopeIds')} />
                  <span>{o.name}</span>
                </label>
              ))
            ) : (
              <p className="muted-note">Không có kết quả phù hợp.</p>
            )}
          </div>
        )}
        {errors.scopeIds && (
          <p className="form-error" role="alert">
            {errors.scopeIds.message}
          </p>
        )}
      </fieldset>
      <Field label="Trạng thái mã" error={errors.status}>
        <select {...register('status')}>
          <option value="ACTIVE">Cho phép áp dụng</option>
          <option value="INACTIVE">Ngừng áp dụng</option>
        </select>
      </Field>
      <Field label="Mô tả" error={errors.description}>
        <textarea rows={3} {...register('description')} />
      </Field>
      {item && (
        <p className="muted-note">
          Đổi điều kiện có thể ảnh hưởng các đơn sử dụng mã chưa được cửa hàng xác nhận.
        </p>
      )}
      <FormActions
        pending={action.isPending || !optionsQuery.isSuccess}
        onClose={onClose}
        label="Lưu mã khuyến mãi"
      />
    </form>
  );
}
function promotionState(row) {
  if (row.trang_thai !== 'ACTIVE') return 'Ngừng áp dụng';
  if (new Date(row.bat_dau) > new Date()) return 'Chưa bắt đầu';
  if (new Date(row.ket_thuc) < new Date()) return 'Đã hết hạn';
  if (row.gioi_han_su_dung != null && row.luot_da_dung >= row.gioi_han_su_dung)
    return 'Hết lượt dùng';
  return 'Đang áp dụng';
}
function BusinessPage({ supplier }) {
  const key = supplier ? 'suppliers' : 'promotions';
  const service = supplier ? supplierService : promotionService;
  const query = useQuery({ queryKey: ['admin', key], queryFn: service.list });
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [edit, setEdit] = useState(undefined);
  const [pending, setPending] = useState(null);
  const action = useAction((v) => service.status(v.row.id, v.next), 'Đã cập nhật trạng thái');
  const activeCode = supplier ? 'HOP_TAC' : 'ACTIVE';
  const rows = (query.data || []).filter(
    (r) =>
      normalize(
        [r.ten, r.ma_code, r.email, r.ma_so_thue, r.dien_thoai].filter(Boolean).join(' '),
      ).includes(normalize(q)) &&
      (status === 'all' || (r.trang_thai === activeCode) === (status === 'active')),
  );
  const current = Math.min(page, Math.ceil(rows.length / 7) || 1);
  const close = () => {
    setEdit(undefined);
    setPage(1);
  };
  const toggle = (row) =>
    setPending({
      row,
      next: row.trang_thai === activeCode ? (supplier ? 'NGUNG_HOP_TAC' : 'INACTIVE') : activeCode,
    });
  const title = supplier ? 'Quản lý nhà cung cấp' : 'Quản lý mã khuyến mãi';
  const Icon = supplier ? Building2 : BadgePercent;
  return (
    <>
      <PageHeading
        title={title}
        description={
          supplier
            ? 'Quản lý thông tin liên hệ và trạng thái hợp tác để chọn khi lập đơn đặt hàng.'
            : 'Thiết lập điều kiện, thời gian và phạm vi cho mã giảm giá của khách hàng.'
        }
        action={
          <Button onClick={() => setEdit(null)}>
            <Plus size={17} />
            {supplier ? 'Thêm nhà cung cấp' : 'Thêm mã khuyến mãi'}
          </Button>
        }
      />
      <div className="data-panel">
        <div className="data-toolbar">
          <div className="inline-search">
            <Search size={17} />
            <input
              aria-label={supplier ? 'Tìm nhà cung cấp' : 'Tìm mã khuyến mãi'}
              placeholder={
                supplier ? 'Tìm tên, điện thoại, mã số thuế…' : 'Tìm mã hoặc tên chương trình…'
              }
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <select
            aria-label="Lọc trạng thái"
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="active">{supplier ? 'Đang hợp tác' : 'Cho phép áp dụng'}</option>
            <option value="inactive">{supplier ? 'Ngừng hợp tác' : 'Ngừng áp dụng'}</option>
          </select>
        </div>
        <QueryState query={query}>
          {rows.length ? (
            <>
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      {(supplier
                        ? ['Nhà cung cấp', 'Liên hệ', 'Địa chỉ', 'Xác minh / Hợp tác', 'Thao tác']
                        : [
                            'Mã khuyến mãi',
                            'Mức giảm',
                            'Thời gian',
                            'Phạm vi / Lượt dùng',
                            'Trạng thái',
                            'Thao tác',
                          ]
                      ).map((c) => (
                        <th key={c}>{c}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {rows.slice((current - 1) * 7, current * 7).map((row) => (
                      <tr key={row.id}>
                        {supplier ? (
                          <>
                            <td>
                              <strong>{row.ten}</strong>
                              <small>
                                {supplierTypes[row.loai_nha_cung_cap] || 'Doanh nghiệp'}
                              </small>
                              <small>
                                {row.ma_so_thue ? `MST: ${row.ma_so_thue}` : 'Chưa có mã số thuế'}
                              </small>
                            </td>
                            <td>
                              {row.nguoi_lien_he || '—'}
                              <small>{row.dien_thoai || '—'}</small>
                              <small>{row.email || '—'}</small>
                            </td>
                            <td>{row.dia_chi || '—'}</td>
                            <td>
                              <span
                                className={`verification-badge verification-${row.trang_thai_xac_minh || 'CHUA_XAC_MINH'}`}
                              >
                                {verificationLabels[row.trang_thai_xac_minh] || 'Chưa xác minh'}
                              </span>
                              <small>
                                {row.trang_thai === 'HOP_TAC' ? 'Đang hợp tác' : 'Ngừng hợp tác'}
                              </small>
                            </td>
                          </>
                        ) : (
                          <>
                            <td>
                              <strong>{row.ma_code || 'Không có mã'}</strong>
                              <small>{row.ten}</small>
                            </td>
                            <td>
                              {row.loai_giam === 'PERCENT'
                                ? `${Number(row.gia_tri_giam)}%`
                                : money(row.gia_tri_giam)}
                              <small>Đơn từ {money(row.don_toi_thieu)}</small>
                              {row.giam_toi_da != null && (
                                <small>Tối đa {money(row.giam_toi_da)}</small>
                              )}
                            </td>
                            <td>
                              {date(row.bat_dau)}
                              <small>đến {date(row.ket_thuc)}</small>
                            </td>
                            <td>
                              {scopeLabels[row.pham_vi_ap_dung] || 'Phạm vi cũ'}
                              <small>
                                {row.luot_da_dung} / {row.gioi_han_su_dung ?? 'không giới hạn'} lượt
                              </small>
                            </td>
                            <td>{promotionState(row)}</td>
                          </>
                        )}
                        <td>
                          <div className="row-actions">
                            <button
                              className="icon-button"
                              aria-label={`Sửa ${supplier ? row.ten : row.ma_code || row.ten}`}
                              onClick={() => setEdit(row)}
                            >
                              <Pencil size={16} />
                            </button>
                            <Button variant="outline" size="sm" onClick={() => toggle(row)}>
                              {row.trang_thai === activeCode
                                ? supplier
                                  ? 'Ngừng hợp tác'
                                  : 'Ngừng áp dụng'
                                : supplier
                                  ? 'Khôi phục hợp tác'
                                  : 'Cho phép áp dụng'}
                            </Button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination page={current} pages={Math.ceil(rows.length / 7)} onChange={setPage} />
            </>
          ) : (
            <EmptyState
              icon={Icon}
              title={supplier ? 'Chưa có nhà cung cấp phù hợp' : 'Chưa có mã khuyến mãi phù hợp'}
              description="Thêm mới hoặc thay đổi bộ lọc để xem dữ liệu."
            />
          )}
        </QueryState>
      </div>
      <Dialog open={edit !== undefined} onOpenChange={(v) => !v && setEdit(undefined)}>
        <DialogContent
          title={
            supplier
              ? edit
                ? 'Chỉnh sửa nhà cung cấp'
                : 'Thêm nhà cung cấp'
              : edit
                ? 'Chỉnh sửa mã khuyến mãi'
                : 'Thêm mã khuyến mãi'
          }
          description="Kiểm tra thông tin trước khi lưu."
        >
          {edit !== undefined &&
            (supplier ? (
              <SupplierForm key={edit?.id || 'new'} item={edit} onClose={close} />
            ) : (
              <PromotionForm key={edit?.id || 'new'} item={edit} onClose={close} />
            ))}
        </DialogContent>
      </Dialog>
      <ConfirmDialog
        open={!!pending}
        onOpenChange={(v) => !v && !action.isPending && setPending(null)}
        title="Xác nhận thay đổi trạng thái?"
        description={
          pending
            ? `${pending.row.ten}. ${supplier ? 'Nhà cung cấp ngừng hợp tác sẽ không được chọn cho đơn đặt hàng mới.' : 'Mã ngừng áp dụng sẽ không dùng được khi đặt hàng hoặc xác nhận đơn.'} Lịch sử hiện có được giữ lại.`
            : ''
        }
        pending={action.isPending}
        onConfirm={async () => {
          try {
            await action.mutateAsync(pending);
            setPending(null);
          } catch {
            setPending(null);
          }
        }}
      />
    </>
  );
}
export function SuppliersPage() {
  return <BusinessPage supplier />;
}
export function PromotionsPage() {
  return <BusinessPage supplier={false} />;
}

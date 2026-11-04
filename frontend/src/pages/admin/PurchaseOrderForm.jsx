import { useState } from 'react';
import { purchasingDate } from '@/utils/purchasing-dates';
import { useQuery } from '@tanstack/react-query';
import { supplierService } from '@/services/business';
import { Link } from 'react-router-dom';
import { Field } from '@/components/common/Shared';
import { MoneyInput } from '@/components/common/MoneyInput';
import { Button } from '@/components/ui/button';

export default function PurchaseOrderForm({ suppliers, products, onSubmit }) {
  const [supplierId, setSupplierId] = useState('');
  const assigned = useQuery({
    queryKey: ['supplier-products', supplierId],
    queryFn: () => supplierService.products(supplierId),
    enabled: !!supplierId,
  });
  const allowed = new Set((assigned.data || []).map(String));
  const availableProducts =
    supplierId && !assigned.isError
      ? (products.data || []).filter((p) => allowed.has(String(p.id)))
      : [];
  const [productId, setProductId] = useState(''),
    [choice, setChoice] = useState(''),
    [factor, setFactor] = useState(''),
    [quantity, setQuantity] = useState('');
  const product = availableProducts.find((p) => String(p.id) === productId);
  const packaging = choice.startsWith('new-') ? choice.slice(4) : null;
  const size = packaging
    ? Number(factor)
    : product?.packages.find((p) => String(p.packageId) === choice)?.size;
  const unitName = packaging === 'LOC' ? 'lốc' : packaging === 'THUNG' ? 'thùng' : 'quy cách';
  return (
    <form
      className="form-stack"
      onSubmit={(e) => {
        e.preventDefault();
        const data = new FormData(e.currentTarget);
        onSubmit({
          supplierId: data.get('supplier'),
          expectedDate: data.get('expectedDate'),
          productId,
          quantity,
          cost: data.get('cost'),
          ...(packaging ? { packaging, unitsPerPackage: Number(factor) } : { packageId: choice }),
        });
      }}
    >
      <Field label="Nhà cung cấp">
        <select
          name="supplier"
          required
          value={supplierId}
          onChange={(e) => {
            setSupplierId(e.target.value);
            setProductId('');
            setChoice('');
            setFactor('');
            setQuantity('');
          }}
        >
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
      {!suppliers.isPending &&
        !suppliers.isError &&
        !suppliers.data?.some((s) => s.trang_thai === 'HOP_TAC') && (
          <p className="muted-note">
            Chưa có nhà cung cấp đang hợp tác.{' '}
            <Link className="text-link" to="/admin/suppliers">
              Đến quản lý nhà cung cấp
            </Link>{' '}
            để thêm hoặc khôi phục hợp tác.
          </p>
        )}
      <Field label="Ngày giao dự kiến">
        <input type="date" name="expectedDate" required min={purchasingDate()} />
      </Field>
      <p className="muted-note">
        Chọn ngày nhà cung cấp dự kiến giao hàng, từ hôm nay trở đi. Ngày nhập thực tế được ghi nhận
        riêng khi nhận hàng.
      </p>
      <Field label="Sản phẩm">
        <select
          value={productId}
          disabled={
            !supplierId ||
            assigned.isPending ||
            assigned.isError ||
            products.isPending ||
            products.isError
          }
          required
          onChange={(e) => {
            setProductId(e.target.value);
            setChoice('');
            setFactor('');
          }}
        >
          <option value="">Chọn sản phẩm</option>
          {availableProducts.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
      </Field>
      {assigned.isError && (
        <p className="form-error">
          Không tải được sản phẩm của NCC: {assigned.error.message}{' '}
          <button type="button" onClick={() => assigned.refetch()}>
            Thử lại
          </button>
        </p>
      )}
      {products.isError && <p className="form-error">{products.error.message}</p>}
      {supplierId &&
        !assigned.isPending &&
        !assigned.isError &&
        !products.isPending &&
        !products.isError &&
        availableProducts.length === 0 && (
          <p className="muted-note">
            NCC chưa được gán sản phẩm.{' '}
            <Link className="text-link" to="/admin/suppliers">
              Chọn sản phẩm trong quản lý nhà cung cấp
            </Link>{' '}
            trước khi lập đơn đặt hàng.
          </p>
        )}
      <Field label="Quy cách">
        <select
          required
          disabled={!product}
          value={choice}
          onChange={(e) => {
            setChoice(e.target.value);
            setFactor(
              e.target.value === 'new-LOC' ? '6' : e.target.value === 'new-THUNG' ? '24' : '',
            );
          }}
        >
          <option value="">Chọn quy cách</option>
          {product?.packages.map((p) => (
            <option key={p.packageId} value={p.packageId}>
              {p.label} · {p.size} đơn vị lẻ
            </option>
          ))}
          <option value="new-LOC">Lốc — khai báo số đơn vị lẻ</option>
          <option value="new-THUNG">Thùng — khai báo số đơn vị lẻ</option>
        </select>
      </Field>
      {packaging && (
        <>
          <Field label={`Số đơn vị lẻ trong 1 ${unitName}`}>
            <input
              type="number"
              min="2"
              max="1000000"
              step="1"
              value={factor}
              required
              onChange={(e) => setFactor(e.target.value)}
            />
          </Field>
          <p className="muted-note">
            Kiểm tra đúng quy cách trên hàng giao. Ví dụ thùng 48 hộp thì nhập 48; số gợi ý có thể
            chỉnh lại. Quy cách nhập mới không tự mở bán trên cửa hàng.
          </p>
        </>
      )}
      <Field label={`Số lượng ${unitName} đặt nhập`}>
        <input
          type="number"
          min="1"
          max="1000000"
          step="1"
          required
          value={quantity}
          onChange={(e) => setQuantity(e.target.value)}
        />
      </Field>
      {!!size && Number(quantity) > 0 && (
        <p className="receiving-summary" role="status">
          {Number(quantity).toLocaleString('vi-VN')} {unitName} ×{' '}
          {Number(size).toLocaleString('vi-VN')} ={' '}
          {(Number(quantity) * Number(size)).toLocaleString('vi-VN')} đơn vị lẻ. Chỉ hàng đạt thực
          nhận mới cộng vào kho.
        </p>
      )}
      <Field label="Giá nhập mỗi quy cách (đ)">
        <MoneyInput
          key={`${supplierId}:${productId}:${choice}`}
          data-field-control
          name="cost"
          required
        />
      </Field>
      <p className="muted-note">
        Giá của nguyên một {unitName}, không phải giá của một đơn vị lẻ. Đơn mới chờ duyệt; chưa
        cộng tồn hoặc công nợ.
      </p>
      <Button type="submit" disabled={!product || !choice || assigned.isFetching}>
        Lập đơn đặt hàng
      </Button>
    </form>
  );
}

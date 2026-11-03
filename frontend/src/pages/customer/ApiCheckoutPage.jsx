import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from '@/contexts/AuthContext';
import { useCart } from '@/contexts/CartContext';
import { cartService, catalogService, orderService } from '@/services/api';
import { useAction } from '@/hooks/useData';
import { phoneSchema } from '@/schemas';
import { Field, PageHeading, EmptyState, ErrorState, Loading } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { OrderSummary } from './CartPage';
import { money, paymentMethodLabels } from '@/utils/format';
const schema = z.object({
  paymentMethod: z.enum(['COD', 'BANK_TRANSFER']),
  addressId: z.string(),
  receiver: z.string().trim().min(1, 'Nhập tên người nhận.').max(150),
  phone: phoneSchema,
  address: z.string().trim().min(1, 'Nhập địa chỉ.').max(1000),
  province: z.string().trim().min(1, 'Nhập tỉnh/thành phố.').max(150),
  ward: z.string().max(150),
  note: z.string().max(2000),
});
export default function ApiCheckoutPage() {
  const { user } = useAuth();
  const cart = useCart();
  const [coupon, setCoupon] = useState('');
  const [confirmation, setConfirmation] = useState(null);
  const [order, setOrder] = useState(null);
  const address = user.addresses?.find((a) => a.mac_dinh) || user.addresses?.[0];
  const {
    register,
    handleSubmit,
    setValue,
    watch,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(schema),
    defaultValues: {
      addressId: address ? String(address.id) : '',
      receiver: address?.ten_nguoi_nhan || user.name,
      phone: address?.so_dien_thoai || user.phone,
      address: address?.dia_chi || '',
      province: address?.tinh_thanh || '',
      ward: address?.phuong_xa || '',
      note: '',
      paymentMethod: 'COD',
    },
  });
  const addressId = watch('addressId');
  const paymentMethod = watch('paymentMethod');
  const options = useQuery({
    queryKey: ['checkout-options'],
    queryFn: catalogService.checkoutOptions,
  });
  const selected = cart.selectedItems;
  const selectionKey = selected
    .map((l) => `${l.packageId}:${l.quantity}`)
    .sort()
    .join(',');
  const quote = useQuery({
    queryKey: ['checkout-quote', user.id, selectionKey, coupon],
    queryFn: () =>
      cartService.quote(
        selected.map((l) => l.packageId),
        coupon,
      ),
    enabled: !order && !cart.loading && selected.length > 0,
    staleTime: 0,
  });
  const promotions = useQuery({ queryKey: ['promotions'], queryFn: catalogService.promotions });
  const action = useAction(
    (values) => orderService.create(user, { ...values, voucherCode: coupon }, selected),
    'Đã tạo đơn hàng',
  );
  const confirm = async () => {
    try {
      const created = await action.mutateAsync(confirmation);
      setOrder(created);
      setConfirmation(null);
      await cart.removePurchased(selected);
    } catch {
      setConfirmation(null);
    }
  };
  if (order)
    return (
      <div className="container success-page">
        <h1>Đặt hàng thành công</h1>
        <p>
          Mã đơn <strong>{order.code}</strong> · {money(order.total)}
        </p>
        <p>{paymentMethodLabels[order.paymentMethod]}</p>
        {order.paymentMethod === 'BANK_TRANSFER' && (
          <p>
            Cửa hàng sẽ liên hệ để cung cấp thông tin chuyển khoản và xác nhận sau khi nhận tiền.
          </p>
        )}
        <Button asChild>
          <Link to={`/account/orders/${order.id}`}>Xem đơn hàng</Link>
        </Button>
      </div>
    );
  if (cart.loading)
    return (
      <div className="container">
        <Loading />
      </div>
    );
  if (!selected.length)
    return (
      <div className="container">
        <EmptyState
          title="Chưa chọn sản phẩm"
          action={
            <Button asChild>
              <Link to="/cart">Về giỏ hàng</Link>
            </Button>
          }
        />
      </div>
    );
  return (
    <div className="container checkout-page">
      <PageHeading
        title="Xác nhận đặt hàng"
        description="Kiểm tra thông tin nhận hàng và số tiền trước khi đặt."
      />
      <form className="cart-layout" noValidate onSubmit={handleSubmit(setConfirmation)}>
        <div className="checkout-form">
          <section className="form-card form-stack">
            <h3>Thông tin nhận hàng</h3>
            {!!user.addresses?.length && (
              <Field label="Địa chỉ đã lưu">
                <select
                  {...register('addressId', {
                    onChange: (e) => {
                      const saved = user.addresses.find((a) => String(a.id) === e.target.value);
                      setValue('receiver', saved?.ten_nguoi_nhan || user.name);
                      setValue('phone', saved?.so_dien_thoai || user.phone);
                      setValue('address', saved?.dia_chi || '');
                      setValue('province', saved?.tinh_thanh || '');
                      setValue('ward', saved?.phuong_xa || '');
                    },
                  })}
                >
                  <option value="">Dùng địa chỉ mới</option>
                  {user.addresses.map((a) => (
                    <option key={a.id} value={a.id}>
                      {[a.dia_chi, a.tinh_thanh].filter(Boolean).join(', ')}
                    </option>
                  ))}
                </select>
              </Field>
            )}
            <Field label="Người nhận" error={errors.receiver}>
              <input {...register('receiver')} readOnly={!!addressId} />
            </Field>
            <Field label="Số điện thoại" error={errors.phone}>
              <input type="tel" {...register('phone')} readOnly={!!addressId} />
            </Field>
            <Field label="Địa chỉ nhận hàng" error={errors.address}>
              <textarea {...register('address')} readOnly={!!addressId} />
            </Field>
            <Field label="Tỉnh/Thành phố" error={errors.province}>
              <input {...register('province')} readOnly={!!addressId} />
            </Field>
            <Field label="Phường/Xã" error={errors.ward}>
              <input {...register('ward')} readOnly={!!addressId} />
            </Field>
            <Field label="Ghi chú" error={errors.note}>
              <textarea {...register('note')} />
            </Field>
          </section>
          <section className="form-card">
            <h3>Phương thức thanh toán</h3>
            {options.isPending ? (
              <Loading />
            ) : options.isError ? (
              <ErrorState error={options.error} retry={options.refetch} />
            ) : (
              <>
                <Field label="Chọn phương thức thanh toán" error={errors.paymentMethod}>
                  <select {...register('paymentMethod')}>
                    {options.data.paymentMethods.map((method) => (
                      <option key={method.code} value={method.code}>
                        {method.label}
                      </option>
                    ))}
                  </select>
                </Field>
                <p>
                  {
                    options.data.paymentMethods.find((method) => method.code === paymentMethod)
                      ?.description
                  }
                </p>
              </>
            )}
          </section>
          <section className="form-card">
            <h3>Mã giảm giá</h3>
            {promotions.isError ? (
              <ErrorState error={promotions.error} retry={promotions.refetch} />
            ) : (
              <select
                aria-label="Mã giảm giá"
                value={coupon}
                onChange={(e) => setCoupon(e.target.value)}
              >
                <option value="">Không sử dụng mã</option>
                {promotions.data
                  ?.filter((p) => p.ma_code)
                  .map((p) => (
                    <option key={p.id} value={p.ma_code}>
                      {p.ma_code} — {p.ten}
                    </option>
                  ))}
              </select>
            )}
            <p className="muted-note">
              Điều kiện áp dụng được kiểm tra khi tính tổng và xác nhận đơn.
            </p>
          </section>
        </div>
        <div>
          {quote.isPending ? (
            <Loading />
          ) : quote.isError ? (
            <>
              <ErrorState error={quote.error} retry={quote.refetch} />
              <Link to="/cart">Kiểm tra lại giỏ hàng</Link>
            </>
          ) : (
            <OrderSummary
              subtotal={quote.data.subtotal}
              shippingFee={quote.data.shippingFee}
              discountAmount={quote.data.discount}
              voucherCode={coupon}
              total={quote.data.total}
            >
              <Button
                className="full-width"
                type="submit"
                disabled={action.isPending || quote.isFetching || !options.isSuccess}
              >
                Đặt hàng
              </Button>
            </OrderSummary>
          )}
        </div>
      </form>
      <ConfirmDialog
        open={!!confirmation}
        onOpenChange={(v) => !v && !action.isPending && setConfirmation(null)}
        title="Xác nhận tạo đơn hàng?"
        description={`Tổng thanh toán ${money(quote.data?.total)}. ${paymentMethodLabels[confirmation?.paymentMethod] || ''}. Đơn hàng sẽ được gửi đến cửa hàng.`}
        onConfirm={confirm}
        pending={action.isPending}
      />
    </div>
  );
}

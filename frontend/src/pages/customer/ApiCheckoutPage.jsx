import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useQuery, useQueryClient } from '@tanstack/react-query';
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
import ApiCheckoutVouchers from '@/components/customer/ApiCheckoutVouchers';
import { provinces } from '@/utils/address';
const schema = z.object({
  paymentMethod: z.enum(['COD', 'MOMO']),
  receiver: z.string().trim().min(1, 'Nhập tên người nhận.').max(150),
  phone: phoneSchema,
  address: z.string().trim().min(1, 'Nhập địa chỉ.').max(1000),
  province: z.string().trim().min(1, 'Nhập tỉnh/thành phố.').max(150),
  ward: z.string().trim().min(1, 'Chọn phường/xã.').max(150),
  note: z.string().max(2000),
});
export default function ApiCheckoutPage() {
  const navigate = useNavigate();
  const [requestKey] = useState(() => {
    const saved = sessionStorage.getItem('waterbus-checkout-key');
    const key = saved || crypto.randomUUID();
    sessionStorage.setItem('waterbus-checkout-key', key);
    return key;
  });
  const { user } = useAuth();
  const cart = useCart();
  const client = useQueryClient();
  const [coupon, setCoupon] = useState('');
  const [confirmation, setConfirmation] = useState(null);
  const [order, setOrder] = useState(null);
  const address = user.addresses?.find((a) => a.mac_dinh) || user.addresses?.[0];
  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(schema),
    defaultValues: {
      receiver: address?.ten_nguoi_nhan || user.name,
      phone: address?.so_dien_thoai || user.phone,
      address: address?.dia_chi || '',
      province: address?.tinh_thanh || '',
      ward: address?.phuong_xa || '',
      note: '',
      paymentMethod: 'COD',
    },
  });
  const paymentMethod = watch('paymentMethod');
  const provinceName = watch('province');
  const wardName = watch('ward');
  const selectedProvince = provinces.find((province) => province.name === provinceName);
  const savedProvinceFallback = provinceName === address?.tinh_thanh && !selectedProvince;
  const savedWardFallback =
    provinceName === address?.tinh_thanh &&
    wardName === address?.phuong_xa &&
    wardName &&
    !selectedProvince?.wards.some((ward) => ward.name === wardName);
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
  const appliedPromotion = promotions.data?.find((promotion) => promotion.ma_code === coupon);
  const discountPercent =
    appliedPromotion?.loai_giam === 'PERCENT' ? Number(appliedPromotion.gia_tri_giam) : undefined;
  const applyCoupon = async (code) => {
    const pricing = await cartService.quote(
      selected.map((line) => line.packageId),
      code,
    );
    client.setQueryData(['checkout-quote', user.id, selectionKey, code], pricing);
    setCoupon(code);
  };
  const action = useAction(
    (values) => orderService.create(user, { ...values, voucherCode: coupon, requestKey }, selected),
    'Đã tạo đơn hàng',
  );
  const confirm = async () => {
    try {
      const created = await action.mutateAsync(confirmation);
      sessionStorage.removeItem('waterbus-checkout-key');
      setOrder(created);
      setConfirmation(null);
      await cart.removePurchased(selected);
      if (created.paymentMethod === 'MOMO') navigate(`/payments/momo/${created.id}`);
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
    <div className="container checkout-page checkout-compact">
      <PageHeading
        title="Xác nhận đặt hàng"
        description="Kiểm tra thông tin nhận hàng và số tiền trước khi đặt."
      />
      <form className="cart-layout" noValidate onSubmit={handleSubmit(setConfirmation)}>
        <div className="checkout-form">
          <section className="form-card checkout-recipient">
            <h3>Thông tin nhận hàng</h3>
            <div className="checkout-recipient-grid">
              <Field label="Người nhận" error={errors.receiver}>
                <input autoComplete="name" {...register('receiver')} />
              </Field>
              <Field label="Số điện thoại" error={errors.phone}>
                <input type="tel" inputMode="numeric" autoComplete="tel" {...register('phone')} />
              </Field>
              <Field className="span-two" label="Địa chỉ nhận hàng" error={errors.address}>
                <textarea rows={2} autoComplete="street-address" {...register('address')} />
              </Field>
              <Field label="Tỉnh/Thành phố" error={errors.province}>
                <select
                  autoComplete="address-level1"
                  {...register('province', {
                    onChange: () =>
                      setValue('ward', '', { shouldDirty: true, shouldValidate: false }),
                  })}
                >
                  <option value="">Chọn tỉnh/thành phố</option>
                  {savedProvinceFallback && <option value={provinceName}>{provinceName}</option>}
                  {provinces.map((province) => (
                    <option key={province.code} value={province.name}>
                      {province.name}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Phường/Xã" error={errors.ward}>
                <select
                  autoComplete="address-level2"
                  disabled={!provinceName}
                  {...register('ward')}
                >
                  <option value="">
                    {provinceName ? 'Chọn phường/xã' : 'Chọn tỉnh/thành phố trước'}
                  </option>
                  {savedWardFallback && <option value={wardName}>{wardName}</option>}
                  {(selectedProvince?.wards || []).map((ward) => (
                    <option key={ward.code} value={ward.name}>
                      {ward.name}
                    </option>
                  ))}
                </select>
              </Field>
              <Field className="span-two" label="Ghi chú" error={errors.note}>
                <textarea rows={2} {...register('note')} />
              </Field>
            </div>
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
                    {options.data.paymentMethods
                      .filter((method) => ['COD', 'MOMO'].includes(method.code))
                      .map((method) => (
                        <option
                          key={method.code}
                          value={method.code}
                          disabled={method.enabled === false}
                        >
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
                {options.data.momoEnabled === false && (
                  <p role="status">
                    MoMo Sandbox chưa sẵn sàng. Cửa hàng cần hoàn tất cấu hình trước khi nhận thanh
                    toán.
                  </p>
                )}
              </>
            )}
          </section>
        </div>
        <div className="checkout-summary-column">
          <ApiCheckoutVouchers
            promotions={promotions}
            items={selected}
            subtotal={quote.data?.subtotal}
            code={coupon}
            discount={quote.data?.discount || 0}
            onApply={applyCoupon}
          />
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
              discountPercent={discountPercent}
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

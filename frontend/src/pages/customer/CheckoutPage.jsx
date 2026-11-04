import { canPurchase } from '@/utils/inventory';
import { requiredStock } from '@/utils/purchase';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { Check, ArrowRight, Banknote, ShieldCheck } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useCart } from '@/contexts/CartContext';
import { useProducts, useAction } from '@/hooks/useData';
import { checkoutSchema } from '@/schemas';
import { orderService } from '@/services';
import { Field, Breadcrumb, PageHeading, EmptyState, QueryState } from '@/components/common/Shared';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { OrderSummary } from './CartPage';
import { lineKey, purchaseUnit } from '@/utils/purchase';
import { money } from '@/utils/format';
import CheckoutVouchers from '@/components/customer/CheckoutVouchers';
import { vouchers } from '@/data/vouchers';
import { evaluateVoucher, calculateOrderPricing } from '@/utils/vouchers';
import { isMock } from '@/services';
import ApiCheckoutPage from './ApiCheckoutPage';
export default function CheckoutPage() {
  return isMock ? <MockCheckoutPage /> : <ApiCheckoutPage />;
}
function MockCheckoutPage() {
  const { user } = useAuth();
  const cart = useCart();
  const products = useProducts();
  const selected = cart.selectedItems;
  const [confirmation, setConfirmation] = useState(null);
  const [order, setOrder] = useState(null);
  const [voucherCode, setVoucherCode] = useState('');
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(checkoutSchema),
    defaultValues: {
      receiver: user.name,
      phone: user.phone,
      address: user.address,
      note: '',
      paymentMethod: 'COD',
    },
  });
  const action = useAction(
    (values) => orderService.create(user, values, selected),
    'Đã tạo đơn hàng',
  );
  const voucherItems = selected.map((line) => {
    const product = products.data?.find((item) => item.id === line.productId);
    return {
      productId: line.productId,
      lineTotal: product ? purchaseUnit(product, line.unit).price * line.quantity : 0,
    };
  });
  const subtotal = voucherItems.reduce((sum, item) => sum + item.lineTotal, 0);
  const stockRequired =
    products.data &&
    selected.every((line) => products.data.some((product) => product.id === line.productId))
      ? requiredStock(selected, products.data)
      : {};
  const unavailable = selected.some((line) => {
    const product = products.data?.find((product) => product.id === line.productId);
    return !canPurchase(product) || stockRequired[line.productId] > product.stock;
  });
  const selectedVoucher = vouchers.find((voucher) => voucher.code === voucherCode);
  const appliedVoucherCode =
    selectedVoucher && evaluateVoucher(selectedVoucher, subtotal, voucherItems).eligible
      ? voucherCode
      : '';
  const pricing = calculateOrderPricing(subtotal, appliedVoucherCode, voucherItems);
  const confirmationPricing = confirmation ? pricing : null;
  const confirm = async () => {
    try {
      const created = await action.mutateAsync(confirmation);
      setOrder(created);
      cart.removePurchased(selected);
      setConfirmation(null);
    } catch {
      setConfirmation(null);
    }
  };
  if (order)
    return (
      <div className="container success-page">
        <div className="success-check">
          <Check size={38} />
        </div>
        <span className="eyebrow">ĐƠN HÀNG MÔ PHỎNG</span>
        <h1>Đã lưu đơn của bạn.</h1>
        <p>
          Mã đơn <strong>{order.id}</strong> · {money(order.total)}
        </p>
        <div className="success-actions">
          <Button asChild>
            <Link to={'/account/orders/' + order.id}>
              Xem đơn <ArrowRight size={16} />
            </Link>
          </Button>
          <Button asChild variant="outline">
            <Link to="/products">Tiếp tục khám phá</Link>
          </Button>
        </div>
      </div>
    );
  return (
    <div className="container checkout-page">
      <Breadcrumb items={[{ label: 'Giỏ hàng', to: '/cart' }, { label: 'Đặt hàng' }]} />
      <PageHeading
        title="Thêm một bước, thêm tươi mát"
        description="Kiểm tra thông tin và tạo đơn hàng."
      />

      <QueryState query={products}>
        {!selected.length ? (
          <EmptyState
            title="Chưa chọn sản phẩm để đặt hàng"
            action={
              <Button asChild>
                <Link to="/cart">Chọn sản phẩm trong giỏ</Link>
              </Button>
            }
          />
        ) : (
          <form
            onSubmit={handleSubmit((values) =>
              setConfirmation({ ...values, voucherCode: appliedVoucherCode }),
            )}
            noValidate
            className="cart-layout"
          >
            <div className="checkout-form">
              <section className="form-card">
                <h3>
                  <span>01</span>Thông tin nhận hàng
                </h3>
                <div className="form-grid">
                  <Field label="Họ tên người nhận" error={errors.receiver}>
                    <input
                      autoComplete="name"
                      {...register('receiver')}
                      placeholder="Nhập họ tên"
                    />
                  </Field>
                  <Field label="Số điện thoại" error={errors.phone}>
                    <input
                      type="tel"
                      inputMode="numeric"
                      autoComplete="tel"
                      autoComplete="tel"
                      {...register('phone')}
                      placeholder="0901234567"
                    />
                  </Field>
                  <Field className="span-two" label="Địa chỉ giao hàng" error={errors.address}>
                    <textarea
                      autoComplete="street-address"
                      {...register('address')}
                      placeholder="Số nhà, đường, phường/xã, tỉnh/thành phố"
                      rows={2}
                    />
                  </Field>
                  <Field className="span-two" label="Ghi chú (không bắt buộc)" error={errors.note}>
                    <textarea {...register('note')} placeholder="Thêm ghi chú cho đơn" rows={2} />
                  </Field>
                </div>
              </section>
              <section className="form-card">
                <h3>
                  <span>02</span>Phương thức thanh toán
                </h3>
                <label className="payment-option">
                  <input type="radio" value="COD" {...register('paymentMethod')} />
                  <Banknote size={25} />
                  <span>
                    <strong>Thanh toán khi nhận hàng</strong>
                    <small>Không thu tiền, không tích hợp cổng thanh toán.</small>
                  </span>
                </label>
              </section>
              <section className="form-card">
                <h3>
                  <span>03</span>Sản phẩm đã chọn
                </h3>
                {selected.map((line) => (
                  <div className="checkout-line" key={lineKey(line)}>
                    <span>
                      {products.data?.find((p) => p.id === line.productId)?.name ||
                        'Sản phẩm không còn khả dụng'}{' '}
                      <small>
                        × {line.quantity}{' '}
                        {purchaseUnit(
                          products.data?.find((p) => p.id === line.productId) || {},
                          line.unit,
                        ).label.toLowerCase()}
                      </small>
                    </span>
                    <strong>
                      {money(
                        purchaseUnit(
                          products.data?.find((p) => p.id === line.productId) || {},
                          line.unit,
                        ).price * line.quantity,
                      )}
                    </strong>
                  </div>
                ))}
              </section>
              <CheckoutVouchers
                subtotal={subtotal}
                items={voucherItems}
                selectedCode={appliedVoucherCode}
                onChange={setVoucherCode}
              />
              {voucherCode && !appliedVoucherCode && (
                <p className="form-error" role="status">
                  Voucher đã chọn không còn đủ điều kiện và đã được bỏ khỏi đơn hàng. Vui lòng chọn
                  voucher khác.
                </p>
              )}
            </div>
            <OrderSummary
              subtotal={subtotal}
              discountAmount={pricing.discountAmount}
              shippingDiscountAmount={pricing.shippingDiscountAmount}
              voucherCode={pricing.voucherCode}
            >
              {unavailable && (
                <p className="form-error" role="alert">
                  Có sản phẩm tạm hết hàng hoặc không đủ tồn kho. Vui lòng quay lại giỏ hàng để điều
                  chỉnh.
                </p>
              )}
              <Button
                type="submit"
                className="full-width"
                disabled={action.isPending || unavailable}
              >
                Tạo đơn hàng <ArrowRight size={17} />
              </Button>
              <span className="summary-trust">
                <ShieldCheck size={16} />
                Không có giao dịch thực tế
              </span>
            </OrderSummary>
          </form>
        )}
      </QueryState>
      <ConfirmDialog
        open={!!confirmation}
        onOpenChange={(v) => !v && !action.isPending && setConfirmation(null)}
        title="Xác nhận tạo đơn hàng?"
        description="Vui lòng kiểm tra sản phẩm, địa chỉ nhận hàng và tổng tiền trước khi xác nhận."
        onConfirm={confirm}
        pending={action.isPending}
      >
        {confirmationPricing && (
          <div className="confirmation-pricing">
            {confirmationPricing.voucherCode && (
              <p>
                Voucher: <strong>{confirmationPricing.voucherCode}</strong> · Giảm{' '}
                {money(
                  confirmationPricing.discountAmount + confirmationPricing.shippingDiscountAmount,
                )}
              </p>
            )}
            <p>
              Tổng thanh toán: <strong>{money(confirmationPricing.total)}</strong>
            </p>
          </div>
        )}
      </ConfirmDialog>
    </div>
  );
}

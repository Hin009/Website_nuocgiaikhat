import { canPurchase } from '@/utils/inventory';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, ArrowRight, Trash2, ShoppingBag, Truck } from 'lucide-react';
import { useCart } from '@/contexts/CartContext';
import { useProducts } from '@/hooks/useData';
import {
  Breadcrumb,
  PageHeading,
  QueryState,
  EmptyState,
  Quantity,
} from '@/components/common/Shared';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { lineKey, purchaseUnit, maxLineQuantity, requiredStock } from '@/utils/purchase';
import { money } from '@/utils/format';
import { calculateOrderPricing } from '@/utils/vouchers';
export function OrderSummary({
  subtotal,
  discountAmount = 0,
  shippingDiscountAmount = 0,
  voucherCode = '',
  children,
}) {
  const { shippingFee: shipping } = calculateOrderPricing(subtotal);
  return (
    <aside className="order-summary">
      <h3>Tóm tắt đơn hàng</h3>
      <div>
        <span>Tạm tính</span>
        <strong>{money(subtotal)}</strong>
      </div>
      <div>
        <span>Phí giao hàng</span>
        <strong>{!subtotal ? money(0) : shipping ? money(shipping) : 'iiễn phí'}</strong>
      </div>
      {discountAmount > 0 && (
        <div className="summary-discount">
          <span>Giảm giá ({voucherCode})</span>
          <strong>-{money(discountAmount)}</strong>
        </div>
      )}
      {shippingDiscountAmount > 0 && (
        <div className="summary-shipping-discount">
          <span>Giảm phí giao hàng ({voucherCode})</span>
          <strong>-{money(shippingDiscountAmount)}</strong>
        </div>
      )}
      <div className="summary-total">
        <span>Tổng cộng</span>
        <strong>{money(subtotal + shipping - discountAmount - shippingDiscountAmount)}</strong>
      </div>
      {children}
      <span className="summary-trust">
        <Truck size={17} />
        Dùng FREESHIP200 để miễn phí giao từ 200.000đ
      </span>
    </aside>
  );
}
export default function CartPage() {
  const cart = useCart();
  const products = useProducts();
  const [removeId, setRemoveId] = useState(null);
  const lines = cart.items.map((item) => ({
    ...item,
    product: products.data?.find((p) => p.id === item.productId),
  }));
  const selected = lines.filter((l) => l.selected);
  const subtotal = selected.reduce(
    (s, l) => s + (l.product ? purchaseUnit(l.product, l.unit).price * l.quantity : 0),
    0,
  );
  const stock =
    products.data && selected.every((l) => l.product) ? requiredStock(selected, products.data) : {};
  const invalid = selected.some(
    (l) => !canPurchase(l.product) || stock[l.productId] > l.product.stock,
  );
  const allSelected = lines.length > 0 && selected.length === lines.length;
  return (
    <div className="container cart-page">
      <Breadcrumb items={[{ label: 'Giỏ hàng' }]} />
      <PageHeading
        title="Giỏ hàng của bạn"
        description={cart.count + ' sản phẩm, sẵn sàng cho ngày tươi mới.'}
      />

      <QueryState query={products}>
        {!cart.items.length ? (
          <EmptyState
            icon={ShoppingBag}
            title="Giỏ hàng đang chờ chút tươi mát"
            description="Thêm những thức uống yêu thích và quay lại đây nhé."
            action={
              <Button asChild>
                <Link to="/products">
                  Khám phá đồ uống <ArrowRight size={17} />
                </Link>
              </Button>
            }
          />
        ) : (
          <div className="cart-layout">
            <div>
              <label className="cart-select-all">
                <input
                  type="checkbox"
                  checked={allSelected}
                  ref={(node) => {
                    if (node) node.indeterminate = selected.length > 0 && !allSelected;
                  }}
                  onChange={(e) => cart.selectAll(e.target.checked)}
                />
                Chọn tất cả ({selected.length}/{lines.length})
              </label>
              <div className="cart-items">
                {lines.map((line) => (
                  <div
                    className={'cart-item' + (!canPurchase(line.product) ? ' is-unavailable' : '')}
                    key={lineKey(line)}
                  >
                    <input
                      className="cart-select"
                      type="checkbox"
                      aria-label={
                        'Chọn ' +
                        (line.product?.name || 'sản phẩm') +
                        ' - ' +
                        (line.product ? purchaseUnit(line.product, line.unit).label : '')
                      }
                      checked={line.selected}
                      onChange={(e) => cart.select(lineKey(line), e.target.checked)}
                    />
                    {line.product ? (
                      <>
                        <Link
                          to={'/products/' + line.productId}
                          className="cart-art"
                          style={{ background: line.product.accent }}
                        >
                          <DrinkArt product={line.product} />
                        </Link>
                        <div className="cart-item-name">
                          <small>{line.product.brand}</small>
                          <Link to={'/products/' + line.productId}>{line.product.name}</Link>
                          <span>
                            {line.product.volume} · {purchaseUnit(line.product, line.unit).label}
                            {purchaseUnit(line.product, line.unit).size > 1
                              ? ' ' + purchaseUnit(line.product, line.unit).size + ' sản phẩm'
                              : ''}
                          </span>
                          <strong>{money(purchaseUnit(line.product, line.unit).price)}</strong>
                          {!canPurchase(line.product) && (
                            <small className="form-error">
                              Tạm hết hàng — vui lòng bỏ chọn sản phẩm này.
                            </small>
                          )}
                          {line.quantity > maxLineQuantity(line.product, cart.items, line) && (
                            <small className="form-error">
                              Tồn kho chỉ còn {line.product.stock} sản phẩm.
                            </small>
                          )}
                        </div>
                        <Quantity
                          value={line.quantity}
                          max={maxLineQuantity(line.product, cart.items, line)}
                          onChange={(v) =>
                            cart.update(
                              lineKey(line),
                              v,
                              maxLineQuantity(line.product, cart.items, line),
                            )
                          }
                        />
                        <strong className="cart-line-total">
                          {money(purchaseUnit(line.product, line.unit).price * line.quantity)}
                        </strong>
                      </>
                    ) : (
                      <p>Sản phẩm này không còn kinh doanh.</p>
                    )}
                    <button
                      className="icon-button"
                      aria-label={'Xóa ' + (line.product?.name || 'sản phẩm')}
                      onClick={() => setRemoveId(lineKey(line))}
                    >
                      <Trash2 size={17} />
                    </button>
                  </div>
                ))}
              </div>
              <Link className="text-link continue-link" to="/products">
                <ArrowLeft size={17} />
                Tiếp tục mua sắm
              </Link>
            </div>
            <OrderSummary subtotal={subtotal}>
              {!selected.length ? (
                <Button disabled className="full-width">
                  Chọn sản phẩm để đặt hàng
                </Button>
              ) : invalid ? (
                <p className="form-error">
                  Hãy bỏ chọn sản phẩm tạm hết hàng hoặc điều chỉnh số lượng trước khi thanh toán.
                </p>
              ) : (
                <Button asChild className="full-width">
                  <Link to="/checkout">
                    Tiến hành đặt đơn <ArrowRight size={17} />
                  </Link>
                </Button>
              )}
            </OrderSummary>
          </div>
        )}
      </QueryState>
      <ConfirmDialog
        open={!!removeId}
        onOpenChange={(v) => !v && setRemoveId(null)}
        title="Xóa sản phẩm khỏi giỏ?"
        description="Bạn có thể thêm lại sản phẩm bất cứ lúc nào."
        onConfirm={() => {
          cart.remove(removeId);
          setRemoveId(null);
        }}
      />
    </div>
  );
}

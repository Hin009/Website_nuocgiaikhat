import { useState } from 'react';
import { TicketPercent, Check } from 'lucide-react';
import { Dialog, DialogContent, DialogTrigger } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { ErrorState, Loading } from '@/components/common/Shared';
import { money } from '@/utils/format';
import { promotionExpiry, promotionUnavailableReason } from '@/utils/checkout-promotions';

const benefit = (promotion) =>
  promotion.loai_giam === 'PERCENT'
    ? `Giảm ${Number(promotion.gia_tri_giam)}%`
    : `Giảm ${money(promotion.gia_tri_giam)}`;

export default function ApiCheckoutVouchers({
  promotions,
  items,
  subtotal,
  code,
  discount,
  onApply,
}) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState('');
  const [input, setInput] = useState('');
  const [error, setError] = useState('');
  const [pending, setPending] = useState(false);
  const available = (promotions.data || []).filter((promotion) => promotion.ma_code);
  const applied = available.find((promotion) => promotion.ma_code === code);
  const changeOpen = (next) => {
    if (pending) return;
    if (next) {
      setDraft(code);
      setInput('');
      setError('');
    }
    setOpen(next);
  };
  const apply = async (nextCode) => {
    setPending(true);
    setError('');
    const trimmed = nextCode.trim();
    const known = available.find(
      (promotion) => promotion.ma_code.toLowerCase() === trimmed.toLowerCase(),
    );
    try {
      const reason = known && promotionUnavailableReason(known, items, subtotal);
      if (reason) throw new Error(reason);
      await onApply(known?.ma_code || trimmed);
      setOpen(false);
    } catch (failure) {
      setError(failure.message || 'Không thể áp dụng mã. Vui lòng thử lại.');
    } finally {
      setPending(false);
    }
  };
  return (
    <section className="checkout-coupon" aria-label="Mã giảm giá">
      <div className="checkout-coupon-heading">
        <TicketPercent size={22} aria-hidden="true" />
        <h3>Mã giảm giá</h3>
      </div>
      {code ? (
        <div className="checkout-coupon-applied" role="status">
          <span className="checkout-coupon-code">
            <Check size={15} />
            {code}
          </span>
          <strong>
            {applied ? benefit(applied) : 'Đã áp dụng'} · -{money(discount)}
          </strong>
        </div>
      ) : (
        <p className="muted-note">Chọn ưu đãi cho đơn hàng của bạn</p>
      )}
      <Dialog open={open} onOpenChange={changeOpen}>
        <DialogTrigger asChild>
          <Button type="button" variant="outline" className="full-width">
            {code ? 'Chọn voucher khác' : 'Chọn hoặc nhập mã giảm giá'}
          </Button>
        </DialogTrigger>
        <DialogContent
          title="Chọn mã giảm giá"
          description="Chọn một voucher hoặc nhập mã để áp dụng cho đơn hàng."
          className="checkout-voucher-dialog"
        >
          <div className="checkout-voucher-entry">
            <label htmlFor="checkout-voucher-code" className="sr-only">
              Nhập mã giảm giá
            </label>
            <input
              id="checkout-voucher-code"
              placeholder="Nhập mã giảm giá"
              value={input}
              disabled={pending}
              onChange={(event) => {
                setInput(event.target.value);
                setError('');
              }}
              onKeyDown={(event) => {
                if (event.key === 'Enter') {
                  event.preventDefault();
                  if (input.trim() && !pending) apply(input);
                }
              }}
            />
            <Button type="button" disabled={pending || !input.trim()} onClick={() => apply(input)}>
              Áp dụng
            </Button>
          </div>
          {error && (
            <p className="form-error" role="alert">
              {error}
            </p>
          )}
          <div className="checkout-voucher-list">
            <label className="checkout-voucher-none">
              <input
                type="radio"
                name="api-checkout-voucher"
                checked={!draft}
                disabled={pending}
                onChange={() => {
                  setDraft('');
                  setError('');
                }}
              />
              Không sử dụng mã giảm giá
            </label>
            {promotions.isPending ? (
              <Loading />
            ) : promotions.isError ? (
              <ErrorState error={promotions.error} retry={promotions.refetch} />
            ) : !available.length ? (
              <p className="muted-note">Chưa có voucher công khai. Bạn có thể nhập mã ở trên.</p>
            ) : (
              available.map((promotion) => {
                const unavailableReason = promotionUnavailableReason(promotion, items, subtotal);
                const belowMinimum =
                  subtotal != null && Number(subtotal) < Number(promotion.don_toi_thieu || 0);
                return (
                  <label
                    key={promotion.id}
                    className={`checkout-voucher-ticket${draft === promotion.ma_code ? ' is-selected' : ''}${unavailableReason ? ' is-disabled' : ''}`}
                    aria-disabled={!!unavailableReason}
                  >
                    <span className="checkout-voucher-stamp">
                      <TicketPercent size={30} />
                      <strong>
                        {promotion.loai_giam === 'PERCENT'
                          ? `${Number(promotion.gia_tri_giam)}%`
                          : 'ƯU ĐÃI'}
                      </strong>
                    </span>
                    <span className="checkout-voucher-info">
                      <strong>{benefit(promotion)}</strong>
                      <span>{promotion.ten}</span>
                      <b>{promotion.ma_code}</b>
                      <small>
                        Đơn từ {money(promotion.don_toi_thieu || 0)}
                        {promotion.giam_toi_da != null
                          ? ` · Giảm tối đa ${money(promotion.giam_toi_da)}`
                          : ''}
                      </small>
                      {promotion.ket_thuc && (
                        <small className="checkout-voucher-expiry">
                          HSD: {promotionExpiry(promotion.ket_thuc)}
                        </small>
                      )}
                      {unavailableReason && (
                        <small className="form-error">
                          {belowMinimum
                            ? `Mua thêm ${money(Number(promotion.don_toi_thieu) - Number(subtotal))} để sử dụng. `
                            : ''}
                          {unavailableReason}
                        </small>
                      )}
                    </span>
                    <input
                      type="radio"
                      name="api-checkout-voucher"
                      aria-label={`Chọn mã ${promotion.ma_code}`}
                      checked={draft === promotion.ma_code}
                      disabled={pending || !!unavailableReason}
                      onChange={() => {
                        setDraft(promotion.ma_code);
                        setError('');
                      }}
                    />
                  </label>
                );
              })
            )}
          </div>
          <div className="checkout-voucher-footer">
            <p>{draft ? `Đã chọn: ${draft}` : 'Không sử dụng mã giảm giá'}</p>
            <div>
              <Button
                type="button"
                variant="outline"
                disabled={pending}
                onClick={() => changeOpen(false)}
              >
                Trở lại
              </Button>
              <Button type="button" disabled={pending} onClick={() => apply(draft)}>
                {pending ? 'Đang kiểm tra…' : 'Đồng ý'}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}

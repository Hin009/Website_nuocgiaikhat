import { TicketPercent } from 'lucide-react';
import { vouchers } from '@/data/vouchers';
import { evaluateVoucher } from '@/utils/vouchers';

export default function CheckoutVouchers({ subtotal, items, selectedCode, onChange }) {
  return (
    <section className="form-card checkout-vouchers">
      <h3>
        <span>04</span>Voucher khuyến mãi
      </h3>
      <fieldset className="voucher-options">
        <legend className="sr-only">Chọn voucher khuyến mãi</legend>
        <label className="voucher-none">
          <input
            type="radio"
            name="checkout-voucher"
            value=""
            checked={!selectedCode}
            onChange={() => onChange('')}
          />
          Không sử dụng voucher
        </label>
        {vouchers.map((voucher) => {
          const evaluation = evaluateVoucher(voucher, subtotal, items);
          return (
            <label
              key={voucher.code}
              className={
                'voucher-card' +
                (!evaluation.eligible ? ' is-disabled' : '') +
                (selectedCode === voucher.code ? ' is-selected' : '')
              }
            >
              <input
                type="radio"
                name="checkout-voucher"
                value={voucher.code}
                disabled={!evaluation.eligible}
                checked={selectedCode === voucher.code}
                onChange={() => onChange(voucher.code)}
                aria-label={'Sử dụng voucher ' + voucher.code}
                aria-describedby={'voucher-conditions-' + voucher.code}
              />
              <TicketPercent size={25} className="voucher-icon" aria-hidden="true" />
              <div className="voucher-content">
                <strong>{voucher.title}</strong>
                <span className="voucher-code">{voucher.code}</span>
                <div id={'voucher-conditions-' + voucher.code}>
                  <p className="voucher-conditions">{evaluation.conditions}</p>
                  {!evaluation.eligible && (
                    <p className="voucher-unavailable">
                      <strong>Chưa đủ điều kiện sử dụng.</strong> {evaluation.reason}
                    </p>
                  )}
                </div>
              </div>
            </label>
          );
        })}
      </fieldset>
      <p className="voucher-hint">Điều kiện được tính trên tiền hàng của các sản phẩm đã chọn.</p>
    </section>
  );
}

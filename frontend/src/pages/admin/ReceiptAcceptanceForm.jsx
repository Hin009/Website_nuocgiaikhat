import { useState } from 'react';
import { purchasingDate } from '@/utils/purchasing-dates';
import { Field } from '@/components/common/Shared';
import { MoneyInput } from '@/components/common/MoneyInput';
import { Button } from '@/components/ui/button';
import { remainingToReceive, receiptItems } from '@/utils/receiving';

export default function ReceiptAcceptanceForm({ order, receipts, packageName, onSubmit }) {
  const [drafts, setDrafts] = useState(() =>
    Object.fromEntries(
      order.items
        .filter((l) => remainingToReceive(l, receipts) > 0)
        .map((l) => [
          l.id,
          {
            delivered: String(remainingToReceive(l, receipts)),
            rejected: '0',
            reason: '',
            manufacturedOn: '',
            expiresOn: '',
            cost: String(l.gia_nhap_du_kien),
          },
        ]),
    ),
  );
  const [error, setError] = useState('');
  const update = (id, key, value) =>
    setDrafts((prev) => ({ ...prev, [id]: { ...prev[id], [key]: value } }));
  return (
    <form
      className="form-stack"
      onSubmit={(e) => {
        e.preventDefault();
        try {
          setError('');
          onSubmit(receiptItems(order.items, drafts, receipts));
        } catch (e) {
          setError(e.message);
        }
      }}
    >
      <p className="muted-note">
        Kiểm hàng tại đây trước khi nhập kho. Hàng lỗi được trả ngay NCC, không cộng tồn và không
        tính công nợ. Đủ số lượng giao đã xử lý (nhập + trả) thì kết thúc đơn, không chờ giao bù.
      </p>
      {order.items
        .filter((l) => drafts[l.id])
        .map((l) => {
          const draft = drafts[l.id],
            remaining = remainingToReceive(l, receipts),
            delivered = Number(draft.delivered),
            rejected = Number(draft.rejected);
          return (
            <section className="return-product" key={l.id}>
              <strong>{packageName(l.quy_cach_id)}</strong>
              <small>
                Còn chờ xử lý: {remaining.toLocaleString('vi-VN')} quy cách · 1 quy cách ={' '}
                {Number(l.he_so_quy_doi || 1).toLocaleString('vi-VN')} đơn vị lẻ
              </small>
              <Field label="Số lượng giao đợt này">
                <input
                  type="number"
                  min="0"
                  max={remaining}
                  step="1"
                  value={draft.delivered}
                  required
                  onChange={(e) => update(l.id, 'delivered', e.target.value)}
                />
              </Field>
              <Field label="Số lượng hàng lỗi trả ngay NCC">
                <input
                  type="number"
                  min="0"
                  max={delivered}
                  step="1"
                  value={draft.rejected}
                  required
                  onChange={(e) => update(l.id, 'rejected', e.target.value)}
                />
              </Field>
              <Field label="Lý do trả hàng lỗi">
                <input
                  value={draft.reason}
                  required={rejected > 0}
                  maxLength={2000}
                  placeholder="Bể, rò rỉ, hết hạn…"
                  onChange={(e) => update(l.id, 'reason', e.target.value)}
                />
              </Field>
              <div className="form-grid">
                <Field label="Ngày sản xuất">
                  <input
                    type="date"
                    value={draft.manufacturedOn}
                    max={purchasingDate()}
                    required={delivered > 0}
                    onChange={(e) => update(l.id, 'manufacturedOn', e.target.value)}
                  />
                </Field>
                <Field label="Ngày hết hạn">
                  <input
                    type="date"
                    value={draft.expiresOn}
                    min={draft.manufacturedOn || undefined}
                    required={delivered > 0}
                    onChange={(e) => update(l.id, 'expiresOn', e.target.value)}
                  />
                </Field>
              </div>
              <Field label="Giá thực tế mỗi quy cách (đ)">
                <MoneyInput
                  data-field-control
                  value={draft.cost}
                  required={delivered > 0}
                  onChange={(v) => update(l.id, 'cost', v)}
                />
              </Field>
              <p className="receiving-summary" role="status">
                Nhập kho: {Math.max(0, delivered - rejected).toLocaleString('vi-VN')} · Trả lỗi:{' '}
                {rejected.toLocaleString('vi-VN')} · Còn chờ nhận:{' '}
                {Math.max(0, remaining - delivered).toLocaleString('vi-VN')} quy cách.
              </p>
            </section>
          );
        })}
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
      <p className="muted-note">
        Phiếu nháp chưa thay đổi kho. Khi bấm xác nhận, chỉ hàng đạt được nhập kho; hàng lỗi được
        ghi nhận trả NCC và tính vào số lượng đã xử lý của đơn.
      </p>
      <Button type="submit">Lưu kiểm nhận và trả hàng lỗi</Button>
    </form>
  );
}

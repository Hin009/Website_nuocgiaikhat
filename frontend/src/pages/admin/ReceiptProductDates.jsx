import { useState } from 'react';
import { purchasingService } from '@/services/api';
import { useAction } from '@/hooks/useData';
import { Field } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { purchasingDate } from '@/utils/purchasing-dates';
import { date } from '@/utils/format';

export default function ReceiptProductDates({ receipt, line }) {
  const [manufacturedOn, setManufacturedOn] = useState(line.ngay_san_xuat || '');
  const [expiresOn, setExpiresOn] = useState(line.ngay_het_han || '');
  const action = useAction(
    (values) => purchasingService.updateReceiptDates(receipt.id, line.id, values),
    'Đã lưu NSX/HSD',
  );
  const label = `NSX: ${line.ngay_san_xuat ? date(`${line.ngay_san_xuat}T12:00:00+07:00`) : 'Chưa ghi'} · HSD: ${line.ngay_het_han ? date(`${line.ngay_het_han}T12:00:00+07:00`) : 'Chưa ghi'}`;
  if (receipt.trang_thai !== 'DRAFT') return <small>{label}</small>;
  return (
    <details className="receipt-product-dates">
      <summary>{label} · Ghi/sửa ngày</summary>
      <form
        className="form-stack"
        onSubmit={async (e) => {
          e.preventDefault();
          try {
            await action.mutateAsync({ manufacturedOn, expiresOn });
          } catch {
            /* Toast and inline error. */
          }
        }}
      >
        <Field label="Ngày sản xuất">
          <input
            type="date"
            required
            max={purchasingDate()}
            value={manufacturedOn}
            disabled={action.isPending}
            onChange={(e) => setManufacturedOn(e.target.value)}
          />
        </Field>
        <Field label="Ngày hết hạn">
          <input
            type="date"
            required
            min={manufacturedOn || undefined}
            value={expiresOn}
            disabled={action.isPending}
            onChange={(e) => setExpiresOn(e.target.value)}
          />
        </Field>
        {action.isError && (
          <p className="form-error" role="alert">
            {action.error.message}
          </p>
        )}
        <Button type="submit" disabled={action.isPending}>
          {action.isPending ? 'Đang lưu…' : 'Lưu NSX/HSD'}
        </Button>
      </form>
    </details>
  );
}

import { useState } from 'react';
import { money } from '@/utils/format';

export default function BankTransferDetails({ bank, amount, reference }) {
  const [failedUrl, setFailedUrl] = useState(null);
  if (!bank?.bankId || !bank?.accountNumber || !bank?.accountName) {
    return (
      <p className="muted-note" role="status">
        Cửa hàng chưa cập nhật thông tin tài khoản chuyển khoản.
      </p>
    );
  }
  const params = new URLSearchParams({ accountName: bank.accountName });
  if (reference) params.set('addInfo', reference);
  if (Number(amount) > 0) params.set('amount', String(Math.round(Number(amount))));
  const qrUrl = `https://img.vietqr.io/image/${encodeURIComponent(bank.bankId)}-${encodeURIComponent(bank.accountNumber)}-qr_only.png?${params}`;
  return (
    <div className="bank-transfer-details">
      <p className="bank-transfer-title">Quét mã QR để chuyển khoản</p>
      {failedUrl === qrUrl ? (
        <p role="status">Chưa tải được mã QR. Bạn có thể chuyển khoản theo thông tin bên dưới.</p>
      ) : (
        <img
          className="bank-transfer-qr"
          src={qrUrl}
          alt="Mã QR chuyển khoản ngân hàng"
          width="168"
          height="168"
          onError={() => setFailedUrl(qrUrl)}
        />
      )}
      <dl className="bank-transfer-account">
        <div>
          <dt>Ngân hàng</dt>
          <dd>{bank.bankName || bank.bankId}</dd>
        </div>
        <div>
          <dt>Số tài khoản</dt>
          <dd>{bank.accountNumber}</dd>
        </div>
        <div>
          <dt>Tên tài khoản</dt>
          <dd>{bank.accountName}</dd>
        </div>
        {reference && (
          <div>
            <dt>Nội dung chuyển khoản</dt>
            <dd>{reference}</dd>
          </div>
        )}
        {Number(amount) > 0 && (
          <div>
            <dt>Số tiền</dt>
            <dd>{money(amount)}</dd>
          </div>
        )}
      </dl>
      <p className="muted-note">
        {reference
          ? 'Chuyển đúng số tiền và nội dung để cửa hàng xác nhận thanh toán.'
          : 'Vui lòng đặt hàng trước khi chuyển khoản để nhận nội dung thanh toán theo mã đơn.'}
      </p>
    </div>
  );
}

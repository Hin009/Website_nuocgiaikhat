import { useEffect, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { useMutation, useQuery } from '@tanstack/react-query';
import { QRCodeSVG } from 'qrcode.react';
import { get, post } from '@/services/http';
import { money } from '@/utils/format';
import { Button } from '@/components/ui/button';
import { ErrorState, Loading } from '@/components/common/Shared';

const labels = {
  PENDING: 'Chờ thanh toán',
  SUCCESS: 'Đã thanh toán',
  FAILED: 'Thanh toán thất bại',
  CANCELLED: 'Đã hủy',
  REFUNDED: 'Đã hoàn tiền',
};
export default function MomoPaymentPage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  // Return parameters only locate the local order; they never determine payment success.
  const lookup = useQuery({
    queryKey: ['momo-return-order', params.get('orderId')],
    queryFn: async () =>
      String((await get('/payments/momo/return', { orderId: params.get('orderId') })).orderId),
    enabled: !id && !!params.get('orderId'),
    retry: false,
  });
  const orderId = id || lookup.data;
  const [started, setStarted] = useState(false);
  const query = useQuery({
    queryKey: ['momo-payment', orderId],
    queryFn: () => get(`/payments/orders/${orderId}/status`),
    enabled: !!orderId,
    refetchInterval: (q) => (q.state.data?.trang_thai === 'SUCCESS' ? false : 3000),
  });
  const start = useMutation({
    mutationFn: () => post(`/payments/orders/${orderId}/momo`),
    onSuccess: () => query.refetch(),
  });
  const payment = query.data;
  const cancelled = ['DA_HUY', 'TU_CHOI'].includes(payment?.orderStatus);
  useEffect(() => {
    if (
      id &&
      payment?.phuong_thuc === 'MOMO' &&
      payment.trang_thai === 'PENDING' &&
      !payment.attempt &&
      !started &&
      !cancelled
    ) {
      setStarted(true);
      start.mutate();
    }
  }, [id, payment, started, cancelled, start]);
  const error = lookup.error || query.error || start.error;
  const attempt = payment?.attempt;
  return (
    <div className="container momo-page">
      <section className="form-card momo-card">
        <div className="momo-brand">
          <strong>WATERBUS</strong>
          <span aria-label="MoMo" className="momo-logo">
            mo
            <br />
            mo
          </span>
        </div>
        <p className="momo-sandbox">MoMo Sandbox · Không phát sinh tiền thật</p>
        <h1>
          {payment?.trang_thai === 'SUCCESS'
            ? '✓ Thanh toán thành công'
            : cancelled
              ? 'Đơn hàng đã hủy'
              : 'Thanh toán bằng MoMo'}
        </h1>
        {error && <ErrorState error={error} retry={() => query.refetch()} />}
        {!payment && !error && <Loading />}
        {payment && (
          <>
            <p>
              Mã đơn: <strong>{payment.orderCode}</strong>
            </p>
            <h2>{money(Number(payment.so_tien))}</h2>
            <p role="status" aria-live="polite">
              {labels[payment.trang_thai] || payment.trang_thai}
            </p>
            {payment.trang_thai === 'SUCCESS' ? (
              <>
                <p>
                  Mã giao dịch MoMo: <strong>{payment.ma_giao_dich}</strong>
                </p>
                {attempt?.paid_at && (
                  <p>Thanh toán lúc {new Date(attempt.paid_at).toLocaleString('vi-VN')}</p>
                )}
                <p>
                  {cancelled
                    ? 'Khoản thanh toán cho đơn đã hủy đang chờ cửa hàng đối soát.'
                    : 'Cửa hàng sẽ xác nhận và xử lý đơn hàng của bạn.'}
                </p>
              </>
            ) : (
              !cancelled &&
              payment.phuong_thuc === 'MOMO' && (
                <>
                  {start.isPending && <Loading />}
                  {payment.trang_thai === 'PENDING' && attempt?.qr_code_data && (
                    <div className="momo-qr">
                      <QRCodeSVG
                        role="img"
                        aria-label="Mã QR MoMo Sandbox"
                        value={attempt.qr_code_data}
                        size={260}
                        marginSize={4}
                        level="M"
                      />
                    </div>
                  )}
                  {payment.trang_thai === 'PENDING' && (
                    <p>
                      Mở ứng dụng <strong>MoMo Test</strong>, chọn Quét mã và xác nhận giao dịch
                      thử. Trạng thái tự cập nhật khi WATERBUS nhận thông báo từ MoMo.
                    </p>
                  )}
                  {attempt?.message && <p>{attempt.message}</p>}
                  {payment.trang_thai === 'PENDING' && attempt?.pay_url && (
                    <>
                      {!attempt.qr_code_data && (
                        <p>
                          Giao dịch này chỉ cung cấp trang thanh toán. Mở MoMo Sandbox để xem QR do
                          MoMo hiển thị.
                        </p>
                      )}
                      <Button asChild>
                        <a href={attempt.pay_url} rel="noopener noreferrer">
                          Mở trang MoMo Sandbox
                        </a>
                      </Button>
                    </>
                  )}
                  {(payment.trang_thai === 'FAILED' ||
                    (!attempt?.pay_url && !attempt?.qr_code_data)) && (
                    <Button disabled={start.isPending} onClick={() => start.mutate()}>
                      {payment.trang_thai === 'FAILED'
                        ? 'Thanh toán lại'
                        : 'Tải thông tin thanh toán'}
                    </Button>
                  )}
                </>
              )
            )}
          </>
        )}
        <p>
          <Link to={orderId ? `/account/orders/${orderId}` : '/account/orders'}>
            Quay lại đơn hàng
          </Link>
        </p>
      </section>
    </div>
  );
}

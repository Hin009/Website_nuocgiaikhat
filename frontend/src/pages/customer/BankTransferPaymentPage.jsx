import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { get, post } from '@/services/http';
import { useAction } from '@/hooks/useData';
import { QueryState } from '@/components/common/Shared';
import BankTransferDetails from '@/components/customer/BankTransferDetails';
import { Button } from '@/components/ui/button';
import { ConfirmDialog } from '@/components/ui/alert-dialog';
import { money } from '@/utils/format';

export default function BankTransferPaymentPage() {
  const { id } = useParams();
  const client = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const query = useQuery({
    queryKey: ['bank-transfer', id],
    queryFn: () => get(`/orders/${id}/bank-transfer`),
    refetchInterval: 5000,
  });
  const action = useAction(
    () => post(`/orders/${id}/bank-transfer/confirm`),
    'Đã gửi xác nhận thanh toán. Cửa hàng sẽ kiểm tra và xác nhận đơn.',
  );
  const confirm = async () => {
    try {
      const result = await action.mutateAsync();
      client.setQueryData(['bank-transfer', id], result);
      setConfirming(false);
    } catch {
      /* Thông báo lỗi do useAction hiển thị. */
    }
  };
  const payment = query.data;
  const cancelled = ['DA_HUY', 'TU_CHOI'].includes(payment?.orderStatus);
  return (
    <div className="container bank-payment-page">
      <section className="form-card bank-payment-card">
        <h1>Thanh toán chuyển khoản</h1>
        <QueryState query={query}>
          {payment && (
            <>
              <p>
                Đơn hàng <strong>{payment.orderCode}</strong> · {money(payment.amount)}
              </p>
              {cancelled ? (
                <p role="status">Đơn hàng đã hủy. Không chuyển khoản cho đơn này.</p>
              ) : payment.status === 'SUCCESS' ? (
                <p role="status">Cửa hàng đã xác nhận thanh toán.</p>
              ) : payment.customerConfirmedAt ? (
                <p role="status">
                  Bạn đã xác nhận thanh toán. Đang chờ admin kiểm tra tiền và xác nhận đơn.
                </p>
              ) : (
                <>
                  {Number(payment.amount) > 0 ? (
                    <BankTransferDetails
                      bank={payment.bank}
                      amount={payment.amount}
                      reference={payment.reference}
                    />
                  ) : (
                    <p>Đơn hàng không cần chuyển tiền. Bấm xác nhận để cửa hàng tiếp tục xử lý.</p>
                  )}
                  <p>
                    Sau khi chuyển khoản, bấm nút bên dưới. Cửa hàng chỉ có thể xác nhận đơn sau
                    bước này.
                  </p>
                  <Button disabled={action.isPending} onClick={() => setConfirming(true)}>
                    Xác nhận thanh toán
                  </Button>
                </>
              )}
              <p>
                <Link to={`/account/orders/${id}`}>Xem đơn hàng</Link>
              </p>
              <Link to="/">Về trang chủ</Link>
            </>
          )}
        </QueryState>
      </section>
      <ConfirmDialog
        open={confirming}
        onOpenChange={(open) => !action.isPending && setConfirming(open)}
        title="Bạn đã chuyển khoản?"
        description="Chỉ xác nhận sau khi đã chuyển đúng số tiền và nội dung. Admin sẽ kiểm tra tiền trước khi xác nhận đơn."
        pending={action.isPending}
        onConfirm={confirm}
      />
    </div>
  );
}

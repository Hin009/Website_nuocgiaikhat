import { test, expect } from '@playwright/test';

for (const scenario of [
  { confirmed: false, role: 'QUAN_TRI_VIEN', blocked: true },
  { confirmed: true, role: 'QUAN_TRI_VIEN', blocked: false },
  { confirmed: true, role: 'NHAN_VIEN', blocked: true },
]) {
  test(`bank-transfer order confirmation: customerConfirmed=${scenario.confirmed}, role=${scenario.role}`, async ({
    page,
  }) => {
    const writes = [];
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    const order = {
      id: 54,
      ma_don: 'DH-QR54',
      kenh_ban: 'ONLINE',
      trang_thai: 'CHO_XAC_NHAN',
      khach_hang_id: 2,
      tai_khoan_khach_id: 2,
      ten_nguoi_nhan: 'Khách QR',
      sdt_nguoi_nhan: '0901234567',
      dia_chi_nhan: 'Hà Nội',
      tong_tien: 50000,
      giam_gia: 0,
      phi_van_chuyen: 0,
      ngay_dat: new Date().toISOString(),
      history: [],
      payments: [
        {
          id: 8,
          phuong_thuc: 'BANK_TRANSFER',
          trang_thai: 'PENDING',
          customer_confirmed_at: scenario.confirmed ? new Date().toISOString() : null,
        },
      ],
      items: [
        {
          id: 1,
          quy_cach_id: 2,
          san_pham_id: 1,
          ten_san_pham: 'Nước cam',
          ten_quy_cach: 'Chai',
          so_luong: 1,
          he_so_quy_doi: 1,
          don_gia: 50000,
          thanh_tien: 50000,
        },
      ],
    };
    await page.addInitScript(() =>
      sessionStorage.setItem(
        'waterbus.api.session',
        JSON.stringify({ token: 'qr-admin-test', portal: 'management' }),
      ),
    );
    await page.route('**/api/v1/**', async (route) => {
      const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
      let data = { items: [], total: 0, page: 0, size: 100 };
      if (path === '/auth/me')
        data = {
          account: { id: 1, email: 'admin@test.invalid', trang_thai: 'ACTIVE' },
          roles: [scenario.role],
          permissions: ['ORDER_UPDATE'],
        };
      else if (path === '/staff/profile')
        data = { id: 7, ho_ten: 'Quản lý', ma_nhan_vien: 'NV007' };
      else if (path === '/staff/orders') data = { items: [order], total: 1, page: 0, size: 100 };
      else if (path === '/staff/orders/54') data = order;
      else if (path === '/staff/orders/54/status') {
        writes.push(route.request().postDataJSON());
        order.trang_thai = 'DANG_CHUAN_BI';
        order.payments[0].trang_thai = 'SUCCESS';
        data = order;
      } else if (path === '/payments/notifications') data = [];
      else if (path === '/payments/events') {
        await route.fulfill({ contentType: 'text/event-stream', body: ': keepalive\n\n' });
        return;
      }
      await route.fulfill({ json: data });
    });
    await page.goto('/admin/orders/54');
    const confirm = page.getByRole('button', { name: 'Xác nhận đơn', exact: true });
    if (scenario.blocked) {
      await expect(confirm).toBeDisabled();
      await expect(
        page.getByText(
          scenario.confirmed
            ? 'Chỉ admin được xác nhận đơn chuyển khoản.'
            : 'Chưa thể xác nhận đơn: khách hàng chưa xác nhận thanh toán.',
          { exact: true },
        ),
      ).toBeVisible();
      expect(writes).toEqual([]);
    } else {
      await expect(confirm).toBeEnabled();
      await confirm.click();
      await expect(page.getByRole('alertdialog')).toContainText('đã kiểm tra và nhận đủ tiền');
      await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
      await expect.poll(() => writes.length).toBe(1);
      expect(writes[0].status).toBe('DANG_CHUAN_BI');
      await expect(page.getByText('Đã thanh toán', { exact: true })).toBeVisible();
    }
    expect(errors).toEqual([]);
  });
}

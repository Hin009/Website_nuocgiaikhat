import { test, expect } from '@playwright/test';

for (const edited of [false, true]) {
  test(`checkout submits ${edited ? 'edited' : 'saved'} recipient and shows MoMo QR and polls server status`, async ({
    page,
  }) => {
    const address = {
      id: 10,
      mac_dinh: true,
      ten_nguoi_nhan: 'Người nhận đã lưu',
      so_dien_thoai: '0901234567',
      dia_chi: '335 Hậu Giang',
      tinh_thanh: 'Thành phố Hồ Chí Minh',
      phuong_xa: 'Phường Bình Tây',
    };
    const bank = {
      bankId: '970436',
      bankName: 'Vietcombank',
      accountNumber: '0123456789',
      accountName: 'CUA HANG THU NGHIEM',
    };
    const writes = [],
      errors = [],
      unexpected = [];
    let placed = false,
      paymentStarted = false,
      paymentPaid = false;
    page.on('pageerror', (error) => errors.push(error.message));
    await page.addInitScript(() =>
      sessionStorage.setItem(
        'waterbus.api.session',
        JSON.stringify({ token: 'test-token', portal: 'customer' }),
      ),
    );
    await page.route('**/api/v1/**', async (route) => {
      const request = route.request();
      const path = new URL(request.url()).pathname.replace('/api/v1', '');
      let data;
      if (path === '/auth/me')
        data = {
          account: { id: 1, email: 'customer@test.invalid', trang_thai: 'ACTIVE' },
          roles: ['KHACH_HANG'],
          permissions: [],
        };
      else if (path === '/me/profile')
        data = { id: 1, ho_ten: 'Khách hàng', dien_thoai: '0909999999' };
      else if (path === '/me/addresses' && request.method() === 'GET') data = [address];
      else if (path === '/me/addresses' && request.method() === 'POST') {
        writes.push({ path, body: request.postDataJSON() });
        data = { id: 11 };
      } else if (path === '/cart')
        data = {
          items: placed
            ? []
            : [
                {
                  san_pham_id: 1,
                  loai_san_pham_id: 2,
                  thuong_hieu_id: 3,
                  quy_cach_id: 2,
                  so_luong: 1,
                },
              ],
        };
      else if (path === '/catalog/checkout-options')
        data = {
          bankTransfer: bank,
          paymentMethods: [
            { code: 'COD', label: 'Thanh toán khi nhận hàng' },
            { code: 'MOMO', label: 'Ví điện tử MoMo (Sandbox)' },
          ],
        };
      else if (path === '/catalog/promotions')
        data = [
          {
            id: 1,
            ma_code: 'SAVE10',
            ten: 'Ưu đãi 10 phần trăm',
            loai_giam: 'PERCENT',
            gia_tri_giam: 10,
            don_toi_thieu: 0,
            giam_toi_da: 3000,
            ket_thuc: '2099-12-31T23:59:00Z',
            pham_vi_ap_dung: 'CATEGORY',
            scopes: [{ loai_san_pham_id: 2 }],
          },
          {
            id: 2,
            ma_code: 'MIN100',
            ten: 'Ưu đãi đơn lớn',
            loai_giam: 'PERCENT',
            gia_tri_giam: 20,
            don_toi_thieu: 100000,
          },
          {
            id: 3,
            ma_code: 'OTHERBRAND',
            ten: 'Ưu đãi thương hiệu khác',
            loai_giam: 'PERCENT',
            gia_tri_giam: 15,
            pham_vi_ap_dung: 'BRAND',
            scopes: [{ thuong_hieu_id: 99 }],
            ket_thuc: '2099-12-31T23:59:00Z',
          },
          {
            id: 4,
            ma_code: 'OTHERPRODUCT',
            ten: 'Ưu đãi sản phẩm khác',
            loai_giam: 'PERCENT',
            gia_tri_giam: 15,
            pham_vi_ap_dung: 'PRODUCT',
            scopes: [{ san_pham_id: 99 }],
            ket_thuc: '2099-12-31T23:59:00Z',
          },
        ];
      else if (path === '/orders/quote') {
        const coupon = request.postDataJSON().couponCode;
        if (coupon && coupon !== 'SAVE10') {
          await route.fulfill({ status: 400, json: { message: 'Mã giảm giá không tồn tại' } });
          return;
        }
        data = {
          subtotal: 50000,
          shippingFee: 0,
          discount: coupon ? 3000 : 0,
          total: coupon ? 47000 : 50000,
        };
      } else if (path === '/orders' && request.method() === 'POST') {
        writes.push({ path, body: request.postDataJSON() });
        placed = true;
        data = {
          id: 20,
          ma_don: 'DH-TEST20',
          tong_tien: request.postDataJSON().couponCode ? 47000 : 50000,
          payments: [{ phuong_thuc: 'MOMO', trang_thai: 'PENDING' }],
        };
      } else if (path === '/payments/orders/20/status' || path === '/payments/momo/return') {
        data = {
          orderId: 20,
          orderCode: 'DH-TEST20',
          orderStatus: 'CHO_XAC_NHAN',
          phuong_thuc: 'MOMO',
          so_tien: edited ? 47000 : 50000,
          trang_thai: paymentPaid ? 'SUCCESS' : 'PENDING',
          ma_giao_dich: paymentPaid ? 'fixture-trans-123' : null,
          attempt: paymentStarted
            ? {
                momo_order_id: 'WB-fixture-20',
                status: paymentPaid ? 'SUCCESS' : 'PENDING',
                qr_code_data: 'fixture-qr-payload',
                pay_url: 'https://test-payment.momo.vn/v2/gateway/pay?fixture=20',
                paid_at: paymentPaid ? '2026-11-10T05:00:00Z' : null,
              }
            : null,
        };
      } else if (path === '/payments/orders/20/momo' && request.method() === 'POST') {
        paymentStarted = true;
        data = {};
      } else {
        unexpected.push(path);
        await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
        return;
      }
      await route.fulfill({ json: data });
    });
    await page.goto('/checkout');
    await expect(page.getByLabel('Địa chỉ đã lưu')).toHaveCount(0);
    for (const [label, value] of [
      ['Người nhận', address.ten_nguoi_nhan],
      ['Số điện thoại', address.so_dien_thoai],
      ['Địa chỉ nhận hàng', address.dia_chi],
      ['Tỉnh/Thành phố', address.tinh_thanh],
      ['Phường/Xã', address.phuong_xa],
    ]) {
      await expect(page.getByLabel(label, { exact: true })).toHaveValue(value);
      await expect(page.getByLabel(label, { exact: true })).toBeEditable();
    }
    if (edited) {
      await page.getByLabel('Người nhận', { exact: true }).fill('Người nhận mới');
      await page.getByLabel('Số điện thoại', { exact: true }).fill('0912345678');
      await page.getByLabel('Địa chỉ nhận hàng').fill('123 Đường Mới');
      await page.getByLabel('Tỉnh/Thành phố').selectOption('Thành phố Hà Nội');
      await expect(page.getByLabel('Phường/Xã')).toHaveValue('');
      await expect(
        page.getByLabel('Phường/Xã').getByRole('option', { name: 'Phường Bình Tây', exact: true }),
      ).toHaveCount(0);
      await page.getByLabel('Phường/Xã').selectOption('Phường Ba Đình');
    }
    const couponSection = page.getByRole('region', { name: 'Mã giảm giá', exact: true });
    const summary = page.locator('.order-summary');
    expect(
      await couponSection.evaluate((element) =>
        Boolean(
          element.compareDocumentPosition(document.querySelector('.order-summary')) &
          Node.DOCUMENT_POSITION_FOLLOWING,
        ),
      ),
    ).toBe(true);
    await couponSection.getByRole('button', { name: 'Chọn hoặc nhập mã giảm giá' }).click();
    const voucherDialog = page.getByRole('dialog', { name: 'Chọn mã giảm giá' });
    await expect(voucherDialog.getByLabel('Chọn mã MIN100')).toBeDisabled();
    await expect(voucherDialog.getByLabel('Chọn mã OTHERBRAND')).toBeDisabled();
    await expect(voucherDialog.getByLabel('Chọn mã OTHERPRODUCT')).toBeDisabled();
    const unavailableTicket = voucherDialog
      .locator('.checkout-voucher-ticket')
      .filter({ has: page.getByLabel('Chọn mã OTHERBRAND') });
    await expect(unavailableTicket).toHaveClass(/is-disabled/);
    await expect(unavailableTicket).toContainText('Giỏ hàng chưa có sản phẩm');
    const eligibleTicket = voucherDialog
      .locator('.checkout-voucher-ticket')
      .filter({ has: page.getByLabel('Chọn mã SAVE10') });
    await expect(eligibleTicket).not.toHaveClass(/is-disabled/);
    await expect(eligibleTicket.locator('.checkout-voucher-expiry')).toHaveText('HSD: 01.01.2100');
    await expect(eligibleTicket.locator('.checkout-voucher-expiry')).toBeVisible();
    expect(
      await eligibleTicket.evaluate((element) => element.scrollHeight <= element.clientHeight),
    ).toBe(true);
    await voucherDialog.getByLabel('Chọn mã SAVE10').check();
    if (edited) {
      await page.setViewportSize({ width: 390, height: 844 });
      expect(
        await voucherDialog.evaluate((element) => element.scrollWidth <= element.clientWidth),
      ).toBe(true);
      await page.screenshot({ path: 'test-results/checkout-voucher-mobile.png' });
      await page.setViewportSize({ width: 1280, height: 900 });
    }
    await voucherDialog.getByRole('button', { name: 'Đồng ý', exact: true }).click();
    await expect(voucherDialog).toHaveCount(0);
    await expect(couponSection).toContainText('Giảm 10%');
    await expect(summary.locator('.summary-discount')).toContainText('Giảm giá 10% (SAVE10)');
    await expect(summary.locator('.summary-discount')).toContainText('3.000');
    await expect(summary.locator('.summary-total')).toContainText('47.000');
    await couponSection.getByRole('button', { name: 'Chọn voucher khác' }).click();
    await voucherDialog.getByLabel('Nhập mã giảm giá').fill('INVALID');
    await voucherDialog.getByRole('button', { name: 'Áp dụng', exact: true }).click();
    await expect(voucherDialog.getByRole('alert')).toContainText('Mã giảm giá không tồn tại');
    await voucherDialog.getByText('Không sử dụng mã giảm giá', { exact: true }).first().click();
    await voucherDialog.getByRole('button', { name: 'Trở lại' }).click();
    await expect(summary.locator('.summary-total')).toContainText('47.000');
    if (!edited) {
      await couponSection.getByRole('button', { name: 'Chọn voucher khác' }).click();
      await voucherDialog.getByText('Không sử dụng mã giảm giá', { exact: true }).first().click();
      await voucherDialog.getByRole('button', { name: 'Đồng ý', exact: true }).click();
      await expect(summary.locator('.summary-discount')).toHaveCount(0);
      await expect(summary.locator('.summary-total')).toContainText('50.000');
    }
    const qr = page.getByRole('img', { name: 'Mã QR MoMo Sandbox' });
    await expect(qr).toHaveCount(0);
    await page.getByLabel('Chọn phương thức thanh toán').selectOption('MOMO');
    await expect(qr).toHaveCount(0);
    await page.getByRole('button', { name: 'Đặt hàng', exact: true }).click();
    await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
    await expect(page).toHaveURL(/payments\/momo\/20$/);
    await expect(qr).toBeVisible();
    await expect(page.getByRole('status')).toHaveText('Chờ thanh toán');
    expect(writes.at(-1)).toMatchObject({
      path: '/orders',
      body: {
        addressId: edited ? 11 : 10,
        paymentMethod: 'MOMO',
        couponCode: edited ? 'SAVE10' : null,
      },
    });
    if (edited)
      expect(writes[0]).toMatchObject({
        path: '/me/addresses',
        body: {
          recipient: 'Người nhận mới',
          phone: '0912345678',
          street: '123 Đường Mới',
          province: 'Thành phố Hà Nội',
          ward: 'Phường Ba Đình',
          isDefault: false,
        },
      });
    else expect(writes).toHaveLength(1);
    expect(writes.at(-1).body.requestKey).toMatch(/^[0-9a-f-]{36}$/);
    await page.goto('/payments/momo/return?orderId=WB-fixture-20&resultCode=0');
    await expect(page.getByRole('status')).toHaveText('Chờ thanh toán');
    await expect(page.getByRole('heading', { name: '✓ Thanh toán thành công' })).toHaveCount(0);
    paymentPaid = true;
    await expect(page.getByRole('heading', { name: '✓ Thanh toán thành công' })).toBeVisible({
      timeout: 10000,
    });
    await expect(page.getByText('fixture-trans-123')).toBeVisible();
    expect(unexpected).toEqual([]);
    expect(errors).toEqual([]);
  });
}

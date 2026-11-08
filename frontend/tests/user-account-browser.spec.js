import { test, expect } from '@playwright/test';

test('admin expands orders inline and retains order processing controls', async ({ page }) => {
  const user = {
    account: { id: 1, email: 'admin@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: [],
  };
  const orders = [1, 2].map((id) => ({
    id,
    ma_don: `DH-${id}`,
    ten_nguoi_nhan: `Khách ${id}`,
    sdt_nguoi_nhan: '0901234567',
    dia_chi_nhan: '123 Đường thử',
    ngay_dat: '2026-11-08T08:00:00Z',
    trang_thai: 'CHO_XAC_NHAN',
    kenh_ban: 'ONLINE',
    tong_tien: 50000,
    phi_van_chuyen: 0,
    giam_gia: 0,
    items: [
      {
        id,
        san_pham_id: 1,
        quy_cach_id: 1,
        ten_san_pham: 'Nước thử nghiệm',
        ten_quy_cach: 'Chai',
        so_luong: 1,
        he_so_quy_doi: 1,
        don_gia: 50000,
        thanh_tien: 50000,
      },
    ],
    history: [],
    payments: [{ phuong_thuc: 'COD' }],
  }));
  const errors = [],
    unexpected = [],
    writes = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname.replace('/api/v1', '');
    let data;
    if (path === '/auth/login') data = { accessToken: 'test-token', user };
    else if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin' };
    else if (path === '/staff/orders') data = { items: orders, total: orders.length };
    else if (/^\/staff\/orders\/\d+$/.test(path))
      data = orders.find((order) => order.id === Number(path.split('/').at(-1)));
    else if (path === '/staff/orders/1/status' && request.method() === 'PATCH') {
      writes.push(request.postDataJSON());
      orders[0].trang_thai = writes.at(-1).status;
      data = orders[0];
    } else {
      unexpected.push(path);
      await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
      return;
    }
    await route.fulfill({ json: data });
  });
  await page.goto('/login');
  await expect(page.getByRole('link', { name: 'Về trang chủ', exact: true })).toBeVisible();
  await page.goto('/admin/orders');
  await expect(page.getByRole('heading', { name: 'Đăng nhập quản lý.' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Về trang chủ', exact: true })).toHaveCount(0);
  await page.getByLabel('Địa chỉ email').fill('admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/\/admin\/orders$/);
  await page.getByRole('button', { name: 'Chi tiết đơn 1', exact: true }).click();
  const details = page.getByRole('region', { name: 'Chi tiết đơn 1', exact: true });
  await expect(details.getByRole('heading', { name: 'Đơn hàng #1', exact: true })).toBeVisible();
  await expect(details).toContainText('Nước thử nghiệm');
  await expect(details.locator('xpath=..')).toHaveAttribute('colspan', '6');
  await expect(page).toHaveURL(/\/admin\/orders$/);
  await details.getByRole('button', { name: 'Xác nhận đơn', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  await expect(
    details.getByRole('button', { name: 'Bắt đầu giao hàng', exact: true }),
  ).toBeVisible();
  expect(writes).toEqual([{ status: 'DANG_CHUAN_BI', note: '' }]);
  await page.getByRole('button', { name: '#2', exact: true }).click();
  await expect(details).toHaveCount(0);
  await expect(page.getByRole('region', { name: 'Chi tiết đơn 2', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Chi tiết đơn 2', exact: true }).click();
  await expect(page.locator('.order-inline-details')).toHaveCount(0);
  expect(unexpected).toEqual([]);
  expect(errors).toEqual([]);
});

test('customer editor omits password while staff editor retains it', async ({ page }) => {
  const user = {
    account: { id: 1, email: 'admin@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['ROLE_MANAGE'],
  };
  const accounts = [
    {
      id: 2,
      email: 'customer@test.invalid',
      ho_ten: 'Khách thử',
      dien_thoai: '0901234567',
      trang_thai: 'ACTIVE',
      roles: ['KHACH_HANG'],
    },
    {
      id: 3,
      email: 'staff@test.invalid',
      ho_ten: 'Nhân viên thử',
      dien_thoai: '0901234568',
      trang_thai: 'ACTIVE',
      roles: ['NHAN_VIEN'],
    },
  ];
  const writes = [],
    errors = [],
    unexpected = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request(),
      path = new URL(request.url()).pathname.replace('/api/v1', '');
    let data;
    if (path === '/auth/login') data = { accessToken: 'test-token', user };
    else if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin' };
    else if (path === '/management/accounts') data = { items: accounts, total: 2 };
    else if (path === '/staff/orders') data = { items: [], total: 0 };
    else if (path === '/management/account-editor/2' && request.method() === 'PUT') {
      const body = request.postDataJSON();
      writes.push(body);
      Object.assign(accounts[0], { ho_ten: body.fullName, dien_thoai: body.phone });
      data = accounts[0];
    } else {
      unexpected.push(path);
      await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
      return;
    }
    await route.fulfill({ json: data });
  });
  await page.goto('/admin/users');
  await page.getByLabel('Địa chỉ email').fill('admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('button', { name: 'Sửa Khách thử', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.locator('input[type="password"]')).toHaveCount(0);
  await dialog.getByLabel('Họ tên', { exact: true }).fill('Khách cập nhật');
  await dialog.getByRole('button', { name: 'Lưu tài khoản', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  await expect.poll(() => writes.length).toBe(1);
  expect(writes[0].password).toBeNull();
  await expect(dialog).toHaveCount(0);
  await page.getByRole('button', { name: 'Sửa Nhân viên thử', exact: true }).click();
  await expect(
    dialog.getByLabel('Mật khẩu mới (để trống nếu giữ nguyên)', { exact: true }),
  ).toBeVisible();
  await dialog.getByLabel('Mật khẩu mới (để trống nếu giữ nguyên)', { exact: true }).fill('short');
  await dialog.getByLabel('Vai trò', { exact: true }).selectOption('CUSTOMER');
  await expect(dialog.locator('input[type="password"]')).toHaveCount(0);
  await dialog.getByLabel('Vai trò', { exact: true }).selectOption('STAFF');
  await expect(
    dialog.getByLabel('Mật khẩu mới (để trống nếu giữ nguyên)', { exact: true }),
  ).toHaveValue('');
  expect(unexpected).toEqual([]);
  expect(errors).toEqual([]);
});

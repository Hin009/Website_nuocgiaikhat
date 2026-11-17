import { test, expect } from '@playwright/test';

test('orders show confirmation identity, search staff, filter calendar periods, and record confirmation', async ({
  page,
}) => {
  const errors = [];
  const updates = [];
  page.on('pageerror', (error) => errors.push(error.message));
  const user = {
    account: { id: 1, email: 'manager@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['ORDER_UPDATE'],
  };
  const base = {
    kenh_ban: 'ONLINE',
    khach_hang_id: 2,
    tai_khoan_khach_id: 2,
    ten_nguoi_nhan: 'Khách hàng',
    sdt_nguoi_nhan: '0901234567',
    dia_chi_nhan: 'HCM',
    tong_tien: 10000,
    giam_gia: 0,
    phi_van_chuyen: 0,
    history: [],
    payments: [],
    items: [
      {
        id: 1,
        quy_cach_id: 1,
        san_pham_id: 1,
        ten_san_pham: 'Cam',
        ten_quy_cach: 'Chai',
        so_luong: 1,
        he_so_quy_doi: 1,
        don_gia: 10000,
        thanh_tien: 10000,
      },
    ],
  };
  const confirmer = {
    nhan_vien_xac_nhan_id: 7,
    ten_nhan_vien_xac_nhan: 'Nguyễn An',
    ma_nhan_vien_xac_nhan: 'NV007',
    thoi_gian_xac_nhan: '2026-11-01T10:00:00+07:00',
  };
  const rows = [
    {
      ...base,
      ...confirmer,
      id: 41,
      ma_don: 'DH-41',
      ngay_dat: '2026-10-31T17:00:00Z',
      trang_thai: 'DANG_CHUAN_BI',
    },
    {
      ...base,
      ...confirmer,
      id: 42,
      ma_don: 'DH-42',
      ngay_dat: '2026-10-31T16:59:59.999Z',
      trang_thai: 'DA_GIAO',
    },
    {
      ...base,
      id: 43,
      ma_don: 'DH-43',
      ngay_dat: '2026-11-11T10:00:00+07:00',
      trang_thai: 'CHO_XAC_NHAN',
    },
    {
      ...base,
      ...confirmer,
      id: 44,
      ma_don: 'DH-44',
      ngay_dat: '2025-12-20T10:00:00+07:00',
      trang_thai: 'DA_GIAO',
      ten_nhan_vien_xac_nhan: 'Quản lý Bình',
      ma_nhan_vien_xac_nhan: 'QL001',
    },
  ];
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'order-test', portal: 'management' }),
    ),
  );
  await page.route('**/api/v1/**', (route) => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let data = { items: [], total: 0, page: 0, size: 100 };
    if (path === '/auth/me') data = user;
    else if (path === '/staff/profile')
      data = { id: 7, ho_ten: 'Quản lý Bình', ma_nhan_vien: 'QL001', dien_thoai: '' };
    else if (path === '/staff/orders')
      data = { items: rows, total: rows.length, page: 0, size: 100 };
    else if (/^\/staff\/orders\/\d+/.test(path)) {
      data = rows.find((row) => row.id === Number(path.split('/')[3]));
      if (path.endsWith('/status')) {
        const body = route.request().postDataJSON();
        updates.push(body);
        Object.assign(data, {
          trang_thai: body.status,
          nhan_vien_xac_nhan_id: 8,
          ten_nhan_vien_xac_nhan: 'Quản lý Bình',
          ma_nhan_vien_xac_nhan: 'QL001',
          thoi_gian_xac_nhan: '2026-11-11T11:00:00+07:00',
        });
      }
    }
    return route.fulfill({ json: data });
  });
  await page.goto('/admin/orders');
  const list = page.locator('.data-panel').first();
  const search = page.getByRole('textbox', { name: 'Tìm đơn hàng' });
  const orderButtons = () => list.locator('button.order-id').allTextContents();
  await expect.poll(orderButtons).toEqual(['#41', '#42', '#43', '#44']);
  await expect(list.getByRole('columnheader', { name: 'Người xác nhận' })).toBeVisible();
  await search.fill('nguyen an');
  await expect.poll(orderButtons).toEqual(['#41', '#42']);
  await search.fill('NV007');
  await expect.poll(orderButtons).toEqual(['#41', '#42']);
  const filter = page.getByLabel('Lọc theo', { exact: true });
  await filter.selectOption('month');
  await page.getByLabel('Tháng', { exact: true }).fill('11/2026');
  await expect.poll(orderButtons).toEqual(['#41']);
  await list.getByRole('button', { name: 'Chi tiết đơn 41', exact: true }).click();
  const details = page.getByRole('region', { name: 'Chi tiết đơn 41', exact: true });
  await expect(details.locator('.order-confirmation-card')).toContainText('Nguyễn An');
  await expect(details.locator('.order-confirmation-card')).toContainText('NV007');
  await expect(details.locator('.order-confirmation-card')).toContainText('Xác nhận lúc:');
  await filter.selectOption('day');
  await page.getByLabel('Ngày', { exact: true }).fill('2026-11-01');
  await expect.poll(orderButtons).toEqual(['#41']);
  await filter.selectOption('quarter');
  await page.getByLabel('Quý', { exact: true }).selectOption('4');
  await page.getByLabel('Năm', { exact: true }).fill('2026');
  await expect.poll(orderButtons).toEqual(['#41', '#42']);
  await filter.selectOption('year');
  await page.getByLabel('Năm', { exact: true }).fill('2025');
  await expect.poll(orderButtons).toEqual([]);
  await search.fill('');
  await expect.poll(orderButtons).toEqual(['#44']);
  await page.getByLabel('Năm', { exact: true }).fill('2026');
  await page.getByLabel('Lọc trạng thái', { exact: true }).selectOption('PENDING');
  await expect.poll(orderButtons).toEqual(['#43']);
  await list.getByRole('button', { name: 'Chi tiết đơn 43', exact: true }).click();
  const pending = page.getByRole('region', { name: 'Chi tiết đơn 43', exact: true });
  await expect(pending.locator('.order-confirmation-card')).toContainText('Chưa xác nhận');
  await pending.getByRole('button', { name: 'Xác nhận đơn', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  await expect.poll(() => updates).toEqual([{ status: 'DANG_CHUAN_BI', note: '' }]);
  await page.getByLabel('Lọc trạng thái', { exact: true }).selectOption('CONFIRMED');
  await expect.poll(orderButtons).toEqual(['#41', '#43']);
  await list.getByRole('button', { name: 'Chi tiết đơn 43', exact: true }).click();
  await expect(
    page
      .getByRole('region', { name: 'Chi tiết đơn 43', exact: true })
      .locator('.order-confirmation-card'),
  ).toContainText('Quản lý Bình');
  await page.goto('/admin/orders/43');
  await expect(page.locator('.order-confirmation-card')).toContainText('QL001');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/admin/orders');
  await expect(page.getByLabel('Lọc theo', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});

test('customer orders filter by Vietnamese calendar day and month', async ({ page }) => {
  const rows = [
    {
      id: 51,
      ngay_dat: '2026-10-31T17:00:00Z',
      trang_thai: 'CHO_XAC_NHAN',
      ten_nguoi_nhan: 'Nguyễn An',
    },
    {
      id: 52,
      ngay_dat: '2026-10-31T16:59:59.999Z',
      trang_thai: 'DA_GIAO',
      ten_nguoi_nhan: 'Nguyễn An',
    },
    { id: 53, ngay_dat: '2026-11-01T16:59:59.999Z', trang_thai: 'DA_GIAO', ten_nguoi_nhan: 'Bình' },
    {
      id: 54,
      ngay_dat: '2026-11-01T17:00:00Z',
      trang_thai: 'DA_GIAO',
      ten_nguoi_nhan: 'Nguyễn An',
    },
  ].map((row) => ({
    ...row,
    tong_tien: 10000,
    giam_gia: 0,
    phi_van_chuyen: 0,
    items: [],
    history: [],
    payments: [],
  }));
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'customer-test', portal: 'customer' }),
    ),
  );
  await page.route('**/api/v1/**', (route) => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let data = { items: [], total: 0, page: 0, size: 100 };
    if (path === '/auth/me')
      data = {
        account: { id: 2, email: 'customer@test.invalid', trang_thai: 'ACTIVE' },
        roles: ['KHACH_HANG'],
        permissions: [],
      };
    else if (path === '/me/profile')
      data = { id: 2, ho_ten: 'Nguyễn An', dien_thoai: '0901234567' };
    else if (path === '/me/addresses') data = [];
    else if (path === '/orders') data = { items: rows, total: 4, page: 0, size: 100 };
    else if (/^\/orders\/\d+$/.test(path))
      data = rows.find((row) => row.id === Number(path.split('/')[2]));
    return route.fulfill({ json: data });
  });
  await page.goto('/account/orders');
  const filter = page.getByRole('group', { name: 'Lọc thời gian đơn hàng' });
  const type = filter.getByLabel('Lọc theo', { exact: true });
  const ids = () => page.locator('button.order-id').allTextContents();
  await expect.poll(ids).toEqual(['#51', '#52', '#53', '#54']);
  await expect(type.locator('option')).toHaveText(['Toàn bộ', 'Ngày', 'Tháng']);
  await type.selectOption('day');
  await filter.getByLabel('Ngày', { exact: true }).fill('2026-11-01');
  await expect.poll(ids).toEqual(['#51', '#53']);
  await page.getByLabel('Lọc trạng thái', { exact: true }).selectOption('COMPLETED');
  await expect.poll(ids).toEqual(['#53']);
  await page.getByLabel('Tìm đơn hàng', { exact: true }).fill('nguyen an');
  await expect(page.getByText('Chưa có đơn hàng phù hợp')).toBeVisible();
  await page.getByLabel('Tìm đơn hàng', { exact: true }).fill('');
  await page.getByLabel('Lọc trạng thái', { exact: true }).selectOption('');
  await type.selectOption('month');
  await filter.getByLabel('Tháng', { exact: true }).fill('11/2026');
  await expect.poll(ids).toEqual(['#51', '#53', '#54']);
  await filter.getByLabel('Tháng', { exact: true }).fill('10/2026');
  await expect.poll(ids).toEqual(['#52']);
  await filter.getByLabel('Tháng', { exact: true }).fill('13/2026');
  await expect(page.getByRole('alert')).toContainText('Chọn ngày hoặc tháng hợp lệ');
  await expect.poll(ids).toEqual([]);
  await type.selectOption('all');
  await expect.poll(ids).toEqual(['#51', '#52', '#53', '#54']);
  await page.setViewportSize({ width: 390, height: 844 });
  await type.selectOption('month');
  await filter.getByLabel('Tháng', { exact: true }).fill('11/2026');
  await expect.poll(ids).toEqual(['#51', '#53', '#54']);
  await expect(filter).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true,
  );
});

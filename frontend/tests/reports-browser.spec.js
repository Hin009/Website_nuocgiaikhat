import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { unzipSync, strFromU8 } from 'fflate';

test.setTimeout(45000);

const rows = [
  {
    product_id: 1,
    product_name: 'Cam',
    sku: 'CAM',
    imported_qty: '2',
    import_amount: '10000',
    sold_qty: '12',
    net_sales: '500',
    cost_of_goods: '300',
    gross_profit: '200',
    margin_percent: '40',
    current_stock: '9',
    discount: 0,
  },
  {
    product_id: 2,
    product_name: 'Bưởi',
    sku: 'BUOI',
    imported_qty: '10',
    import_amount: '2000',
    sold_qty: '2',
    net_sales: '1000',
    cost_of_goods: '1100',
    gross_profit: '-100',
    margin_percent: '-10',
    current_stock: '20',
    discount: 0,
  },
  {
    product_id: 3,
    product_name: 'Đào',
    sku: 'DAO',
    imported_qty: '5',
    import_amount: '300',
    sold_qty: '5',
    net_sales: '0',
    cost_of_goods: '0',
    gross_profit: '0',
    margin_percent: null,
    current_stock: '1',
    discount: 0,
  },
];

test('report filters sit by search, send calendar bounds, and headers toggle numeric and name sorting', async ({
  page,
}) => {
  await page.addInitScript(() => {
    window.print = () => {
      window.__reportPrinted = true;
    };
  });
  const queries = [];
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const user = {
    account: { id: 1, email: 'report@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['REPORT_ALL'],
  };
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'report-test', portal: 'management' }),
    ),
  );
  await page.route('**/api/v1/**', (route) => {
    const url = new URL(route.request().url());
    const path = url.pathname.replace('/api/v1', '');
    let data = { items: [], total: 0, page: 0, size: 100 };
    if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Report Test', dien_thoai: '' };
    else if (path === '/management/reports/product-profit') {
      queries.push(Object.fromEntries(url.searchParams));
      data = rows;
    }
    return route.fulfill({ json: data });
  });
  await page.goto('/admin/reports');
  const panel = page.locator('.product-profit-section');
  await expect(panel.locator('tbody tr')).toHaveCount(3);
  await expect(page.locator('.dashboard-bottom')).toHaveCount(0);
  await expect(page.locator('.operations-card')).toHaveCount(0);
  await expect(page.getByRole('heading', { name: 'Những đơn hàng gần đây' })).toHaveCount(0);
  await expect(page.locator('.metrics-grid')).not.toContainText('Khách hàng');
  await expect(page.locator('.metrics-grid')).not.toContainText('Sản phẩm');
  await expect(page.getByRole('heading', { name: 'Sản phẩm bán chạy trong kỳ' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Xu hướng doanh thu trong kỳ' })).toBeVisible();
  await expect(page.locator('.range-buttons')).toHaveCount(0);
  await expect(panel.locator('.profit-toolbar').getByLabel('Tìm sản phẩm')).toBeVisible();
  const filter = panel.getByLabel('Lọc theo', { exact: true });
  await filter.selectOption('day');
  await panel.getByLabel('Ngày', { exact: true }).fill('2026-11-11');
  await expect.poll(() => queries.at(-1)).toEqual({ from: '2026-11-11', to: '2026-11-11' });
  await filter.selectOption('month');
  await panel.getByLabel('Chọn tháng từ lịch', { exact: true }).fill('2026-11');
  await expect(panel.getByLabel('Tháng', { exact: true })).toHaveValue('11/2026');
  await panel.getByLabel('Tháng', { exact: true }).fill('02/2024');
  await expect.poll(() => queries.at(-1)).toEqual({ from: '2024-02-01', to: '2024-02-29' });
  await filter.selectOption('quarter');
  await panel.getByLabel('Năm', { exact: true }).fill('2026');
  await panel.getByLabel('Quý', { exact: true }).selectOption('2');
  await expect.poll(() => queries.at(-1)).toEqual({ from: '2026-04-01', to: '2026-06-30' });
  await filter.selectOption('year');
  await panel.getByLabel('Năm', { exact: true }).fill('2025');
  await expect.poll(() => queries.at(-1)).toEqual({ from: '2025-01-01', to: '2025-12-31' });
  await filter.selectOption('all');
  await expect(panel.locator('tbody tr')).toHaveCount(3);
  const names = () => panel.locator('tbody tr td:first-child strong').allTextContents();
  for (const [label, ascending, descending] of [
    ['Sản phẩm', ['Bưởi', 'Cam', 'Đào'], ['Đào', 'Cam', 'Bưởi']],
    ['SL nhập', ['Cam', 'Đào', 'Bưởi'], ['Bưởi', 'Đào', 'Cam']],
    ['Tiền nhập', ['Đào', 'Bưởi', 'Cam'], ['Cam', 'Bưởi', 'Đào']],
    ['SL bán', ['Bưởi', 'Đào', 'Cam'], ['Cam', 'Đào', 'Bưởi']],
    ['Doanh thu', ['Đào', 'Cam', 'Bưởi'], ['Bưởi', 'Cam', 'Đào']],
    ['Giá vốn', ['Đào', 'Cam', 'Bưởi'], ['Bưởi', 'Cam', 'Đào']],
    ['Lãi gộp', ['Bưởi', 'Đào', 'Cam'], ['Cam', 'Đào', 'Bưởi']],
    ['Tỷ suất', ['Bưởi', 'Cam', 'Đào'], ['Cam', 'Bưởi', 'Đào']],
    ['Tồn hiện tại', ['Đào', 'Cam', 'Bưởi'], ['Bưởi', 'Cam', 'Đào']],
  ]) {
    const button = panel.getByRole('button', { name: `Sắp xếp theo ${label}`, exact: true });
    await button.click();
    await expect.poll(names).toEqual(ascending);
    await button.click();
    await expect.poll(names).toEqual(descending);
  }
  await panel.getByLabel('Tìm sản phẩm').fill('buoi');
  await expect(panel.locator('tbody tr')).toHaveCount(1);
  await expect(panel.locator('tbody')).toContainText('Bưởi');
  await filter.selectOption('month');
  await panel.getByLabel('Tháng', { exact: true }).fill('02/2024');
  await expect(panel.getByRole('button', { name: 'Xuất Excel', exact: true })).toBeEnabled();
  const xlsxDownloadPromise = page.waitForEvent('download');
  await panel.getByRole('button', { name: 'Xuất Excel', exact: true }).click();
  const xlsxDownload = await xlsxDownloadPromise;
  expect(xlsxDownload.suggestedFilename()).toMatch(/2024-02-01_2024-02-29\.xlsx$/);
  const xlsxBytes = await readFile(await xlsxDownload.path());
  const zip = unzipSync(xlsxBytes);
  const workbookText = Object.values(zip)
    .map((bytes) => strFromU8(bytes))
    .join('');
  expect(workbookText).toContain('Bưởi');
  expect(workbookText).not.toContain('Cam');
  expect(workbookText).toContain('29/02/2024');
  expect(workbookText).toContain('TỔNG CỘNG');
  const pdfDownloadPromise = page.waitForEvent('download');
  await panel.getByRole('button', { name: 'Xuất PDF', exact: true }).click();
  const pdfDownload = await pdfDownloadPromise;
  expect(pdfDownload.suggestedFilename()).toMatch(/2024-02-01_2024-02-29\.pdf$/);
  const pdfBytes = await readFile(await pdfDownload.path());
  expect(pdfBytes.subarray(0, 5).toString()).toBe('%PDF-');
  expect(pdfBytes.length).toBeGreaterThan(5000);
  await panel.getByRole('button', { name: 'In báo cáo', exact: true }).click();
  const printFrame = page.frameLocator('iframe[title="Bản in báo cáo WaterBus"]');
  await expect(printFrame.locator('body')).toContainText('Bưởi');
  await expect(printFrame.locator('body')).not.toContainText('Cam');
  await expect(printFrame.locator('body')).toContainText('29/02/2024');
  await expect(printFrame.locator('tbody tr')).toHaveCount(2);
  expect(await printFrame.locator('body').evaluate(() => window.__reportPrinted)).toBe(true);
  await panel.getByLabel('Tìm sản phẩm').fill('khong-co-san-pham');
  for (const label of ['Xuất Excel', 'Xuất PDF', 'In báo cáo'])
    await expect(panel.getByRole('button', { name: label, exact: true })).toBeDisabled();
  await page.setViewportSize({ width: 390, height: 844 });
  const toolbar = await panel.locator('.profit-toolbar').boundingBox();
  expect(toolbar.width).toBeLessThanOrEqual(390);
  expect(errors).toEqual([]);
});

test('report order totals and best sellers follow the period while overview retains operations', async ({
  page,
}) => {
  const user = {
    account: { id: 1, email: 'report@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['REPORT_ALL'],
  };
  const orders = [
    {
      id: 1,
      ngay_dat: '2026-11-10T03:00:00Z',
      trang_thai: 'HOAN_TAT',
      giam_gia: 0,
      phi_van_chuyen: 0,
      tong_tien: 3000,
      items: [{ san_pham_id: 1, so_luong: 3, he_so_quy_doi: 1, don_gia: 1000, thanh_tien: 3000 }],
    },
    {
      id: 2,
      ngay_dat: '2026-12-10T03:00:00Z',
      trang_thai: 'DA_GIAO',
      giam_gia: 0,
      phi_van_chuyen: 0,
      tong_tien: 7000,
      items: [{ san_pham_id: 1, so_luong: 7, he_so_quy_doi: 1, don_gia: 1000, thanh_tien: 7000 }],
    },
    {
      id: 3,
      ngay_dat: '2026-11-10T05:00:00Z',
      trang_thai: 'CHO_XAC_NHAN',
      giam_gia: 0,
      phi_van_chuyen: 0,
      tong_tien: 1000,
      items: [],
    },
  ];
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'report-test', portal: 'management' }),
    ),
  );
  await page.route('**/api/v1/**', (route) => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let data = { items: [], total: 0, page: 0, size: 100 };
    if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Report Test' };
    else if (path === '/management/reports/product-profit') data = rows;
    else if (path === '/staff/orders') data = { items: orders, total: orders.length };
    else if (/^\/staff\/orders\/\d+$/.test(path))
      data = orders.find((o) => o.id === Number(path.split('/').pop()));
    else if (path === '/management/products')
      data = {
        items: [
          {
            id: 1,
            ten: 'Cam',
            loai_san_pham_id: 1,
            thuong_hieu_id: 1,
            trang_thai: 'DANG_BAN',
            hien_thi: true,
          },
        ],
        total: 1,
      };
    return route.fulfill({ json: data });
  });
  await page.goto('/admin/reports');
  const metric = (label) =>
    page.locator('.report-order-metrics .metric-card').filter({ hasText: label }).locator('strong');
  await expect(metric('Đơn hàng trong kỳ')).toHaveText('3');
  await expect(metric('Đơn hoàn thành trong kỳ')).toHaveText('2');
  await page.getByLabel('Lọc theo', { exact: true }).selectOption('day');
  await page.getByLabel('Ngày', { exact: true }).fill('2026-11-10');
  await expect(metric('Đơn hàng trong kỳ')).toHaveText('2');
  await expect(metric('Đơn hoàn thành trong kỳ')).toHaveText('1');
  await expect(page.locator('.top-products .top-product strong')).toContainText('3');
  await page.getByLabel('Ngày', { exact: true }).fill('2026-12-10');
  await expect(metric('Đơn hàng trong kỳ')).toHaveText('1');
  await expect(page.locator('.top-products .top-product strong')).toContainText('7');
  await expect(page.locator('.dashboard-bottom')).toHaveCount(0);
  await page.goto('/admin');
  await expect(page.getByRole('heading', { name: 'Những đơn hàng gần đây' })).toBeVisible();
  await expect(page.locator('.operations-card')).toBeVisible();
  await expect(page.locator('.metrics-grid')).toContainText('Sản phẩm');
  await expect(page.locator('.metrics-grid')).toContainText('Khách hàng');
  await expect(page.getByRole('heading', { name: 'Đồ uống được yêu thích' })).toBeVisible();
});

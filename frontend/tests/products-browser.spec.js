import { test, expect } from '@playwright/test';

async function setup(page, admin) {
  const user = {
    account: { id: 1, email: 'test@test.invalid', trang_thai: 'ACTIVE' },
    roles: [admin ? 'QUAN_TRI_VIEN' : 'NHAN_VIEN'],
    permissions: ['REPORT_STOCK', 'ORDER_UPDATE'],
  };
  const writes = [],
    unexpected = [],
    errors = [];
  let stock = 20,
    conflict = false;
  const adjustments = [];
  const paged = (items) => ({ items, total: items.length, page: 0, size: 100 });
  const products = [
    {
      id: 1,
      ten: 'Nước kiểm thử',
      loai_san_pham_id: 1,
      thuong_hieu_id: 1,
      trang_thai: 'DANG_BAN',
      hien_thi: true,
    },
    {
      id: 2,
      ten: 'Hàng ngừng bán',
      loai_san_pham_id: 1,
      thuong_hieu_id: 1,
      trang_thai: 'NGUNG_KINH_DOANH',
      hien_thi: false,
    },
  ];
  const packages = [{ id: 1, san_pham_id: 1, he_so_quy_doi: 1, gia_ban: 10000, dang_ban: true }];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request(),
      path = new URL(req.url()).pathname.replace('/api/v1', ''),
      method = req.method();
    let data;
    if (method !== 'GET') writes.push({ path, body: req.postDataJSON() });
    if (path === '/auth/login') data = { accessToken: 'test-token', user };
    else if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Người kiểm thử' };
    else if (path === '/management/products/1/stock' && method === 'PATCH') {
      const body = req.postDataJSON();
      if (conflict || body.expectedStock !== stock) {
        stock = 30;
        await route.fulfill({
          status: 409,
          json: {
            message: 'Tồn kho đã thay đổi. Tải lại danh sách rồi kiểm tra số lượng trước khi lưu.',
          },
        });
        return;
      }
      adjustments.unshift({
        id: adjustments.length + 1,
        so_luong_truoc: stock,
        so_luong_sau: body.stock,
        chenh_lech: body.stock - stock,
        ly_do: body.reason,
        adjusted_by: 'Quản lý kiểm thử',
        thoi_diem: '2026-11-04T03:00:00Z',
      });
      stock = body.stock;
      data = { productId: 1, stock };
    } else if (path === '/management/product-editor/1' && method === 'PUT') {
      const body = req.postDataJSON();
      products[0].ten = body.fullName;
      products[0].dung_tich = body.volume;
      data = products[0];
    } else if (/^\/staff\/products\/\d+\/inventory-details$/.test(path)) {
      data = path.includes('/1/')
        ? {
            batches: [
              {
                id: 1,
                receipt_id: 10,
                ngay_san_xuat: '2026-01-01',
                ngay_het_han: '2027-01-01',
                received_units: 24,
              },
              {
                id: 2,
                receipt_id: 11,
                ngay_san_xuat: '2026-02-01',
                ngay_het_han: '2027-02-01',
                received_units: 48,
              },
            ],
            adjustments,
          }
        : { batches: [], adjustments: [] };
    } else if (path === '/management/products') data = paged(products);
    else if (path === '/staff/products')
      data = paged(
        products.map((p) => ({
          ...p,
          so_luong_co_ban: p.id === 1 ? stock : 0,
          nguong_canh_bao: 5,
          packages: packages.filter((q) => q.san_pham_id === p.id),
          images: [],
        })),
      );
    else if (path === '/management/packages') data = paged(packages);
    else if (path === '/management/categories') data = paged([{ id: 1, ten: 'Nước ngọt' }]);
    else if (path === '/catalog/categories') data = [{ id: 1, ten: 'Nước ngọt' }];
    else if (path === '/management/brands') data = paged([{ id: 1, ten: 'Thương hiệu thử' }]);
    else if (path === '/catalog/brands') data = [{ id: 1, ten: 'Thương hiệu thử' }];
    else if (path === '/staff/reports/stock')
      data = paged([{ san_pham_id: 1, so_luong_co_ban: stock, nguong_canh_bao: 5 }]);
    else if (['/staff/orders', '/management/images'].includes(path)) data = paged([]);
    else {
      unexpected.push(method + ' ' + path);
      await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
      return;
    }
    await route.fulfill({ status: 200, json: data });
  });
  await page.goto('/admin/products');
  await page.getByLabel('Địa chỉ email').fill('test@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page.getByRole('row', { name: /Nước kiểm thử/ })).toBeVisible();
  return {
    writes,
    unexpected,
    errors,
    conflict: () => {
      conflict = true;
    },
  };
}

test('staff can view stock including inactive products without editing controls', async ({
  page,
}) => {
  const state = await setup(page, false);
  await expect(page.getByRole('link', { name: 'Sản phẩm', exact: true })).toBeVisible();
  await expect(
    page.getByRole('row', { name: /Nước kiểm thử/ }).getByRole('cell', { name: '20', exact: true }),
  ).toBeVisible();
  await expect(page.getByRole('row', { name: /Hàng ngừng bán/ })).toContainText('Ngừng bán');
  const row = page.getByRole('row', { name: /Nước kiểm thử/ });
  await expect(
    page.getByRole('columnheader', { name: 'Lịch sử điều chỉnh', exact: true }),
  ).toHaveCount(0);
  await expect(page.getByRole('columnheader', { name: 'Hạn sử dụng', exact: true })).toHaveCount(0);
  const toggle = page.getByRole('button', { name: 'Chi tiết Nước kiểm thử', exact: true });
  await toggle.click();
  await expect(toggle).toHaveAttribute('aria-expanded', 'true');
  const panel = page.locator('#product-inventory-1');
  await expect(panel.getByRole('heading', { name: 'Lịch sử sửa đổi', exact: true })).toBeVisible();
  await expect(panel.getByRole('heading', { name: 'Hạn sử dụng', exact: true })).toBeVisible();
  const sections = panel.locator('section');
  const left = await sections.nth(0).boundingBox(),
    right = await sections.nth(1).boundingBox();
  expect(Math.abs(left.y - right.y)).toBeLessThan(2);
  expect(right.x).toBeGreaterThan(left.x + left.width);
  await expect(panel).toContainText('HSD: 01/01/2027');
  await expect(panel).toContainText('HSD: 01/02/2027');
  await expect(panel).toContainText('NSX: 01/01/2026');
  await page.screenshot({ path: 'test-results/product-inventory-expanded.png', fullPage: true });
  const lots = panel.getByRole('list', { name: 'Các lô nhập Nước kiểm thử', exact: true });
  await expect(lots.getByRole('listitem').first()).toContainText('Phiếu #11');
  expect(
    await lots.evaluate(
      (element) => element.scrollHeight > element.clientHeight && element.clientHeight <= 112,
    ),
  ).toBe(true);
  await lots.evaluate((element) => {
    element.scrollTop = element.scrollHeight;
  });
  expect(await lots.evaluate((element) => element.scrollTop)).toBeGreaterThan(0);
  await expect(panel).toContainText('Chưa có điều chỉnh số lượng.');
  await page.getByRole('button', { name: 'Chi tiết Hàng ngừng bán', exact: true }).click();
  await expect(panel).toHaveCount(0);
  await expect(page.locator('#product-inventory-2')).toContainText('Chưa có lô nhập xác nhận.');
  await row.getByRole('button', { name: 'Nước kiểm thử', exact: true }).click();
  await expect(page.locator('#product-inventory-2')).toHaveCount(0);
  await expect(panel).toBeVisible();
  await toggle.click();
  await expect(page.locator('.product-inventory-row')).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Thêm sản phẩm', exact: true })).toHaveCount(0);
  await expect(page.getByRole('spinbutton')).toHaveCount(0);
  await expect(page.getByRole('button', { name: /^Sửa / })).toHaveCount(0);
  expect(state.writes.filter((w) => w.path !== '/auth/login')).toEqual([]);
  expect(state.unexpected).toEqual([]);
  expect(state.errors).toEqual([]);
});

test('admin changes stock inline with reason and handles concurrent changes safely', async ({
  page,
}) => {
  const state = await setup(page, true);
  const stock = page.getByRole('spinbutton', { name: 'Tồn kho Nước kiểm thử', exact: true });
  await stock.fill('25');
  await page.getByRole('button', { name: 'Lưu số lượng', exact: true }).click();
  expect(state.writes.filter((w) => w.path.endsWith('/stock'))).toHaveLength(0);
  await page
    .getByRole('textbox', { name: 'Lý do điều chỉnh Nước kiểm thử', exact: true })
    .fill('Kiểm kê thực tế');
  await page.getByRole('button', { name: 'Lưu số lượng', exact: true }).click();
  await expect(stock).toHaveValue('25');
  await expect.poll(() => state.writes.filter((w) => w.path.endsWith('/stock')).length).toBe(1);
  await expect(stock).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Lưu số lượng', exact: true })).toHaveCount(0);
  expect(state.writes.filter((w) => w.path.endsWith('/stock'))[0].body).toEqual({
    stock: 25,
    expectedStock: 20,
    reason: 'Kiểm kê thực tế',
  });
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.getByRole('button', { name: 'Chi tiết Nước kiểm thử', exact: true }).click();
  const history = page.locator('#product-inventory-1');
  await expect(history).toContainText('20 → 25');
  await expect(history).toContainText('(+5)');
  await expect(history).toContainText('Lý do: Kiểm kê thực tế');
  await expect(history).toContainText('Quản lý kiểm thử');
  state.conflict();
  await stock.fill('26');
  await page
    .getByRole('textbox', { name: 'Lý do điều chỉnh Nước kiểm thử', exact: true })
    .fill('Đối chiếu lại');
  await page.getByRole('button', { name: 'Lưu số lượng', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Tồn kho đã thay đổi');
  await page.getByRole('button', { name: 'Tải lại danh sách', exact: true }).click();
  await expect(stock).toHaveValue('30');
  expect(state.unexpected).toEqual([]);
  expect(state.errors).toEqual([]);
});

test('product editing displays automatic price without sending manual pricing', async ({
  page,
}) => {
  const state = await setup(page, true);
  await page.getByRole('button', { name: 'Sửa Nước kiểm thử', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByLabel('Giá bán tự động', { exact: true })).toHaveAttribute(
    'readonly',
    '',
  );
  await dialog.getByLabel('Tên sản phẩm', { exact: true }).fill('Nước kiểm thử cập nhật');
  await dialog.getByLabel('Quy cách', { exact: true }).fill('330ml');
  await dialog.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect
    .poll(() => state.writes.filter((w) => w.path === '/management/product-editor/1').length)
    .toBe(1);
  expect(
    state.writes.find((w) => w.path === '/management/product-editor/1').body,
  ).not.toHaveProperty('price');
  await expect(dialog).toHaveCount(0);
  await page.getByRole('button', { name: 'Thêm sản phẩm', exact: true }).click();
  await expect(
    page.getByRole('dialog').getByLabel('Số lượng tồn kho', { exact: true }),
  ).toHaveAttribute('readonly', '');
  expect(state.unexpected).toEqual([]);
  expect(state.errors).toEqual([]);
});

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
      stock = body.stock;
      data = { productId: 1, stock };
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
  await expect(page.getByRole('button', { name: 'Lưu số lượng', exact: true })).toHaveCount(0);
  expect(state.writes.filter((w) => w.path.endsWith('/stock'))[0].body).toEqual({
    stock: 25,
    expectedStock: 20,
    reason: 'Kiểm kê thực tế',
  });
  await expect(page.getByRole('dialog')).toHaveCount(0);
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

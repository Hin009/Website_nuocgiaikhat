import { test, expect } from '@playwright/test';

test('admin creates and edits product images with automatic prices', async ({ page, request }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const name = `E2E image drink ${Date.now()}`;
  await page.goto('/admin/products');
  await page.getByLabel('Địa chỉ email').fill('e2e-admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('button', { name: 'Thêm sản phẩm', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('Tên sản phẩm', { exact: true }).fill(name);
  await dialog.getByLabel('Thương hiệu', { exact: true }).fill('E2E brand');
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    'base64',
  );
  await dialog
    .locator('input[type=file]')
    .setInputFiles({ name: 'drink.png', mimeType: 'image/png', buffer: png });
  await dialog.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect(dialog).toHaveCount(0, { timeout: 30000 });
  await page.getByLabel('Tìm sản phẩm quản lý').fill(name);
  await page.getByRole('button', { name: `Sửa ${name}`, exact: true }).click();
  await expect(dialog.getByLabel('Số lượng tồn kho', { exact: true })).toHaveValue('0');
  const oldUrl = await dialog.getByLabel('Hoặc đường dẫn ảnh').inputValue();
  expect((await request.get(oldUrl)).ok()).toBeTruthy();
  await dialog
    .locator('input[type=file]')
    .setInputFiles({ name: 'replacement.png', mimeType: 'image/png', buffer: png });
  await dialog.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect(dialog).toHaveCount(0, { timeout: 30000 });
  const listed = await (
    await request.get('/api/v1/catalog/products', { params: { q: name } })
  ).json();
  expect(listed.items).toHaveLength(1);
  expect(listed.items[0].so_luong_co_ban).toBe(0);
  const detail = await (await request.get(`/api/v1/catalog/products/${listed.items[0].id}`)).json();
  expect(detail.images[0].duong_dan).not.toBe(oldUrl);
  await page.goto(`/products/${listed.items[0].id}`);
  const image = page.locator('.detail-art img');
  await expect(image).toHaveAttribute('src', detail.images[0].duong_dan);
  await expect(image).toBeVisible();
  expect(errors).toEqual([]);
});
// Requires an isolated backend on port 18080 with a disposable backend_test database.
// Never point this test at the normal Docker API/database.
test('real PostgreSQL catalog, customer checkout, and management pages', async ({
  page,
  request,
}) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const api = 'http://127.0.0.1:18080/api/v1';
  const login = await request.post(`${api}/auth/login`, {
    data: { email: 'e2e-admin@test.invalid', password: 'TestPass123!' },
  });
  expect(login.ok()).toBeTruthy();
  const headers = { Authorization: `Bearer ${(await login.json()).accessToken}` };
  const catalog = await (await request.get(`${api}/catalog/products`)).json();
  const product = await (
    await request.get(`${api}/catalog/products/${catalog.items[0].id}`)
  ).json();
  const pack = product.packages.find((q) => q.he_so_quy_doi === 1);
  const supplier = await (
    await request.post(`${api}/management/suppliers`, {
      headers,
      data: { ten: `E2E ${Date.now()}` },
    })
  ).json();
  expect(
    (
      await request.post(`${api}/management/supplier-products`, {
        headers,
        data: { nha_cung_cap_id: supplier.id, san_pham_id: product.id },
      })
    ).ok(),
  ).toBeTruthy();
  const poResponse = await request.post(`${api}/purchases`, {
    headers,
    data: {
      supplierId: supplier.id,
      items: [{ packageId: pack.id, quantity: 10, unitCost: 4000 }],
    },
  });
  expect(poResponse.ok()).toBeTruthy();
  const po = await poResponse.json();
  expect(
    (
      await request.patch(`${api}/purchases/${po.id}/status`, {
        headers,
        data: { status: 'DA_DUYET' },
      })
    ).ok(),
  ).toBeTruthy();
  const receipt = await (
    await request.post(`${api}/purchases/${po.id}/receipts`, {
      headers,
      data: { items: [{ purchaseLineId: po.items[0].id, quantity: 10, actualCost: 4000 }] },
    })
  ).json();
  expect(
    (await request.post(`${api}/receipts/${receipt.id}/confirm`, { headers })).ok(),
  ).toBeTruthy();

  await page.goto('/products');
  await expect(page.getByText(product.ten, { exact: true }).first()).toBeVisible();
  await page.goto('/register');
  await page.getByLabel('Họ và tên').fill('API Customer');
  await page.getByLabel('Địa chỉ email').fill(`e2e-${Date.now()}@test.invalid`);
  await page.getByLabel('Số điện thoại').fill('0900000000');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByLabel('Nhập lại mật khẩu').fill('TestPass123!');
  await page.getByRole('button', { name: 'Tạo tài khoản' }).click();
  await expect(page).toHaveURL(/\/$/);
  await page.goto(`/products/${product.id}`);
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await expect(page.getByText('Đã thêm vào giỏ hàng', { exact: true })).toBeVisible();
  await page.goto('/cart');
  await expect(page.getByText(product.ten, { exact: true }).first()).toBeVisible();
  await expect(page.locator('.order-summary').getByText('Miễn phí', { exact: true })).toBeVisible();
  await page.goto('/checkout');
  await expect(page.locator('.order-summary').getByText('Miễn phí', { exact: true })).toBeVisible();
  await page.getByLabel('Chọn phương thức thanh toán').selectOption('COD');
  await page.getByLabel('Địa chỉ nhận hàng').fill('123 API Test');
  await page.getByLabel('Tỉnh/Thành phố').selectOption('Thành phố Hồ Chí Minh');
  await page.getByLabel('Phường/Xã').selectOption('Phường Bến Thành');
  await page.getByRole('button', { name: 'Đặt hàng', exact: true }).click();
  const placed = page.waitForResponse(
    (r) => r.url().endsWith('/api/v1/orders') && r.request().method() === 'POST',
  );
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  const saved = await (await placed).json();
  expect(saved.phi_van_chuyen).toBe(0);
  expect(saved.payments[0].phuong_thuc).toBe('COD');
  expect(saved.payments[0].trang_thai).toBe('PENDING');
  await expect(page.getByRole('heading', { name: 'Đặt hàng thành công' })).toBeVisible();
  await page.getByRole('link', { name: 'Xem đơn hàng', exact: true }).click();
  await expect(page.getByText(product.ten, { exact: true }).first()).toBeVisible();
  await page.evaluate(async () => {
    const { authService } = await import('/src/services/api.js');
    await authService.logout();
  });
  await page.goto('/admin');
  await page.getByLabel('Địa chỉ email').fill('e2e-admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page.getByRole('link', { name: 'Sản phẩm', exact: true })).toBeVisible();
  for (const route of [
    'products',
    'categories',
    'users',
    'customers',
    'orders',
    'stock-receipts',
    'reports',
  ]) {
    await page.goto(`/admin/${route}`);
    await expect(page.locator('main h1')).toBeVisible();
    await expect(page.getByText('Máy chủ gặp sự cố.', { exact: false })).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});

import { test, expect } from '@playwright/test';

test('category deletion confirms preservation of history and removes category from product choices', async ({
  page,
}) => {
  const user = {
    account: { id: 1, email: 'category@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: [],
  };
  const categories = [
    { id: 9, ten: 'Nước trái cây', hien_thi: true },
    { id: 10, ten: 'Nước ngọt', hien_thi: true },
  ];
  const unexpected = [],
    errors = [];
  let deletes = 0;
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'category-test', portal: 'management' }),
    ),
  );
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname.replace('/api/v1', '');
    let data;
    if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin' };
    else if (path === '/management/categories')
      data = { items: categories, total: categories.length };
    else if (path === '/management/categories/9' && request.method() === 'DELETE') {
      deletes++;
      categories.splice(
        categories.findIndex((c) => c.id === 9),
        1,
      );
      return route.fulfill({ status: 204 });
    } else if (
      [
        '/management/products',
        '/management/packages',
        '/management/brands',
        '/management/images',
        '/staff/reports/stock',
        '/staff/orders',
      ].includes(path)
    )
      data = { items: [], total: 0 };
    else {
      unexpected.push(request.method() + ' ' + path);
      return route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
    }
    await route.fulfill({ json: data });
  });
  await page.goto('/admin/categories');
  const remove = page.getByRole('button', { name: 'Xóa loại sản phẩm Nước trái cây', exact: true });
  await expect(remove).toHaveAttribute('title', 'Xóa loại sản phẩm');
  await expect(page.locator('.muted-note')).toContainText('Lịch sử liên quan vẫn được giữ lại');
  await remove.click();
  const confirmation = page.getByRole('alertdialog');
  await expect(confirmation).toContainText('Lịch sử sản phẩm, đơn hàng và khuyến mãi được giữ lại');
  await confirmation.getByRole('button', { name: 'Quay lại', exact: true }).click();
  expect(deletes).toBe(0);
  await remove.click();
  await confirmation.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(confirmation).toHaveCount(0);
  await expect(page.locator('tbody')).not.toContainText('Nước trái cây');
  await expect(page.locator('tbody')).toContainText('Nước ngọt');
  await page.reload();
  await expect(page.locator('tbody')).toContainText('Nước ngọt');
  await expect(page.locator('tbody')).not.toContainText('Nước trái cây');
  await page.goto('/admin/products');
  await page.getByRole('button', { name: 'Thêm sản phẩm', exact: true }).click();
  const select = page.getByRole('dialog').getByLabel('Loại sản phẩm', { exact: true });
  await expect(select.locator('option')).toHaveText(['Nước ngọt']);
  expect(deletes).toBe(1);
  expect(unexpected).toEqual([]);
  expect(errors).toEqual([]);
});

import { test, expect } from '@playwright/test';

test('account deletion appears only after deactivation, confirms and handles stale status', async ({
  page,
}) => {
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
      trang_thai: 'LOCKED',
      roles: ['NHAN_VIEN'],
    },
  ];
  let deleted = 0;
  let rejectDelete = false;
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.addInitScript(() =>
    sessionStorage.setItem(
      'waterbus.api.session',
      JSON.stringify({ token: 'test-token', portal: 'management' }),
    ),
  );
  await page.route('**/api/v1/**', async (route) => {
    const request = route.request();
    const path = new URL(request.url()).pathname.replace('/api/v1', '');
    let data;
    if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin' };
    else if (path === '/management/accounts') data = { items: accounts, total: accounts.length };
    else if (path === '/staff/orders') data = { items: [], total: 0 };
    else if (path === '/management/accounts/2/status' && request.method() === 'PATCH') {
      accounts[0].trang_thai = request.postDataJSON().status;
      data = accounts[0];
    } else if (path === '/management/accounts/2' && request.method() === 'DELETE') {
      deleted++;
      if (rejectDelete)
        return route.fulfill({
          status: 400,
          json: { message: 'Hãy ngừng hoạt động tài khoản trong Chỉnh sửa trước khi xóa.' },
        });
      accounts.splice(
        accounts.findIndex((a) => a.id === 2),
        1,
      );
      return route.fulfill({ status: 204 });
    } else throw new Error('Unexpected API: ' + request.method() + ' ' + path);
    await route.fulfill({ json: data });
  });
  await page.goto('/admin/users');
  await expect(page.getByRole('button', { name: 'Sửa Khách thử', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Xóa Khách thử', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xóa Nhân viên thử', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Sửa Khách thử', exact: true }).click();
  const editor = page.getByRole('dialog');
  await expect(editor.getByLabel('Đang hoạt động')).toHaveCount(0);
  await editor.getByRole('button', { name: 'Hủy', exact: true }).click();
  const lock = page.getByRole('button', { name: 'Khóa tài khoản Khách thử', exact: true });
  await expect(lock.locator('xpath=preceding-sibling::button[1]')).toHaveAttribute(
    'aria-label',
    'Sửa Khách thử',
  );
  await lock.click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  const unlock = page.getByRole('button', { name: 'Mở khóa tài khoản Khách thử', exact: true });
  await expect(unlock).toBeVisible();
  await unlock.click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  await expect(lock).toBeVisible();
  await expect(page.getByRole('button', { name: 'Xóa Khách thử', exact: true })).toHaveCount(0);
  await lock.click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Xác nhận', exact: true })
    .click();
  const remove = page.getByRole('button', { name: 'Xóa Khách thử', exact: true });
  await expect(remove).toBeVisible();
  const row = remove.locator('xpath=ancestor::tr');
  await expect(row).toContainText('Đã khóa');
  await expect(row.locator('.row-actions button').last()).toHaveAttribute(
    'aria-label',
    'Xóa Khách thử',
  );
  await remove.click();
  const confirmation = page.getByRole('alertdialog');
  await expect(confirmation).toContainText('customer@test.invalid');
  await confirmation.getByRole('button', { name: 'Quay lại', exact: true }).click();
  expect(deleted).toBe(0);
  rejectDelete = true;
  await remove.click();
  await confirmation.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect.poll(() => deleted).toBe(1);
  await expect(confirmation).toBeVisible();
  await expect(page.locator('[data-sonner-toast][data-type="error"]')).toContainText(
    'Hãy ngừng hoạt động',
  );
  rejectDelete = false;
  await confirmation.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(confirmation).toHaveCount(0);
  await expect(page.locator('tbody')).not.toContainText('customer@test.invalid');
  await page.reload();
  await expect(page.locator('tbody')).not.toContainText('customer@test.invalid');
  await page.goto('/admin/customers');
  await expect(page.getByRole('heading', { name: 'Khách hàng', exact: true })).toBeVisible();
  await expect(page.locator('button[title="Xóa tài khoản"]')).toHaveCount(0);
  expect(errors).toEqual([]);
});

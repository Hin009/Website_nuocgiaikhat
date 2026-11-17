import { test, expect } from '@playwright/test';
for (const role of ['KHACH_HANG', 'NHAN_VIEN', 'QUAN_TRI_VIEN']) {
  test(role + ' changes own password with current password and logs in again', async ({ page }) => {
    const management = role !== 'KHACH_HANG';
    const calls = [],
      errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript(
      (portal) =>
        sessionStorage.setItem(
          'waterbus.api.session',
          JSON.stringify({ token: 'own-password-token', portal }),
        ),
      management ? 'management' : 'customer',
    );
    await page.route('**/api/v1/**', async (route) => {
      const request = route.request(),
        path = new URL(request.url()).pathname.replace('/api/v1', '');
      let data = { items: [], total: 0 };
      if (path === '/auth/me')
        data = {
          account: { id: 1, email: 'owner@test.invalid', trang_thai: 'ACTIVE' },
          roles: [role],
          permissions: [],
        };
      else if (path === '/me/profile' || path === '/staff/profile')
        data = { id: 1, ho_ten: 'Owner Test', dien_thoai: '0901234567' };
      else if (path === '/me/addresses' || path.startsWith('/catalog/')) data = [];
      else if (path === '/auth/password' && request.method() === 'PUT') {
        const body = request.postDataJSON();
        calls.push(body);
        if (body.oldPassword !== 'TestPass123!')
          return route.fulfill({ status: 400, json: { message: 'Mật khẩu cũ không đúng' } });
        data = { message: 'Đã đổi mật khẩu, vui lòng đăng nhập lại' };
      }
      await route.fulfill({ json: data });
    });
    await page.goto(management ? '/admin/profile' : '/account');
    const section = page.getByRole('region', { name: 'Đổi mật khẩu của tôi', exact: true });
    await section.getByLabel('Mật khẩu hiện tại', { exact: true }).fill('TestPass123!');
    await expect(section.getByRole('button', { name: 'Hiện mật khẩu', exact: true })).toHaveCount(
      0,
    );
    await expect(
      section.getByRole('button', { name: 'Đổi mật khẩu', exact: true }).locator('svg'),
    ).toHaveCount(0);
    for (const [label, toggleLabel] of [
      ['Mật khẩu hiện tại', 'mật khẩu hiện tại'],
      ['Mật khẩu mới', 'mật khẩu mới'],
      ['Xác nhận mật khẩu mới', 'mật khẩu xác nhận'],
    ]) {
      await section.getByRole('button', { name: 'Hiện ' + toggleLabel, exact: true }).click();
      await expect(section.getByLabel(label, { exact: true })).toHaveAttribute('type', 'text');
      await expect(
        section.getByRole('button', { name: 'Ẩn ' + toggleLabel, exact: true }),
      ).toHaveAttribute('aria-pressed', 'true');
      for (const other of ['Mật khẩu hiện tại', 'Mật khẩu mới', 'Xác nhận mật khẩu mới'].filter(
        (item) => item !== label,
      ))
        await expect(section.getByLabel(other, { exact: true })).toHaveAttribute(
          'type',
          'password',
        );
      await section.getByRole('button', { name: 'Ẩn ' + toggleLabel, exact: true }).click();
      await expect(section.getByLabel(label, { exact: true })).toHaveAttribute('type', 'password');
    }
    if (role === 'KHACH_HANG') {
      await section.screenshot({ path: 'test-results/password-form-desktop.png' });
      await page.setViewportSize({ width: 390, height: 844 });
      await section.screenshot({ path: 'test-results/password-form-mobile.png' });
      await page.setViewportSize({ width: 1280, height: 900 });
    }
    await section.getByLabel('Mật khẩu mới', { exact: true }).fill('short');
    await section.getByLabel('Xác nhận mật khẩu mới', { exact: true }).fill('short');
    await section.getByRole('button', { name: 'Đổi mật khẩu', exact: true }).click();
    await expect(section.getByRole('alert')).toContainText('ít nhất 8');
    await section.getByLabel('Mật khẩu mới', { exact: true }).fill('NewPassword123!');
    await section.getByLabel('Xác nhận mật khẩu mới', { exact: true }).fill('Mismatch123!');
    await section.getByRole('button', { name: 'Đổi mật khẩu', exact: true }).click();
    await expect(section.getByRole('alert')).toContainText('chưa khớp');
    expect(calls).toHaveLength(0);
    await section.getByLabel('Mật khẩu hiện tại', { exact: true }).fill('WrongPass123!');
    await section.getByLabel('Xác nhận mật khẩu mới', { exact: true }).fill('NewPassword123!');
    await section.getByRole('button', { name: 'Đổi mật khẩu', exact: true }).click();
    await expect(section.getByRole('alert')).toContainText('Mật khẩu cũ không đúng');
    await expect(section).toBeVisible();
    await section.getByLabel('Mật khẩu hiện tại', { exact: true }).fill('TestPass123!');
    await section.getByRole('button', { name: 'Đổi mật khẩu', exact: true }).click();
    await expect.poll(() => new URL(page.url()).pathname).toBe(management ? '/admin' : '/login');
    await expect(
      page.getByRole('heading', {
        name: management ? 'Đăng nhập quản lý.' : 'Rất vui gặp lại bạn.',
      }),
    ).toBeVisible();
    expect(calls.at(-1)).toEqual({ oldPassword: 'TestPass123!', newPassword: 'NewPassword123!' });
    expect(await page.evaluate(() => sessionStorage.getItem('waterbus.api.session'))).toBeNull();
    expect(errors).toEqual([]);
  });
}

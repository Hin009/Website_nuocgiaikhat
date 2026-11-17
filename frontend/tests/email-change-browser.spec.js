import { test, expect } from '@playwright/test';
async function setup(page, role = 'KHACH_HANG', options = {}) {
  let email = 'original@test.invalid';
  let target = '';
  let verified = false;
  const calls = [],
    errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(
    (portal) =>
      sessionStorage.setItem(
        'waterbus.api.session',
        JSON.stringify({ token: 'email-test-token', portal }),
      ),
    role === 'KHACH_HANG' ? 'customer' : 'management',
  );
  await page.route('**/api/v1/**', async (route) => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let data = { items: [], total: 0, page: 0, size: 100 };
    if (path === '/auth/me')
      data = { account: { id: 1, email, trang_thai: 'ACTIVE' }, roles: [role], permissions: [] };
    else if (path === '/me/profile' || path === '/staff/profile')
      data = { id: 1, ho_ten: 'Email Test', dien_thoai: '0901234567' };
    else if (path === '/me/addresses' || path.startsWith('/catalog/')) data = [];
    return route.fulfill({ json: data });
  });
  const challengeId = 'd0eccad2-2196-4cd2-8dc0-52c0aef3b631';
  await page.route('**/api/v1/auth/email-change/**', async (route) => {
    const action = new URL(route.request().url()).pathname.split('/').pop();
    const body = route.request().postDataJSON();
    calls.push({ action, body });
    const fail = (message, status = 400) => route.fulfill({ status, json: { message } });
    if (action === 'request-current') {
      if (options.smtpMissing) return fail('Chức năng gửi OTP chưa được cấu hình.', 503);
      verified = false;
      return route.fulfill({
        json: {
          challengeId,
          email,
          expiresInSeconds: 300,
          retryAfterSeconds: 60,
          message: 'Kiểm tra email hiện tại.',
        },
      });
    }
    if (action === 'verify-current') {
      if (body.code !== '123456') return fail('Mã OTP không đúng.');
      verified = true;
      return route.fulfill({ json: { expiresInSeconds: 600 } });
    }
    if (action === 'request-new') {
      if (!verified) return fail('Chưa xác minh email hiện tại.');
      if (options.smtpMissing) return fail('Chức năng gửi OTP chưa được cấu hình.', 503);
      if (body.email === 'taken@test.invalid') return fail('Email mới không khả dụng.', 409);
      target = body.email;
      return route.fulfill({
        json: {
          challengeId,
          email: target,
          expiresInSeconds: 300,
          retryAfterSeconds: 60,
          message: 'Kiểm tra email mới.',
        },
      });
    }
    if (action === 'verify-new') {
      if (body.code !== '654321') return fail('Mã OTP không đúng.');
      email = target;
      return route.fulfill({ json: { email, message: 'Email được thay đổi thành công.' } });
    }
    if (action === 'resend')
      return route.fulfill({
        json: {
          challengeId,
          email: verified ? target : email,
          expiresInSeconds: 300,
          retryAfterSeconds: 60,
          message: 'Đã gửi lại OTP.',
        },
      });
    if (action === 'cancel') return route.fulfill({ json: { message: 'Đã hủy.' } });
    return fail('Unexpected old-email endpoint', 404);
  });
  await page.goto(role === 'KHACH_HANG' ? '/account' : '/admin/profile');
  await page.getByRole('button', { name: 'Thay đổi email', exact: true }).click();
  return { calls, errors };
}
async function verifyCurrent(page) {
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByLabel('Địa chỉ email mới')).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Gửi OTP tới email hiện tại', exact: true }).click();
  await expect(dialog.getByRole('button', { name: /Gửi lại sau/ })).toBeDisabled();
  await dialog.getByLabel('Mã OTP email hiện tại').fill('111111');
  await dialog.getByRole('button', { name: 'Xác minh email hiện tại', exact: true }).click();
  await expect(dialog.getByRole('alert')).toContainText('OTP không đúng');
  await expect(dialog.getByLabel('Địa chỉ email mới')).toHaveCount(0);
  await dialog.getByLabel('Mã OTP email hiện tại').fill('123456');
  await dialog.getByRole('button', { name: 'Xác minh email hiện tại', exact: true }).click();
  await expect(dialog.getByLabel('Địa chỉ email mới')).toBeVisible();
}
for (const role of ['KHACH_HANG', 'NHAN_VIEN', 'QUAN_TRI_VIEN']) {
  test(
    role + ' verifies current email before entering and confirming new email',
    async ({ page }) => {
      const state = await setup(page, role);
      const dialog = page.getByRole('dialog');
      await expect(dialog.getByLabel('Địa chỉ email hiện tại')).toHaveCount(0);
      await expect(dialog.getByLabel('Mã OTP email hiện tại')).toHaveCount(0);
      await verifyCurrent(page);
      await dialog.getByLabel('Địa chỉ email mới').fill('original@test.invalid');
      await dialog.getByRole('button', { name: 'Gửi OTP tới email mới', exact: true }).click();
      await expect(dialog.getByRole('alert')).toContainText('phải khác');
      expect(state.calls.filter((c) => c.action === 'request-new')).toHaveLength(0);
      await dialog.getByLabel('Địa chỉ email mới').fill('taken@test.invalid');
      await dialog.getByRole('button', { name: 'Gửi OTP tới email mới', exact: true }).click();
      await expect(dialog.getByRole('alert')).toContainText('không khả dụng');
      await dialog.getByLabel('Địa chỉ email mới').fill('new-address@test.invalid');
      await dialog.getByRole('button', { name: 'Gửi OTP tới email mới', exact: true }).click();
      expect(state.calls.at(-1)).toEqual({
        action: 'request-new',
        body: {
          email: 'new-address@test.invalid',
          challengeId: 'd0eccad2-2196-4cd2-8dc0-52c0aef3b631',
        },
      });
      await expect(dialog.getByRole('button', { name: /Gửi lại sau/ })).toBeDisabled();
      await expect(page.getByLabel('Email', { exact: true })).toHaveText('or******@test.invalid');
      await dialog.getByLabel('Mã OTP email mới').fill('111111');
      await dialog.getByRole('button', { name: 'Xác nhận đổi email', exact: true }).click();
      await expect(dialog.getByRole('alert')).toContainText('OTP không đúng');
      await dialog.getByLabel('Mã OTP email mới').fill('654321');
      await dialog.getByRole('button', { name: 'Xác nhận đổi email', exact: true }).click();
      await expect(dialog.getByRole('heading')).toHaveText('Email được thay đổi thành công');
      await dialog.getByRole('button', { name: 'Hoàn tất', exact: true }).click();
      await expect(page.getByLabel('Email', { exact: true })).toHaveText(
        'ne*********@test.invalid',
      );
      await page.reload();
      await expect(page.getByLabel('Email', { exact: true })).toHaveText(
        'ne*********@test.invalid',
      );
      expect(
        state.calls.every((c) =>
          ['request-current', 'verify-current', 'request-new', 'verify-new'].includes(c.action),
        ),
      ).toBe(true);
      expect(
        await page.evaluate(() => JSON.stringify({ ...localStorage, ...sessionStorage })),
      ).not.toContain('654321');
      expect(state.errors).toEqual([]);
    },
  );
}
test('email change reports unavailable SMTP before current email verification', async ({
  page,
}) => {
  await setup(page, 'KHACH_HANG', { smtpMissing: true });
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: 'Gửi OTP tới email hiện tại', exact: true }).click();
  await expect(dialog.getByRole('alert')).toContainText('chưa được cấu hình');
  await expect(dialog.getByLabel('Địa chỉ email mới')).toHaveCount(0);
});
test('expired new email codes can be resent and the target can change before confirmation', async ({
  page,
}) => {
  await page.clock.install();
  const state = await setup(page);
  const dialog = page.getByRole('dialog');
  await verifyCurrent(page);
  await dialog.getByLabel('Địa chỉ email mới').fill('new@test.invalid');
  await dialog.getByRole('button', { name: 'Gửi OTP tới email mới', exact: true }).click();
  await page.clock.fastForward(301000);
  await expect(
    dialog.getByRole('button', { name: 'Xác nhận đổi email', exact: true }),
  ).toBeDisabled();
  await dialog.getByRole('button', { name: 'Gửi lại OTP', exact: true }).click();
  await expect(dialog.getByRole('button', { name: /Gửi lại sau/ })).toBeDisabled();
  await dialog.getByRole('button', { name: 'Nhập email mới khác', exact: true }).click();
  await expect(dialog.getByRole('button', { name: /Gửi mã sau/ })).toBeDisabled();
  await page.clock.fastForward(61000);
  await dialog.getByLabel('Địa chỉ email mới').fill('another@test.invalid');
  await dialog.getByRole('button', { name: 'Gửi OTP tới email mới', exact: true }).click();
  expect(state.calls.at(-1).body).toMatchObject({
    email: 'another@test.invalid',
    challengeId: 'd0eccad2-2196-4cd2-8dc0-52c0aef3b631',
  });
  await expect(dialog.getByLabel('Mã OTP email mới')).toBeVisible();
  await dialog.getByRole('button', { name: 'Đóng hộp thoại', exact: true }).click();
  await expect(dialog).toHaveCount(0);
  expect(state.calls.at(-1).action).toBe('cancel');
  await expect(page.getByLabel('Email', { exact: true })).toHaveText('or******@test.invalid');
});

test('current email code expiry can be resent and the verification grant expires', async ({
  page,
}) => {
  await page.clock.install();
  const state = await setup(page);
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: 'Gửi OTP tới email hiện tại', exact: true }).click();
  await page.clock.fastForward(301000);
  await expect(
    dialog.getByRole('button', { name: 'Xác minh email hiện tại', exact: true }),
  ).toBeDisabled();
  await dialog.getByRole('button', { name: 'Gửi lại OTP', exact: true }).click();
  await dialog.getByLabel('Mã OTP email hiện tại').fill('123456');
  await dialog.getByRole('button', { name: 'Xác minh email hiện tại', exact: true }).click();
  await page.clock.fastForward(601000);
  await expect(dialog.getByRole('alert')).toContainText('đã hết hạn');
  await expect(dialog.getByLabel('Địa chỉ email mới')).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Bắt đầu lại', exact: true }).click();
  expect(state.calls.at(-1).action).toBe('cancel');
  await expect(
    dialog.getByRole('button', { name: 'Gửi OTP tới email hiện tại', exact: true }),
  ).toBeVisible();
});

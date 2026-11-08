import { test, expect } from '@playwright/test';

const challengeId = 'ca0cf91a-4417-41dd-a33a-11ec5c29b83e';
const resetToken = 'a'.repeat(43);
test('customer verifies OTP before setting password, then returns to login', async ({ page }) => {
  const calls = [];
  await page.route('**/api/v1/auth/password-reset/**', async (route) => {
    const action = new URL(route.request().url()).pathname.split('/').pop();
    const body = route.request().postDataJSON();
    calls.push({ action, body });
    if (action === 'request')
      return route.fulfill({
        json: {
          challengeId,
          retryAfterSeconds: 60,
          expiresInSeconds: 300,
          message: 'Nếu email phù hợp, mã OTP sẽ được gửi.',
        },
      });
    if (action === 'verify')
      return body.code === '123456'
        ? route.fulfill({ json: { resetToken, expiresInSeconds: 300 } })
        : route.fulfill({ status: 400, json: { message: 'OTP không hợp lệ hoặc hết hạn.' } });
    return route.fulfill({ json: { message: 'Đã đổi mật khẩu.' } });
  });
  await page.goto('/login');
  await page.getByRole('link', { name: 'Quên mật khẩu?' }).click();
  await expect(page.locator('input[type="password"]')).toHaveCount(0);
  await page.getByLabel('Email đăng ký').fill('customer@test.invalid');
  await page.getByRole('button', { name: 'Gửi mã OTP' }).click();
  await expect(page.getByRole('button', { name: /Gửi lại sau/ })).toBeDisabled();
  await page.getByLabel('Mã OTP').fill('111111');
  await page.getByRole('button', { name: 'Xác minh OTP' }).click();
  await expect(page.getByRole('alert')).toContainText('OTP không hợp lệ');
  await expect(page.locator('input[type="password"]')).toHaveCount(0);
  await page.getByLabel('Mã OTP').fill('123456');
  await page.getByRole('button', { name: 'Xác minh OTP' }).click();
  await page.getByLabel('Mật khẩu mới', { exact: true }).fill('NewPassword123!');
  await page.getByLabel('Xác nhận mật khẩu mới').fill('DoesNotMatch123!');
  await page.getByRole('button', { name: 'Lưu mật khẩu mới' }).click();
  await expect(page.getByRole('alert')).toContainText('chưa khớp');
  expect(calls.filter((c) => c.action === 'complete')).toHaveLength(0);
  await page.getByLabel('Xác nhận mật khẩu mới').fill('NewPassword123!');
  await page.getByRole('button', { name: 'Lưu mật khẩu mới' }).click();
  await expect(page).toHaveURL(/\/login$/);
  expect(calls.at(-1)).toEqual({
    action: 'complete',
    body: { challengeId, resetToken, newPassword: 'NewPassword123!' },
  });
  expect(await page.evaluate(() => JSON.stringify(localStorage))).not.toContain(resetToken);
});

test('missing SMTP configuration keeps the customer on email step', async ({ page }) => {
  await page.route('**/api/v1/auth/password-reset/request', (route) =>
    route.fulfill({ status: 503, json: { message: 'Chức năng gửi OTP chưa được cấu hình.' } }),
  );
  await page.goto('/forgot-password');
  await page.getByLabel('Email đăng ký').fill('customer@test.invalid');
  await page.getByRole('button', { name: 'Gửi mã OTP' }).click();
  await expect(page.getByRole('alert')).toContainText('chưa được cấu hình');
  await expect(page.getByLabel('Email đăng ký')).toBeVisible();
  await expect(page.locator('input[type="password"]')).toHaveCount(0);
});

test('verified password form expires after five minutes', async ({ page }) => {
  await page.clock.install();
  await page.route('**/api/v1/auth/password-reset/**', (route) =>
    route.fulfill({
      json: route.request().url().endsWith('/request')
        ? { challengeId, retryAfterSeconds: 60, expiresInSeconds: 300, message: 'Kiểm tra email.' }
        : { resetToken, expiresInSeconds: 300 },
    }),
  );
  await page.goto('/forgot-password');
  await page.getByLabel('Email đăng ký').fill('customer@test.invalid');
  await page.getByRole('button', { name: 'Gửi mã OTP' }).click();
  await page.getByLabel('Mã OTP').fill('123456');
  await page.getByRole('button', { name: 'Xác minh OTP' }).click();
  await expect(page.getByLabel('Mật khẩu mới', { exact: true })).toBeVisible();
  await page.clock.fastForward(301000);
  await expect(page.getByRole('alert')).toContainText('hết hạn');
  await expect(page.getByLabel('Email đăng ký')).toBeVisible();
  await expect(page.locator('input[type="password"]')).toHaveCount(0);
});

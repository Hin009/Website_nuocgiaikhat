import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
const provinces = JSON.parse(
  readFileSync(new URL('../src/data/vietnam-addresses.json', import.meta.url), 'utf8'),
);

for (const role of ['QUAN_TRI_VIEN', 'NHAN_VIEN']) {
  test(`${role} saves and reloads a structured address`, async ({ page }) => {
    const errors = [],
      unexpected = [],
      saves = [];
    const city = provinces[0],
      ward = city.wards[0],
      nextCity = provinces[1],
      nextWard = nextCity.wards[0];
    const user = {
      account: { id: 1, email: 'profile@test.invalid', trang_thai: 'ACTIVE' },
      roles: [role],
      permissions: ['STAFF_SELF', 'ORDER_UPDATE'],
    };
    const profile = {
      id: 1,
      ho_ten: 'Người kiểm thử',
      dien_thoai: '0901234567',
      dia_chi: `12 Đường cũ, ${ward.name}, ${city.name}`,
      ngay_sinh: '1995-05-06',
      gioi_tinh: 'NAM',
    };
    page.on('pageerror', (e) => errors.push(e.message));
    await page.route('**/api/v1/**', async (route) => {
      const req = route.request(),
        path = new URL(req.url()).pathname.replace('/api/v1', '');
      let data;
      if (path === '/auth/login') data = { accessToken: 'test-token', user };
      else if (path === '/auth/me') data = user;
      else if (path === '/staff/profile') {
        if (req.method() === 'PUT') {
          const body = req.postDataJSON();
          saves.push(body);
          Object.assign(profile, {
            ho_ten: body.fullName,
            dien_thoai: body.phone,
            dia_chi: body.address,
          });
        }
        data = profile;
      } else if (path === '/staff/orders') data = { items: [], total: 0, page: 0, size: 100 };
      else {
        unexpected.push(req.method() + ' ' + path);
        await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
        return;
      }
      await route.fulfill({ status: 200, json: data });
    });
    await page.goto('/admin/profile');
    await page.getByLabel('Địa chỉ email').fill('profile@test.invalid');
    await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
    await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
    const province = page.getByLabel('Tỉnh/Thành phố', { exact: true });
    const wardSelect = page.getByLabel('Phường/Xã', { exact: true });
    await expect(province).toHaveValue(city.code);
    await expect(wardSelect).toHaveValue(ward.code);
    await expect(page.getByLabel('Số nhà, tên đường')).toHaveValue('12 Đường cũ');
    await province.selectOption(nextCity.code);
    await expect(wardSelect).toHaveValue('');
    await page.getByRole('button', { name: 'Lưu thông tin', exact: true }).click();
    expect(saves).toHaveLength(0);
    await wardSelect.selectOption(nextWard.code);
    await page.getByLabel('Số nhà, tên đường').fill('99 Đường mới');
    await page.getByRole('button', { name: 'Lưu thông tin', exact: true }).click();
    await expect.poll(() => saves.length).toBe(1);
    expect(saves[0]).toMatchObject({
      address: `99 Đường mới, ${nextWard.name}, ${nextCity.name}`,
      birthDate: '1995-05-06',
      gender: 'NAM',
    });
    await page.reload();
    await expect(province).toHaveValue(nextCity.code);
    await expect(wardSelect).toHaveValue(nextWard.code);
    await expect(page.getByLabel('Số nhà, tên đường')).toHaveValue('99 Đường mới');
    expect(unexpected).toEqual([]);
    expect(errors).toEqual([]);
  });
}

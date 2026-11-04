import { test, expect } from '@playwright/test';
async function login(page, role = 'Khách hàng') {
  await page.goto(role === 'Khách hàng' ? '/login' : '/admin');
  await page.getByRole('button', { name: role, exact: true }).click();
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  if (role === 'Khách hàng') await expect(page).not.toHaveURL(/login/);
  else await expect(page.locator('.admin-shell')).toBeVisible();
}
test.beforeEach(async ({ page }) => {
  await page.context().route('https://fonts.googleapis.com/**', (route) => route.abort());
  await page.context().route('https://fonts.gstatic.com/**', (route) => route.abort());
});
test('Trang chủ và responsive ở 360, 768, 1024, 1440px', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Một ngụm tươi mới.');
  await expect(page.locator('.product-card')).toHaveCount(12);
  for (const width of [360, 768, 1024, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect
      .poll(() =>
        page.evaluate(() => ({
          fits: document.documentElement.scrollWidth <= window.innerWidth,
          width: window.innerWidth,
          scrollWidth: document.documentElement.scrollWidth,
          path: location.pathname,
          offenders: [...document.querySelectorAll('body *')]
            .filter((e) => e.getBoundingClientRect().right > window.innerWidth + 1)
            .slice(0, 8)
            .map((e) => ({
              tag: e.tagName,
              cls: e.className,
              right: e.getBoundingClientRect().right,
              width: e.getBoundingClientRect().width,
            })),
        })),
      )
      .toMatchObject({ fits: true });
    await page.screenshot({ path: 'docs/screenshots/home-' + width + '.png', fullPage: true });
  }
  expect(errors).toEqual([]);
});
test('Tìm kiếm bỏ dấu, lọc và xem chi tiết sản phẩm', async ({ page }) => {
  await page.goto('/products?q=tra&category=tea');
  await expect(page.locator('.product-card')).toHaveCount(3);
  await page.getByLabel('Tìm kiếm sản phẩm', { exact: true }).fill('khong do');
  await expect(page.locator('.product-card')).toHaveCount(1);
  await page.locator('.product-name').click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Trà xanh không độ');
  await page.getByRole('tab', { name: 'Thông tin chi tiết' }).click();
  await expect(page.getByRole('definition').filter({ hasText: 'Không Độ' })).toBeVisible();
});
test('Giỏ hàng → đăng nhập → tạo đơn → xem và hủy đơn', async ({ page }) => {
  await page.goto('/products/p01');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.getByRole('link', { name: 'Xem giỏ hàng', exact: true }).click();
  await expect(page.locator('.cart-item')).toHaveCount(1);
  await page.getByRole('button', { name: 'Tăng số lượng' }).click();
  await page.getByRole('link', { name: 'Tiến hành đặt đơn' }).click();
  await expect(page).toHaveURL(/login/);
  await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL(/checkout/);
  await page.getByRole('button', { name: 'Tạo đơn hàng' }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Đã lưu đơn của bạn.' })).toBeVisible();
  await page.getByRole('link', { name: 'Xem đơn' }).click();
  await expect(page.locator('.summary-total')).toHaveCount(0);
  await page.getByRole('button', { name: 'Hủy đơn hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByText('Vui lòng nhập lý do hủy.', { exact: true })).toBeVisible();
  await page.getByLabel('Lý do hủy đơn').fill('Thử nghiệm hủy đơn');
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('alertdialog')).toHaveCount(0);
  await expect(page.locator('.status-cancelled')).toBeVisible();
});
test('STAFF được vào vận hành nhưng bị chặn trang tài khoản quản trị', async ({ page }) => {
  await login(page, 'Nhân viên');
  await expect(page).toHaveURL(/admin$/);
  await expect(page.locator('.admin-sidebar a[href="/admin/products"]')).toHaveCount(0);
  await page.goto('/admin/products');
  await expect(page).toHaveURL(/unauthorized/);
  await page.goto('/admin/users');
  await expect(page).toHaveURL(/unauthorized/);
  await expect(page.getByRole('heading', { name: 'Bạn chưa có quyền truy cập' })).toBeVisible();
});
test('ADMIN kế thừa quyền STAFF, thêm danh mục và sản phẩm có validation', async ({ page }) => {
  await login(page, 'Quản trị');
  await page.goto('/admin/categories');
  await page.getByRole('button', { name: 'Thêm danh mục', exact: true }).click();
  await page.getByRole('button', { name: 'Lưu danh mục' }).click();
  await expect(page.getByText('Tên cần ít nhất 2 ký tự.', { exact: true })).toBeVisible();
  await page.getByLabel('Tên danh mục').fill('Đồ uống thử nghiệm');
  await page.getByRole('button', { name: 'Lưu danh mục' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByText('Đồ uống thử nghiệm', { exact: true })).toBeVisible();
  await page.goto('/admin/products');
  await page.getByRole('button', { name: 'Thêm sản phẩm', exact: true }).click();
  await page.getByLabel('Tên sản phẩm').fill('Nước mới');
  await page.getByLabel('Thương hiệu', { exact: true }).fill('WaterBus');
  await page.getByRole('button', { name: 'Lưu sản phẩm' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.getByLabel('Tìm sản phẩm quản lý').fill('nuoc moi');
  await expect(page.getByText('Nước mới', { exact: true })).toBeVisible();
  await page.goto('/admin/users');
  await expect(page.getByRole('heading', { name: 'Tài khoản & nhân viên' })).toBeVisible();
});
test('Nhập kho và chuyển trạng thái đơn cập nhật được', async ({ page }) => {
  await login(page, 'Quản trị');
  await page.goto('/admin/stock-receipts');
  await page.getByRole('button', { name: 'Tạo phiếu nhập', exact: true }).first().click();
  await page.getByLabel('Sản phẩm', { exact: true }).selectOption('p01');
  await page.getByLabel('Nhà cung cấp').fill('Nhà cung cấp trải nghiệm');
  await page.getByRole('button', { name: 'Kiểm tra phiếu nhập' }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByRole('cell', { name: 'Nhà cung cấp trải nghiệm' })).toBeVisible();
  await page.goto('/admin/orders/WB1027');
  await page.getByRole('button', { name: 'Xác nhận đơn', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.locator('.status-confirmed')).toBeVisible();
});
test('Các màn hình quản lý responsive và không có lỗi runtime', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await login(page, 'Quản trị');
  for (const path of [
    '/admin',
    '/admin/products',
    '/admin/categories',
    '/admin/orders',
    '/admin/stock-receipts',
    '/admin/customers',
    '/admin/users',
    '/admin/reports',
  ]) {
    await page.goto(path);
    await expect(page.locator('.admin-main h1')).toBeVisible();
    await expect(page.getByRole('status').filter({ hasText: 'Đang tải dữ liệu' })).toHaveCount(0);
    for (const width of [360, 768, 1280]) {
      await page.setViewportSize({ width, height: 1000 });
      await expect
        .poll(() =>
          page.evaluate(() => ({
            fits: document.documentElement.scrollWidth <= window.innerWidth,
            width: window.innerWidth,
            scrollWidth: document.documentElement.scrollWidth,
            path: location.pathname,
            offenders: [...document.querySelectorAll('body *')]
              .filter((e) => e.getBoundingClientRect().right > window.innerWidth + 1)
              .slice(0, 8)
              .map((e) => ({
                tag: e.tagName,
                cls: e.className,
                right: e.getBoundingClientRect().right,
                width: e.getBoundingClientRect().width,
              })),
          })),
        )
        .toMatchObject({ fits: true });
    }
    if (path === '/admin')
      await page.screenshot({ path: 'docs/screenshots/dashboard-desktop.png', fullPage: true });
  }
  expect(errors).toEqual([]);
});
test('Điện thoại mở menu, lọc và sidebar quản lý', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.getByRole('button', { name: 'Mở menu', exact: true }).click();
  await page.getByRole('link', { name: 'Tất cả sản phẩm', exact: true }).first().click();
  await page.getByRole('button', { name: 'Lọc', exact: true }).click();
  await page.getByRole('radio', { name: /Nước ngọt/ }).click();
  await expect(page.getByRole('radio', { name: /Nước ngọt/ })).toBeChecked();
  await page.getByRole('button', { name: 'Đóng bộ lọc' }).click();
  await expect(page.locator('.product-card')).toHaveCount(4);
  await page.screenshot({ path: 'docs/screenshots/catalog-mobile.png', fullPage: true });
  await login(page, 'Quản trị');
  await page.getByRole('button', { name: 'Mở menu quản lý' }).click();
  await page
    .locator('.admin-sidebar')
    .getByRole('link', { name: 'Đặt hàng & nhập hàng', exact: true })
    .click();
  await expect(page.getByRole('heading', { name: 'Quản lý nhập hàng' })).toBeVisible();
});

test('Đăng ký có validation và chỉ tạo vai trò khách hàng', async ({ page }) => {
  await page.goto('/register');
  await page.getByLabel('Họ và tên').fill('Khách Trải Nghiệm');
  await page.getByLabel('Địa chỉ email').fill('moi@waterbus.demo');
  await page.getByLabel('Số điện thoại').fill('0909876543');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('ThuNghiem@123');
  await page.getByLabel('Nhập lại mật khẩu').fill('KhongKhop@123');
  await page.getByRole('button', { name: 'Tạo tài khoản' }).click();
  await expect(page.getByText('Mật khẩu xác nhận chưa khớp.')).toBeVisible();
  await page.getByLabel('Nhập lại mật khẩu').fill('ThuNghiem@123');
  await page.getByRole('button', { name: 'Tạo tài khoản' }).click();
  await expect(page).toHaveURL('/');
  await page.goto('/admin');
  await expect(page).toHaveURL(/admin/);
});
test('Tạo nhân viên với xác nhận, đăng nhập tài khoản mới và chặn tự khóa ADMIN', async ({
  page,
}) => {
  await login(page, 'Quản trị');
  await page.goto('/admin/users');
  await page.getByRole('button', { name: 'Sửa Lê Ngọc An', exact: true }).click();
  await page.getByLabel('Đang hoạt động').uncheck();
  await page.getByRole('button', { name: 'Lưu tài khoản' }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(
    page.getByText('Không thể khóa hoặc hạ quyền tài khoản đang sử dụng.', { exact: true }),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Hủy', exact: true }).click();
  await page.getByRole('button', { name: 'Thêm tài khoản' }).click();
  await page.getByLabel('Họ tên', { exact: true }).fill('Nhân Viên Mới');
  await page.getByLabel('Email', { exact: true }).fill('staffmoi@waterbus.demo');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('NhanVien@123');
  await page.getByRole('button', { name: 'Lưu tài khoản' }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByRole('cell', { name: 'staffmoi@waterbus.demo' })).toBeVisible();
  await page.getByRole('button', { name: /Đăng xuất/ }).click();
  await page.goto('/admin');
  await page.getByLabel('Địa chỉ email').fill('staffmoi@waterbus.demo');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('NhanVien@123');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL('/admin');
});

test('Separate customer and management login portals', async ({ page }) => {
  await page.goto('/admin/orders');
  await expect(page).toHaveURL(/admin\?redirect=/);
  await expect(page.getByRole('button', { name: 'Khách hàng', exact: true })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Đăng ký ngay' })).toHaveCount(0);
  await page.getByRole('button', { name: 'Nhân viên', exact: true }).click();
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL('/admin/orders');
  await page.getByRole('button', { name: /Đăng xuất/ }).click();
  await expect(page).toHaveURL(/admin/);
  await page.goto('/login');
  await expect(page.getByRole('button', { name: 'Nhân viên', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Quản trị', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Khách hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page).toHaveURL('/');
  await page.goto('/admin');
  await expect(page).toHaveURL(/admin/);
});

test('Management entry requires login at the root URL', async ({ page }) => {
  await page.goto('/quan-ly');
  await expect(page).toHaveURL('/admin');
  await expect(page.getByRole('heading', { name: 'Đăng nhập quản lý.' })).toBeVisible();
  await expect(page.locator('.admin-shell')).toHaveCount(0);
  await page.getByLabel('Địa chỉ email').fill('khach@waterbus.demo');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('Demo@123');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('nhân viên và quản trị viên');
  await expect(page.locator('.admin-shell')).toHaveCount(0);
  await page.getByRole('button', { name: 'Quản trị', exact: true }).click();
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await expect(page.locator('.admin-shell')).toBeVisible();
  await expect(page).toHaveURL('/admin');
  await page.reload();
  await expect(page.locator('.admin-shell')).toBeVisible();
  await page.getByRole('button', { name: /Đăng xuất/ }).click();
  await expect(page).toHaveURL('/admin');
  await expect(page.getByRole('heading', { name: 'Đăng nhập quản lý.' })).toBeVisible();
  await expect(page.locator('.admin-shell')).toHaveCount(0);
});

for (const role of ['Nhân viên', 'Quản trị']) {
  test(`Management profile and logo navigation: ${role}`, async ({ page }) => {
    await login(page, role);
    await expect(page.getByRole('link', { name: 'Xem cửa hàng', exact: true })).toHaveCount(0);
    await page.getByRole('link', { name: 'Thông tin cá nhân', exact: true }).click();
    await expect(page).toHaveURL('/admin/profile');
    await expect(page.getByRole('heading', { name: 'Thông tin tài khoản' })).toBeVisible();
    await expect(page.getByLabel('Email', { exact: true })).toHaveValue(
      role === 'Nhân viên' ? 'nhanvien@waterbus.demo' : 'admin@waterbus.demo',
    );
    await page.getByLabel('Họ và tên').fill(role + ' Cập Nhật');
    await page.getByRole('button', { name: 'Lưu thông tin', exact: true }).click();
    await expect(page.getByText('Đã lưu thông tin', { exact: true })).toBeVisible();
    await page.reload();
    await expect(page.getByLabel('Họ và tên')).toHaveValue(role + ' Cập Nhật');
    await page.getByRole('link', { name: 'WaterBus - Tổng quan quản lý', exact: true }).click();
    await expect(page).toHaveURL('/admin');
    await expect(page.locator('.admin-shell')).toBeVisible();
  });
}

test('Package selection, direct quantity entry and selective checkout', async ({ page }) => {
  await login(page);
  await page.goto('/products/p01');
  await page.getByLabel('Đơn vị mua').selectOption('pack');
  await page.getByRole('spinbutton', { name: 'Số lượng', exact: true }).fill('2');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.getByLabel('Đơn vị mua').selectOption('case');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.getByLabel('Đơn vị mua').selectOption('single');
  await page.getByRole('spinbutton', { name: 'Số lượng', exact: true }).fill('3');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.goto('/products/p02');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.goto('/cart');
  await expect(page.locator('.cart-item')).toHaveCount(4);
  await page.getByRole('checkbox', { name: /Chọn tất cả/ }).uncheck();
  await expect(page.getByRole('button', { name: 'Chọn sản phẩm để đặt hàng' })).toBeDisabled();
  await expect(page.locator('.summary-total')).toContainText('0');
  await page
    .getByRole('checkbox', { name: 'Chọn Coca-Cola nguyên bản - Lốc', exact: true })
    .check();
  await page
    .getByRole('checkbox', { name: 'Chọn Coca-Cola nguyên bản - Thùng', exact: true })
    .check();
  await expect(page.locator('.summary-total')).toContainText('352.640');
  await page.reload();
  await expect(
    page.getByRole('checkbox', { name: 'Chọn Coca-Cola nguyên bản - Lon', exact: true }),
  ).not.toBeChecked();
  await page.getByRole('link', { name: 'Tiến hành đặt đơn', exact: true }).click();
  await expect(page.locator('.checkout-line')).toHaveCount(2);
  await expect(page.locator('.checkout-line').first()).toContainText('2 lốc');
  await expect(page.locator('.summary-total')).toContainText('352.640');
  await page.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Đã lưu đơn của bạn.' })).toBeVisible();
  await page.goto('/cart');
  await expect(page.locator('.cart-item')).toHaveCount(2);
  await expect(
    page.getByRole('checkbox', { name: 'Chọn Coca-Cola nguyên bản - Lon', exact: true }),
  ).not.toBeChecked();
  await expect(
    page.getByRole('checkbox', { name: 'Chọn Nước cam ép Twister - Chai', exact: true }),
  ).not.toBeChecked();
});

test('Cart numeric quantity validation and mobile selection', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/products/p01');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.goto('/cart');
  const quantity = page.getByRole('spinbutton', { name: 'Số lượng', exact: true });
  await quantity.fill('15');
  await quantity.blur();
  await expect(page.locator('.cart-line-total')).toContainText('165.000');
  await quantity.fill('0');
  await quantity.blur();
  await expect(quantity).toHaveValue('1');
  await quantity.fill('999');
  await quantity.blur();
  await expect(quantity).toHaveValue('240');
  await page.getByRole('checkbox', { name: /Chọn tất cả/ }).uncheck();
  await expect(page.getByRole('button', { name: 'Chọn sản phẩm để đặt hàng' })).toBeDisabled();
  await page.getByRole('checkbox', { name: /Chọn tất cả/ }).check();
  await expect(page.getByRole('link', { name: 'Tiến hành đặt đơn' })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('Customer order details expand inline with only one order open', async ({ page }) => {
  await login(page);
  await page.goto('/account/orders');
  const toggles = page.locator('.order-expand');
  const details = page.locator('.order-inline-details');
  await expect(toggles).toHaveCount(8);
  await expect(details).toHaveCount(0);
  const firstId = await toggles.first().getAttribute('aria-controls');
  await toggles.first().click();
  await expect(page).toHaveURL('/account/orders');
  await expect(details).toHaveCount(1);
  await expect(details).toHaveAttribute('id', firstId);
  await expect(details.getByRole('heading', { name: 'Sản phẩm trong đơn' })).toBeVisible();
  await expect(details.getByRole('heading', { name: 'Thông tin nhận hàng' })).toBeVisible();
  await toggles.nth(1).click();
  await expect(details).toHaveCount(1);
  await expect(details).toHaveAttribute('id', await toggles.nth(1).getAttribute('aria-controls'));
  await expect(toggles.first()).toHaveAttribute('aria-expanded', 'false');
  await toggles.nth(1).click();
  await expect(details).toHaveCount(0);
  await page.locator('.order-toggle').first().focus();
  await page.keyboard.press('Enter');
  await expect(details).toBeVisible();
  await page.getByLabel('Lọc trạng thái').selectOption('PENDING');
  await expect(details).toHaveCount(0);
  await toggles.first().click();
  await details.getByRole('button', { name: 'Hủy đơn hàng', exact: true }).click();
  await page.getByLabel('Lý do hủy đơn').fill('Kiểm tra hủy đơn từ danh sách');
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('alertdialog')).toHaveCount(0);
  await expect(details).toHaveCount(0);
  await page.getByLabel('Lọc trạng thái').selectOption('');
  await toggles.first().click();
  await page.getByLabel('Tìm đơn hàng').fill('WB1027');
  await expect(details).toHaveCount(0);
  await page.getByLabel('Tìm đơn hàng').fill('');
  for (const width of [1440, 768, 360]) {
    await page.setViewportSize({ width, height: 1000 });
    await toggles.first().click();
    await expect(details).toBeVisible();
    await expect
      .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
      .toBe(true);
    await toggles.first().click();
  }
  await expect(page).toHaveURL('/account/orders');
});

test('Customer profile saves dependent province and ward selections', async ({ page }) => {
  await login(page);
  await page.goto('/account');
  const province = page.getByLabel('Tỉnh/Thành phố', { exact: true });
  const ward = page.getByLabel('Phường/Xã', { exact: true });
  const street = page.getByLabel('Số nhà, tên đường', { exact: true });
  const save = page.getByRole('button', { name: 'Lưu thông tin', exact: true });
  await expect(province.locator('option')).toHaveCount(35);
  await expect(province).toHaveValue('79');
  await expect(street).toHaveValue('12 Nguyễn Huệ');
  await expect(ward).toHaveValue('');
  await save.click();
  await expect(page.getByText('Vui lòng chọn phường/xã.', { exact: true })).toBeVisible();
  await ward.selectOption({ index: 1 });
  await province.selectOption('1');
  await expect(ward).toHaveValue('');
  await ward.selectOption({ index: 1 });
  const selectedWardCode = await ward.inputValue();
  const wardName = await ward.locator('option:checked').textContent();
  const provinceName = await province.locator('option:checked').textContent();
  await street.fill('25 Đường Hoa');
  await save.click();
  await expect(page.getByText('Đã lưu thông tin', { exact: true })).toBeVisible();
  await page.reload();
  await expect(province).toHaveValue('1');
  await expect(ward).toHaveValue(selectedWardCode);
  await expect(street).toHaveValue('25 Đường Hoa');
  for (const width of [360, 768, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect
      .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
      .toBe(true);
  }
  await page.goto('/products/p01');
  await page.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await page.goto('/checkout');
  await expect(page.getByLabel('Địa chỉ giao hàng', { exact: true })).toHaveValue(
    `25 Đường Hoa, ${wardName}, ${provinceName}`,
  );
  await page.goto('/account');
  await province.selectOption('');
  await expect(ward).toBeDisabled();
  await expect(ward).toHaveValue('');
  await save.click();
  await expect(page.getByText('Vui lòng chọn tỉnh/thành phố.', { exact: true })).toBeVisible();
});

test('Checkout vouchers disable ineligible offers and save the applied discount', async ({
  page,
}) => {
  await login(page);
  await page.evaluate(() =>
    localStorage.setItem(
      'waterbus.cart',
      JSON.stringify([{ productId: 'p01', unit: 'single', quantity: 50, selected: true }]),
    ),
  );
  await page.goto('/checkout');
  await page.reload();
  const orderVoucher = page.getByRole('radio', { name: 'Sử dụng voucher DONHANG20', exact: true });
  const shippingVoucher = page.getByRole('radio', {
    name: 'Sử dụng voucher FREESHIP200',
    exact: true,
  });
  await expect(orderVoucher).toBeEnabled();
  await expect(shippingVoucher).toBeEnabled();
  await expect(page.locator('#voucher-conditions-FREESHIP200')).toContainText('Cần chọn voucher');
  await expect(page.locator('.summary-total strong')).toContainText('570.000');
  await shippingVoucher.check();
  await expect(page.locator('.summary-total strong')).toContainText('550.000');
  await expect(page.locator('.summary-shipping-discount')).toContainText('20.000');
  await page.getByRole('radio', { name: 'Không sử dụng voucher', exact: true }).check();
  const originalTotal = await page.locator('.summary-total strong').textContent();
  await orderVoucher.check();
  await expect(page.locator('.summary-discount')).toContainText('110.000');
  const discountedTotal = await page.locator('.summary-total strong').textContent();
  await page.getByRole('radio', { name: 'Không sử dụng voucher', exact: true }).check();
  await expect(page.locator('.summary-discount')).toHaveCount(0);
  await expect(page.locator('.summary-total strong')).toHaveText(originalTotal);
  await orderVoucher.check();
  for (const width of [360, 768, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await expect
      .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
      .toBe(true);
  }
  await page.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await expect(page.getByRole('alertdialog')).toContainText('DONHANG20');
  await expect(page.getByRole('alertdialog')).toContainText(discountedTotal);
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Đã lưu đơn của bạn.' })).toBeVisible();
  const order = await page.evaluate(
    () => JSON.parse(localStorage.getItem('waterbus.mock.v1')).orders[0],
  );
  expect(order).toMatchObject({ voucherCode: 'DONHANG20', discountAmount: 110000, total: 460000 });
  await page.getByRole('link', { name: 'Xem đơn', exact: true }).click();
  await expect(page.locator('.order-discount')).toContainText('DONHANG20');
  await expect(page.locator('.order-totals p').last()).toContainText(discountedTotal);
});

test('Checkout vouchers recalculate eligibility from selected cart items', async ({ page }) => {
  await login(page);
  await page.evaluate(() =>
    localStorage.setItem(
      'waterbus.cart',
      JSON.stringify([
        { productId: 'p01', unit: 'single', quantity: 20, selected: true },
        { productId: 'p02', unit: 'single', quantity: 30, selected: false },
      ]),
    ),
  );
  await page.goto('/checkout');
  await page.reload();
  const orderVoucher = page.getByRole('radio', { name: 'Sử dụng voucher DONHANG20', exact: true });
  const shippingVoucher = page.getByRole('radio', {
    name: 'Sử dụng voucher FREESHIP200',
    exact: true,
  });
  await expect(orderVoucher).toBeDisabled();
  await expect(page.locator('#voucher-conditions-DONHANG20')).toContainText(
    'Chưa đủ điều kiện sử dụng.',
  );
  await expect(page.locator('#voucher-conditions-DONHANG20')).toContainText('500.000');
  await expect(page.locator('#voucher-conditions-DONHANG20')).toContainText('Cần mua thêm');
  await expect(shippingVoucher).toBeEnabled();
  await shippingVoucher.check();
  await expect(page.locator('.summary-shipping-discount')).toContainText('20.000');
  await expect(page.locator('.summary-total strong')).toContainText('220.000');
  await page.goto('/cart');
  await page.getByRole('checkbox', { name: /Chọn tất cả/ }).check();
  await page.getByRole('link', { name: 'Tiến hành đặt đơn', exact: true }).click();
  await expect(orderVoucher).toBeEnabled();
  await expect(shippingVoucher).toBeEnabled();
});

test('Checkout saves a shipping voucher and shows its reduction in order details', async ({
  page,
}) => {
  await login(page);
  await page.evaluate(() =>
    localStorage.setItem(
      'waterbus.cart',
      JSON.stringify([{ productId: 'p01', unit: 'single', quantity: 20, selected: true }]),
    ),
  );
  await page.goto('/checkout');
  await page.reload();
  await page.getByRole('radio', { name: 'Sử dụng voucher FREESHIP200', exact: true }).check();
  await page.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await page.getByRole('link', { name: 'Xem đơn', exact: true }).click();
  await expect(page.locator('.order-shipping-discount')).toContainText('FREESHIP200');
  await expect(page.locator('.order-totals p').last()).toContainText('220.000');
});

async function setCocaStock(page, stock) {
  await page.goto('/admin/products');
  await page.getByLabel('Tìm sản phẩm quản lý').fill('Coca-Cola');
  await page.getByRole('button', { name: 'Sửa Coca-Cola nguyên bản', exact: true }).click();
  await page.getByLabel('Số lượng tồn kho', { exact: true }).fill(String(stock));
  await page.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
}

test('Purchasing reserves inventory immediately and synchronizes low stock across customer and admin tabs', async ({
  page,
}) => {
  test.setTimeout(90000);
  await login(page, 'Quản trị');
  await setCocaStock(page, 21);
  const customerPage = await page.context().newPage();
  await login(customerPage);
  await customerPage.goto('/products/p01');
  await customerPage.getByRole('button', { name: 'Thêm vào giỏ hàng', exact: true }).click();
  await customerPage.goto('/checkout');
  await customerPage.getByRole('button', { name: 'Tạo đơn hàng', exact: true }).click();
  await customerPage.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(customerPage.getByRole('heading', { name: 'Đã lưu đơn của bạn.' })).toBeVisible();
  const row = page.getByRole('row').filter({ hasText: 'Coca-Cola nguyên bản' });
  await expect(row).toContainText('Sắp hết hàng');
  await expect(row.getByRole('cell').nth(3)).toContainText('20');
  await customerPage.goto('/products?q=Coca-Cola');
  const card = customerPage.locator('.product-card').filter({ hasText: 'Coca-Cola nguyên bản' });
  await expect(card).toHaveClass(/is-unavailable/);
  await expect(card.getByText('Tạm hết hàng')).toBeVisible();
  await expect(card.getByRole('button')).toBeDisabled();
  await customerPage.goto('/products/p01');
  await expect(
    customerPage.getByRole('button', { name: 'Tạm hết hàng', exact: true }),
  ).toBeDisabled();
  await customerPage.evaluate(() =>
    localStorage.setItem(
      'waterbus.cart',
      JSON.stringify([{ productId: 'p01', unit: 'single', quantity: 1, selected: true }]),
    ),
  );
  await customerPage.goto('/cart');
  await customerPage.reload();
  await expect(customerPage.locator('.cart-item')).toContainText('Tạm hết hàng');
  await expect(
    customerPage.getByRole('link', { name: 'Tiến hành đặt đơn', exact: true }),
  ).toHaveCount(0);
  await customerPage.goto('/checkout');
  await expect(
    customerPage.getByRole('button', { name: 'Tạo đơn hàng', exact: true }),
  ).toBeDisabled();
  await setCocaStock(page, 50);
  await expect(
    customerPage.getByRole('button', { name: 'Tạo đơn hàng', exact: true }),
  ).toBeEnabled();
  await customerPage.close();
});

test('Admin can edit stock and retains discontinued products for later reactivation', async ({
  page,
}) => {
  await login(page, 'Quản trị');
  await setCocaStock(page, 20);
  const row = page.getByRole('row').filter({ hasText: 'Coca-Cola nguyên bản' });
  await expect(row).toContainText('Sắp hết hàng');
  await row.getByRole('button', { name: 'Ngừng bán Coca-Cola nguyên bản', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(row).toBeVisible();
  await expect(row).toContainText('Ngừng bán');
  await row.getByRole('button', { name: 'Sửa Coca-Cola nguyên bản', exact: true }).click();
  await expect(page.getByLabel('Đang kinh doanh', { exact: true })).not.toBeChecked();
  await page.getByLabel('Số lượng tồn kho', { exact: true }).fill('45');
  await page.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(row).toContainText('Ngừng bán');
  await expect(row.getByRole('cell').nth(3)).toHaveText('45');
  const customerPage = await page.context().newPage();
  await customerPage.goto('/products?q=Coca-Cola');
  await expect(customerPage.locator('.product-card')).toHaveCount(0);
  await row.getByRole('button', { name: 'Sửa Coca-Cola nguyên bản', exact: true }).click();
  await page.getByLabel('Đang kinh doanh', { exact: true }).check();
  await page.getByRole('button', { name: 'Lưu sản phẩm', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(row).toContainText('Đang bán');
  await expect(customerPage.locator('.product-card')).toHaveCount(1);
  await expect(customerPage.locator('.product-card button')).toBeEnabled();
  await customerPage.close();
});

test('Staff cannot open product management or change inventory through the service', async ({
  page,
}) => {
  await login(page, 'Nhân viên');
  await expect(page.locator('.admin-sidebar a[href="/admin/products"]')).toHaveCount(0);
  await expect(page.locator('.admin-sidebar a[href="/admin/stock-receipts"]')).toHaveCount(0);
  const errors = await page.evaluate(async () => {
    const { adminService } = await import('/src/services/index.js');
    const results = [];
    for (const action of [
      () => adminService.save('products', { id: 'p01', stock: 999 }),
      () => adminService.remove('products', 'p01'),
      () => adminService.receipt({ productId: 'p01', quantity: 10, cost: 1 }),
    ]) {
      try {
        await action();
        results.push('allowed');
      } catch (error) {
        results.push(error.message);
      }
    }
    return results;
  });
  expect(errors).toHaveLength(3);
  for (const error of errors) expect(error).toContain('Chỉ quản trị viên');
  for (const path of ['/admin/products', '/admin/stock-receipts']) {
    await page.goto(path);
    await expect(page).toHaveURL('/unauthorized');
  }
});

import { test, expect } from '@playwright/test';
import { purchasingDate } from '../src/utils/purchasing-dates';

test('home posters navigate and catalog prioritizes products by expiry', async ({ page }) => {
  const errors = [], unexpected = [];
  page.on('pageerror', e => errors.push(e.message));
  const rows = [
    { id: 1, ten: 'HSD chưa ghi', next_expiry: null, ngay_tao: '2026-11-07' },
    { id: 2, ten: 'HSD còn xa', next_expiry: '2099-12-01', ngay_tao: '2026-11-01' },
    { id: 3, ten: 'HSD gần nhất', next_expiry: purchasingDate(), ngay_tao: '2026-10-01' },
  ].map(r => ({ ...r, so_luong_co_ban: 20, trang_thai: 'DANG_BAN', hien_thi: true, loai_san_pham_id: 1, thuong_hieu_id: 1, loai_bao_bi: 'LON', packages: [{ id: r.id, he_so_quy_doi: 1, gia_ban: 10000, dang_ban: true }], images: [] }));
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname.replace('/api/v1', '');
    let data;
    if (path === '/catalog/products') data = { items: rows, total: rows.length };
    else if (/^\/catalog\/products\/\d+$/.test(path)) data = rows.find(r => r.id === Number(path.split('/').at(-1)));
    else if (path === '/catalog/categories') data = [{ id: 1, ten: 'Nước giải khát' }];
    else if (path === '/catalog/brands') data = [{ id: 1, ten: 'WaterBus' }];
    else if (path === '/catalog/promotions') data = [];
    else { unexpected.push(path); await route.fulfill({ status: 404, json: { message: 'Unexpected API' } }); return; }
    await route.fulfill({ json: data });
  });
  await page.goto('/');
  const carousel = page.getByRole('region', { name: 'Bộ sưu tập WaterBus', exact: true });
  await expect(carousel.getByRole('heading')).toContainText('Một ngụm tươi mới.');
  await expect(page.locator('.hero-proof')).toHaveCount(0);
  await carousel.getByRole('button', { name: 'Poster tiếp theo', exact: true }).click();
  await expect(carousel.getByRole('heading')).toContainText('Bật nắp tươi mát.');
  await expect(carousel.locator('img')).toBeVisible();
  expect(await carousel.locator('img').evaluate(img => img.complete && img.naturalWidth > 0)).toBe(true);
  await page.screenshot({ path: 'test-results/home-carousel-citrus.png', fullPage: false });
  await carousel.getByRole('button', { name: 'Poster trước', exact: true }).click();
  await carousel.getByRole('button', { name: 'Poster trước', exact: true }).click();
  await expect(carousel.getByRole('heading')).toContainText('Chậm một chút.');
  await carousel.getByRole('button', { name: 'Xem poster 2', exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(carousel.getByRole('button', { name: 'Poster tiếp theo', exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: 'test-results/home-carousel-mobile.png', fullPage: false });
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/products');
  await page.getByLabel('Sắp xếp sản phẩm').selectOption('expiry');
  await expect(page.locator('.catalog-grid .product-name')).toHaveText(['HSD gần nhất', 'HSD còn xa', 'HSD chưa ghi']);
  await page.goto('/products?sort=newest');
  await expect(page.getByLabel('Sắp xếp sản phẩm')).toHaveValue('expiry');
  await expect(page.locator('.catalog-grid .product-name').first()).toHaveText('HSD gần nhất');
  expect(unexpected).toEqual([]); expect(errors).toEqual([]);
});

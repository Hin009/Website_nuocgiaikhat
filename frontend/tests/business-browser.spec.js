import { test, expect } from '@playwright/test';

test('supplier management replaces creation in receipts and promotion editor sends valid scope data', async ({
  page,
}) => {
  const suppliers = [];
  const promotions = [];
  const writes = [];
  const errors = [];
  const unexpected = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const user = {
    account: { id: 1, email: 'admin@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['SUPPLIER_MANAGE', 'PROMOTION_MANAGE'],
  };
  const paged = (items) => ({ items, total: items.length, page: 0, size: 100 });
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const path = url.pathname.replace('/api/v1', '');
    const method = req.method();
    let data;
    if (path === '/auth/login') data = { accessToken: 'browser-test-token', user };
    else if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin', dien_thoai: '0900000000' };
    else if (path === '/management/supplier-tax-check')
      data = {
        duplicate: false,
        taxCode: req.postDataJSON().taxCode,
        message: 'Đúng định dạng, không trùng mã.',
      };
    else if (
      path === '/management/suppliers' ||
      (path === '/management/supplier-editor' && method === 'GET')
    )
      data = paged(suppliers);
    else if (/^\/management\/supplier-editor\/\d+\/products$/.test(path))
      data = suppliers.find((s) => s.id === Number(path.split('/')[3]))?.product_ids || [];
    else if (path === '/management/promotion-editor' && method === 'GET') data = paged(promotions);
    else if (path === '/management/products')
      data = paged([
        {
          id: 1,
          ten: 'Nước ngọt kiểm thử',
          sku: 'TEST',
          loai_san_pham_id: 1,
          thuong_hieu_id: 1,
          trang_thai: 'DANG_BAN',
          hien_thi: true,
          dung_tich: '330ml',
          ngay_tao: new Date().toISOString(),
        },
      ]);
    else if (path === '/management/categories') data = paged([{ id: 1, ten: 'Nước ngọt' }]);
    else if (path === '/management/brands') data = paged([{ id: 1, ten: 'Thương hiệu thử' }]);
    else if (path === '/management/packages')
      data = paged([
        {
          id: 1,
          san_pham_id: 1,
          ten_quy_cach: 'Lon lẻ',
          he_so_quy_doi: 1,
          gia_ban: 10000,
          dang_ban: true,
        },
      ]);
    else if (path === '/staff/reports/stock')
      data = paged([{ san_pham_id: 1, so_luong_co_ban: 10, nguong_canh_bao: 5 }]);
    else if (
      [
        '/staff/orders',
        '/purchases',
        '/receipts',
        '/supplier-returns',
        '/management/images',
      ].includes(path)
    )
      data = paged([]);
    else if (path.startsWith('/management/supplier-editor')) {
      const body = req.postDataJSON();
      writes.push({ path, body, method });
      const id = Number(path.split('/')[3]) || 1;
      if (path.endsWith('/status')) {
        const row = suppliers.find((s) => s.id === id);
        row.trang_thai = body.status;
        data = row;
      } else {
        data = {
          id,
          ten: body.fullName,
          product_ids: body.productIds,
          ma_so_thue: body.taxCode,
          loai_nha_cung_cap: body.supplierType,
          trang_thai_xac_minh: body.verificationStatus,
          ghi_chu_xac_minh: body.verificationNotes,
          nguoi_lien_he: body.contactName,
          dien_thoai: body.phone,
          email: body.email,
          dia_chi: body.address,
          trang_thai: body.status,
        };
        const index = suppliers.findIndex((s) => s.id === id);
        if (index < 0) suppliers.push(data);
        else suppliers[index] = data;
      }
    } else if (path.startsWith('/management/promotion-editor')) {
      const body = req.postDataJSON();
      writes.push({ path, body, method });
      const id = Number(path.split('/')[3]) || 1;
      if (path.endsWith('/status')) {
        const row = promotions.find((p) => p.id === id);
        row.trang_thai = body.status;
        data = row;
      } else {
        data = {
          id,
          ma_code: body.code,
          ten: body.fullName,
          mo_ta: body.description,
          loai_giam: body.discountType,
          gia_tri_giam: body.value,
          giam_toi_da: body.maxDiscount,
          don_toi_thieu: body.minimumOrder,
          bat_dau: body.startsAt,
          ket_thuc: body.endsAt,
          gioi_han_su_dung: body.totalLimit,
          gioi_han_moi_khach: body.customerLimit,
          pham_vi_ap_dung: body.scope,
          scope_ids: body.scopeIds,
          trang_thai: body.status,
          luot_da_dung: 0,
        };
        const index = promotions.findIndex((p) => p.id === id);
        if (index < 0) promotions.push(data);
        else promotions[index] = data;
      }
    } else {
      unexpected.push(`${method} ${path}`);
      await route.fulfill({ status: 404, json: { message: 'Unexpected API request' } });
      return;
    }
    await route.fulfill({ status: 200, json: data });
  });
  await page.goto('/admin/suppliers');
  await page.getByLabel('Địa chỉ email').fill('admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  await page.getByRole('button', { name: 'Thêm nhà cung cấp', exact: true }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('checkbox', { name: /Nước ngọt kiểm thử/ }).check();
  await dialog.getByLabel('Tên nhà cung cấp').fill('Nhà cung cấp thử');
  await dialog.getByLabel('Người liên hệ').fill('Người liên hệ thử');
  await dialog.getByLabel('Số điện thoại', { exact: true }).fill('123456789');
  await dialog.getByRole('button', { name: 'Lưu nhà cung cấp', exact: true }).click();
  await expect(dialog.getByText('Số điện thoại phải gồm đúng 10 hoặc 11 chữ số.')).toBeVisible();
  expect(writes).toHaveLength(0);
  await dialog.getByLabel('Số điện thoại', { exact: true }).fill('0900000000');
  await dialog.getByLabel('Loại nhà cung cấp').selectOption('HO_KINH_DOANH');
  await dialog.getByLabel('Mã số thuế / Số định danh').fill('012345678901');
  await dialog.getByRole('button', { name: 'Kiểm tra định dạng và trùng mã', exact: true }).click();
  await expect(dialog.getByRole('status')).toHaveText('Đúng định dạng, không trùng mã.');
  await expect(dialog.getByRole('link', { name: /Tra cứu trên Cổng/ })).toHaveAttribute(
    'href',
    'https://tracuunnt.gdt.gov.vn/tcnnt/mstdn.jsp',
  );
  await dialog.getByLabel('Email', { exact: true }).fill('supplier@test.invalid');
  await dialog.getByLabel('Địa chỉ', { exact: true }).fill('123 Đường thử');
  await dialog.getByRole('button', { name: 'Lưu nhà cung cấp', exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await page.getByRole('button', { name: 'Sửa Nhà cung cấp thử', exact: true }).click();
  await expect(dialog.getByRole('checkbox', { name: /Nước ngọt kiểm thử/ })).toBeChecked();
  await dialog.getByLabel('Người liên hệ').fill('Liên hệ đã sửa');
  await dialog.getByLabel('Trạng thái xác minh', { exact: true }).selectOption('DA_XAC_MINH');
  await dialog.getByRole('button', { name: 'Lưu nhà cung cấp', exact: true }).click();
  await expect(dialog.getByText('Xác nhận đã đối chiếu hồ sơ và thông tin tra cứu.')).toBeVisible();
  await dialog.getByLabel('Xác nhận đối chiếu', { exact: true }).check();
  await dialog.getByLabel('Mã số thuế / Số định danh').fill('012345678902');
  await expect(dialog.getByLabel('Trạng thái xác minh', { exact: true })).toHaveValue(
    'CAN_KIEM_TRA_LAI',
  );
  await page.screenshot({ path: 'test-results/supplier-legal.png', fullPage: true });
  await dialog.getByRole('button', { name: 'Lưu nhà cung cấp', exact: true }).click();
  await expect(page.getByRole('cell', { name: /Liên hệ đã sửa/ })).toBeVisible();
  await page.goto('/admin/stock-receipts');
  await expect(page.getByRole('button', { name: 'Thêm nhà cung cấp', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }).click();
  await expect(
    dialog.getByLabel('Nhà cung cấp').locator('option', { hasText: 'Nhà cung cấp thử' }),
  ).toHaveCount(1);
  await page.goto('/admin/suppliers');
  await page.getByRole('button', { name: 'Ngừng hợp tác', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Khôi phục hợp tác', exact: true })).toBeVisible();
  await page.goto('/admin/stock-receipts');
  await page.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }).click();
  await expect(
    dialog.getByLabel('Nhà cung cấp').locator('option', { hasText: 'Nhà cung cấp thử' }),
  ).toHaveCount(0);
  await expect(dialog.getByRole('link', { name: 'Đến quản lý nhà cung cấp' })).toBeVisible();
  await page.goto('/admin/promotions');
  await page.getByRole('button', { name: 'Thêm mã khuyến mãi', exact: true }).click();
  await dialog.getByLabel('Mã khuyến mãi', { exact: true }).fill('test10');
  await dialog.getByLabel('Tên chương trình').fill('Mã giảm kiểm thử');
  await expect(dialog.getByLabel('Phạm vi áp dụng').locator('option')).toHaveCount(2);
  await dialog.getByLabel('Phạm vi áp dụng').selectOption('BRAND');
  await dialog.getByLabel('Thương hiệu thử', { exact: true }).check();
  await dialog.getByLabel('Phạm vi áp dụng').selectOption('CATEGORY');
  await expect(dialog.getByText('Đã chọn 0', { exact: true })).toBeVisible();
  await dialog.getByLabel('Tìm đối tượng áp dụng').fill('không có');
  await expect(dialog.getByText('Không có kết quả phù hợp.')).toBeVisible();
  await dialog.getByLabel('Tìm đối tượng áp dụng').fill('nước');
  await dialog.getByLabel('Nước ngọt', { exact: true }).check();
  await expect(dialog.getByText('Đã chọn 1', { exact: true })).toBeVisible();
  await dialog.getByLabel('Giảm tối đa (đ, để trống nếu không giới hạn)').fill('50000');
  await expect(dialog.getByLabel('Giảm tối đa (đ, để trống nếu không giới hạn)')).toHaveValue(
    '50.000',
  );
  await page.screenshot({ path: 'test-results/promotion-targets.png', fullPage: true });
  await dialog.getByRole('button', { name: 'Lưu mã khuyến mãi', exact: true }).click();
  await expect(dialog).toHaveCount(0);
  await page.getByRole('button', { name: 'Sửa TEST10', exact: true }).click();
  await expect(dialog.getByLabel('Nước ngọt', { exact: true })).toBeChecked();
  await dialog.getByLabel('Mức giảm (%)', { exact: true }).fill('15');
  await dialog.getByRole('button', { name: 'Lưu mã khuyến mãi', exact: true }).click();
  await expect(page.getByRole('cell', { name: /15%/ })).toBeVisible();
  await page.getByRole('button', { name: 'Ngừng áp dụng', exact: true }).click();
  await page.getByRole('button', { name: 'Xác nhận', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Cho phép áp dụng', exact: true })).toBeVisible();
  expect(writes.find((w) => w.path === '/management/promotion-editor').body).toMatchObject({
    code: 'TEST10',
    scope: 'CATEGORY',
    scopeIds: [1],
    maxDiscount: 50000,
    totalLimit: null,
  });
  expect(suppliers[0]).toMatchObject({
    product_ids: [1],
    nguoi_lien_he: 'Liên hệ đã sửa',
    trang_thai: 'NGUNG_HOP_TAC',
  });
  expect(promotions[0]).toMatchObject({ gia_tri_giam: 15, trang_thai: 'INACTIVE', scope_ids: [1] });
  expect(errors).toEqual([]);
  expect(unexpected).toEqual([]);
});

import { test, expect } from '@playwright/test';
import { purchasingDate } from '../src/utils/purchasing-dates';

test('import packs/cases and settle rejected goods during receiving', async ({ page }) => {
  const errors = [],
    unexpected = [],
    writes = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const user = {
    account: { id: 1, email: 'admin@test.invalid', trang_thai: 'ACTIVE' },
    roles: ['QUAN_TRI_VIEN'],
    permissions: ['IMPORT_READ', 'IMPORT_RECEIVE', 'IMPORT_APPROVE', 'IMPORT_CREATE', 'REPORT_ALL'],
  };
  const paged = (items) => ({ items, total: items.length, page: 0, size: 100 });
  const po = {
    id: 1,
    ma_don_nhap: 'DN-TEST',
    nha_cung_cap_id: 1,
    trang_thai: 'DA_DUYET',
    ngay_dat: '2026-01-01T23:30:00Z',
    ngay_giao_du_kien: purchasingDate(new Date(Date.now() - 2 * 86400000)),
    items: [
      {
        id: 1,
        quy_cach_id: 1,
        he_so_quy_doi: 1,
        so_luong_dat: 99,
        gia_nhap_du_kien: 5000,
        so_luong_da_nhan: 0,
        so_luong_da_tra_loi: 0,
        so_luong_con_lai: 99,
      },
    ],
  };
  const orders = [po],
    receipts = [];
  const packages = [
    {
      id: 1,
      san_pham_id: 1,
      ten_quy_cach: 'Hộp lẻ',
      don_vi_tinh: 'HOP',
      he_so_quy_doi: 1,
      gia_ban: 8000,
      dang_ban: true,
    },
  ];
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request(),
      path = new URL(req.url()).pathname.replace('/api/v1', ''),
      method = req.method();
    let data;
    if (method !== 'GET') writes.push({ path, body: req.postDataJSON() });
    if (path === '/auth/login') data = { accessToken: 'test-token', user };
    else if (path === '/auth/me') data = user;
    else if (path === '/staff/profile') data = { id: 1, ho_ten: 'Admin', dien_thoai: '0900000000' };
    else if (/^\/management\/supplier-editor\/\d+\/products$/.test(path))
      data = path.includes('/1/') ? [1] : path.includes('/2/') ? [2] : [];
    else if (path === '/purchases' && method === 'POST') {
      const body = req.postDataJSON(),
        line = body.items[0],
        id = orders.length + 1;
      packages.push({
        id,
        san_pham_id: line.productId,
        ten_quy_cach:
          (line.packaging === 'THUNG' ? 'Thùng ' : 'Lốc ') +
          line.unitsPerPackage +
          ' đơn vị (nhập)',
        don_vi_tinh: line.packaging,
        he_so_quy_doi: line.unitsPerPackage,
        gia_ban: 8000 * line.unitsPerPackage,
        dang_ban: false,
      });
      data = {
        id,
        ma_don_nhap: 'DN-' + id,
        nha_cung_cap_id: body.supplierId,
        trang_thai: 'CHO_DUYET',
        ngay_dat: new Date().toISOString(),
        ngay_giao_du_kien: body.expectedDate,
        items: [
          {
            id,
            quy_cach_id: id,
            he_so_quy_doi: line.unitsPerPackage,
            so_luong_dat: line.quantity,
            gia_nhap_du_kien: line.unitCost,
            so_luong_con_lai: line.quantity,
          },
        ],
      };
      orders.push(data);
    } else if (path === '/purchases') data = paged(orders);
    else if (/^\/purchases\/\d+$/.test(path))
      data = {
        ...orders.find((o) => o.id === Number(path.split('/')[2])),
        receipts: receipts.filter((r) => r.don_ncc_id === Number(path.split('/')[2])),
      };
    else if (path === '/purchases/1/receipts') {
      const item = req.postDataJSON().items[0];
      data = {
        id: 1,
        don_ncc_id: 1,
        nha_cung_cap: 'NCC thử',
        trang_thai: 'DRAFT',
        ngay_nhap: new Date().toISOString(),
        items: [
          {
            id: 1,
            ct_don_ncc_id: 1,
            ten_san_pham: 'Milo kiểm thử',
            ten_quy_cach: 'Hộp lẻ',
            so_luong_thuc_nhan: item.quantity,
            so_luong_loai: item.rejectedQuantity,
            ly_do_loai: item.rejectionReason,
            gia_nhap_thuc_te: item.actualCost,
          },
        ],
      };
      receipts.push(data);
    } else if (path === '/receipts/1/confirm') {
      receipts[0].trang_thai = 'CONFIRMED';
      receipts[0].ngay_xac_nhan = new Date().toISOString();
      po.trang_thai = 'DA_NHAN_DU';
      Object.assign(po.items[0], {
        so_luong_da_nhan: 90,
        so_luong_da_tra_loi: 9,
        so_luong_con_lai: 0,
      });
      data = receipts[0];
    } else if (path === '/receipts') data = paged(receipts);
    else if (path === '/supplier-returns' && method === 'GET') {
      const rejected = receipts
        .filter((r) => r.trang_thai === 'CONFIRMED' && r.items.some((l) => l.so_luong_loai > 0))
        .map((r) => ({
          id: r.id,
          history_key: 'receipt-' + r.id,
          source: 'RECEIPT_REJECTION',
          ma_phieu: 'TRA-NHAN-' + r.id,
          lan_nhap_id: r.id,
          nha_cung_cap: r.nha_cung_cap,
          ngay_lap: r.ngay_nhap,
          trang_thai: 'CONFIRMED',
          tong_tien: r.items.reduce((sum, l) => sum + l.so_luong_loai * l.gia_nhap_thuc_te, 0),
          so_tien_giam_no: 0,
          so_tien_cho_hoan: 0,
          so_tien_da_hoan: 0,
          refunds: [],
          items: r.items
            .filter((l) => l.so_luong_loai > 0)
            .map((l) => ({ ...l, so_luong: l.so_luong_loai, ly_do: l.ly_do_loai })),
        }));
      data = paged(rejected);
    } else if (path === '/management/suppliers')
      data = paged([
        { id: 1, ten: 'NCC thử', trang_thai: 'HOP_TAC' },
        { id: 2, ten: 'NCC nước ngọt', trang_thai: 'HOP_TAC' },
        { id: 3, ten: 'NCC chưa có sản phẩm', trang_thai: 'HOP_TAC' },
      ]);
    else if (path === '/management/products')
      data = paged([
        {
          id: 1,
          ten: 'Milo kiểm thử',
          sku: 'TEST',
          loai_san_pham_id: 1,
          thuong_hieu_id: 1,
          trang_thai: 'DANG_BAN',
          hien_thi: true,
        },
        {
          id: 2,
          ten: 'Coca kiểm thử',
          sku: 'COCA',
          loai_san_pham_id: 1,
          thuong_hieu_id: 1,
          trang_thai: 'DANG_BAN',
          hien_thi: true,
        },
      ]);
    else if (path === '/management/packages') data = paged(packages);
    else if (path === '/management/categories') data = paged([{ id: 1, ten: 'Sữa' }]);
    else if (path === '/management/brands') data = paged([{ id: 1, ten: 'Milo' }]);
    else if (path === '/management/reports/product-profit')
      data = [
        {
          product_id: 1,
          product_name: 'Milo kiểm thử',
          sku: 'TEST',
          imported_qty: 100,
          import_amount: 6040000,
          sold_qty: 10,
          net_sales: 210000,
          discount: 0,
          cost_of_goods: 100000,
          gross_profit: 110000,
          margin_percent: 52.38,
          current_stock: 90,
          zero_cost_qty: 0,
        },
      ];
    else if (path === '/staff/reports/stock')
      data = paged([{ san_pham_id: 1, so_luong_co_ban: 90 }]);
    else if (['/staff/orders', '/management/images', '/management/accounts'].includes(path))
      data = paged([]);
    else {
      unexpected.push(method + ' ' + path);
      await route.fulfill({ status: 404, json: { message: 'Unexpected API' } });
      return;
    }
    await route.fulfill({ status: 200, json: data });
  });
  await page.goto('/admin/stock-receipts');
  await page.getByLabel('Địa chỉ email').fill('admin@test.invalid');
  await page.getByLabel('Mật khẩu', { exact: true }).fill('TestPass123!');
  await page.getByRole('button', { name: 'Đăng nhập', exact: true }).click();
  const dialog = page.getByRole('dialog');
  const delivery = purchasingDate(new Date(Date.now() + 7 * 86400000));
  await expect(
    page.getByRole('heading', { name: 'Đơn đặt hàng và nhập hàng', exact: true }),
  ).toBeVisible();
  const confirmSave = async (path) => {
    await Promise.all([
      page.waitForResponse(
        (response) =>
          new URL(response.url()).pathname === '/api/v1' + path &&
          response.request().method() === 'POST',
      ),
      page.getByRole('button', { name: 'Xác nhận', exact: true }).click(),
    ]);
    await expect(page.getByRole('alertdialog')).toHaveCount(0);
    await expect(dialog).toHaveCount(0);
  };
  await page.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }).click();
  const supplierSelect = dialog.getByLabel('Nhà cung cấp', { exact: true });
  const productSelect = dialog.getByLabel('Sản phẩm', { exact: true });
  await expect(productSelect).toBeDisabled();
  await supplierSelect.selectOption('1');
  await expect(productSelect).toBeEnabled();
  await expect(productSelect.locator('option')).toHaveText(['Chọn sản phẩm', 'Milo kiểm thử']);
  await productSelect.selectOption('1');
  await dialog.getByLabel('Quy cách', { exact: true }).selectOption('new-THUNG');
  await dialog.getByLabel('Số lượng thùng đặt nhập').fill('2');
  await dialog.getByLabel('Giá nhập mỗi quy cách (đ)').fill('100000');
  await supplierSelect.selectOption('2');
  await expect(productSelect.locator('option')).toHaveText(['Chọn sản phẩm', 'Coca kiểm thử']);
  await expect(productSelect).toHaveValue('');
  await expect(dialog.getByLabel('Quy cách', { exact: true })).toBeDisabled();
  await expect(dialog.getByLabel('Giá nhập mỗi quy cách (đ)')).toHaveValue('');
  await expect(dialog.getByLabel('Số lượng quy cách đặt nhập')).toHaveValue('');
  await supplierSelect.selectOption('3');
  await expect(dialog.getByText(/NCC chưa được gán sản phẩm/)).toBeVisible();
  await expect(
    dialog.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }),
  ).toBeDisabled();
  await dialog.getByRole('button', { name: 'Đóng hộp thoại', exact: true }).click();
  for (const [packaging, factor, quantity, cost, label, total] of [
    ['THUNG', '48', '2', '240000', 'thùng', '96'],
    ['LOC', '6', '4', '30000', 'lốc', '24'],
  ]) {
    await page.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }).click();
    await dialog.getByLabel('Nhà cung cấp', { exact: true }).selectOption('1');
    await dialog.getByLabel('Sản phẩm', { exact: true }).selectOption('1');
    await dialog.getByLabel('Quy cách', { exact: true }).selectOption('new-' + packaging);
    await expect(dialog.getByLabel('Ngày giao dự kiến')).toHaveAttribute('min', purchasingDate());
    await dialog.getByLabel('Ngày giao dự kiến').fill(delivery);
    await dialog.getByLabel('Số đơn vị lẻ trong 1 ' + label, { exact: true }).fill(factor);
    await dialog.getByLabel('Số lượng ' + label + ' đặt nhập', { exact: true }).fill(quantity);
    await dialog.getByLabel('Giá nhập mỗi quy cách (đ)', { exact: true }).fill(cost);
    await expect(dialog.getByRole('status')).toContainText('= ' + total + ' đơn vị lẻ');
    if (packaging === 'THUNG')
      await page.screenshot({ path: 'test-results/case-purchasing.png', fullPage: true });
    await dialog.getByRole('button', { name: 'Lập đơn đặt hàng', exact: true }).click();
    await confirmSave('/purchases');
    expect(writes.filter((w) => w.path === '/purchases').at(-1).body.expectedDate).toBe(delivery);
    await expect(
      page.getByRole('row', { name: 'DN-' + orders.length, exact: false }),
    ).toContainText(
      new Intl.DateTimeFormat('vi-VN', { dateStyle: 'medium' }).format(
        new Date(delivery + 'T12:00:00+07:00'),
      ),
    );
    expect(writes.filter((w) => w.path === '/purchases').at(-1).body.items[0]).toEqual({
      productId: 1,
      packaging,
      unitsPerPackage: Number(factor),
      quantity: Number(quantity),
      unitCost: Number(cost),
    });
  }
  const orderRow = page.getByRole('row', { name: /DN-TEST/ });
  await expect(orderRow).toContainText('Quá hạn giao 2 ngày');
  await orderRow.getByRole('button', { name: 'Nhận hàng', exact: true }).click();
  await expect(dialog.getByLabel('Số lượng giao đợt này')).toHaveValue('99');
  await dialog.getByLabel('Số lượng hàng lỗi trả ngay NCC').fill('9');
  await dialog.getByLabel('Lý do trả hàng lỗi', { exact: true }).fill('Bể khi giao');
  await expect(dialog.getByRole('status')).toHaveText(
    'Nhập kho: 90 · Trả lỗi: 9 · Còn chờ nhận: 0 quy cách.',
  );
  await expect(dialog.getByLabel('Giá thực tế mỗi quy cách (đ)')).toHaveValue('5.000');
  await page.screenshot({ path: 'test-results/receiving-defects.png', fullPage: true });
  await dialog.getByRole('button', { name: 'Lưu kiểm nhận và trả hàng lỗi', exact: true }).click();
  await confirmSave('/purchases/1/receipts');
  expect(writes.find((w) => w.path === '/purchases/1/receipts').body.items[0]).toEqual({
    purchaseLineId: 1,
    quantity: 90,
    rejectedQuantity: 9,
    rejectionReason: 'Bể khi giao',
    actualCost: 5000,
  });
  await expect(
    page.getByText('Sẽ trả lỗi khi xác nhận: 9 — Bể khi giao', { exact: true }),
  ).toBeVisible();
  await expect(page.getByText('TRA-NHAN-1', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Xác nhận nhận / trả hàng', exact: true }).click();
  await confirmSave('/receipts/1/confirm');
  await expect(orderRow).toContainText('Đã nhận đủ');
  await expect(orderRow).toContainText('Đã nhận trễ 2 ngày');
  await expect(orderRow).toContainText('Nhận đủ:');
  await expect(orderRow).not.toContainText('Quá hạn giao');
  await expect(orderRow).toContainText('Chờ nhận: 0');
  await expect(orderRow.getByRole('button', { name: 'Nhận hàng', exact: true })).toHaveCount(0);
  await expect(page.getByText('Đã nhận và trả hàng lỗi', { exact: true })).toBeVisible();
  await expect(page.getByText('Đã trả lỗi NCC: 9 — Bể khi giao', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Trả hàng lỗi', exact: true })).toHaveCount(0);
  expect(writes.some((w) => w.path === '/supplier-returns')).toBe(false);
  const historyRow = page.getByRole('row', { name: /TRA-NHAN-1/ });
  await expect(historyRow).toContainText('Milo kiểm thử — Hộp lẻ × 9');
  await expect(historyRow).toContainText('Bể khi giao');
  await expect(historyRow).toContainText('45.000');
  await expect(historyRow).toContainText('Không tính công nợ');
  await expect(historyRow).toContainText('Đã trả khi kiểm nhận');
  await expect(historyRow.getByRole('button')).toHaveCount(0);
  await page.reload();
  await expect(historyRow).toHaveCount(1);
  await expect(historyRow).toContainText('Milo kiểm thử — Hộp lẻ × 9');
  await page.screenshot({ path: 'test-results/receiving-settled.png', fullPage: true });
  expect(writes.some((w) => w.path === '/management/supplier-products')).toBe(false);
  await expect(page.getByLabel('Lọc đơn đặt hàng theo')).toHaveValue('ngay_giao_du_kien');
  await page
    .getByLabel('Từ ngày', { exact: true })
    .fill(purchasingDate(new Date(Date.now() + 3 * 86400000)));
  await page.getByLabel('Đến ngày', { exact: true }).fill(delivery);
  await expect(page.getByRole('row', { name: /DN-2/ })).toHaveCount(1);
  await page.getByLabel('Lọc đơn đặt hàng theo').selectOption('ngay_dat');
  await expect(page.getByRole('row', { name: /DN-2/ })).toHaveCount(0);
  await page.getByLabel('Lọc đơn đặt hàng theo').selectOption('ngay_giao_du_kien');
  await expect(page.getByRole('row', { name: /DN-2/ })).toHaveCount(1);
  await page.getByRole('button', { name: 'Xóa bộ lọc ngày', exact: true }).click();
  await page.getByLabel('Lọc đơn đặt hàng theo').selectOption('ngay_dat');
  await page.getByLabel('Từ ngày', { exact: true }).fill('2026-01-02');
  await page.getByLabel('Đến ngày', { exact: true }).fill('2026-01-02');
  await expect(orderRow).toHaveCount(1);
  await expect(orderRow).toContainText('Đã nhận trễ 2 ngày');
  await expect(page.getByRole('row', { name: /DN-2/ })).toHaveCount(0);
  await expect(historyRow).toHaveCount(0);
  await expect(page.getByText('Không có lần nhập hàng trong khoảng ngày đã chọn')).toBeVisible();
  await page.getByLabel('Từ ngày', { exact: true }).fill('2026-01-01');
  await page.getByLabel('Đến ngày', { exact: true }).fill('2026-01-01');
  await expect(orderRow).toHaveCount(0);
  await expect(page.getByText('Không có đơn đặt hàng trong khoảng ngày đã chọn')).toBeVisible();
  await page.getByRole('button', { name: 'Xóa bộ lọc ngày', exact: true }).click();
  await expect(orderRow).toHaveCount(1);
  await expect(historyRow).toHaveCount(1);
  await page.goto('/admin/reports');
  const finance = page.locator('.product-profit-section');
  await expect(finance.locator('.profit-totals .metric-card')).toHaveCount(4);
  await expect(finance).not.toContainText('Giá trị hàng đã nhập rồi trả NCC');
  await expect(finance).not.toContainText('Nhập ròng');
  await expect(finance).toContainText('110.000');
  await expect(finance.locator('thead th')).toHaveCount(8);
  expect(errors).toEqual([]);
  expect(unexpected).toEqual([]);
});

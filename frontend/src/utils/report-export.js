const number = (value) => (Number.isFinite(Number(value)) ? Number(value) : 0);
const displayNumber = (value) =>
  value == null ? '—' : number(value).toLocaleString('vi-VN', { maximumFractionDigits: 2 });
const displayDate = (value) => value.split('-').reverse().join('/');
export const reportColumns = [
  { key: 'product_name', label: 'Sản phẩm', width: 34 },
  { key: 'sku', label: 'SKU', width: 18 },
  { key: 'imported_qty', label: 'SL nhập', width: 14 },
  { key: 'import_amount', label: 'Tiền nhập (đ)', width: 20 },
  { key: 'sold_qty', label: 'SL bán', width: 14 },
  { key: 'net_sales', label: 'Doanh thu (đ)', width: 20 },
  { key: 'discount', label: 'Giảm giá (đ)', width: 18 },
  { key: 'cost_of_goods', label: 'Giá vốn (đ)', width: 20 },
  { key: 'gross_profit', label: 'Lãi gộp (đ)', width: 20 },
  { key: 'margin_percent', label: 'Tỷ suất (%)', width: 14 },
  { key: 'current_stock', label: 'Tồn hiện tại', width: 16 },
];

export function createExportReport({
  rows,
  from,
  to,
  search = '',
  sort,
  generatedAt = new Date(),
}) {
  const data = rows.map((row) =>
    reportColumns.map(({ key }, index) =>
      index < 2
        ? String(row[key] ?? '')
        : key === 'margin_percent' && row[key] == null
          ? null
          : number(row[key]),
    ),
  );
  const totals = reportColumns.map((column, index) =>
    index === 0
      ? 'TỔNG CỘNG'
      : index === 1 || column.key === 'margin_percent'
        ? null
        : data.reduce((sum, row) => sum + row[index], 0),
  );
  // Margin of the whole report is weighted by revenue, not a sum of percentages.
  totals[9] = totals[5] !== 0 ? (totals[8] / totals[5]) * 100 : null;
  const sortLabel = reportColumns.find((c) => c.key === sort?.key)?.label || 'Lãi gộp (đ)';
  return {
    title: 'WATERBUS · BÁO CÁO DOANH THU',
    period: from && to ? `${displayDate(from)} – ${displayDate(to)}` : 'Toàn bộ thời gian',
    search: search.trim() || 'Tất cả sản phẩm',
    sort: `${sortLabel} · ${sort?.direction === 'asc' ? 'Tăng dần' : 'Giảm dần'}`,
    generatedAt: new Intl.DateTimeFormat('vi-VN', {
      dateStyle: 'short',
      timeStyle: 'short',
      timeZone: 'Asia/Ho_Chi_Minh',
    }).format(generatedAt),
    filename: `WaterBus-bao-cao-${from && to ? `${from}_${to}` : 'toan-bo'}`,
    data,
    totals,
  };
}

export function createExcelSheet(report) {
  const heading = (value) => [
    { value, type: String, columnSpan: reportColumns.length, fontWeight: 'bold' },
    ...Array(reportColumns.length - 1).fill(null),
  ];
  const cells = (row, total = false) =>
    row.map((value, index) => {
      if (value == null) return null;
      const numeric = index >= 2;
      return {
        value: index === 9 ? value / 100 : value,
        type: numeric ? Number : String,
        ...(numeric
          ? {
              format: index === 9 ? '0.00%' : [2, 4, 10].includes(index) ? '#,##0' : '#,##0.00',
              align: 'right',
            }
          : {}),
        ...(total ? { fontWeight: 'bold', backgroundColor: '#E8F0E9' } : {}),
        wrap: true,
      };
    });
  return [
    heading(report.title),
    heading(`Thời gian: ${report.period}`),
    heading(`Sản phẩm: ${report.search}`),
    heading(`Sắp xếp: ${report.sort}`),
    heading(`Ngày xuất: ${report.generatedAt} (UTC+7) · Đơn vị tiền: VND`),
    [],
    reportColumns.map((c) => ({
      value: c.label,
      type: String,
      fontWeight: 'bold',
      backgroundColor: '#24573E',
      textColor: '#FFFFFF',
      wrap: true,
    })),
    ...report.data.map((row) => cells(row)),
    cells(report.totals, true),
  ];
}

function textRows(report) {
  return [...report.data, report.totals].map((row) =>
    row.map((value, index) =>
      index < 2
        ? String(value ?? '')
        : displayNumber(value) + (index === 9 && value != null ? '%' : ''),
    ),
  );
}

export function createPdfDefinition(report) {
  return {
    info: { title: report.title, author: 'WaterBus' },
    pageSize: 'A4',
    pageOrientation: 'landscape',
    pageMargins: [24, 28, 24, 32],
    defaultStyle: { font: 'Roboto', fontSize: 8 },
    content: [
      { text: report.title, bold: true, fontSize: 16, color: '#24573e', margin: [0, 0, 0, 10] },
      {
        text: `Thời gian: ${report.period}    |    Ngày xuất: ${report.generatedAt} (UTC+7)`,
        margin: [0, 0, 0, 5],
      },
      { text: `Sản phẩm: ${report.search}    |    Sắp xếp: ${report.sort}`, margin: [0, 0, 0, 12] },
      {
        table: {
          headerRows: 1,
          dontBreakRows: true,
          widths: [105, 50, ...Array(9).fill('*')],
          body: [
            reportColumns.map((c) => ({
              text: c.label,
              bold: true,
              color: '#ffffff',
              fillColor: '#24573e',
            })),
            ...textRows(report).map((row, rowIndex) =>
              row.map((text, index) => ({
                text,
                alignment: index < 2 ? 'left' : 'right',
                bold: rowIndex === report.data.length,
                fillColor:
                  rowIndex === report.data.length
                    ? '#e8f0e9'
                    : rowIndex % 2 === 0
                      ? '#f6f8f5'
                      : '#ffffff',
              })),
            ),
          ],
        },
        layout: 'lightHorizontalLines',
      },
      {
        text: 'Đơn vị tiền: VND. Tồn hiện tại được ghi nhận tại thời điểm xuất báo cáo.',
        fontSize: 7,
        margin: [0, 10, 0, 0],
      },
    ],
    footer: (currentPage, pageCount) => ({
      text: `WaterBus · Trang ${currentPage}/${pageCount}`,
      alignment: 'right',
      fontSize: 8,
      margin: [24, 8, 24, 0],
    }),
  };
}

const escapeHtml = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char],
  );
export function createPrintHtml(report) {
  const body = textRows(report)
    .map(
      (row, index) =>
        `<tr${index === report.data.length ? ' class="totals"' : ''}>${row.map((value) => `<td>${escapeHtml(value)}</td>`).join('')}</tr>`,
    )
    .join('');
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escapeHtml(report.title)}</title><style>
    @page { size: A4 landscape; margin: 12mm; }
    body { font: 10px Arial, sans-serif; color: #182b22; margin: 0; }
    h1 { font-size: 20px; margin: 0 0 12px; }
    p { margin: 6px 0; } table { width: 100%; border-collapse: collapse; margin-top: 18px; table-layout: fixed; }
    th,td { border: 1px solid #cdd7ce; padding: 7px 4px; text-align: right; overflow-wrap: anywhere; }
    th { background: #e8f0e9; } th:first-child,td:first-child { width: 15%; text-align: left; }
    th:nth-child(2),td:nth-child(2) { width: 8%; text-align: left; }
    thead { display: table-header-group; } tr { break-inside: avoid; } .totals { font-weight: bold; background: #edf4ee; }
  </style></head><body><h1>${escapeHtml(report.title)}</h1><p>Thời gian: ${escapeHtml(report.period)}</p><p>Sản phẩm: ${escapeHtml(report.search)} · Sắp xếp: ${escapeHtml(report.sort)}</p><p>Ngày xuất: ${escapeHtml(report.generatedAt)} (UTC+7) · Đơn vị tiền: VND</p><table><thead><tr>${reportColumns.map((c) => `<th>${escapeHtml(c.label)}</th>`).join('')}</tr></thead><tbody>${body}</tbody></table><p>Tồn hiện tại được ghi nhận tại thời điểm xuất báo cáo.</p></body></html>`;
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}

export async function exportExcel(report) {
  const { default: writeExcelFile } = await import('write-excel-file/browser');
  const blob = await writeExcelFile(createExcelSheet(report), {
    sheet: 'Báo cáo doanh thu',
    columns: reportColumns.map((c) => ({ width: c.width })),
    stickyRowsCount: 7,
    orientation: 'landscape',
  }).toBlob();
  downloadBlob(blob, `${report.filename}.xlsx`);
}

export async function exportPdf(report) {
  const [{ default: pdfMake }, { default: fonts }] = await Promise.all([
    import('pdfmake/build/pdfmake'),
    import('pdfmake/build/vfs_fonts'),
  ]);
  pdfMake.addVirtualFileSystem(fonts);
  const blob = await pdfMake.createPdf(createPdfDefinition(report)).getBlob();
  downloadBlob(blob, `${report.filename}.pdf`);
}

export function printReport(report) {
  return new Promise((resolve, reject) => {
    const frame = document.createElement('iframe');
    frame.title = 'Bản in báo cáo WaterBus';
    frame.setAttribute('aria-hidden', 'true');
    frame.style.cssText = 'position:fixed;width:1px;height:1px;bottom:0;left:0;border:0;';
    const cleanup = () => frame.remove();
    frame.onload = () => {
      try {
        frame.contentWindow.addEventListener('afterprint', () => setTimeout(cleanup, 0), {
          once: true,
        });
        frame.contentWindow.focus();
        frame.contentWindow.print();
        resolve();
      } catch (error) {
        cleanup();
        reject(error);
      }
    };
    frame.srcdoc = createPrintHtml(report);
    document.body.appendChild(frame);
    // Keep the document alive while the native print dialog is open.
    setTimeout(cleanup, 300000);
  });
}

import { describe, expect, it } from 'vitest';
import writeExcelFile from 'write-excel-file/universal';
import { unzipSync, strFromU8 } from 'fflate';
import { create } from 'fontkit';
import fonts from 'pdfmake/build/vfs_fonts';
import {
  createExportReport,
  createExcelSheet,
  createPdfDefinition,
  createPrintHtml,
} from '../src/utils/report-export';

const rows = [
  {
    product_name: 'Bưởi',
    sku: '=1+1',
    imported_qty: '10',
    import_amount: '2000',
    sold_qty: '2',
    net_sales: '1000',
    discount: '20',
    cost_of_goods: '1100',
    gross_profit: '-100',
    margin_percent: '-10',
    current_stock: '20',
  },
  {
    product_name: '<img src=x onerror=alert(1)>',
    sku: 'TEST',
    imported_qty: '2',
    import_amount: '10',
    sold_qty: '1',
    net_sales: '500',
    discount: 0,
    cost_of_goods: '300',
    gross_profit: '200',
    margin_percent: '40',
    current_stock: '3',
  },
];
const report = () =>
  createExportReport({
    rows,
    from: '2024-02-01',
    to: '2024-02-29',
    search: 'buoi',
    sort: { key: 'gross_profit', direction: 'asc' },
    generatedAt: new Date('2026-11-11T07:00:00Z'),
  });

describe('report export', () => {
  it('keeps the exact visible row order, numeric values, weighted margin, and filter metadata', () => {
    const result = report();
    expect(result.data.map((r) => r[0])).toEqual(rows.map((r) => r.product_name));
    expect(result.data[0][8]).toBe(-100);
    expect(result.totals[3]).toBe(2010);
    expect(result.totals[5]).toBe(1500);
    expect(result.totals[8]).toBe(100);
    expect(result.totals[9]).toBeCloseTo((100 / 1500) * 100);
    expect(result.period).toBe('01/02/2024 – 29/02/2024');
    expect(result.search).toBe('buoi');
    expect(result.filename).toContain('2024-02-01_2024-02-29');
    expect(result.sort).toContain('Tăng dần');
  });
  it('creates a real XLSX workbook with numeric amounts and literal text instead of spreadsheet formulas', async () => {
    const sheet = createExcelSheet(report());
    const blob = await writeExcelFile(sheet).toBlob();
    const zip = unzipSync(new Uint8Array(await blob.arrayBuffer()));
    expect(Object.keys(zip)).toContain('xl/worksheets/sheet1.xml');
    const worksheet = strFromU8(zip['xl/worksheets/sheet1.xml']);
    const allXml = Object.values(zip)
      .map((bytes) => strFromU8(bytes))
      .join('');
    expect(worksheet).toContain('<v>-100</v>');
    expect(allXml).toContain('Bưởi');
    expect(allXml).toContain('=1+1');
    expect(worksheet).not.toContain('<f>');
  });
  it('prints escaped product/filter text and repeats table headers on A4 landscape pages', () => {
    const html = createPrintHtml(report());
    expect(html).not.toContain('<img src=x');
    expect(html).toContain('&lt;img');
    expect(html).toContain('A4 landscape');
    expect(html).toContain('<thead>');
    expect(html).toContain('TỔNG CỘNG');
    expect(html).toContain('29/02/2024');
  });
  it('builds PDF data with repeating headers, footer, and fonts covering Vietnamese diacritics', () => {
    const definition = createPdfDefinition(report());
    expect(definition.pageOrientation).toBe('landscape');
    expect(definition.content[3].table.headerRows).toBe(1);
    expect(definition.content[3].table.body).toHaveLength(4);
    expect(definition.footer(2, 3).text).toContain('2/3');
    for (const name of ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      const font = create(Buffer.from(fonts[name], 'base64'));
      for (const char of 'Bưởi Đào Thống kê Lãi gộp Tỷ suất')
        expect(font.hasGlyphForCodePoint(char.codePointAt(0))).toBe(true);
    }
  });
  it('leaves margins undefined when there are no sales', () => {
    const result = createExportReport({
      rows: [],
      sort: { key: 'gross_profit', direction: 'desc' },
    });
    expect(result.period).toBe('Toàn bộ thời gian');
    expect(result.totals[9]).toBeNull();
  });
});

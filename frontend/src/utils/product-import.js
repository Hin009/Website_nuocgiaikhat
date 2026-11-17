import { normalize } from './format';
export const importHeaders = [
  'Tên sản phẩm',
  'Thương hiệu',
  'Loại sản phẩm',
  'Quy cách',
  'Bao bì',
  'Mô tả',
  'Đang kinh doanh',
];
export const MAX_IMPORT_ROWS = 200;
const text = (value) => (value == null ? '' : String(value).trim());
const key = (p) =>
  [p.name, p.brand, p.categoryId, p.volume].map((v) => normalize(text(v))).join('|');
export function parseProductRows(matrix, categories, existing = []) {
  if (!matrix.length) throw new Error('File Excel không có dữ liệu.');
  const headers = matrix[0].map((v) => normalize(text(v)));
  const expected = importHeaders.map(normalize);
  for (const header of expected.slice(0, 5)) {
    if (!headers.includes(header))
      throw new Error(
        'Thiếu cột: ' + importHeaders[expected.indexOf(header)] + '. Hãy dùng file mẫu.',
      );
  }
  if (headers.some((h, i) => h && (!expected.includes(h) || headers.indexOf(h) !== i)))
    throw new Error(
      'File có cột không hỗ trợ hoặc tiêu đề trùng. Hãy dùng đúng các cột trong file mẫu.',
    );
  const data = matrix
    .slice(1)
    .map((cells, i) => ({ cells, rowNumber: i + 2 }))
    .filter(({ cells }) => cells.some((v) => text(v)));
  if (!data.length) throw new Error('Chưa có sản phẩm trong file Excel.');
  if (data.length > MAX_IMPORT_ROWS) throw new Error('Mỗi lần chỉ nhập tối đa 200 sản phẩm.');
  const seen = new Set(existing.map(key));
  return data.map(({ cells, rowNumber }) => {
    const get = (i) => text(cells[headers.indexOf(expected[i])]);
    const errors = [];
    const matches = categories.filter(
      (c) => normalize(c.name) === normalize(get(2)) || String(c.id) === get(2),
    );
    const category = matches.length === 1 ? matches[0] : null;
    if (!category)
      errors.push('Loại sản phẩm không tồn tại hoặc không rõ; chọn tên trong danh sách loại.');
    const packaging = { lon: 'LON', chai: 'CHAI', hop: 'HOP' }[normalize(get(4))];
    if (!packaging) errors.push('Bao bì phải là Lon, Chai hoặc Hộp.');
    const activeText = normalize(get(6));
    if (!['', 'co', 'khong', 'true', 'false', '1', '0'].includes(activeText))
      errors.push('Đang kinh doanh: nhập Có hoặc Không.');
    const product = {
      fullName: get(0),
      brand: get(1),
      categoryId: category?.id,
      volume: get(3),
      packaging,
      description: get(5),
      active: !['khong', 'false', '0'].includes(activeText),
    };
    for (const [value, min, max, label] of [
      [product.fullName, 2, 150, 'Tên sản phẩm'],
      [product.brand, 1, 150, 'Thương hiệu'],
      [product.volume, 1, 80, 'Quy cách'],
      [product.description, 0, 3000, 'Mô tả'],
    ]) {
      if (value.length < min || value.length > max)
        errors.push(label + ': cần từ ' + min + ' đến ' + max + ' ký tự.');
    }
    const identity = key({
      name: product.fullName,
      brand: product.brand,
      categoryId: category?.id,
      volume: product.volume,
    });
    if (seen.has(identity))
      errors.push('Trùng sản phẩm đã có hoặc dòng trước (tên, thương hiệu, loại và quy cách).');
    seen.add(identity);
    if (cells.some((v, i) => text(v) && !headers[i]))
      errors.push('Có dữ liệu ở cột không có tiêu đề.');
    return { rowNumber, product, categoryName: category?.name || get(2), errors };
  });
}
export async function readProductExcel(file, categories, existing) {
  if (!/\.xlsx$/i.test(file.name))
    throw new Error('Vui lòng chọn file Excel .xlsx (lưu lại file .xls thành .xlsx nếu cần).');
  if (file.size > 5 * 1024 * 1024) throw new Error('File Excel tối đa 5 MB.');
  const { readSheet } = await import('read-excel-file/browser');
  let rows;
  try {
    rows = await readSheet(file, { sheet: 1 });
  } catch {
    throw new Error('Không đọc được file Excel. Kiểm tra file .xlsx và thử lại.');
  }
  return parseProductRows(rows, categories, existing);
}
export function templateSheets(categories) {
  const cells = (row) => row.map((value) => ({ value, type: String }));
  return [
    {
      sheet: 'Sản phẩm',
      data: [cells(importHeaders)],
      columns: importHeaders.map(() => ({ width: 25 })),
    },
    {
      sheet: 'Hướng dẫn',
      data: [
        ['Điền sản phẩm vào sheet Sản phẩm, mỗi dòng một sản phẩm; tối đa 200 dòng.'],
        ['Bắt buộc: Tên sản phẩm, Thương hiệu, Loại sản phẩm, Quy cách, Bao bì.'],
        ['Bao bì: Lon / Chai / Hộp. Quy cách ví dụ: Lon 330ml.'],
        ['Đang kinh doanh: Có / Không; để trống mặc định Có. Mô tả không bắt buộc.'],
        ['Không nhập giá hoặc tồn kho; ghi nhận bằng phiếu nhập hàng sau khi tạo sản phẩm.'],
        ['Ảnh sản phẩm có thể thêm sau trong Chỉnh sửa. Chỉ đọc sheet đầu tiên.'],
        ['Tên loại sản phẩm hợp lệ:'],
        ...categories.map((c) => [c.name]),
      ].map(cells),
      columns: [{ width: 105 }],
    },
  ];
}
export async function downloadProductTemplate(categories) {
  const { default: writeExcelFile } = await import('write-excel-file/browser');
  const blob = await writeExcelFile(templateSheets(categories)).toBlob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'WaterBus-mau-nhap-san-pham.xlsx';
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

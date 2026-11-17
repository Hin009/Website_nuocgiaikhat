import { useState } from 'react';
import { toast } from 'sonner';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Field } from '@/components/common/Shared';
import { useAction } from '@/hooks/useData';
import { adminService } from '@/services';
import { readProductExcel, downloadProductTemplate } from '@/utils/product-import';
export default function ProductImportDialog({ categories, products, onClose }) {
  const [rows, setRows] = useState([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [filename, setFilename] = useState('');
  const action = useAction((items) => adminService.importProducts(items));
  const pending = busy || action.isPending;
  const invalid = rows.filter((r) => r.errors.length).length;
  const run = async (fn) => {
    setBusy(true);
    setError('');
    try {
      await fn();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };
  return (
    <Dialog open onOpenChange={(open) => !open && !pending && onClose()}>
      <DialogContent
        title="Nhập sản phẩm từ Excel"
        className="product-import-dialog"
        description="Tải file mẫu, điền sản phẩm rồi chọn file để xem trước và lưu hàng loạt."
      >
        <div className="form-stack">
          <Button
            variant="outline"
            disabled={pending}
            onClick={() => run(() => downloadProductTemplate(categories))}
          >
            Tải file Excel mẫu
          </Button>
          <p className="muted-note">
            File .xlsx, tối đa 5 MB và 200 sản phẩm. Chỉ đọc sheet đầu tiên. Tên loại sản phẩm phải
            có sẵn; xem danh sách trong sheet Hướng dẫn của file mẫu.
          </p>
          <p className="muted-note">
            Sản phẩm mới có tồn kho bằng 0. Tạo phiếu nhập hàng để ghi nhận giá vốn và giá bán tự
            động. Bạn có thể thêm ảnh sau trong Chỉnh sửa.
          </p>
          <Field label="Chọn file Excel">
            <input
              type="file"
              accept=".xlsx"
              disabled={pending}
              onChange={(e) => {
                const file = e.target.files?.[0];
                setRows([]);
                setError('');
                setFilename(file?.name || '');
                if (file)
                  run(async () => setRows(await readProductExcel(file, categories, products)));
              }}
            />
          </Field>
          {busy && <p role="status">Đang xử lý file Excel…</p>}
          {error && (
            <p className="form-error" role="alert">
              {error}
            </p>
          )}
          {!!rows.length && (
            <>
              <p role="status">
                {filename}: {rows.length} sản phẩm, {invalid} dòng lỗi.
              </p>
              {!!invalid && (
                <p className="form-error" role="alert">
                  Sửa các dòng lỗi trong Excel và chọn lại file trước khi nhập. Chưa có sản phẩm nào
                  được lưu.
                </p>
              )}
              <div className="table-scroll product-import-preview">
                <table>
                  <thead>
                    <tr>
                      <th>Dòng Excel</th>
                      <th>Tên sản phẩm</th>
                      <th>Thương hiệu</th>
                      <th>Loại</th>
                      <th>Quy cách</th>
                      <th>Bao bì</th>
                      <th>Kinh doanh</th>
                      <th>Kiểm tra</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r) => (
                      <tr key={r.rowNumber}>
                        <td>{r.rowNumber}</td>
                        <td>{r.product.fullName}</td>
                        <td>{r.product.brand}</td>
                        <td>{r.categoryName}</td>
                        <td>{r.product.volume}</td>
                        <td>{r.product.packaging}</td>
                        <td>{r.product.active ? 'Có' : 'Không'}</td>
                        <td className={r.errors.length ? 'form-error' : ''}>
                          {r.errors.join(' ') || 'Hợp lệ'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
          <div className="dialog-actions">
            <Button variant="outline" disabled={pending} onClick={onClose}>
              Hủy
            </Button>
            <Button
              disabled={pending || !rows.length || !!invalid}
              onClick={async () => {
                setError('');
                try {
                  const result = await action.mutateAsync(
                    rows.map(({ rowNumber, product }) => ({ rowNumber, product })),
                  );
                  toast.success('Đã thêm ' + result.createdCount + ' sản phẩm từ Excel');
                  onClose();
                } catch (e) {
                  setError(e.message);
                }
              }}
            >
              {action.isPending ? 'Đang nhập…' : 'Nhập ' + rows.length + ' sản phẩm'}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

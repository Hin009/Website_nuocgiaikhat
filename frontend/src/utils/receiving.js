export function remainingToReceive(line, receipts = []) {
  if (line.so_luong_con_lai != null) return Math.max(0, Number(line.so_luong_con_lai));
  const processed = receipts
    .filter((r) => r.trang_thai === 'CONFIRMED')
    .flatMap((r) => r.items)
    .filter((item) => Number(item.ct_don_ncc_id) === Number(line.id))
    .reduce(
      (sum, item) => sum + Number(item.so_luong_thuc_nhan) + Number(item.so_luong_loai || 0),
      0,
    );
  return Math.max(0, Number(line.so_luong_dat) - processed);
}

export function receiptItems(lines, drafts, receipts = []) {
  const items = [];
  for (const line of lines) {
    const draft = drafts[line.id];
    if (!draft) continue;
    const delivered = Number(draft.delivered),
      rejected = Number(draft.rejected);
    if (
      !Number.isSafeInteger(delivered) ||
      !Number.isSafeInteger(rejected) ||
      delivered < 0 ||
      rejected < 0 ||
      rejected > delivered
    )
      throw new Error(
        'Số lượng hàng giao và hàng lỗi phải là số nguyên; hàng lỗi không vượt hàng giao.',
      );
    if (delivered > remainingToReceive(line, receipts))
      throw new Error('Số lượng giao vượt số lượng còn chờ xử lý.');
    if (!delivered) continue;
    if (rejected > 0 && !draft.reason?.trim())
      throw new Error('Ghi lý do trả hàng lỗi cho nhà cung cấp.');
    const cost = Number(draft.cost);
    if (String(draft.cost ?? '').trim() === '' || !Number.isFinite(cost) || cost < 0)
      throw new Error('Nhập giá thực tế hợp lệ.');
    items.push({
      purchaseLineId: line.id,
      quantity: delivered - rejected,
      rejectedQuantity: rejected,
      rejectionReason: draft.reason?.trim() || '',
      actualCost: cost,
    });
  }
  if (!items.length) throw new Error('Nhập số lượng giao lớn hơn 0 cho ít nhất một dòng.');
  return items;
}

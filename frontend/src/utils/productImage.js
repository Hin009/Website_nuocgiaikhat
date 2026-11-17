const MAX_BYTES = 5 * 1024 * 1024;
const TYPES = ['image/jpeg', 'image/png', 'image/webp'];

export function validateProductImage(file) {
  if (!file.size || file.size > MAX_BYTES)
    throw new Error('Ảnh phải có dung lượng từ 1 byte đến 5 MB.');
  if (!TYPES.includes(file.type)) throw new Error('Chỉ nhận ảnh JPG, PNG hoặc WebP.');
}

// Ignore almost transparent edge noise when finding the product's bounds.
export function foregroundBounds(data, width, height) {
  let left = width,
    top = height,
    right = -1,
    bottom = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] <= 16) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < left) throw new Error('Không nhận diện được sản phẩm. Vui lòng chọn ảnh rõ hơn.');
  return { left, top, width: right - left + 1, height: bottom - top + 1 };
}

async function loadSource(source) {
  if (typeof source !== 'string') return source;
  const url = new URL(source, window.location.origin);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('Đường dẫn ảnh không hợp lệ.');
  let response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(30000), credentials: 'omit' });
  } catch {
    throw new Error('Không đọc được ảnh từ đường dẫn. Hãy tải ảnh về và chọn tệp để xóa phông.');
  }
  if (!response.ok) throw new Error('Không tải được ảnh từ đường dẫn.');
  if (Number(response.headers.get('content-length')) > MAX_BYTES)
    throw new Error('Ảnh không được vượt quá 5 MB.');
  return response.blob();
}

export async function prepareProductImage(source, onProgress = () => {}) {
  const input = await loadSource(source);
  validateProductImage(input);
  onProgress('Đang tải bộ xử lý và xóa phông… Lần đầu có thể mất vài phút.');
  const { removeBackground } = await import('@imgly/background-removal');
  const foreground = await removeBackground(input, {
    device: 'cpu',
    model: 'isnet_fp16',
    output: { format: 'image/png' },
    progress: (key, current, total) => {
      if (key.startsWith('fetch:') && total > 0)
        onProgress(`Đang tải bộ xử lý xóa phông: ${Math.round((current / total) * 100)}%`);
      else onProgress('Đang tách sản phẩm khỏi nền…');
    },
  });
  const bitmap = await createImageBitmap(foreground);
  try {
    const canvas = document.createElement('canvas');
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const context = canvas.getContext('2d', { willReadFrequently: true });
    context.drawImage(bitmap, 0, 0);
    const bounds = foregroundBounds(
      context.getImageData(0, 0, bitmap.width, bitmap.height).data,
      bitmap.width,
      bitmap.height,
    );
    // Keep a consistent small margin and limit dimensions so PNG uploads stay manageable.
    const scale = Math.min(1, 1400 / Math.max(bounds.width, bounds.height));
    const width = Math.max(1, Math.round(bounds.width * scale));
    const height = Math.max(1, Math.round(bounds.height * scale));
    const padding = Math.max(4, Math.round(Math.max(width, height) * 0.05));
    canvas.width = width + padding * 2;
    canvas.height = height + padding * 2;
    context.drawImage(
      bitmap,
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
      padding,
      padding,
      width,
      height,
    );
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
    if (!blob) throw new Error('Không xuất được ảnh sản phẩm. Vui lòng thử lại.');
    validateProductImage(blob);
    return new File([blob], 'product.png', { type: 'image/png' });
  } finally {
    bitmap.close();
  }
}

import axios from 'axios';
const messages = {
  401: 'Phiên đăng nhập đã hết hạn.',
  403: 'Bạn không có quyền thực hiện thao tác này.',
  404: 'Không tìm thấy dữ liệu.',
  409: 'Dữ liệu có xung đột. Vui lòng tải lại.',
  422: 'Vui lòng kiểm tra thông tin đã nhập.',
  500: 'Máy chủ gặp sự cố. Vui lòng thử lại sau.',
};
export const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || undefined,
  timeout: 15000,
});
http.interceptors.response.use(
  (r) => r,
  (error) => {
    const result = new Error(
      messages[error.response?.status] ||
        (error.response ? 'Yêu cầu không thành công.' : 'Không kết nối được máy chủ.'),
    );
    result.status = error.response?.status;
    result.fields = error.response?.data?.errors;
    if (result.status === 401) window.dispatchEvent(new Event('waterbus:unauthorized'));
    return Promise.reject(result);
  },
);
// Chưa gắn cookie/Bearer hay cấu trúc JSON khi chưa xác minh hợp đồng backend.

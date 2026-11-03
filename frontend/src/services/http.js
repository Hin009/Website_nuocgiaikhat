import axios from 'axios';
import { accessToken, saveSession } from './session';
const messages = {
  401: 'Vui lòng đăng nhập lại.',
  403: 'Bạn không có quyền thực hiện thao tác này.',
  404: 'Không tìm thấy dữ liệu.',
  409: 'Dữ liệu có xung đột. Vui lòng tải lại.',
  500: 'Máy chủ gặp sự cố. Vui lòng thử lại sau.',
};
export const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api/v1',
  timeout: 15000,
});
http.interceptors.request.use((config) => {
  const token = accessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
http.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status;
    const result = new Error(
      error.response?.data?.message ||
        messages[status] ||
        (error.response ? 'Yêu cầu không thành công.' : 'Không kết nối được máy chủ.'),
    );
    result.status = status;
    result.fields = error.response?.data?.errors;
    if (status === 401 && !error.config?.url?.includes('/auth/login')) {
      saveSession(null);
      if (typeof window !== 'undefined') window.dispatchEvent(new Event('waterbus:unauthorized'));
    }
    return Promise.reject(result);
  },
);
export const get = async (path, params) => (await http.get(path, { params })).data;
export const post = async (path, data = {}) => (await http.post(path, data)).data;
export const put = async (path, data) => (await http.put(path, data)).data;
export const patch = async (path, data) => (await http.patch(path, data)).data;
export const del = async (path) => (await http.delete(path)).data;
export async function allPages(path, params = {}) {
  const first = await get(path, { ...params, page: 0, size: 100 });
  if (Array.isArray(first)) return first;
  const items = [...first.items];
  for (let page = 1; items.length < first.total; page++) {
    const next = await get(path, { ...params, page, size: 100 });
    if (!next.items.length) break;
    items.push(...next.items);
  }
  return items;
}

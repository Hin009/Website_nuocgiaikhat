import * as mock from './mock';
import * as api from './api';
export const isMock = import.meta.env.VITE_DATA_MODE === 'mock';
const services = isMock ? mock : api;
export const { catalogService, authService, orderService, adminService, transitions } = services;
export { cartService } from './api';

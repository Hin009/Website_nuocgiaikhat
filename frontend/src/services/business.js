import { allPages, get, post, put, patch } from './http';

export const supplierService = {
  checkTax: (values) => post('/management/supplier-tax-check', values),
  list: () => allPages('/management/supplier-editor'),
  products: (id) => get(`/management/supplier-editor/${id}/products`),
  save: (id, values) => {
    const body = { ...values, productIds: values.productIds.map(Number) };
    return id
      ? put(`/management/supplier-editor/${id}`, body)
      : post('/management/supplier-editor', body);
  },
  status: (id, status) => patch(`/management/supplier-editor/${id}/status`, { status }),
};
export const promotionService = {
  list: () => allPages('/management/promotion-editor'),
  save: (id, values) => {
    const body = {
      ...values,
      startsAt: new Date(values.startsAt).toISOString(),
      endsAt: new Date(values.endsAt).toISOString(),
      scopeIds: values.scopeIds.map(Number),
    };
    return id
      ? put(`/management/promotion-editor/${id}`, body)
      : post('/management/promotion-editor', body);
  },
  status: (id, status) => patch(`/management/promotion-editor/${id}/status`, { status }),
  brands: () => allPages('/management/brands'),
};

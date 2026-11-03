import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { catalogService, adminService, orderService } from '@/services';
export const useProducts = () => useQuery({ queryKey: ['products'], queryFn: catalogService.list });
export const useCategories = () =>
  useQuery({ queryKey: ['categories'], queryFn: catalogService.categories });
export const useProduct = (id) =>
  useQuery({ queryKey: ['products', id], queryFn: () => catalogService.detail(id), enabled: !!id });
export const useAdmin = (key) =>
  useQuery({ queryKey: ['admin', key], queryFn: () => adminService.all(key) });
export const useOrders = (user) =>
  useQuery({
    queryKey: ['orders', user?.id, user?.role],
    queryFn: () => orderService.list(user),
    enabled: !!user,
  });
export function useAction(fn, message) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: fn,
    onSuccess: async () => {
      await client.invalidateQueries();
      if (message) toast.success(message);
    },
    onError: (error) => toast.error(error.message),
  });
}

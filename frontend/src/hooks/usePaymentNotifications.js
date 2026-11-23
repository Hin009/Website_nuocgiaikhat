import { useEffect } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { get } from '@/services/http';
import { accessToken } from '@/services/session';

export function usePaymentNotifications(enabled, accountId) {
  const client = useQueryClient();
  const query = useQuery({
    queryKey: ['payment-notifications', accountId],
    queryFn: async () => {
      const rows = await get('/payments/notifications');
      return Array.isArray(rows) ? rows : [];
    },
    enabled,
    staleTime: Infinity,
  });
  const initialized = query.isSuccess;
  useEffect(() => {
    if (!enabled || !initialized) return;
    const key = ['payment-notifications', accountId];
    const initial = client.getQueryData(key) || [];
    let cursor = Math.max(0, ...initial.map((n) => Number(n.id)));
    const controller = new AbortController();
    const connect = async () => {
      while (!controller.signal.aborted) {
        try {
          const base = (import.meta.env.VITE_API_BASE_URL || '/api/v1').replace(/\/$/, '');
          const response = await fetch(`${base}/payments/events?after=${cursor}`, {
            headers: { Authorization: `Bearer ${accessToken()}`, Accept: 'text/event-stream' },
            signal: controller.signal,
          });
          if ([401, 403].includes(response.status)) return;
          if (!response.ok || !response.body) throw new Error('SSE unavailable');
          const reader = response.body.getReader();
          const decoder = new TextDecoder();
          let buffer = '';
          while (!controller.signal.aborted) {
            const { value, done } = await reader.read();
            if (done) break;
            buffer = (buffer + decoder.decode(value, { stream: true })).replace(/\r\n/g, '\n');
            let end;
            while ((end = buffer.indexOf('\n\n')) >= 0) {
              const frame = buffer.slice(0, end);
              buffer = buffer.slice(end + 2);
              if (
                !frame
                  .split('\n')
                  .some(
                    (line) => line.trim() === 'event:payment' || line.trim() === 'event: payment',
                  )
              )
                continue;
              const data = frame
                .split('\n')
                .filter((line) => line.startsWith('data:'))
                .map((line) => line.slice(5).trimStart())
                .join('\n');
              const notification = JSON.parse(data);
              if (Number(notification.id) <= cursor) continue;
              cursor = Number(notification.id);
              client.setQueryData(key, (rows = []) =>
                [notification, ...rows.filter((n) => n.id !== notification.id)].slice(0, 20),
              );
              client.invalidateQueries({ queryKey: ['orders'] });
              client.invalidateQueries({ queryKey: ['order'] });
              client.invalidateQueries({ queryKey: ['admin'] });
              toast.success(notification.message, { id: `payment-${notification.id}` });
            }
          }
        } catch {
          if (controller.signal.aborted) return;
        }
        await new Promise((resolve) => {
          const onAbort = () => {
            clearTimeout(timer);
            resolve();
          };
          const timer = setTimeout(() => {
            controller.signal.removeEventListener('abort', onAbort);
            resolve();
          }, 2000);
          controller.signal.addEventListener('abort', onAbort, { once: true });
        });
      }
    };
    connect();
    return () => controller.abort();
  }, [enabled, initialized, accountId, client]);
  return query;
}

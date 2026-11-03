import * as Alert from '@radix-ui/react-alert-dialog';
import { Button } from './button';
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  onConfirm,
  pending = false,
  children,
}) {
  return (
    <Alert.Root open={open} onOpenChange={onOpenChange}>
      <Alert.Portal>
        <Alert.Overlay className="dialog-overlay" />
        <Alert.Content className="dialog-content confirm-dialog">
          <Alert.Title>{title}</Alert.Title>
          <Alert.Description>{description}</Alert.Description>
          {children}
          <div className="dialog-actions">
            <Alert.Cancel asChild>
              <Button variant="outline" disabled={pending}>
                Quay lại
              </Button>
            </Alert.Cancel>
            <Button variant="destructive" onClick={onConfirm} disabled={pending}>
              {pending ? 'Đang xử lý…' : 'Xác nhận'}
            </Button>
          </div>
        </Alert.Content>
      </Alert.Portal>
    </Alert.Root>
  );
}

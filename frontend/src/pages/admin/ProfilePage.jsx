import { PageHeading } from '@/components/common/Shared';
import { ProfilePage } from '@/pages/customer/AccountPage';
import { useAuth } from '@/contexts/AuthContext';
import { roleLabels } from '@/utils/format';

export default function AdminProfilePage() {
  const { user } = useAuth();
  return (
    <>
      <PageHeading
        title="Thông tin tài khoản"
        description={user.name + ' · ' + roleLabels[user.role]}
      />
      <ProfilePage management />
    </>
  );
}

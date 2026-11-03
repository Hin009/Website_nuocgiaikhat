import provinces from '@/data/vietnam-addresses.json';

export { provinces };

const normalize = (value) =>
  value
    .trim()
    .toLocaleLowerCase('vi-VN')
    .replace(/^(tỉnh|thành phố|tp\.?)\s*/u, '');

export function profileAddressDefaults(user) {
  const province = provinces.find((item) => item.code === user.provinceCode);
  const ward = province?.wards.find((item) => item.code === user.wardCode);
  if (province && ward && typeof user.streetAddress === 'string') {
    return { provinceCode: province.code, wardCode: ward.code, streetAddress: user.streetAddress };
  }
  const parts = (user.address || '').split(',').map((part) => part.trim());
  const legacyProvince = provinces.find((item) => normalize(item.name) === normalize(parts.at(-1)));
  if (legacyProvince) parts.pop();
  const legacyWard = legacyProvince?.wards.find(
    (item) => normalize(item.name) === normalize(parts.at(-1) || ''),
  );
  if (legacyWard) parts.pop();
  return {
    provinceCode: legacyProvince?.code || '',
    wardCode: legacyWard?.code || '',
    streetAddress: parts.join(', '),
  };
}

export function formatProfileAddress(values) {
  const province = provinces.find((item) => item.code === values.provinceCode);
  const ward = province?.wards.find((item) => item.code === values.wardCode);
  return [values.streetAddress.trim(), ward?.name, province?.name].filter(Boolean).join(', ');
}

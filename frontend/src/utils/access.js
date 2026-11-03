export function hasRole(user, roles) {
  if (!user || user.active === false) return false;
  return roles.includes(user.role) || (user.role === 'ADMIN' && roles.includes('STAFF'));
}
export const safeReturn = (value) =>
  typeof value === 'string' &&
  value.startsWith('/') &&
  !value.startsWith('//') &&
  !value.includes('\\') &&
  !Array.from(value).some((char) => char.charCodeAt(0) < 32)
    ? value
    : '/';

export function authReturn(value, management = false) {
  const path = safeReturn(value);
  const isManagement = /^\/admin(?:[/?#]|$)/.test(path);
  const isLogin = /^\/(?:login|register)(?:[/?#]|$)/.test(path);
  return isLogin || isManagement !== management ? (management ? '/admin' : '/') : path;
}

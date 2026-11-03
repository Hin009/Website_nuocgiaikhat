const key = 'waterbus.api.session';
let memory = null;
export function readSession() {
  try {
    return memory || JSON.parse(sessionStorage.getItem(key) || 'null');
  } catch {
    return memory;
  }
}
export function saveSession(value) {
  memory = value;
  try {
    if (value) sessionStorage.setItem(key, JSON.stringify(value));
    else sessionStorage.removeItem(key);
  } catch {
    /* Memory session remains usable. */
  }
}
export const accessToken = () => readSession()?.token || null;

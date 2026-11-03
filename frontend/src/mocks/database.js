import { makeSeed } from './seed';
const KEY = 'waterbus.mock.v1';
let volatile;
export function readDb() {
  try {
    const parsed = JSON.parse(localStorage.getItem(KEY));
    if (parsed?.version === 1) return parsed;
  } catch {
    if (volatile) return structuredClone(volatile);
  }
  return makeSeed();
}
export function writeDb(db) {
  volatile = structuredClone(db);
  try {
    localStorage.setItem(KEY, JSON.stringify(db));
  } catch {
    /* dữ liệu vẫn dùng được trong phiên */
  }
  return db;
}
export function resetDb() {
  return writeDb(makeSeed());
}
export function updateDb(fn) {
  const db = readDb();
  const result = fn(db);
  writeDb(db);
  return result;
}
export const uid = (prefix) => prefix + '-' + crypto.randomUUID().slice(0, 8);
export async function digest(value) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
}

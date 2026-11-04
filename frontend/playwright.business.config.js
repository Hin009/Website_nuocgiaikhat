import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests',
  testMatch: [
    'business-browser.spec.js',
    'purchasing-browser.spec.js',
    'products-browser.spec.js',
    'staff-address-browser.spec.js',
  ],
  workers: 1,
  timeout: 120000,
  use: {
    baseURL: 'http://127.0.0.1:5175',
    channel: 'chrome',
    headless: true,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5175',
    url: 'http://127.0.0.1:5175',
    reuseExistingServer: true,
    env: { VITE_DATA_MODE: 'api' },
    timeout: 30000,
  },
});

import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests',
  testMatch: 'api-browser.spec.js',
  workers: 1,
  timeout: 120000,
  use: {
    baseURL: 'http://127.0.0.1:5174',
    channel: 'chrome',
    headless: true,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5174',
    url: 'http://127.0.0.1:5174',
    reuseExistingServer: true,
    env: { VITE_DATA_MODE: 'api', VITE_PROXY_TARGET: 'http://127.0.0.1:18080' },
    timeout: 30000,
  },
});

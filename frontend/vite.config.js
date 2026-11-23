import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { fileURLToPath, URL } from 'node:url';
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  return {
    plugins: [react(), tailwindcss()],
    resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
    optimizeDeps: { include: ['@imgly/background-removal'] },
    server: {
      port: 5173,
      allowedHosts: env.VITE_ALLOWED_HOST ? [env.VITE_ALLOWED_HOST] : [],
      strictPort: true,
      proxy: {
        '/api': {
          target: process.env.VITE_PROXY_TARGET || env.VITE_PROXY_TARGET || 'http://127.0.0.1:8080',
          changeOrigin: true,
        },
      },
    },
    preview: {
      proxy: {
        '/api': {
          target: process.env.VITE_PROXY_TARGET || env.VITE_PROXY_TARGET || 'http://127.0.0.1:8080',
          changeOrigin: true,
        },
      },
    },
    test: { environment: 'node', include: ['tests/**/*.test.js'] },
  };
});

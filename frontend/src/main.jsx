import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from '@/contexts/AuthContext';
import { CartProvider } from '@/contexts/CartContext';
import App from './App';
import './index.css';
const client = new QueryClient({
  defaultOptions: { queries: { staleTime: 30000, retry: false, refetchOnWindowFocus: false } },
});
window.addEventListener('storage', (event) => {
  if (event.key === 'waterbus.mock.v1' || event.key === null) client.invalidateQueries();
});
ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <QueryClientProvider client={client}>
      <BrowserRouter>
        <AuthProvider>
          <CartProvider>
            <App />
          </CartProvider>
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
);

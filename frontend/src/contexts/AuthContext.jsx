import { createContext, useContext, useEffect, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { authService } from '@/services';
const AuthContext = createContext(null);
export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const client = useQueryClient();
  useEffect(() => {
    let mounted = true;
    authService
      .me()
      .then((u) => {
        if (mounted) setUser(u);
      })
      .catch((e) => {
        if (mounted) setError(e.message);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);
  useEffect(() => {
    const expire = () => {
      setUser(null);
      client.clear();
    };
    window.addEventListener('waterbus:unauthorized', expire);
    return () => window.removeEventListener('waterbus:unauthorized', expire);
  }, [client]);
  const login = async (values, register = false, portal = 'customer') => {
    const u = await authService[register ? 'register' : 'login'](values, portal);
    client.clear();
    setUser(u);
    return u;
  };
  const logout = () => {
    authService.logout();
    setUser(null);
    client.clear();
  };
  return (
    <AuthContext.Provider value={{ user, loading, error, login, logout, setUser }}>
      {children}
    </AuthContext.Provider>
  );
}
export const useAuth = () => useContext(AuthContext);

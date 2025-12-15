import { createContext, useContext, useEffect, useState, useCallback } from "react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router";
import { apiClient } from "../api/client";
import type { AuthResponse, LoginRequest, CreateUserRequest } from "../api/client";
import { decodeToken, isTokenExpired, isTokenValid } from "../utils/jwt";

interface AuthContextType {
  user: AuthResponse | null;
  isAuthenticated: boolean;
  login: (data: LoginRequest) => Promise<void>;
  signup: (data: CreateUserRequest) => Promise<void>;
  logout: () => void;
  refreshToken: () => Promise<boolean>;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // Restore user state from token on mount
  const restoreUserFromToken = useCallback(async (): Promise<void> => {
    const accessToken = localStorage.getItem("access_token");
    const refreshToken = localStorage.getItem("refresh_token");

    if (!accessToken) {
      setLoading(false);
      return;
    }

    // Check if access token is valid
    if (isTokenValid(accessToken)) {
      // Decode token to extract user info
      const payload = decodeToken(accessToken);
      if (payload && payload.user_id && payload.email && payload.username) {
        setUser({
          access_token: accessToken,
          refresh_token: refreshToken || "",
          user_id: payload.user_id,
          email: payload.email,
          username: payload.username,
        });
        setLoading(false);
        return;
      }
    }

    // If access token is expired but refresh token exists, try to refresh
    if (isTokenExpired(accessToken) && refreshToken) {
      try {
        const response = await apiClient.refreshToken({ refresh_token: refreshToken });
        if (response.access_token && response.refresh_token) {
          setUser(response);
          setLoading(false);
          return;
        }
      } catch (error) {
        // Refresh failed, clear tokens
        apiClient.logout();
        setLoading(false);
        return;
      }
    }

    // Token is invalid and refresh failed or doesn't exist
    apiClient.logout();
    setLoading(false);
  }, []);

  useEffect(() => {
    restoreUserFromToken();
  }, [restoreUserFromToken]);

  const login = async (data: LoginRequest) => {
    try {
      const response = await apiClient.login(data);
      setUser(response);
      navigate("/");
    } catch (error) {
      throw error;
    }
  };

  const signup = async (data: CreateUserRequest) => {
    try {
      const response = await apiClient.createUser(data);
      setUser(response);
      navigate("/");
    } catch (error) {
      throw error;
    }
  };

  const logout = useCallback(() => {
    apiClient.logout();
    setUser(null);
    navigate("/login");
  }, [navigate]);

  const refreshToken = useCallback(async (): Promise<boolean> => {
    const refreshTokenValue = localStorage.getItem("refresh_token");
    if (!refreshTokenValue) {
      return false;
    }

    try {
      const response = await apiClient.refreshToken({ refresh_token: refreshTokenValue });
      if (response.access_token && response.refresh_token) {
        setUser(response);
        return true;
      }
      return false;
    } catch (error) {
      // Refresh failed, logout user
      logout();
      return false;
    }
  }, [logout]);

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        login,
        signup,
        logout,
        refreshToken,
        loading,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}



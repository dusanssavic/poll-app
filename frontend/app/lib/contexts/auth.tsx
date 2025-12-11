import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router";
import { apiClient } from "../api/client";
import type { AuthResponse, LoginRequest, CreateUserRequest } from "../api/client";

interface AuthContextType {
  user: AuthResponse | null;
  isAuthenticated: boolean;
  login: (data: LoginRequest) => Promise<void>;
  signup: (data: CreateUserRequest) => Promise<void>;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    // Check if user is already authenticated
    const token = localStorage.getItem("access_token");
    if (token && apiClient.isAuthenticated()) {
      // Optionally validate token or fetch user info
      // For now, we'll just set authenticated state
      setUser({
        access_token: token,
        refresh_token: localStorage.getItem("refresh_token") || "",
        user_id: "",
        email: "",
        username: "",
      });
    }
    setLoading(false);
  }, []);

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

  const logout = () => {
    apiClient.logout();
    setUser(null);
    navigate("/login");
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        login,
        signup,
        logout,
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



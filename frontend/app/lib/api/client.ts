// API Client wrapper using generated OpenAPI client
import { OpenAPI } from "./generated/core/OpenAPI";
import { ApiError as GeneratedApiError } from "./generated/core/ApiError";
import {
  UsersService,
  PollsService,
  VotesService,
  type AuthResponse,
  type CreateUserRequest,
  type LoginRequest,
  type RefreshTokenRequest,
  type CreatePollRequest,
  type UpdatePollRequest,
  type PollResponse,
  type VoteRequest,
  type VoteResponse,
  type VoteCountsResponse,
  type VotersResponse,
} from "./generated";

// Configure OpenAPI base URL
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8080";
OpenAPI.BASE = API_BASE_URL;

// Configure token resolver
OpenAPI.TOKEN = async () => {
  if (typeof window === "undefined") return "";
  return localStorage.getItem("access_token") || "";
};

// Token refresh state management
let isRefreshing = false;
let refreshPromise: Promise<AuthResponse | null> | null = null;

/**
 * Attempts to refresh the access token using the refresh token
 */
async function attemptTokenRefresh(): Promise<AuthResponse | null> {
  if (isRefreshing && refreshPromise) {
    return refreshPromise;
  }

  isRefreshing = true;
  refreshPromise = (async () => {
    try {
      const refreshToken = localStorage.getItem("refresh_token");
      if (!refreshToken) {
        return null;
      }

      const response = await UsersService.refreshToken({
        refresh_token: refreshToken,
      });

      if (response.access_token && response.refresh_token) {
        localStorage.setItem("access_token", response.access_token);
        localStorage.setItem("refresh_token", response.refresh_token);
        return response;
      }
      return null;
    } catch (error) {
      // Refresh failed, clear tokens
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
      return null;
    } finally {
      isRefreshing = false;
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

/**
 * Wraps an API call to handle 401 errors by refreshing the token and retrying
 */
async function withTokenRefresh<T>(
  apiCall: () => Promise<T>,
  retries = 1
): Promise<T> {
  try {
    return await apiCall();
  } catch (error: any) {
    // Check if it's a 401 error (from ApiError or regular error) and we haven't exhausted retries
    const is401 = 
      (error instanceof GeneratedApiError && error.status === 401) ||
      (error.status === 401);
    
    if (is401 && retries > 0) {
      const refreshResponse = await attemptTokenRefresh();
      if (refreshResponse) {
        // Retry the original call with new token
        return withTokenRefresh(apiCall, retries - 1);
      } else {
        // Refresh failed, redirect to login
        if (typeof window !== "undefined") {
          window.location.href = "/login";
        }
        throw error;
      }
    }
    throw error;
  }
}

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public response?: { error?: string }
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export class ApiClient {
  // User APIs
  async createUser(data: CreateUserRequest): Promise<AuthResponse> {
    try {
      const response = await UsersService.createUser(data);
      if (response.access_token && response.refresh_token) {
        this.setTokens(response.access_token, response.refresh_token);
      }
      return response;
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async login(data: LoginRequest): Promise<AuthResponse> {
    try {
      const response = await UsersService.login(data);
      if (response.access_token && response.refresh_token) {
        this.setTokens(response.access_token, response.refresh_token);
      }
      return response;
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async refreshToken(data: RefreshTokenRequest): Promise<AuthResponse> {
    try {
      const response = await UsersService.refreshToken(data);
      if (response.access_token && response.refresh_token) {
        this.setTokens(response.access_token, response.refresh_token);
      }
      return response;
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async logout(): Promise<void> {
    if (typeof window === "undefined") return;
    
    try {
      // Call the logout endpoint to revoke tokens on the server
      // Use withTokenRefresh to handle token refresh if needed
      await withTokenRefresh(() => UsersService.logout());
    } catch (error: any) {
      // Even if the API call fails, we should still clear local tokens
      // This ensures the user is logged out locally even if the server call fails
      console.error("Logout API call failed:", error);
    } finally {
      // Always clear local storage regardless of API call success/failure
      localStorage.removeItem("access_token");
      localStorage.removeItem("refresh_token");
    }
  }

  isAuthenticated(): boolean {
    if (typeof window === "undefined") return false;
    return localStorage.getItem("access_token") !== null;
  }

  // Poll APIs
  async listPolls(): Promise<PollResponse[]> {
    try {
      return await withTokenRefresh(() => PollsService.listPolls());
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getPoll(id: string): Promise<PollResponse> {
    try {
      return await withTokenRefresh(() => PollsService.getPoll(id));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async createPoll(data: CreatePollRequest): Promise<PollResponse> {
    try {
      return await withTokenRefresh(() => PollsService.createPoll(data));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async updatePoll(id: string, data: UpdatePollRequest): Promise<PollResponse> {
    try {
      return await withTokenRefresh(() => PollsService.updatePoll(id, data));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async deletePoll(id: string): Promise<void> {
    try {
      return await withTokenRefresh(() => PollsService.deletePoll(id));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  // Vote APIs
  async voteOnPoll(id: string, data: VoteRequest): Promise<VoteResponse> {
    try {
      return await withTokenRefresh(() => VotesService.voteOnPoll(id, data));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getVoteCounts(id: string): Promise<VoteCountsResponse> {
    try {
      return await withTokenRefresh(() => VotesService.getVoteCounts(id));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getVotersByOption(id: string, option: string): Promise<VotersResponse> {
    try {
      return await withTokenRefresh(() => VotesService.getVotersByOption(id, option));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async deleteVote(id: string): Promise<void> {
    try {
      return await withTokenRefresh(() => VotesService.deleteVote(id));
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  private setTokens(accessToken: string, refreshToken: string): void {
    if (typeof window === "undefined") return;
    localStorage.setItem("access_token", accessToken);
    localStorage.setItem("refresh_token", refreshToken);
  }

  private handleError(error: any): ApiError {
    if (error.body) {
      return new ApiError(
        error.body.error || error.message || "An error occurred",
        error.status || 500,
        error.body
      );
    }
    return new ApiError(
      error.message || "An error occurred",
      error.status || 500
    );
  }
}

export const apiClient = new ApiClient();

// Re-export types for convenience
export type {
  AuthResponse,
  CreateUserRequest,
  LoginRequest,
  RefreshTokenRequest,
  CreatePollRequest,
  UpdatePollRequest,
  PollResponse,
  VoteRequest,
  VoteResponse,
  VoteCountsResponse,
  VotersResponse,
  UserInfo,
} from "./generated";

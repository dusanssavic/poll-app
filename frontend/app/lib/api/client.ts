// API Client wrapper using generated OpenAPI client
import { OpenAPI } from "./generated/core/OpenAPI";
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

  logout(): void {
    if (typeof window === "undefined") return;
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
  }

  isAuthenticated(): boolean {
    if (typeof window === "undefined") return false;
    return localStorage.getItem("access_token") !== null;
  }

  // Poll APIs
  async listPolls(): Promise<PollResponse[]> {
    try {
      return await PollsService.listPolls();
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getPoll(id: string): Promise<PollResponse> {
    try {
      return await PollsService.getPoll(id);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async createPoll(data: CreatePollRequest): Promise<PollResponse> {
    try {
      return await PollsService.createPoll(data);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async updatePoll(id: string, data: UpdatePollRequest): Promise<PollResponse> {
    try {
      return await PollsService.updatePoll(id, data);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async deletePoll(id: string): Promise<void> {
    try {
      return await PollsService.deletePoll(id);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  // Vote APIs
  async voteOnPoll(id: string, data: VoteRequest): Promise<VoteResponse> {
    try {
      return await VotesService.voteOnPoll(id, data);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getVoteCounts(id: string): Promise<VoteCountsResponse> {
    try {
      return await VotesService.getVoteCounts(id);
    } catch (error: any) {
      throw this.handleError(error);
    }
  }

  async getVotersByOption(id: string, option: string): Promise<VotersResponse> {
    try {
      return await VotesService.getVotersByOption(id, option);
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

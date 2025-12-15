/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { AuthResponse } from '../models/AuthResponse';
import type { CreateUserRequest } from '../models/CreateUserRequest';
import type { LoginRequest } from '../models/LoginRequest';
import type { RefreshTokenRequest } from '../models/RefreshTokenRequest';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class UsersService {
    /**
     * Create a new user
     * Register a new user account
     * @param requestBody
     * @returns AuthResponse User created successfully
     * @throws ApiError
     */
    public static createUser(
        requestBody: CreateUserRequest,
    ): CancelablePromise<AuthResponse> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/users',
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                400: `Invalid request or user already exists`,
            },
        });
    }
    /**
     * User login
     * Authenticate user and receive access tokens
     * @param requestBody
     * @returns AuthResponse Login successful
     * @throws ApiError
     */
    public static login(
        requestBody: LoginRequest,
    ): CancelablePromise<AuthResponse> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/users/login',
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                401: `Invalid credentials`,
            },
        });
    }
    /**
     * Refresh access token
     * Get a new access token using a refresh token
     * @param requestBody
     * @returns AuthResponse Token refreshed successfully
     * @throws ApiError
     */
    public static refreshToken(
        requestBody: RefreshTokenRequest,
    ): CancelablePromise<AuthResponse> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/users/refresh',
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                401: `Invalid refresh token`,
            },
        });
    }
    /**
     * User logout
     * Logout user and revoke all refresh tokens
     * @returns void
     * @throws ApiError
     */
    public static logout(): CancelablePromise<void> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/users/logout',
            errors: {
                401: `Unauthorized`,
                500: `Internal server error`,
            },
        });
    }
}

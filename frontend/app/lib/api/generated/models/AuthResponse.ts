/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
export type AuthResponse = {
    /**
     * JWT access token (15 minutes TTL)
     */
    access_token?: string;
    /**
     * JWT refresh token (7 days TTL)
     */
    refresh_token?: string;
    user_id?: string;
    email?: string;
    username?: string;
};


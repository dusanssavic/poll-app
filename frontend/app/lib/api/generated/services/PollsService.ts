/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { CreatePollRequest } from '../models/CreatePollRequest';
import type { PollResponse } from '../models/PollResponse';
import type { UpdatePollRequest } from '../models/UpdatePollRequest';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class PollsService {
    /**
     * List all polls
     * Get a list of all polls
     * @returns PollResponse List of polls
     * @throws ApiError
     */
    public static listPolls(): CancelablePromise<Array<PollResponse>> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/api/polls',
        });
    }
    /**
     * Create a new poll
     * Create a new poll (requires authentication)
     * @param requestBody
     * @returns PollResponse Poll created successfully
     * @throws ApiError
     */
    public static createPoll(
        requestBody: CreatePollRequest,
    ): CancelablePromise<PollResponse> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/polls',
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                400: `Invalid request`,
                401: `Unauthorized`,
            },
        });
    }
    /**
     * Get poll by ID
     * Get detailed information about a specific poll
     * @param id Poll ID
     * @returns PollResponse Poll details
     * @throws ApiError
     */
    public static getPoll(
        id: string,
    ): CancelablePromise<PollResponse> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/api/polls/{id}',
            path: {
                'id': id,
            },
            errors: {
                404: `Poll not found`,
            },
        });
    }
    /**
     * Update poll
     * Update a poll (requires authentication and ownership)
     * @param id Poll ID
     * @param requestBody
     * @returns PollResponse Poll updated successfully
     * @throws ApiError
     */
    public static updatePoll(
        id: string,
        requestBody: UpdatePollRequest,
    ): CancelablePromise<PollResponse> {
        return __request(OpenAPI, {
            method: 'PUT',
            url: '/api/polls/{id}',
            path: {
                'id': id,
            },
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                400: `Invalid request or not owner`,
                401: `Unauthorized`,
            },
        });
    }
    /**
     * Delete poll
     * Delete a poll (requires authentication and ownership)
     * @param id Poll ID
     * @returns void
     * @throws ApiError
     */
    public static deletePoll(
        id: string,
    ): CancelablePromise<void> {
        return __request(OpenAPI, {
            method: 'DELETE',
            url: '/api/polls/{id}',
            path: {
                'id': id,
            },
            errors: {
                400: `Invalid request or not owner`,
                401: `Unauthorized`,
            },
        });
    }
}

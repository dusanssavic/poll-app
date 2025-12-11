/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { VoteCountsResponse } from '../models/VoteCountsResponse';
import type { VoteRequest } from '../models/VoteRequest';
import type { VoteResponse } from '../models/VoteResponse';
import type { VotersResponse } from '../models/VotersResponse';
import type { CancelablePromise } from '../core/CancelablePromise';
import { OpenAPI } from '../core/OpenAPI';
import { request as __request } from '../core/request';
export class VotesService {
    /**
     * Vote on a poll
     * Submit a vote for a poll option (requires authentication, one vote per user per poll)
     * @param id Poll ID
     * @param requestBody
     * @returns VoteResponse Vote submitted successfully
     * @throws ApiError
     */
    public static voteOnPoll(
        id: string,
        requestBody: VoteRequest,
    ): CancelablePromise<VoteResponse> {
        return __request(OpenAPI, {
            method: 'POST',
            url: '/api/polls/{id}/vote',
            path: {
                'id': id,
            },
            body: requestBody,
            mediaType: 'application/json',
            errors: {
                400: `Invalid request or already voted`,
                401: `Unauthorized`,
            },
        });
    }
    /**
     * Get vote counts
     * Get vote counts for all options in a poll
     * @param id Poll ID
     * @returns VoteCountsResponse Vote counts
     * @throws ApiError
     */
    public static getVoteCounts(
        id: string,
    ): CancelablePromise<VoteCountsResponse> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/api/polls/{id}/votes',
            path: {
                'id': id,
            },
            errors: {
                404: `Poll not found`,
            },
        });
    }
    /**
     * Get voters by option
     * Get list of users who voted for a specific option
     * @param id Poll ID
     * @param option Poll option
     * @returns VotersResponse List of voters
     * @throws ApiError
     */
    public static getVotersByOption(
        id: string,
        option: string,
    ): CancelablePromise<VotersResponse> {
        return __request(OpenAPI, {
            method: 'GET',
            url: '/api/polls/{id}/votes/{option}',
            path: {
                'id': id,
                'option': option,
            },
            errors: {
                404: `Poll or option not found`,
            },
        });
    }
}

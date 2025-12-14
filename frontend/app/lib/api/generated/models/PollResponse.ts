/* generated using openapi-typescript-codegen -- do not edit */
/* istanbul ignore file */
/* tslint:disable */
/* eslint-disable */
import type { UserInfo } from './UserInfo';
export type PollResponse = {
    id?: string;
    title?: string;
    description?: string | null;
    options?: Array<string>;
    owner_id?: string;
    created_at?: string;
    updated_at?: string;
    /**
     * Map of option to vote count (only included in poll details endpoint)
     */
    vote_counts?: Record<string, number>;
    /**
     * Map of option to list of voters (only included in poll details endpoint)
     */
    voters_by_option?: Record<string, Array<UserInfo>>;
};


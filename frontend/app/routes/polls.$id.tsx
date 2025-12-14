import { useEffect, useState } from "react";
import { useParams, Link, useNavigate } from "react-router";
import type { Route } from "./+types/polls.$id";
import { apiClient } from "../lib/api/client";
import { useAuth } from "../lib/contexts/auth";
import type { PollResponse, UserInfo } from "../lib/api/client";
import { Navigation } from "../components/Navigation";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Poll Details - Poll App" },
    { name: "description", content: "View poll details and vote" },
  ];
}

export default function PollDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { isAuthenticated, user } = useAuth();
  const [poll, setPoll] = useState<PollResponse | null>(null);
  const [selectedOption, setSelectedOption] = useState<string>("");
  const [selectedOptionForVoters, setSelectedOptionForVoters] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [voting, setVoting] = useState(false);
  const [reverting, setReverting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      loadPoll();
    }
  }, [id]);

  const loadPoll = async () => {
    try {
      const data = await apiClient.getPoll(id!);
      setPoll(data);
    } catch (err: any) {
      setError(err.message || "Failed to load poll");
    } finally {
      setLoading(false);
    }
  };

  const handleVote = async () => {
    if (!selectedOption || !isAuthenticated) {
      return;
    }

    setVoting(true);
    setError(null);

    try {
      await apiClient.voteOnPoll(id!, { option: selectedOption });
      await loadPoll();
      setSelectedOption("");
    } catch (err: any) {
      setError(err.response?.error || err.message || "Failed to vote");
    } finally {
      setVoting(false);
    }
  };

  const handleVoteCountClick = (option: string) => {
    setSelectedOptionForVoters(option);
  };

  const isOwner = poll && isAuthenticated && user && poll.owner_id === user.user_id;

  // Check if the current user has voted
  const hasUserVoted = (): boolean => {
    if (!poll || !user || !poll.voters_by_option) {
      return false;
    }
    
    // Check if user's ID appears in any of the voters_by_option arrays
    for (const option in poll.voters_by_option) {
      console.log(option, user.user_id);
      const voters = poll.voters_by_option[option];
      if (voters.some((voter: UserInfo) => voter.id === user.user_id)) {
        return true;
      }
    }
    return false;
  };

  // Get the option the user voted for
  const getUserVotedOption = (): string | null => {
    if (!poll || !user || !poll.voters_by_option) {
      return null;
    }
    
    for (const option in poll.voters_by_option) {
      const voters = poll.voters_by_option[option];
      if (voters.some((voter: UserInfo) => voter.id === user.user_id)) {
        return option;
      }
    }
    return null;
  };

  const handleRevertVote = async () => {
    if (!isAuthenticated || !id) {
      return;
    }

    setReverting(true);
    setError(null);

    try {
      await apiClient.deleteVote(id);
      await loadPoll();
      setSelectedOption("");
    } catch (err: any) {
      setError(err.response?.error || err.message || "Failed to revert vote");
    } finally {
      setReverting(false);
    }
  };

  const userHasVoted = hasUserVoted();
  const userVotedOption = getUserVotedOption();

  if (loading) {
    return (
      <>
        <Navigation />
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center">Loading poll...</div>
        </div>
      </>
    );
  }

  if (error && !poll) {
    return (
      <>
        <Navigation />
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center text-red-600 dark:text-red-400">
            {error}
          </div>
        </div>
      </>
    );
  }

  if (!poll) {
    return null;
  }

  const totalVotes = poll?.vote_counts
    ? Object.values(poll.vote_counts).reduce((sum: number, count: number) => sum + count, 0)
    : 0;

  return (
    <>
      <Navigation />
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link
          to="/"
          className="text-blue-600 hover:text-blue-500 dark:text-blue-400 mb-4 inline-block"
        >
          ← Back to polls
        </Link>

        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6 mb-6">
          <div className="flex items-start justify-between mb-4">
            <div className="flex-1">
              <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
                {poll.title}
              </h1>
              {poll.description && (
                <p className="text-gray-600 dark:text-gray-400">
                  {poll.description}
                </p>
              )}
            </div>
            {isOwner && (
              <Link
                to={`/polls/${poll.id}/edit`}
                className="ml-4 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                title="Edit poll"
              >
                <svg
                  className="w-6 h-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                  />
                </svg>
              </Link>
            )}
          </div>

          {error && (
            <div className="mb-4 rounded-md bg-red-50 dark:bg-red-900/20 p-4">
              <div className="text-sm text-red-800 dark:text-red-200">
                {error}
              </div>
            </div>
          )}

          {isAuthenticated && !userHasVoted && (
            <div className="mb-6">
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                Cast your votes
              </h2>
              <div className="space-y-2">
                {poll.options?.map((option: string) => (
                  <label
                    key={option}
                    className="flex items-center p-3 border border-gray-300 dark:border-gray-700 rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer"
                  >
                    <input
                      type="radio"
                      name="option"
                      value={option}
                      checked={selectedOption === option}
                      onChange={(e) => setSelectedOption(e.target.value)}
                      className="mr-3"
                    />
                    <span className="text-gray-900 dark:text-white">
                      {option}
                    </span>
                  </label>
                ))}
              </div>
              <button
                onClick={handleVote}
                disabled={!selectedOption || voting}
                className="mt-4 w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {voting ? "Voting..." : "Vote"}
              </button>
            </div>
          )}

          {!isAuthenticated && !userHasVoted && (
            <div className="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-md">
              <p className="text-sm text-yellow-800 dark:text-yellow-200">
                Please{" "}
                <Link
                  to="/login"
                  className="font-medium underline"
                >
                  sign in
                </Link>{" "}
                to vote on this poll.
              </p>
            </div>
          )}

          {userHasVoted && (
            <div className="mt-6">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-gray-900 dark:text-white">
                  Results ({totalVotes} {totalVotes === 1 ? "vote" : "votes"})
                </h2>
                <button
                  onClick={handleRevertVote}
                  disabled={reverting}
                  className="px-4 py-2 text-sm bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white rounded-md hover:bg-gray-300 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {reverting ? "Reverting..." : "Change Vote"}
                </button>
              </div>
              <div className="space-y-2">
                {poll.options?.map((option: string) => {
                  const count = poll?.vote_counts?.[option] || 0;
                  const percentage =
                    totalVotes > 0 ? Math.round((count / totalVotes) * 100) : 0;
                  const isUserVotedOption = option === userVotedOption;

                  return (
                    <div key={option} className="relative">
                      <button
                        onClick={() => handleVoteCountClick(option)}
                        className={`w-full text-left p-3 border rounded-md hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors ${
                          isUserVotedOption
                            ? "border-green-500 dark:border-green-400 border-2"
                            : "border-gray-300 dark:border-gray-700"
                        }`}
                      >
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-gray-900 dark:text-white font-medium">
                            {option}
                            {isUserVotedOption && (
                              <span className="ml-2 text-xs text-green-600 dark:text-green-400">
                                (Your vote)
                              </span>
                            )}
                          </span>
                          <span className="text-gray-600 dark:text-gray-400 text-sm">
                            {count} ({percentage}%)
                          </span>
                        </div>
                        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                          <div
                            className="bg-blue-600 h-2 rounded-full transition-all"
                            style={{ width: `${percentage}%` }}
                          />
                        </div>
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {selectedOptionForVoters !== null && (
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                Voters for "{selectedOptionForVoters}"
              </h3>
              <button
                onClick={() => setSelectedOptionForVoters(null)}
                className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
              >
                ✕
              </button>
            </div>
            <div className="space-y-2">
              {!poll?.voters_by_option?.[selectedOptionForVoters] || poll.voters_by_option[selectedOptionForVoters].length === 0 ? (
                <p className="text-gray-500 dark:text-gray-400">
                  No voters yet
                </p>
              ) : (
                poll.voters_by_option[selectedOptionForVoters].map((voter: UserInfo) => (
                  <div
                    key={voter.id}
                    className="p-2 border border-gray-200 dark:border-gray-700 rounded"
                  >
                    <p className="text-gray-900 dark:text-white font-medium">
                      {voter.username}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {voter.email}
                    </p>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
    </>
  );
}



import { useEffect, useState } from "react";
import { Link } from "react-router";
import type { Route } from "./+types/home";
import { apiClient } from "../lib/api/client";
import { useAuth } from "../lib/contexts/auth";
import type { PollResponse } from "../lib/api/client";
import { Navigation } from "../components/Navigation";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Poll App" },
    { name: "description", content: "Poll Application" },
  ];
}

export default function Home() {
  const [polls, setPolls] = useState<PollResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { isAuthenticated, user } = useAuth();

  useEffect(() => {
    loadPolls();
  }, []);

  const loadPolls = async () => {
    try {
      setLoading(true);
      const data = await apiClient.listPolls();
      setPolls(data);
    } catch (err: any) {
      setError(err.message || "Failed to load polls");
    } finally {
      setLoading(false);
    }
  };

  const isOwner = (poll: PollResponse) => {
    return isAuthenticated && user && poll.owner_id === user.user_id;
  };

  if (loading) {
    return (
      <>
        <Navigation />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center">Loading polls...</div>
        </div>
      </>
    );
  }

  if (error) {
    return (
      <>
        <Navigation />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="text-center text-red-600 dark:text-red-400">
            {error}
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <Navigation />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
            All Polls
          </h1>
        </div>

        {polls.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-500 dark:text-gray-400">
              No polls yet.{" "}
              {isAuthenticated && (
                <Link
                  to="/polls/new"
                  className="text-blue-600 hover:text-blue-500 dark:text-blue-400"
                >
                  Create the first one!
                </Link>
              )}
            </p>
          </div>
        ) : (
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {polls.map((poll) => (
              <div
                key={poll.id}
                className="bg-white dark:bg-gray-800 rounded-lg shadow p-6 hover:shadow-lg transition-shadow"
              >
                <div className="flex items-start justify-between mb-4">
                  <Link
                    to={`/polls/${poll.id}`}
                    className="flex-1"
                  >
                    <h2 className="text-xl font-semibold text-gray-900 dark:text-white hover:text-blue-600 dark:hover:text-blue-400">
                      {poll.title}
                    </h2>
                  </Link>
                  {isOwner(poll) && (
                    <Link
                      to={`/polls/${poll.id}/edit`}
                      className="ml-2 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
                      title="Edit poll"
                    >
                      <svg
                        className="w-5 h-5"
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
                {poll.description && (
                  <p className="text-gray-600 dark:text-gray-400 mb-4">
                    {poll.description}
                  </p>
                )}
                <div className="flex items-center justify-between">
                  <span className="text-sm text-gray-500 dark:text-gray-400">
                    {poll.options?.length || 0} options
                  </span>
                  <Link
                    to={`/polls/${poll.id}`}
                    className="text-sm text-blue-600 hover:text-blue-500 dark:text-blue-400"
                  >
                    View Details →
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

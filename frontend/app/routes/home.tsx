import type { Route } from "./+types/home";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Poll App" },
    { name: "description", content: "Poll Application" },
  ];
}

export default function Home() {
  return (
    <div>
      <h1>Poll App</h1>
    </div>
  );
}

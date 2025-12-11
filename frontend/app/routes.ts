import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/home.tsx"),
  route("login", "routes/login.tsx"),
  route("signup", "routes/signup.tsx"),
  route("polls/new", "routes/polls.new.tsx"),
  route("polls/:id", "routes/polls.$id.tsx"),
  route("polls/:id/edit", "routes/polls.$id.edit.tsx"),
] satisfies RouteConfig;

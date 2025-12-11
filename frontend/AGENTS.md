# Poll-App frontend!

## Getting Started

### Installation

Install the dependencies:

```bash
npm install
```

### Development

Start the development server with HMR:

```bash
npm run dev
```

Your application will be available at `http://localhost:5173`.

## Type Generation

The frontend uses two types of generated TypeScript code:

### Route Types (React Router)

React Router v7 automatically generates TypeScript types for all routes. These types are used for type-safe route components, loaders, actions, and meta functions.

**Automatic Generation:**
- Types are automatically generated when you run `npm run dev`
- Types are generated as part of `npm run typecheck`

**Manual Generation:**
If you see errors about missing `+types` modules, generate them manually:

```bash
npx react-router typegen
```

This will generate type files in `.react-router/types/app/routes/+types/` for all your routes.

**Note:** The `+types` imports (e.g., `import type { Route } from "./+types/login"`) are resolved by React Router's type system. If your editor shows errors, try:
1. Restarting the TypeScript server
2. Running `npm run dev` once to ensure types are generated
3. Running `npx react-router typegen` manually

### API Client Generation

The frontend uses a TypeScript API client generated from the OpenAPI specification.

**Generate API Client:**

```bash
npm run generate-api
```

This will generate TypeScript types and API client code in `app/lib/api/generated/` based on the OpenAPI spec in `../backend/api/openapi.json`.

**Note:** The generated client uses `axios` for HTTP requests, which is included as a dependency.

### Using the Generated API Client

The generated API client is wrapped in `app/lib/api/client.ts` for convenience. Use the wrapper instead of the generated services directly:

```typescript
import { apiClient } from "~/lib/api/client";
import type { PollResponse } from "~/lib/api/client";

// Use the API client
const polls = await apiClient.listPolls();
const newPoll = await apiClient.createPoll({
  title: 'My Poll',
  options: ['Option 1', 'Option 2']
});
```

The wrapper handles:
- Authentication token management (automatically adds tokens from localStorage)
- Error handling
- Base URL configuration

**Direct Service Usage (Advanced):**
If you need to use the generated services directly:

```typescript
import { PollsService, OpenAPI } from "~/lib/api/generated";

// Configure OpenAPI (usually done in client.ts)
OpenAPI.BASE = "http://localhost:8080";
OpenAPI.TOKEN = async () => localStorage.getItem("access_token") || "";

// Use services
const polls = await PollsService.listPolls();
```

### Re-generating Types

**Route Types:**
Route types are automatically regenerated when routes change. If needed, regenerate manually:
```bash
npx react-router typegen
```

**API Client:**
Whenever the backend API changes, regenerate the client:
```bash
npm run generate-api
```

**Both Types:**
To regenerate both route types and API client:
```bash
npx react-router typegen && npm run generate-api
```

## Building for Production

Create a production build:

```bash
npm run build
```

## Deployment

### Docker Deployment

To build and run using Docker:

```bash
docker build -t my-app .

# Run the container
docker run -p 3000:3000 my-app
```

### DIY Deployment

Make sure to deploy the output of `npm run build`

```
├── package.json
├── package-lock.json (or pnpm-lock.yaml, or bun.lockb)
├── build/
│   ├── client/    # Static assets
│   └── server/    # Server-side code
```

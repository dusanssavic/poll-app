# Library Structure

This directory contains shared utilities, contexts, and API clients used across the application.

## Directory Structure

```
lib/
├── api/              # API client and generated code
│   ├── client.ts     # API client wrapper (configured for auth)
│   └── generated/    # Auto-generated from OpenAPI spec (DO NOT EDIT)
├── contexts/         # React Context providers
│   └── auth.tsx      # Authentication context
├── hooks/            # Custom React hooks (for future use)
└── utils/            # Pure utility functions (for future use)
```

## Usage

### API Client
```typescript
import { apiClient } from "~/lib/api/client";
import type { PollResponse } from "~/lib/api/client";

const polls = await apiClient.listPolls();
```

### Authentication Context
```typescript
import { useAuth } from "~/lib/contexts/auth";

function MyComponent() {
  const { user, isAuthenticated, login, logout } = useAuth();
  // ...
}
```

## Conventions

- **`api/`**: API-related code, including generated clients
- **`contexts/`**: React Context providers and hooks
- **`hooks/`**: Reusable custom React hooks
- **`utils/`**: Pure utility functions (no React dependencies)

## Adding New Code

- **Context providers** → `contexts/`
- **Custom hooks** → `hooks/`
- **Utility functions** → `utils/`
- **API-related** → `api/` (but use `client.ts` wrapper, don't edit `generated/`)


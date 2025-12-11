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

## API Client Generation

The frontend uses a TypeScript API client generated from the OpenAPI specification.

### Generate API Client

First, install the OpenAPI generator:

```bash
npm install -g @openapitools/openapi-generator-cli
```

Then generate the client:

```bash
npm run generate-api
```

This will generate TypeScript types and API client code in `src/api/generated/` based on the OpenAPI spec in `../backend/api/openapi.json`.

### Using the Generated API Client

```typescript
import { DefaultApi, Configuration } from './api/generated';

// Create API instance
const api = new DefaultApi(new Configuration({
  basePath: 'http://localhost:8080',
  accessToken: () => {
    // Get token from localStorage or context
    return localStorage.getItem('access_token') || '';
  }
}));

// Use the API
const polls = await api.listPolls();
const newPoll = await api.createPoll({
  title: 'My Poll',
  options: ['Option 1', 'Option 2']
}, {
  headers: {
    'Authorization': `Bearer ${localStorage.getItem('access_token')}`
  }
});
```

### Re-generating the Client

Whenever the backend API changes, regenerate the client:

```bash
npm run generate-api
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

# API Documentation

This directory contains the OpenAPI 3.0 specification for the Poll App API in JSON format.

## File

- `openapi.json` - Complete OpenAPI 3.0 specification in a single JSON file

## Generate TypeScript Client for Frontend

Using [openapi-generator](https://openapi-generator.tech/) (recommended):

```bash
# Install openapi-generator
npm install -g @openapitools/openapi-generator-cli

# Generate TypeScript client
openapi-generator-cli generate \
  -i backend/api/openapi.json \
  -g typescript-axios \
  -o frontend/src/api/generated \
  --additional-properties=supportsES6=true,npmName=poll-app-api,withInterfaces=true
```

Or using [swagger-codegen](https://swagger.io/tools/swagger-codegen/):

```bash
swagger-codegen generate \
  -i backend/api/openapi.json \
  -l typescript-axios \
  -o frontend/src/api/generated
```

## View API Documentation

You can view the API documentation using:

1. **Swagger UI**: Upload `openapi.json` to https://editor.swagger.io/
2. **Redoc**: Use https://redocly.github.io/redoc/ or install locally
3. **Postman**: Import the OpenAPI spec into Postman

## Validate the Specification

Validate the OpenAPI spec:

```bash
# Using swagger-cli
npm install -g @apidevtools/swagger-cli
swagger-cli validate backend/api/openapi.json

# Using openapi-generator
openapi-generator-cli validate -i backend/api/openapi.json
```

## Integration with Frontend

The generated TypeScript client can be used in the frontend like this:

```typescript
import { DefaultApi, Configuration } from './api/generated';

const api = new DefaultApi(new Configuration({
  basePath: 'http://localhost:8080',
  accessToken: () => localStorage.getItem('access_token') || ''
}));

// Use the API
const polls = await api.listPolls();
const poll = await api.createPoll({
  title: 'My Poll',
  options: ['Option 1', 'Option 2']
}, {
  headers: {
    'Authorization': `Bearer ${localStorage.getItem('access_token')}`
  }
});
```

## Keeping the Spec in Sync

When adding new endpoints or modifying existing ones:

1. Update `backend/api/openapi.json`
2. Regenerate the frontend client using the command above
3. Update any frontend code that uses the API

Consider adding a script to `package.json` to automate client generation.

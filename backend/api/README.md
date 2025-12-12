# API Documentation

This directory contains the OpenAPI 3.0 specification for the Poll App API in JSON format.

## Files

- `openapi.yaml` - Complete OpenAPI 3.0 specification in YAML format (source of truth)
- `openapi.json` - Complete OpenAPI 3.0 specification in JSON format (generated from YAML)
- `types.gen.go` - Generated Go types from OpenAPI schema (auto-generated, do not edit)

## Generate Go Types for Backend

The backend uses [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen) to generate Go structs from the OpenAPI schema.

**Generate Go types:**
```bash
cd backend
make generate
# or
go generate ./api
```

This will generate `api/types.gen.go` with all request/response types defined in the OpenAPI schema.

**Note:** The generated file is in `.gitignore` and should be regenerated when the OpenAPI schema changes.

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

1. Update `backend/api/openapi.yaml` (source of truth)
2. Update `backend/api/openapi.json` to match (or regenerate from YAML)
3. Regenerate Go types: `cd backend && make generate`
4. Regenerate the frontend client: `cd frontend && npm run generate-api`
5. Update any code that uses the API

**Workflow:**
- Always update `openapi.yaml` first
- Regenerate both Go types and TypeScript client
- The generated files are in `.gitignore` and should be regenerated on each machine

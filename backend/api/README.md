# API Documentation

This directory contains the OpenAPI 3.0 specification for the Poll App API.

## Files

- `openapi.yaml` - OpenAPI 3.0 specification in YAML format (source of truth)
- `openapi.json` - OpenAPI 3.0 specification in JSON format
- `types.gen.go` - Generated Go types (auto-generated, do not edit)

## Generating Code from OpenAPI Schema

When you update the OpenAPI schema, regenerate both backend and frontend code:

### Backend (Go Types)

```bash
cd backend
make generate-api
```

This generates `api/types.gen.go` with all request/response types using [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen).

### Frontend (TypeScript Client)

```bash
cd frontend
npm run generate-api
```

This generates TypeScript types and API client in `app/lib/api/generated/` using [openapi-typescript-codegen](https://github.com/ferdikoomen/openapi-typescript-codegen).

## Workflow

When adding or modifying API endpoints:

1. Update `openapi.yaml` (source of truth)
2. Update `openapi.json` to match
3. Regenerate backend types: `cd backend && make generate-api`
4. Regenerate frontend client: `cd frontend && npm run generate-api`
5. Update code that uses the API

**Note:** Generated files are in `.gitignore` and should be regenerated on each machine.

## Viewing API Documentation

- **Swagger UI**: https://editor.swagger.io/ (upload `openapi.json`)
- **Redoc**: https://redocly.github.io/redoc/ (upload `openapi.json`)
- **Postman**: Import `openapi.json`

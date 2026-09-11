# Swagger/OpenAPI API Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document all existing CreatorHub Go API routes in OpenAPI 3.0 and expose the spec and Swagger UI locally.

**Architecture:** Keep a hand-authored `openapi.yaml` as the source of truth. Add two read-only `net/http` routes that serve the YAML and a small Swagger UI HTML shell; no business handler or database code changes are required.

**Tech Stack:** Go 1.24 `net/http`, OpenAPI 3.0 YAML, Swagger UI browser CDN, Go `embed` or a fixed docs directory path, Go tests with `net/http/httptest`.

**Spec:** `docs/superpowers/specs/2026-09-11-swagger-openapi-design.md`

## Global Constraints

- Preserve all existing API behavior and route paths.
- Use the actual response envelope `{code, message, data}`.
- Document all 29 existing routes exactly once.
- Do not add a runtime Go dependency or modify Flutter/Vue/MySQL code.
- Keep the API server running after verification.

---

### Task 1: Build the OpenAPI specification

**Files:**
- Create: `services/api/docs/openapi.yaml`
- Create: `services/api/docs/docs.go`
- Read for request/response fields: `services/api/cmd/server/main.go`
- Read for domain response models: `services/api/internal/account`, `services/api/internal/chat`, `services/api/internal/friend`, `services/api/internal/video`

**Interfaces:**
- Produces: OpenAPI 3.0 document at `/openapi.yaml` in a later task.
- Schema names used by later tasks: `ErrorResponse`, `User`, `AuthData`, `Video`, `Conversation`, `Message`, `Group`, `GroupMember`, `Friend`, and `FriendRequest`.

- [x] **Step 1: Inventory the handlers and fields**

  Read each handler registered in `services/api/cmd/server/main.go` and record its exact JSON input fields, path/query parameters, success status, and response data shape. Use the route inventory in the spec as the checklist; do not invent endpoints.

- [x] **Step 2: Write the OpenAPI document**

  Create `services/api/docs/openapi.yaml` with `openapi: 3.0.3`, server URL `/`, `info`, the 29 paths, `components.securitySchemes.bearerAuth`, reusable schemas, and reusable error responses. Public routes are `/health`, registration, user login, and admin login; all other `/api/v1` routes require `bearerAuth`.

- [x] **Step 3: Validate the document locally**

  Run a YAML parser available in the workspace or a small standard-library check for required top-level keys, then verify that the set of `(method, path)` entries equals the 29-route inventory. Expected result: no parse error, no missing or duplicate route.

### Task 2: Serve the specification and Swagger UI

**Files:**
- Create: `services/api/docs/swagger.html`
- Modify: `services/api/cmd/server/main.go` near the existing route registrations
- Create: `services/api/cmd/server/docs_routes.go`
- Test: `services/api/cmd/server/swagger_test.go`

**Interfaces:**
- Produces: `GET /openapi.yaml` with `Content-Type: application/yaml` and `GET /swagger` with `Content-Type: text/html`.
- Consumes: `services/api/docs/openapi.yaml` and `services/api/docs/swagger.html`.

- [x] **Step 1: Add failing route tests**

  Add `httptest` coverage that invokes the documentation handlers and asserts `/openapi.yaml` returns HTTP 200 containing `openapi: 3.0.3`, while `/swagger` returns HTTP 200 containing `SwaggerUIBundle` and `/openapi.yaml`. Run `go test ./cmd/server -run Swagger -v`; the tests should fail before the routes exist.

- [x] **Step 2: Add the minimal serving implementation**

  Use `//go:embed docs/openapi.yaml docs/swagger.html` in `services/api/cmd/server/main.go` or a small adjacent docs helper. Register read-only handlers for `/openapi.yaml` and `/swagger`; return 404 for no other docs path. The HTML must initialize Swagger UI with `url: '/openapi.yaml'` and must not expose credentials or mutate API behavior.

- [x] **Step 3: Run focused tests**

  Run `go test ./cmd/server -run Swagger -v`. Expected result: all documentation route tests pass.

### Task 3: Verify the whole API documentation integration

**Files:**
- Modify only if validation finds a documented mismatch: `services/api/docs/openapi.yaml`
- Test: existing `services/api/cmd/server/*_test.go`

- [x] **Step 1: Run all Go API tests**

  Run `cd services/api && go test ./...`. Expected result: exit code 0.

- [x] **Step 2: Start or reuse the API server**

  Keep the existing API server running on its configured port. If it is not running, start it with the existing `.env` configuration; do not change credentials or ports.

- [x] **Step 3: Smoke-test both documentation URLs**

  Run `curl -i http://127.0.0.1:18080/openapi.yaml` and `curl -i http://127.0.0.1:18080/swagger`. Expected result: both return HTTP 200; the first contains `openapi: 3.0.3`, and the second contains the Swagger UI bootstrap code.

- [x] **Step 4: Check route coverage**

  Compare the route list in `main.go` with the OpenAPI `paths` map. Expected result: 29 matching method/path pairs, with no business route omitted.

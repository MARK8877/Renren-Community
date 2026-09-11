# CreatorHub API Swagger/OpenAPI Design

## Goal

为现有 Go API 提供一份可导入 Swagger UI、Postman 和其他 OpenAPI 工具的完整 OpenAPI 3.0 文档，并提供本地访问入口。

## Scope

覆盖 `services/api/cmd/server/main.go` 中现有的 29 个路由：健康检查，以及认证、视频、会话/群组、消息、用户和好友接口。只增加文档资源和文档访问路由，不改变任何业务接口的请求处理、鉴权和数据库行为。

## Design

1. 使用 `services/api/docs/openapi.yaml` 作为唯一文档源，手工描述实际代码中存在的路径、参数、请求体、响应体和错误码；同目录的 Go 包负责嵌入并提供静态资源。
2. 使用标准 OpenAPI 3.0 `components.securitySchemes.bearerAuth` 描述 JWT Bearer Token；除健康检查、注册、用户登录和管理员登录外，其他接口标记为需要鉴权。
3. 在 Go 服务中增加两个只读文档路由：
   - `GET /openapi.yaml` 返回 OpenAPI 文件；
   - `GET /swagger` 返回一个轻量 Swagger UI 页面，引用同一份 `/openapi.yaml`。
4. Swagger UI 使用浏览器加载的官方 CDN 资源；即使 CDN 不可用，`/openapi.yaml` 仍可直接下载并导入本地 Swagger 工具。
5. 文档统一描述现有响应包装格式 `{code, message, data}`，并覆盖 400、401、403、404、500 等实际返回状态。

## Endpoint inventory

- `GET /health`
- `GET /api/v1/videos`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/admin/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/conversations`
- `POST /api/v1/conversations/read-all`
- `POST /api/v1/conversations/groups`
- `GET /api/v1/conversations/{key}/group`
- `PATCH /api/v1/conversations/{key}/group`
- `GET /api/v1/conversations/{key}/members`
- `POST /api/v1/conversations/{key}/members/invite`
- `PATCH /api/v1/conversations/{key}/members/{userID}/role`
- `PATCH /api/v1/conversations/{key}/members/{userID}/mute`
- `DELETE /api/v1/conversations/{key}/members/{userID}`
- `DELETE /api/v1/conversations/{key}/leave`
- `PATCH /api/v1/conversations/{key}/owner`
- `GET /api/v1/conversations/{key}/join-requests`
- `POST /api/v1/conversations/{key}/join-requests/{id}/resolve`
- `GET /api/v1/conversations/{key}/messages`
- `POST /api/v1/conversations/{key}/messages`
- `POST /api/v1/conversations/{key}/read`
- `GET /api/v1/users/search`
- `GET /api/v1/friends`
- `GET /api/v1/friend-requests`
- `POST /api/v1/friend-requests`
- `POST /api/v1/friend-requests/{id}/accept`
- `POST /api/v1/friend-requests/{id}/reject`

## Acceptance criteria

- OpenAPI 3.0 parser accepts `openapi.yaml` without errors.
- Every route above appears exactly once in the document with the correct HTTP method.
- Protected operations declare `bearerAuth`; public operations do not require it.
- `/openapi.yaml` and `/swagger` are available while the API server is running.
- Existing API tests continue to pass, and documentation route tests verify content type, status code, and OpenAPI markers.

## Explicitly not included

- No change to Flutter, Vue, MySQL schema, authentication behavior, or API response behavior.
- No automatic code generator or new Go runtime dependency.
- No undocumented future endpoints.

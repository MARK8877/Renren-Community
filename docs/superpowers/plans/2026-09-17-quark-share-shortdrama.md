# 夸克公开分享短剧聚合 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将公开夸克分享目录中的全部视频聚合为一部短剧写入 `short_dramas`，并提供列表与按需刷新播放地址 API。

**Architecture:** Go API 新增独立 `quarkshortdrama` 适配器，使用夸克公开分享接口完成 token、目录递归和视频预览；复用现有 `shortdrama.Drama`/`Repository` 持久化 JSON。服务端新增短剧查询仓储和两个受保护 HTTP 路由，播放路由按剧集标识重新获取临时 m3u8。

**Tech Stack:** Go 1.24、标准库 `net/http`/`encoding/json`、现有 MySQL 仓储、`httptest`。

**Spec:** `docs/superpowers/specs/2026-09-17-quark-share-shortdrama-design.md`

## Global Constraints

- 只读取公开夸克分享元数据，不下载、转码或转存视频文件。
- `stoken` 只在请求期间使用，不写入数据库、日志或 API 响应。
- 只接受 HTTPS 夸克分享 URL，拒绝任意上游 URL，避免 SSRF。
- 复用 `short_dramas` 表，不新增表；其他数据源和 Flutter UI 不改动。
- m3u8 地址是临时地址，前端播放前必须调用刷新接口。

### Task 1: Build Quark share client and recursive collector

**Files:**
- Create: `services/api/internal/quarkshortdrama/url.go`
- Create: `services/api/internal/quarkshortdrama/client.go`
- Create: `services/api/internal/quarkshortdrama/model.go`
- Test: `services/api/internal/quarkshortdrama/url_test.go`
- Test: `services/api/internal/quarkshortdrama/client_test.go`

**Interfaces:**
- Consumes: public share URL, HTTP client, `pwd_id`, root `fid`.
- Produces: `type Episode struct { Episode int; Title, PwdID, FID, FIDToken, URL, M3U8URL string; Size, Duration int64 }`, `type Drama struct { ExternalID, Name, UpdateTime string; Episodes []Episode }`, `NewClient(httpClient *http.Client, apiHost string)`, `Collect(ctx context.Context, shareURL string, limit int) (Drama, error)`.

- [x] **Step 1: Write failing URL and response tests**

Test `ParseShareURL` with the supplied URL and assert `pwd_id=db532a8e9950` and `rootFID=3164a37f94734cad87356081c609f154`; reject non-HTTPS and non-`pan.quark.cn` hosts. Test token/detail/video-preview JSON fixtures, including 66 video filtering and ignoring images.

- [x] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/quarkshortdrama -count=1`

Expected: FAIL because `ParseShareURL`, `NewClient`, and `Collect` are undefined.

- [x] **Step 3: Implement minimal client**

Implement:

```go
func ParseShareURL(raw string) (pwdID, rootFID string, err error)
func NewClient(httpClient *http.Client, apiHost string) *Client
func (c *Client) Collect(ctx context.Context, shareURL string, limit int) (Drama, error)
```

Call `POST /1/clouddrive/share/sharepage/token` with `{pwd_id,passcode:""}`; recursively call `GET /1/clouddrive/share/sharepage/detail` with `pwd_id`, `stoken`, `pdir_fid`, `_page`, `_size`; filter `format_type` beginning with `video/`; for each video call `GET /1/clouddrive/share/sharepage/video_preview` with `pwd_id`, `stoken`, `fid`, `fid_token`. Sort filenames by the numeric episode captured from `第N集`, otherwise stable filename order. Stop at `limit` and detect repeated directory fids.

- [x] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/quarkshortdrama -count=1`

Expected: PASS without network access.

### Task 2: Extend short-drama JSON model and repository listing

**Files:**
- Modify: `services/api/internal/shortdrama/model.go`
- Modify: `services/api/internal/shortdrama/repository.go`
- Test: `services/api/internal/shortdrama/repository_test.go`

**Interfaces:**
- Consumes: `shortdrama.Drama` from Task 1 and existing `short_dramas` rows.
- Produces: `List(ctx context.Context, page, pageSize int) ([]DramaRecord, error)`, `ByID(ctx context.Context, id uint64) (DramaRecord, error)`; `DramaRecord` includes database ID and all persisted metadata.

- [x] **Step 1: Write failing repository tests**

Use the existing MySQL test pattern to insert one `short_dramas` row with an episode JSON object containing `pwd_id`, `fid`, `fid_token`, and `m3u8url`; assert `List` returns decoded episodes and `ByID` returns the same row.

- [x] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/shortdrama -run 'TestRepository(List|ByID)' -count=1`

Expected: FAIL because `List`, `ByID`, and the expanded episode fields are not implemented.

- [x] **Step 3: Implement model/repository support**

Add JSON fields to `Episode` while preserving existing fields. Implement bounded pagination (`page` minimum 1, `pageSize` default 20, maximum 100), `ORDER BY scraped_at DESC, id DESC`, JSON unmarshalling, and `sql.ErrNoRows` mapping to `ErrNotFound`.

- [x] **Step 4: Run tests to verify they pass**

Run: `go test ./internal/shortdrama -run 'TestRepository(List|ByID)' -count=1`

Expected: PASS.

### Task 3: Add Quark importer command and configuration

**Files:**
- Create: `services/api/cmd/importquarkshortdrama/main.go`
- Modify: `services/api/.env.example`
- Modify: `services/api/migrations/README.md`

**Interfaces:**
- Consumes: `QUARK_SHARE_URL`, optional `QUARK_IMPORT_LIMIT` (default 1000), optional `QUARK_API_HOST` (default `https://drive-m.quark.cn`).
- Produces: idempotent upsert into `short_dramas` and JSON output `{discovered, imported}`.

- [x] **Step 1: Write command validation test**

Add a small pure helper test for missing `QUARK_SHARE_URL` and invalid limits; assert the command exits before opening MySQL or making HTTP requests.

- [x] **Step 2: Run the command test to verify it fails**

Run: `go test ./cmd/importquarkshortdrama -count=1`

Expected: FAIL because the command package does not exist.

- [x] **Step 3: Implement command and docs**

Load environment values, construct the client, call `Collect`, convert the result to `shortdrama.Drama` with `source_id=100003` and `source_name=夸克公开分享`, set `episodes_json`, and call existing `shortdrama.Repository.Upsert`. Never print token values.

- [x] **Step 4: Run command validation and missing-config smoke test**

Run: `go test ./cmd/importquarkshortdrama -count=1`

Then run with `env -u QUARK_SHARE_URL go run ./cmd/importquarkshortdrama`; expected output is a clear configuration error and no database write.

### Task 4: Add authenticated short-drama API routes

**Files:**
- Modify: `services/api/cmd/server/main.go`
- Create: `services/api/cmd/server/shortdramas.go`
- Test: `services/api/cmd/server/shortdramas_test.go`

**Interfaces:**
- Consumes: `shortdrama.Repository.List`, `ByID`, stored episode identifiers, and `quarkshortdrama.Client.Preview`.
- Produces: `GET /api/v1/short-dramas?page=1&pageSize=20` and `GET /api/v1/short-dramas/{id}/episodes/{index}/play-url`, both behind `requireAuth`.

- [x] **Step 1: Write failing handler tests**

Test unauthenticated list returns 401; authenticated list returns the stored record; invalid ID/index returns 400/404; preview upstream failure maps to 502/503; successful preview returns `{url,duration,expiresAt}` without exposing `stoken`.

- [x] **Step 2: Run tests to verify they fail**

Run: `go test ./cmd/server -run 'TestShortDrama' -count=1`

Expected: FAIL because routes, handlers, and server dependencies are not defined.

- [x] **Step 3: Implement routes and handlers**

Add `shortDramas *shortdrama.Repository` and `quark *quarkshortdrama.Client` to the server, register both routes, decode IDs safely, call the repository, refresh playback URLs on demand, and return existing `response{Code,Message,Data}` envelopes.

- [x] **Step 4: Run handler tests**

Run: `go test ./cmd/server -run 'TestShortDrama' -count=1`

Expected: PASS.

### Task 5: End-to-end verification and service restart

**Files:**
- Modify only files required by earlier tasks.

**Interfaces:**
- Consumes: all previous task outputs.
- Produces: verified database row, API response, and running API process.

- [x] **Step 1: Run complete Go tests and format checks**

Run: `gofmt -w internal/quarkshortdrama internal/shortdrama cmd/importquarkshortdrama cmd/server` then `go test ./...` and `git diff --check`.

- [x] **Step 2: Apply no schema migration**

Verify `short_dramas` already exists; do not create a new table or alter unrelated schema.

- [x] **Step 3: Execute the importer with the supplied public link**

Run using `QUARK_SHARE_URL` in the process environment only. Expected result is one upserted drama with up to 66 video episodes; if upstream access fails, preserve the exact error and do not insert partial data.

- [x] **Step 4: Verify API and server**

Use a valid existing test login token to call the list route, then call one play-url route. Check `curl -fsS http://127.0.0.1:18080/health` and ensure the API process remains listening on port 18080.

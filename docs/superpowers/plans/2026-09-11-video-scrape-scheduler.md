# Pexels 视频采集调度 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Go API 中增加 Pexels 视频每 4 小时采集一次、每次最多 50 条、管理员可手动触发且可查询任务状态的调度能力。

**Architecture:** Go API 进程内运行 ticker；定时触发和手动触发共用一个带互斥锁的任务执行器。执行器复用 `services/api/scraper/free_video_scraper.py`，通过子进程执行 `--pexels --pexels-limit 50 --import`，并用 MySQL 任务表记录任务生命周期；现有 `platform_videos` 表保持不变。

**Tech Stack:** Go 1.24.2、标准库 `net/http`/`os/exec`/`sync`/`time`、MySQL、现有 Python Pexels scraper、OpenAPI 3.0.3。

**Spec:** `docs/superpowers/specs/2026-09-11-video-scrape-scheduler-design.md`

## Global Constraints

- 采集源固定为现有 Pexels 公共视频采集器。
- 默认间隔为 4 小时，默认每次最多处理 50 条；默认首次启动不立即采集。
- 不修改 `platform_videos` 表字段、现有视频接口返回结构、Flutter 页面或 Vue 页面。
- 同一时间只运行一个采集任务；失败不自动重试。
- Pexels 密钥继续由现有 `.env`/运行环境提供，代码、日志和 API 响应不得输出密钥或密码。
- 未登录返回 `401`，普通用户访问调度管理接口返回 `403`。
- 当前项目目录没有 `.git`，不执行 `git commit`；每项以测试和可复现命令作为交付检查点。

## File Map

- Create: `services/api/migrations/000007_create_video_scrape_jobs.sql` — 调度任务表。
- Create: `services/api/internal/scraper/model.go` — 任务状态、触发类型和结果模型。
- Create: `services/api/internal/scraper/repository.go` — 任务表 SQL 仓储。
- Create: `services/api/internal/scraper/command.go` — Python scraper 子进程适配器和统计解析。
- Create: `services/api/internal/scraper/service.go` — 单任务锁、异步触发和生命周期更新。
- Create: `services/api/internal/scraper/scheduler.go` — 4 小时 ticker 和关闭逻辑。
- Create: `services/api/internal/scraper/*_test.go` — 仓储、命令解析、并发和调度测试。
- Modify: `services/api/internal/config/config.go` — 加载采集器路径和超时配置，保留 4 小时/50 条默认值。
- Modify: `services/api/.env.example` — 增加非敏感采集器配置示例。
- Modify: `services/api/cmd/server/main.go` — 初始化服务、注册管理员路由、启动/停止调度器。
- Create or modify: `services/api/cmd/server/scraper_test.go` — 管理员接口状态码和响应测试。
- Modify: `services/api/docs/openapi.yaml` — 调度接口、响应模型和 `Scraper` 标签。
- Modify: `README.md` — 迁移命令、启动配置和手动触发示例。

---

### Task 1: 建立任务表和仓储边界

**Files:**
- Create: `services/api/migrations/000007_create_video_scrape_jobs.sql`
- Create: `services/api/internal/scraper/model.go`
- Create: `services/api/internal/scraper/repository.go`
- Test: `services/api/internal/scraper/repository_test.go`

**Interfaces:**
- Produces `scraper.Job`, `scraper.Status`, `scraper.TriggerType`。
- `TriggerType` 的常量为 `TriggerScheduled` 和 `TriggerManual`；`Status` 的常量为 `StatusRunning`、`StatusSucceeded` 和 `StatusFailed`。
- Produces `scraper.JobStore`：

```go
type JobStore interface {
    Create(ctx context.Context, trigger TriggerType) (Job, error)
    Complete(ctx context.Context, id uint64, status Status, message string) error
    Latest(ctx context.Context) (Job, error)
    MarkRunningFailed(ctx context.Context, message string) error
}
```

- `Repository` 实现 `JobStore`，构造函数为 `NewRepository(db *sql.DB) *Repository`。

- [x] **Step 1: Write the migration**

创建 `video_scrape_jobs`，沿用现有迁移的 `utf8mb4`、`DATETIME(3)` 和 `created_at/updated_at` 约定：

```sql
CREATE TABLE IF NOT EXISTS video_scrape_jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    status ENUM('running','succeeded','failed') NOT NULL,
    trigger_type ENUM('scheduled','manual') NOT NULL,
    started_at DATETIME(3) NOT NULL,
    finished_at DATETIME(3) NULL,
    error_message TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_video_scrape_jobs_created_at (created_at),
    KEY idx_video_scrape_jobs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [x] **Step 2: Define the model and store interface**

在 `model.go` 中定义带 JSON 标签的 `Job`，时间字段使用 `time.Time`/`*time.Time`；定义 `ErrNoJob` 和 `ErrAlreadyRunning` 以便服务层区分数据库无记录与并发冲突。

- [x] **Step 3: Implement repository SQL methods**

`Create` 插入 `running` 状态并返回 `LastInsertId`；`Complete` 更新状态、结束时间和错误消息；`Latest` 按 `id DESC LIMIT 1` 查询；`MarkRunningFailed` 将所有遗留 `running` 任务更新为 `failed`，错误信息固定为 `server restarted`。

- [x] **Step 4: Add repository tests**

使用现有 MySQL 测试约定；当 `MYSQL_TEST_DSN` 未设置时跳过集成测试。设置后创建表、验证创建/完成/查询及重启清理 SQL，最后清理测试任务记录。

- [x] **Step 5: Run the focused test**

Run: `cd services/api && MYSQL_TEST_DSN='<test-dsn>' go test ./internal/scraper -run TestRepository -v`

Expected: repository tests pass; without `MYSQL_TEST_DSN`, tests report `SKIP` 而不是失败。

---

### Task 2: 复用现有 Python 采集器并解析统计结果

**Files:**
- Create: `services/api/internal/scraper/command.go`
- Test: `services/api/internal/scraper/command_test.go`

**Interfaces:**
- `RunResult`：`Discovered int`、`Processed int`。
- `Command`：

```go
type Command interface {
    Run(ctx context.Context) (RunResult, error)
}
```

- `PythonCommand`：

```go
func NewPythonCommand(apiDir, pythonBin, scriptPath string, limit int) *PythonCommand
func (c *PythonCommand) Run(ctx context.Context) (RunResult, error)
```

- [x] **Step 1: Write parser and argument tests**

覆盖：解析 stderr 最后一行 `{"discovered":50,"accepted":50,"imported":50}`；缺字段时使用 0；非法 JSON 返回错误；命令参数必须包含 `--pexels`、`--pexels-limit`、`50`、`--import`；非零退出码返回包含 stderr 的错误但不包含环境密钥。

- [x] **Step 2: Run tests to verify the new adapter is incomplete**

Run: `cd services/api && go test ./internal/scraper -run TestPythonCommand -v`

Expected: FAIL because the parser/command adapter is not implemented yet。

- [x] **Step 3: Implement the subprocess adapter**

使用 `exec.CommandContext`，设置 `cmd.Dir = apiDir`；以 `pythonBin scriptPath --pexels --pexels-limit <limit> --import` 启动；分别捕获 stdout/stderr，只解析 stderr 的 JSON 统计行。上下文取消或超时直接返回错误。

- [x] **Step 4: Run focused tests**

Run: `cd services/api && go test ./internal/scraper -run TestPythonCommand -v`

Expected: PASS。

---

### Task 3: 实现单任务服务和 4 小时调度器

**Files:**
- Create: `services/api/internal/scraper/service.go`
- Create: `services/api/internal/scraper/scheduler.go`
- Test: `services/api/internal/scraper/service_test.go`
- Test: `services/api/internal/scraper/scheduler_test.go`

**Interfaces:**
- `Service`：

```go
func NewService(store JobStore, command Command, timeout time.Duration) *Service
func (s *Service) Trigger(ctx context.Context, trigger TriggerType) (Job, error)
func (s *Service) Status(ctx context.Context) (StatusSnapshot, error)
func (s *Service) MarkStale(ctx context.Context) error
```

`StatusSnapshot` 固定为：

```go
type StatusSnapshot struct {
    Running bool `json:"running"`
    Latest  *Job `json:"latest,omitempty"`
}
```

- 当已有任务运行时，`Trigger` 返回 `ErrAlreadyRunning`；成功时先持久化 `running` 任务，再异步执行并返回任务 ID。
- `Scheduler`：

```go
func NewScheduler(service *Service, interval time.Duration) *Scheduler
func (s *Scheduler) Run(ctx context.Context)
func (s *Scheduler) NextRunAt() time.Time
```

`Scheduler.NextRunAt` 返回下一个 ticker 周期时间；API handler 将它与 `Service.Status` 合并为响应中的 `nextRunAt`。

- [x] **Step 1: Write service tests with fakes**

使用内存 `fakeJobStore` 和 `fakeCommand`，覆盖：手动触发返回任务 ID；任务完成后写入 `succeeded`；命令错误写入 `failed`；并发第二次触发返回 `ErrAlreadyRunning`；`MarkStale` 委托仓储。

- [x] **Step 2: Run tests to verify the service is incomplete**

Run: `cd services/api && go test ./internal/scraper -run 'TestService|TestScheduler' -v`

Expected: FAIL because `Service`/`Scheduler` are not implemented yet。

- [x] **Step 3: Implement `Service.Trigger` and lifecycle updates**

用 `sync.Mutex` 保护进程内运行标志；创建任务后使用 `context.WithoutCancel(ctx)` 派生后台上下文，再用 `context.WithTimeout` 限制 Python 子进程；无论成功或失败都在 `defer` 中释放锁并更新任务记录。

- [x] **Step 4: Implement the ticker loop**

`Scheduler.Run` 使用 `time.NewTicker(interval)`；只监听 ticker 和父 context；每次 ticker 到期调用 `service.Trigger(context.Background(), TriggerScheduled)`，若返回 `ErrAlreadyRunning` 只记录日志，不启动第二个任务；退出时停止 ticker。

- [x] **Step 5: Run focused tests**

Run: `cd services/api && go test ./internal/scraper -run 'TestService|TestScheduler' -v`

Expected: PASS，且并发测试稳定通过。

---

### Task 4: 增加管理员 API 和鉴权

**Files:**
- Modify: `services/api/cmd/server/main.go`
- Create: `services/api/cmd/server/scraper_test.go`

**Interfaces:**
- Register:

```go
mux.HandleFunc("POST /api/v1/admin/scraper/run", api.requireAdmin(api.runScraper))
mux.HandleFunc("GET /api/v1/admin/scraper/status", api.requireAdmin(api.scraperStatus))
```

- `server` 新增 `scraper scraperController`。
- 为了可测试，`server` 字段使用最小接口而不是具体实现：

```go
type scraperController interface {
    Trigger(context.Context, scraper.TriggerType) (scraper.Job, error)
    Status(context.Context) (scraper.StatusSnapshot, error)
}
```

生产环境注入 `*scraper.Service`；测试使用 fake controller。
- `requireAdmin` 先复用 `requireAuth`，再检查 `claims.Role == "admin"`，失败写入现有 `response{Code: 10103, Message: "无管理员权限"}`。
- `runScraper` 成功返回 `202` 和 `{ "jobId": <id> }`；`ErrAlreadyRunning` 返回 `409`；其他错误返回 `500`。
- `scraperStatus` 返回 `running`、最近任务和 `nextRunAt`，不暴露密钥或内部命令行。

- [x] **Step 1: Write handler tests**

使用 fake service 或可注入的服务依赖，验证无 token 为 `401`、普通角色为 `403`、管理员触发为 `202`、重复触发为 `409`、状态查询为 `200`。

- [x] **Step 2: Run handler tests to verify they fail**

Run: `cd services/api && go test ./cmd/server -run TestScraper -v`

Expected: FAIL because the routes and handlers are not registered yet。

- [x] **Step 3: Implement `requireAdmin` and handlers**

只复用现有 `writeJSON`、`response` 和 token claims；不要改动普通视频、聊天或用户接口。

- [x] **Step 4: Register routes and run tests**

Run: `cd services/api && go test ./cmd/server -run TestScraper -v`

Expected: PASS。

---

### Task 5: 配置、服务生命周期和文档

**Files:**
- Modify: `services/api/internal/config/config.go`
- Modify: `services/api/.env.example`
- Modify: `services/api/cmd/server/main.go`
- Modify: `services/api/docs/openapi.yaml`
- Modify: `README.md`
- Test: `services/api/cmd/server/docs_test.go`

**Configuration defaults:**

```text
SCRAPER_INTERVAL=4h
SCRAPER_TIMEOUT=15m
SCRAPER_PYTHON_BIN=scraper/.venv/bin/python
SCRAPER_SCRIPT_PATH=scraper/free_video_scraper.py
```

采集条数在服务层固定为 `50`，不提供可改变业务规则的环境变量。

- [x] **Step 1: Add duration parsing and scraper config**

在 `config.Config` 增加 `Scraper` 字段；实现 `envDuration(key, fallback)`，对非法 duration 返回带变量名的配置错误；将上述默认值写入 `.env.example`，不写真实密钥。

- [x] **Step 2: Wire startup and shutdown**

在 `main` 中创建 scraper repository、Python command、service 和 scheduler；启动时调用 `MarkStale`，再用 `signal.NotifyContext` 启动 scheduler；HTTP server 关闭时取消 context 并等待 scheduler goroutine 退出。保持 `http.Server` 监听地址和所有现有路由不变。

- [x] **Step 3: Extend OpenAPI**

在 `docs/openapi.yaml` 增加 `Scraper` tag、两个路径、`ScraperJob`/`ScraperRunData`/`ScraperStatusData` schemas，以及 `401`、`403`、`409`、`500` 响应引用。`docs.go` 使用 embed，无需修改。

- [x] **Step 4: Update README**

在数据库初始化示例中加入 `000007_create_video_scrape_jobs.sql`；补充启动 API 后默认 4 小时调度、管理员手动触发 curl 示例和状态查询示例；明确手动/定时任务都固定 Pexels 50 条。

- [x] **Step 5: Verify docs and config**

Run: `cd services/api && go test ./cmd/server -run 'TestDocumentationRoutes|TestSwagger' -v`

Expected: OpenAPI/Swagger routes still return `200`，OpenAPI body contains both scraper paths。

---

### Task 6: 全量验证和本机手工验收

**Files:**
- Verify only: all files from Tasks 1–5。

- [x] **Step 1: Apply migration**

Run: `mysql -u "$MYSQL_USER" -p "$MYSQL_DATABASE" < services/api/migrations/000007_create_video_scrape_jobs.sql`

Expected: `video_scrape_jobs` table exists with the seven task fields and no changes to `platform_videos`.

- [x] **Step 2: Run Go tests**

Run: `cd services/api && go test ./...`

Expected: PASS。

- [x] **Step 3: Run Python scraper tests**

Run: `cd services/api && scraper/.venv/bin/python -m unittest discover -s scraper -p 'test_*.py' -v`

Expected: PASS；本步骤不触发真实 Pexels 请求。

- [x] **Step 4: Start or keep the API server running**

Run from `services/api` with existing environment values. Do not start a second listener if port `18080` is already occupied; use the existing process for HTTP checks.

- [x] **Step 5: Verify admin trigger and status**

使用已有管理员 token：

```bash
curl -i -X POST http://127.0.0.1:18080/api/v1/admin/scraper/run \
  -H "Authorization: Bearer $ADMIN_TOKEN"
curl -i http://127.0.0.1:18080/api/v1/admin/scraper/status \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Expected: 首次返回 `202`，随后状态为 `running` 再变为 `succeeded` 或带错误信息的 `failed`；任务执行期间第二次触发返回 `409`。

- [x] **Step 6: Verify video persistence and no duplicate key**

查询 `platform_videos` 的 Pexels 记录数量和 `(platform, external_id)` 唯一约束；确认任务最多尝试 50 条，重复视频不会产生重复行。

- [x] **Step 7: Verify authorization**

使用未登录请求和普通用户 token 分别调用两个 scraper 接口，确认返回 `401` 和 `403`，且不会创建任务记录。

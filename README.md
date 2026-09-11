# CreatorHub

CreatorHub 使用单仓库管理三个应用：

| 目录 | 技术 | 用途 |
|---|---|---|
| `apps/mobile` | Flutter | iOS/Android 用户端 |
| `apps/admin` | Vue 3 + TypeScript + Vite | Web 管理后台 |
| `services/api` | Go + MySQL | 用户端和管理后台 API |

## 本地启动

### Flutter

```bash
cd apps/mobile
flutter pub get
flutter run
```

### Go API

```bash
cd services/api
cp .env.example .env
# 将 .env 中的 MySQL 账号和密码改为本地配置，并把变量加载到运行环境
go run ./cmd/server
```

健康检查：`GET http://localhost:18080/health`

MySQL 要求：

- MySQL 8.0 或更高版本。
- 数据库字符集使用 `utf8mb4`。
- 默认数据库名为 `creatorhub`。
- API 启动时会检查数据库连接，连接失败则停止启动。

初始化账号表：

```bash
mysql -u root -p creatorhub < services/api/migrations/000001_create_users.sql
mysql -u root -p creatorhub < services/api/migrations/000002_seed_test_user.sql
mysql -u root -p creatorhub < services/api/migrations/000006_create_platform_videos.sql
mysql -u root -p creatorhub < services/api/migrations/000007_create_video_scrape_jobs.sql
```

Flutter 登录测试账号：

```text
账号：test@example.com
密码：Test123456!
```

该账号只用于本地开发环境，不要导入生产数据库。

创建第一个后台管理员：

```bash
cd services/api
go run ./cmd/createadmin admin@example.com change_me_123 管理员
```

账号接口：

| 方法 | 路径 | 用途 |
|---|---|---|
| POST | `/api/v1/auth/register` | Flutter 用户注册 |
| POST | `/api/v1/auth/login` | Flutter 用户登录 |
| GET | `/api/v1/auth/me` | 使用 Bearer Token 获取当前用户 |
| POST | `/api/v1/admin/login` | Vue 管理员登录，仅允许 `admin` 角色 |
| GET | `/api/v1/videos` | 获取视频数据 |
| POST | `/api/v1/admin/scraper/run` | 管理员手动启动 Pexels 采集 |
| GET | `/api/v1/admin/scraper/status` | 管理员查看采集任务状态 |

免费公开视频抓取与导入（不需要 Apify CLI 或 Token）：

```bash
cd services/api
python3 -m venv scraper/.venv
scraper/.venv/bin/python -m pip install -r scraper/requirements-free.txt
cp scraper/seeds.example.json scraper/seeds.json
# 编辑 scraper/seeds.json，填入公开 YouTube、X、抖音视频 URL。
set -a; source .env; set +a
scraper/.venv/bin/python scraper/free_video_scraper.py --seeds scraper/seeds.json --import
```

脚本只读取公开页面元数据，不下载视频文件；点赞数、评论数和转发数按来源字段写入。X/抖音可能因登录墙或反爬导致记录跳过，播放地址也可能是临时地址。

没有具体视频 URL 时，可使用关键词发现模式。脚本会合并平台搜索和公开网页搜索结果，再逐条读取视频详情；默认每个关键词最多 20 条、单次最多处理 200 个候选、只保留最近 30 天的记录：

```bash
cd services/api
cp scraper/queries.example.json scraper/queries.json
set -a; source .env; set +a
scraper/.venv/bin/python scraper/free_video_scraper.py --queries scraper/queries.json --import
```

关键词发现对 YouTube 最稳定；X/抖音搜索页和通用网页搜索可能需要登录、受到限流或缺少互动字段，缺少必要字段的结果会被跳过。脚本不配置搜索 API Key，只读取公开搜索页面；每个站点请求间隔至少 1 秒，单请求超时 20 秒。可使用 `--search-limit` 调整每个关键词的候选数量，使用 `--since-days` 调整时间范围。

Pexels 手动一次性采集公开视频（只写入元数据和远程播放地址，不下载视频）：

```bash
scraper/.venv/bin/python scraper/free_video_scraper.py --pexels --pexels-limit 20 --import
```

Pexels 公开接口不提供点赞、评论、转发统计；项目会为演示数据生成随机互动数，评论正文仍由 Flutter 视频评论区生成。

API 服务启动后会默认每 4 小时自动执行一次 Pexels 采集，每次最多处理 50 条；首次启动不会立即采集。管理员登录后可以立即触发任务：

```bash
curl -i -X POST http://localhost:18080/api/v1/admin/scraper/run \
  -H "Authorization: Bearer <管理员 token>"
curl -i http://localhost:18080/api/v1/admin/scraper/status \
  -H "Authorization: Bearer <管理员 token>"
```

定时任务和手动任务共用单任务锁；任务正在运行时再次触发会返回 `409`。可在 `.env` 中调整 `SCRAPER_INTERVAL`、`SCRAPER_TIMEOUT`、`SCRAPER_PYTHON_BIN` 和 `SCRAPER_SCRIPT_PATH`，采集条数固定为 50。

Apify 抓取脚本（可选，仍需 Apify CLI、Token 和 Actor 输入 JSON）：

```bash
cd services/api
./scraper/scrape_social_videos.sh youtube-input.json x-input.json douyin-input.json
```

脚本使用 YouTube、X/Twitter、TikTok/Douyin Actor，保留字段完整的记录后写入 MySQL。输入 schema 以 Actor 实时信息为准：

```bash
apify actors info "streamers/youtube-scraper" --user-agent apify-agent-skills/apify-ultimate-scraper --input --json
apify actors info "apidojo/tweet-scraper" --user-agent apify-agent-skills/apify-ultimate-scraper --input --json
apify actors info "clockworks/tiktok-scraper" --user-agent apify-agent-skills/apify-ultimate-scraper --input --json
```

Flutter 会自动为 macOS、Web 和 Android 模拟器选择本地 API 地址。真机调试时使用：

```bash
flutter run --dart-define=API_BASE_URL=http://你的电脑局域网IP:18080
```

### Vue 3 管理后台

```bash
cd apps/admin
pnpm install
pnpm dev
```

开发服务器会把 `/api` 请求代理到 `http://localhost:18080`。

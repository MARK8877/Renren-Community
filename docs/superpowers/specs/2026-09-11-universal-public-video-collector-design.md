# 通用公开视频采集器设计

## 1. 背景与目标

当前采集脚本需要用户提供具体视频 URL，无法在没有 URL 的情况下发现候选视频。本设计将其扩展为一次性、手动触发的“通用公开视频采集器”：先从平台搜索/热门页和公开搜索页面发现候选 URL，再提取公开元数据，过滤点赞数大于 100 的视频，复用现有导入命令写入 MySQL `platform_videos` 表。

本设计只处理公开可访问页面，不下载视频文件，也不绕过登录、验证码、付费墙或访问限制。

## 2. 范围

### 2.1 包含内容

- 平台搜索入口：优先使用 yt-dlp 支持的平台搜索能力。
- 通用搜索入口：读取不需要 API Key 的公开搜索页面，提取候选链接。
- 通用网页兜底：解析 OpenGraph、Schema.org JSON-LD、公开 JSON 和 `<video>` 标签。
- 统一字段：平台、视频 ID、标题、播放地址、点赞数、评论数、转发数、发布时间。
- 严格过滤：`like_count > 100`。
- URL/平台 ID 去重。
- 单个站点超时、限流或解析失败时跳过并记录原因。
- 复用现有 `cmd/importvideos` 写入 `platform_videos`。

### 2.2 不包含内容

- 不承诺覆盖所有互联网网站或所有公开视频。
- 不抓取登录后、私有、付费或明确禁止自动访问的内容。
- 不下载、转码、托管或代理视频文件。
- 不新增后台管理页面、Flutter 页面或 API 响应字段。
- 不绕过验证码、风控、地区限制或反爬措施。

## 3. 方案与组件

继续扩展 `services/api/scraper/free_video_scraper.py`，不新增独立服务或爬虫框架。

### 3.1 DiscoveryAdapter

负责根据关键词产生候选视频页面 URL。

- `PlatformSearchAdapter`：使用 yt-dlp 的平台搜索入口；YouTube 使用 `ytsearchN:<query>`，其他站点按已支持的公开搜索入口尝试。
- `WebSearchAdapter`：读取公开搜索页面（初始实现使用无 API Key 的 HTML 搜索入口），提取结果链接并限制数量。
- 适配器返回原始 URL，不负责字段标准化和数据库写入。

### 3.2 MetadataExtractor

对候选 URL 按以下顺序提取：

1. yt-dlp 详情提取。
2. 页面 OpenGraph 与 Schema.org JSON-LD。
3. 页面公开 JSON 数据。
4. `<video src>` 或 `<source src>` 播放地址。

缺少标题、播放地址或可确认点赞数时，候选记录跳过。

### 3.3 Normalizer

把不同来源字段转换为现有导入格式：

```json
{
  "platform": "youtube",
  "videoId": "external-id",
  "title": "视频标题",
  "playUrl": "https://...",
  "url": "https://...",
  "likes": 101,
  "comments": 12,
  "shares": 3,
  "publishedAt": "2026-09-11T00:00:00Z"
}
```

过滤条件为严格 `likes > 100`，恰好 100 个赞不写入数据库。

### 3.4 Deduplicator

按以下优先级去重：

1. `(platform, videoId)`。
2. 标准化后的来源 URL。

同一视频在平台搜索和通用搜索中重复出现时只保留一条。

### 3.5 Importer

继续调用现有 `services/api/cmd/importvideos`，不改变数据库表结构和 API 数据格式。导入命令默认阈值也保持为严格大于 100。

## 4. 配置与执行

采集配置文件使用 JSON：

```json
{
  "queries": [
    "AI 创作",
    "产品设计",
    "摄影",
    "科技",
    "视频剪辑"
  ],
  "perQueryLimit": 20,
  "maxCandidates": 200,
  "minLikes": 100,
  "sinceDays": 30
}
```

执行为手动一次性任务：

```bash
cd services/api
scraper/.venv/bin/python scraper/free_video_scraper.py \
  --queries scraper/queries.json \
  --search-limit 20 \
  --since-days 30 \
  --import
```

现有 `--seeds` URL 模式继续保留，作为精确采集入口。

## 5. 限流与失败处理

- 每个站点请求间隔至少 1 秒。
- 单请求超时 20 秒。
- 单个候选最多重试 1 次，仍失败则跳过。
- 候选总数上限 200 条。
- 任何单站点失败不终止其他站点处理。
- 失败日志包含平台、查询词或 URL、错误类型；不输出 Cookie、Token 或密码。
- 播放地址可能是短期签名 URL，数据库只保存抓取时可用的公开地址。

## 6. 数据流

```text
queries.json
  ↓
平台搜索 + 公开搜索页面
  ↓
候选 URL 去重
  ↓
yt-dlp / HTML 元数据解析
  ↓
标准化字段
  ↓
likes > 100、时间范围、字段完整性过滤
  ↓
platform_videos 去重写入
  ↓
GET /api/v1/videos
  ↓
Flutter 视频页面
```

## 7. 验收标准

1. 不提供具体视频 URL 时，可以使用关键词配置启动一次采集。
2. YouTube 等可识别平台能从搜索结果进入视频详情提取元数据。
3. 通用搜索结果能被解析为候选 URL，并与平台搜索结果合并去重。
4. 点赞数为 100 的记录被跳过，点赞数为 101 的记录可进入导入流程。
5. 缺少标题、播放地址或点赞数的记录被跳过。
6. 单个网站超时或被拒绝时，任务继续处理其他候选。
7. 导入结果写入现有 `platform_videos` 表，API 和 Flutter 无需改字段即可展示。
8. 手动任务结束后输出成功数、跳过数和失败原因摘要。

## 8. 测试计划

- Python 单元测试：搜索结果解析、HTML 元数据解析、字段标准化、严格点赞阈值、去重和超时隔离。
- Go 测试：导入命令和 API 默认阈值保持 `> 100`。
- Flutter 测试：视频接口继续发送 `minLikes=100` 并解析标准字段。
- 离线测试不访问真实站点；真实采集仅作为手动验收，不作为自动化测试依赖。

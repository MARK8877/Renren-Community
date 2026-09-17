# 夸克公开分享短剧聚合设计

## 背景与目标

将公开夸克分享链接
`https://pan.quark.cn/s/db532a8e9950#/list/share/3164a37f94734cad87356081c609f154`
中的全部视频整理为一部短剧，写入现有 `short_dramas` 表，并提供供 Flutter 前端调用的查询与播放地址接口。

已验证该分享目录当前包含 66 个视频和 2 张图片。仅采集公开元数据与播放地址，不下载或转存视频文件。

## 方案

采用“元数据快照 + 按需刷新播放地址”的混合方案：

1. 解析分享链接中的 `pwd_id` 和目录 `fid`。
2. 调用夸克公开分享接口获取 `stoken`，分页递归读取所有子目录。
3. 过滤 `video/*` 文件，保留文件名、fid、fid token、大小、时长、更新时间。
4. 对每个视频调用公开 `video_preview` 接口获取当前 m3u8 地址；地址只作为采集时快照，不依赖其长期有效性。
5. 将整部短剧作为一条 `short_dramas` 记录，所有视频按自然集数排序写入 `episodes_json`。
6. API 返回短剧元数据；播放接口根据保存的 `pwd_id/fid/fid_token` 重新获取 `stoken`，实时刷新指定集的 m3u8 地址。`stoken` 不持久化。

## 数据模型

不新增表，复用 `short_dramas`：

- `source_id=100003`
- `source_name=夸克公开分享`
- `external_id`：由 `pwd_id` 与根目录 fid 稳定生成
- `name`：分享标题或根目录名称
- `total_episodes`：视频文件数量
- `update_time`：分享目录更新时间
- `episodes_json`：数组，每项包含 `episode`、`title`、`pwd_id`、`fid`、`fid_token`、`size`、`duration`、`url`、`m3u8url`

`url` 保存公开分享页地址或文件预览地址；`m3u8url` 是临时地址。`stoken` 只在请求期间使用，不写入数据库、日志或响应；分享标识仅保存为刷新播放地址所需的公开目录元数据。

## API 契约

所有接口沿用现有 Bearer 登录鉴权。

### 获取短剧列表

`GET /api/v1/short-dramas?page=1&pageSize=20`

返回短剧摘要和 `episodes` 元数据，按 `scraped_at DESC, id DESC` 排序。

### 刷新指定剧集播放地址

`GET /api/v1/short-dramas/{id}/episodes/{index}/play-url`

服务端使用该剧集的夸克标识调用 `video_preview`，返回新的 m3u8 URL、时长和有效期信息。上游失败时返回明确的 502/503，不返回过期快照冒充可用地址。

## 采集命令

新增命令 `cmd/importquarkshortdrama`，配置项：

- `QUARK_SHARE_URL`：必填，公开分享 URL
- `QUARK_IMPORT_LIMIT`：可选，默认 1000，限制最多剧集数
- `QUARK_API_HOST`：可选，默认 `https://drive-m.quark.cn`

采集过程幂等，使用 `(source_id, external_id)` 更新同一部短剧，不覆盖其他来源数据。

## 错误处理与限制

- 分享链接失效、需要提取码、目录权限变化时停止并返回上游错误。
- 只接受 HTTPS 夸克分享链接，拒绝任意 URL 作为接口地址，避免 SSRF。
- 忽略图片、文档和空目录；目录分页采用固定上限并检测重复 fid，防止循环。
- m3u8 地址可能过期，前端必须在播放前调用刷新接口。
- 不绕过登录、提取码、风控或版权限制；公开链接的可访问性不代表内容可再分发。

## 测试策略

- 分享 URL 解析和路径校验测试。
- token/detail/video_preview 响应解析测试。
- 递归目录、分页、视频过滤和集数排序测试。
- 入库幂等测试。
- API 鉴权、分页、越界剧集索引和上游错误映射测试。
- 使用 httptest 模拟夸克接口，不在单元测试中下载视频或依赖外部网络。

## 不做项

- 不改 Flutter UI；本次只提供前端可调用的 Go API。
- 不下载、转码、缓存或重新分发视频文件。
- 不将用户账号 Cookie、密码或私有网盘凭证写入项目。

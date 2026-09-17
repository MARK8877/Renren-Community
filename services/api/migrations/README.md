# 数据库迁移

迁移文件按编号顺序执行。短剧采集使用 `000010_create_short_dramas.sql`，将系列信息和剧集播放地址以 JSON 持久化到 `short_dramas.episodes_json`。

## 短剧入库

先在 `services/api/.env` 配置 `YAOHUD_API_KEY`，再执行：

```bash
cd services/api
go run ./cmd/importshortdramas
```

采集器默认搜索“短剧”、使用来源 1、每次最多导入 20 条，可通过 `YAOHUD_QUERY`、`YAOHUD_SOURCE`、`YAOHUD_IMPORT_LIMIT` 覆盖。

## 书旗短剧入库

在淘宝开放平台控制台获取 `AppKey` 与 `AppSecret`，写入 `services/api/.env` 的 `ALIBABA_APP_KEY` 和 `ALIBABA_APP_SECRET`，再执行：

```bash
cd services/api
go run ./cmd/importalibabashortdramas
```

该接口只提供短剧元数据，当前适配器不会生成或猜测剧集播放地址。

## AA1 免费短剧入库

执行以下命令即可从 AA1 文档所示接口抓取并写入 `short_dramas`：

```bash
cd services/api
go run ./cmd/importaa1shortdramas
```

可通过 `AA1_QUERY` 设置关键词，`AA1_PAGE_SIZE` 设置请求条数，`AA1_IMPORT_LIMIT` 设置本次最大入库数。接口返回的夸克资源链接会保存在 `episodes_json` 的“全集资源”项中；它不是视频直链。

## ISTERO 全网短剧入库

将 ISTERO 的 `Authorization`（或 `token`）只配置在本机 `services/api/.env`，然后执行：

```bash
cd services/api
go run ./cmd/importisteroshortdramas
```

可通过 `ISTERO_QUERY` 设置搜索词，`ISTERO_IMPORT_LIMIT` 设置本次最大入库数。接口返回的是网盘资源链接，不是视频直链。

## 夸克公开分享短剧入库

夸克分享页只读取公开目录元数据和临时播放地址，不下载视频，也不保存 `stoken`。将分享页地址配置到本机环境后执行：

```bash
cd services/api
QUARK_SHARE_URL='https://pan.quark.cn/s/db532a8e9950#/list/share/3164a37f94734cad87356081c609f154' go run ./cmd/importquarkshortdrama
```

默认最多采集 1000 集；可用 `QUARK_IMPORT_LIMIT` 调整。数据复用 `short_dramas` 表，以一条短剧记录保存全部剧集元数据。

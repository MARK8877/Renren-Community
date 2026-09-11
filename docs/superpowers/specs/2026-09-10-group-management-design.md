# 群聊创建与群管理设计

## 目标与范围

在消息页提供统一的发起入口，并让群主与管理员能管理群资料、成员和秩序。所有群管理结果持久化到 MySQL，并由 Go API 在服务端执行权限校验。

本次包含：

- 消息页移除“全部已读”，新增“+”综合入口。
- 独立创建群聊页：群名称、内置群头像、群公告、入群方式、是否允许成员邀请。
- 群主/管理员/成员三种角色。
- 群头像、公告、入群方式、成员邀请、管理员设置、禁言、移除成员。
- 创建成功后直接进入群聊；群详情提供管理入口。

本次不包含：自定义图片上传、群转让、解散群、群聊历史迁移、邀请链接对外分享、批量成员导入。

## 权限规则

| 角色 | 能力 |
| --- | --- |
| 群主 | 编辑全部群资料；管理管理员；邀请、禁言、移除普通成员；处理入群申请。 |
| 管理员 | 编辑公告；邀请成员；禁言、移除普通成员；不能管理群主或其他管理员。 |
| 普通成员 | 查看群资料；在群主开启时邀请成员；不能管理他人。 |

禁言成员仍可浏览历史消息，但服务端拒绝其新消息，直至禁言时间结束。被移除成员不能读取或发送该群消息。

## 用户流程

```text
消息页右上角 +
├── 发起群聊 → 创建群聊页 → 创建成功 → 新群聊
├── 添加好友 → 复用添加联系人页
└── 新的好友 → 复用好友申请页

群聊详情 → 群管理
├── 群资料：头像、公告、入群方式、成员邀请开关
├── 成员：邀请、设为/取消管理员、禁言、移除
└── 入群申请：仅“需群主同意”时显示
```

创建群聊时创建者自动为群主及首位成员。群头像仅能从项目 `assets/avatar/` 中的预置素材选择；数据库保存素材键，客户端将其映射为本地资源。

## 入群方式

| 方式 | 行为 |
| --- | --- |
| 允许直接加入 | 受邀请用户立即成为成员。 |
| 需群主同意 | 受邀请用户提交申请；群主同意后成为成员。 |

成员邀请总是由已在群内的用户发起。普通成员仅在“允许成员邀请”打开时可邀请；管理员和群主始终可邀请。

## 数据模型

### `conversations`（群聊记录）

新增字段：

- `owner_user_id BIGINT NOT NULL`：群主用户 ID。
- `avatar_asset_key VARCHAR(120) NOT NULL DEFAULT ''`：内置头像素材键。
- `announcement VARCHAR(500) NOT NULL DEFAULT ''`：群公告。
- `join_mode ENUM('direct','approval') NOT NULL DEFAULT 'direct'`：入群方式。
- `member_invite_enabled BOOLEAN NOT NULL DEFAULT TRUE`：普通成员是否可邀请。

### `conversation_members`（成员记录）

新增字段：

- `role ENUM('owner','admin','member') NOT NULL DEFAULT 'member'`。
- `muted_until DATETIME NULL`：禁言截止时间；空值表示未禁言。

### `group_join_requests`（新增）

- `id`、`conversation_id`、`applicant_user_id`、`inviter_user_id`、`status(pending/accepted/rejected)`、`created_at`、`handled_at`。
- 同一用户在同一群仅保留一条待处理申请。

现有按用户创建的默认群数据将把当前用户写为群主；其他既有成员默认普通成员，确保升级后可继续读取会话。

## API 契约

所有接口均要求登录；资源不存在或当前用户不是该群成员时返回 `404`，权限不足返回 `403`，参数不合法返回 `400`。

| 方法与路径 | 用途 | 权限 |
| --- | --- | --- |
| `POST /api/v1/conversations/groups` | 创建群，接收名称、头像、公告、入群方式、邀请开关 | 登录用户 |
| `GET /api/v1/conversations/{key}/group` | 读取群资料和当前用户角色 | 群成员 |
| `PATCH /api/v1/conversations/{key}/group` | 更新头像、公告、入群方式、邀请开关 | 群主；公告允许管理员 |
| `GET /api/v1/conversations/{key}/members` | 读取成员及角色、禁言状态 | 群成员 |
| `POST /api/v1/conversations/{key}/members/invite` | 邀请已注册用户 | 群主/管理员；或开启成员邀请的成员 |
| `PATCH /api/v1/conversations/{key}/members/{userID}/role` | 设置或取消管理员 | 群主 |
| `PATCH /api/v1/conversations/{key}/members/{userID}/mute` | 设置或解除禁言 | 群主/管理员 |
| `DELETE /api/v1/conversations/{key}/members/{userID}` | 移除普通成员 | 群主/管理员 |
| `GET /api/v1/conversations/{key}/join-requests` | 列出待处理申请 | 群主 |
| `POST /api/v1/conversations/{key}/join-requests/{id}/resolve` | 同意或拒绝申请 | 群主 |

创建群请求中的名称为 2–30 个字符，公告最多 500 个字符。禁言请求使用明确的截止时间或解除标记；服务端不接受客户端传入的角色判断结果。

## Flutter 页面与状态

- `MessagesScreen`：右上角 `+` 打开底部动作面板；移除“全部已读”控件及客户端调用。
- `CreateGroupScreen`：保存群资料草稿；校验名称后调用创建接口；成功后以接口返回的会话键跳转至 `GroupChatScreen`。
- `GroupChatScreen`：读取群资料；在详情中显示公告与成员；根据当前角色显示相应管理操作。发送消息前从 API 状态检查禁言结果并展示明确提示。
- `GroupManagementScreen`：管理资料、成员、入群申请。复用 `ChatAvatar` 与联系人搜索结果，不创建新的头像或联系人模型。

服务端是唯一权限来源。Flutter 只根据返回的当前角色控制入口可见性，接口失败后刷新资料并显示服务端错误信息。

## 验收与测试

- 群主可创建包含资料的群，创建后可进入该群。
- 非成员无法读取、发送或管理群内容。
- 管理员不可提升管理员、管理群主或其他管理员。
- 禁言成员发送消息被拒绝；解除禁言后可正常发送。
- 移除成员后无法继续访问群消息。
- “需群主同意”场景下，成员仅在群主同意后加入。
- Flutter 组件测试覆盖综合入口、创建页校验、角色条件入口和 API 成功/失败反馈。
- Go 仓储与处理器测试覆盖角色鉴权、成员状态变更和入群申请状态转换。

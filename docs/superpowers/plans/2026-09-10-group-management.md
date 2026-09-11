# 群聊创建与群管理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为消息页增加群聊综合入口，完成独立建群页，并实现群资料、成员角色、邀请、入群申请、禁言和移除成员的 Go/MySQL/Flutter 全链路能力。

**Architecture:** MySQL 负责保存群资料、成员角色与状态；Go chat repository 集中执行成员查询和权限判断，HTTP handler 只做参数解析与错误映射；Flutter 通过 `ChatApi` 调用接口，消息页、创建页和群管理页分别负责入口、建群和管理交互。服务端权限是最终依据，客户端只用于隐藏不适用的操作。

**Tech Stack:** Flutter/Dart、Go `net/http`、MySQL、现有 `ChatApi`、Flutter widget tests、Go tests。

**Spec:** `docs/superpowers/specs/2026-09-10-group-management-design.md`

## Global Constraints

- 只改消息页、群聊相关 Flutter 页面、聊天 API、Go chat 服务与对应 MySQL migration。
- 不增加头像上传；群头像只保存 `assets/avatar/` 的素材键。
- 所有群管理操作必须在 Go 服务端按群成员角色鉴权。
- 禁言成员可以读历史消息，但发送接口必须拒绝有效期内的发送。
- 遵循 TDD：每个行为先写失败测试并运行，再写最小实现。
- 不删除已有聊天数据；migration 必须为已有群提供默认值。

---

### Task 1: 扩展 MySQL 群管理数据结构

**Files:**
- Create: `services/api/migrations/000005_create_group_management.sql`
- Modify: `services/api/internal/chat/repository.go`
- Modify: `services/api/go.mod` and `services/api/go.sum` (add the test-only `github.com/DATA-DOG/go-sqlmock` dependency)
- Test: `services/api/internal/chat/repository_test.go`

**Interfaces:**
- Produces `chat.GroupDetails`, `chat.GroupMember`, `chat.JoinRequest` 数据结构，以及 repository 的资料/成员/状态变更方法。
- Consumes existing `Conversation`, `CreatedGroup`, `memberConversationID`, and `users` table.

- [ ] **Step 1: Write the failing repository tests**

  Add tests for the pure authorization decisions and SQL-backed operations using `sqlmock`: owner can update all group fields; admin cannot alter another admin; a muted member cannot pass `CanSend`; member removal makes membership lookup fail; duplicate pending join request is rejected.

- [ ] **Step 2: Run tests to verify they fail**

  Run `cd services/api && go test ./internal/chat -run 'Test(Group|Member|JoinRequest)' -count=1`.
  Expected: FAIL because the new types and methods do not exist.

- [ ] **Step 3: Add the test dependency**

  Add `github.com/DATA-DOG/go-sqlmock` to the Go module and run `cd services/api && go mod tidy`. Keep it used only by `_test.go` files.

- [ ] **Step 4: Add migration**

  Add `owner_user_id`, `avatar_asset_key`, `announcement`, `join_mode`, and `member_invite_enabled` to `conversations`; add `role` and `muted_until` to `conversation_members`; create `group_join_requests` with a unique pending constraint. Use defaults that preserve existing rows and foreign keys to `users`/`conversations`.

- [ ] **Step 5: Implement repository methods**

  Add `GetGroup`, `ListMembers`, `UpdateGroup`, `InviteMember`, `SetMemberRole`, `SetMemberMute`, `RemoveMember`, `ListJoinRequests`, and `ResolveJoinRequest`. Each method must first resolve the caller's membership and role in the same transaction as the mutation. Update `CreateGroup` to save all initial group settings and owner role. Update default seeding so the current user's member row is `owner`.

- [ ] **Step 6: Run tests to verify they pass**

  Run `cd services/api && go test ./internal/chat -run 'Test(Group|Member|JoinRequest)' -count=1`.
  Expected: all repository tests PASS.

### Task 2: Add authenticated Go group-management endpoints

**Files:**
- Modify: `services/api/cmd/server/main.go`
- Modify: `services/api/internal/chat/repository.go`
- Test: `services/api/cmd/server/main_test.go`

**Interfaces:**
- Consumes repository methods from Task 1 and `auth.Claims`.
- Produces the API routes and JSON contracts listed in the spec.

- [ ] **Step 1: Write failing handler tests**

  Use `httptest` with a repository fixture to assert: unauthenticated calls return `401`; non-member calls return `404`; member role violations return `403`; valid create/update/invite/mute/remove requests return `200`/`201`; invalid names and invalid join modes return `400`.

- [ ] **Step 2: Run tests to verify they fail**

  Run `cd services/api && go test ./cmd/server -run 'TestGroup' -count=1`.
  Expected: FAIL because routes and handlers are absent.

- [ ] **Step 3: Register routes and handlers**

  Register the group detail, member, invitation, role, mute, remove, join-request and resolve routes after the existing conversation routes. Parse and validate JSON at the handler boundary, call repository methods with `claims.UserID`, and map `ErrNotFound` to `404`, permission errors to `403`, validation errors to `400`, and database errors to `500`.

- [ ] **Step 4: Enforce send-time mute authorization**

  In `createMessage`, query the caller's member state before inserting. Return `403` with a stable message when `muted_until > NOW()`. Do not rely on a Flutter-provided flag.

- [ ] **Step 5: Run handler and API tests**

  Run `cd services/api && go test ./...`.
  Expected: all Go tests PASS.

### Task 3: Extend the Flutter chat API client

**Files:**
- Modify: `apps/mobile/lib/src/chat/chat_api.dart`
- Test: `apps/mobile/test/chat_api_test.dart`

**Interfaces:**
- Produces typed methods: `createGroup`, `groupDetails`, `groupMembers`, `updateGroup`, `inviteMember`, `setMemberRole`, `setMemberMute`, `removeMember`, `joinRequests`, and `resolveJoinRequest`.
- Consumes the existing authenticated request helper and `ChatApiException`.

- [ ] **Step 1: Write failing client contract tests**

  Assert request paths, methods, JSON fields, and typed decoding for group details, member role/mute state, and created group data. Assert non-2xx responses become `ChatApiException` without swallowing the server message.

- [ ] **Step 2: Run tests to verify they fail**

  Run `cd apps/mobile && flutter test test/chat_api_test.dart --plain-name '群管理 API'`.
  Expected: FAIL because the typed methods/models are missing.

- [ ] **Step 3: Add models and methods**

  Add immutable `GroupDetailsData`, `GroupMemberData`, and `JoinRequestData`. Expand `CreatedGroupData` with returned avatar/settings fields. Encode only supported values (`direct`/`approval`, `owner`/`admin`/`member`) and keep the access token in the existing request path.

- [ ] **Step 4: Run client tests**

  Run `cd apps/mobile && flutter test test/chat_api_test.dart --plain-name '群管理 API'`.
  Expected: PASS.

### Task 4: Add the independent create-group page and message-page entry

**Files:**
- Create: `apps/mobile/lib/src/screens/create_group_screen.dart`
- Modify: `apps/mobile/lib/src/screens/messages_screen.dart`
- Test: `apps/mobile/test/messages_screen_test.dart`
- Test: `apps/mobile/test/create_group_screen_test.dart`

**Interfaces:**
- Consumes `ChatApi.createGroup`, `AuthSession`, existing add-contact and friend-request routes.
- Produces `CreateGroupScreen` with a completion callback returning `CreatedGroupData`.

- [ ] **Step 1: Write failing widget tests**

  Test that messages no longer renders `mark-all-read`; tapping `messages-compose-actions` shows `发起群聊`, `添加好友`, and `新的好友`; tapping `发起群聊` opens `create-group-screen`; empty/one-character names keep submit disabled or show validation; a successful submit opens `GroupChatScreen` with the returned conversation key.

- [ ] **Step 2: Run tests to verify they fail**

  Run `cd apps/mobile && flutter test test/messages_screen_test.dart test/create_group_screen_test.dart --plain-name '群聊综合入口'`.
  Expected: FAIL because the new entry and screen are absent and the old button is still present.

- [ ] **Step 3: Implement the message-page action sheet**

  Remove the `mark-all-read` AppBar action and `markAllRead` UI path. Add a keyed AppBar icon that opens a bottom sheet. Route existing add-contact/friend-request callbacks unchanged, and push `CreateGroupScreen` for the group action.

- [ ] **Step 4: Implement `CreateGroupScreen`**

  Build fields for group name, preset avatar grid from `assets/avatar/`, announcement, join mode radio buttons, and member-invite switch. Validate name length 2–30 and announcement length <=500. Show a progress state during `ChatApi.createGroup`; on success push/replace with `GroupChatScreen`; on failure retain input and show `ChatApiException.message`.

- [ ] **Step 5: Run widget tests**

  Run `cd apps/mobile && flutter test test/messages_screen_test.dart test/create_group_screen_test.dart`.
  Expected: PASS, including existing contact, swipe, ordering, pin, and delete tests.

### Task 5: Add group detail and management UI

**Files:**
- Create: `apps/mobile/lib/src/screens/group_management_screen.dart`
- Modify: `apps/mobile/lib/src/screens/group_chat_screen.dart`
- Test: `apps/mobile/test/group_management_screen_test.dart`
- Test: `apps/mobile/test/group_chat_screen_test.dart`

**Interfaces:**
- Consumes typed API models/methods from Task 3 and `ChatAvatar`.
- Produces a management route opened from group details, with role-sensitive controls and refresh after every mutation.

- [ ] **Step 1: Write failing widget tests**

  Cover owner controls for avatar, announcement, join mode, invite switch, member invitation, admin assignment, mute, remove, and join-request resolution. Cover that a member sees read-only group data and that an admin cannot see owner/admin management actions. Cover success refresh and server-error SnackBar.

- [ ] **Step 2: Run tests to verify they fail**

  Run `cd apps/mobile && flutter test test/group_management_screen_test.dart --plain-name '群管理'`.
  Expected: FAIL because the screen and management entry are absent.

- [ ] **Step 3: Add management entry to `GroupChatScreen`**

  Fetch group details on open, show the announcement and role badge, and add a settings action that pushes `GroupManagementScreen`. Keep existing message loading, avatars, mentions, media input and chat layout unchanged.

- [ ] **Step 4: Implement role-sensitive management sections**

  Add sections for group profile, member list, invitation search, role controls, mute duration/解除, remove confirmation, and pending join requests. Render controls from server-returned role and refresh details/members after each successful mutation. Do not allow the client to mutate role state locally without a successful API response.

- [ ] **Step 5: Verify Flutter group tests**

  Run `cd apps/mobile && flutter test test/group_chat_screen_test.dart test/group_management_screen_test.dart`.
  Expected: PASS.

### Task 6: End-to-end verification and migration check

**Files:**
- Modify: `services/api/migrations/000005_create_group_management.sql` only if the clean-install check finds ordering or default issues.
- Modify: `apps/mobile/test/messages_screen_test.dart` only for stable keys/assertions introduced by the implementation.

- [ ] **Step 1: Run all Go tests**

  Run `cd services/api && go test ./...`.
  Expected: PASS.

- [ ] **Step 2: Run all relevant Flutter tests and analyzer**

  Run `cd apps/mobile && flutter test test/messages_screen_test.dart test/create_group_screen_test.dart test/group_chat_screen_test.dart test/group_management_screen_test.dart test/chat_api_test.dart`.
  Then run `flutter analyze lib/src/screens/messages_screen.dart lib/src/screens/create_group_screen.dart lib/src/screens/group_chat_screen.dart lib/src/screens/group_management_screen.dart lib/src/chat/chat_api.dart`.
  Expected: all tests PASS and analyzer reports no issues.

- [ ] **Step 3: Verify clean migration and API health**

  Apply `services/api/migrations/000005_create_group_management.sql` with the configured MySQL client against the local database, start the Go server with the existing project `.env`, and request `GET http://127.0.0.1:18080/health`.
  Expected: migration succeeds, server remains running, and health returns `{\"code\":0,\"message\":\"ok\"}`.

- [ ] **Step 4: Run the authorized test-account smoke flow**

  Use the previously authorized test account to log in, open Messages, open the `+` menu, create a group with each join mode, open group management, and confirm the owner controls are visible. Do not print credentials or secrets in output.

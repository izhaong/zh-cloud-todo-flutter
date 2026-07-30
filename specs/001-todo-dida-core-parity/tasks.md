# Tasks: Todo 核心能力与多端交付（Flutter 客户端重建）

**Input**: [spec.md](./spec.md)、[plan.md](./plan.md)

**Tests**: 每个 feature 迁移均需配套 `flutter_test`（Fake Repository/Dio），随任务一起完成，不单列可选。

## Phase 1: Setup

- [x] T001 初始化 spec-kit（`.specify/` + 本目录）
- [x] T002 [P] 在 `pubspec.yaml` 建立当前依赖：`flutter_riverpod`、`go_router`、`dio`、`drift`+`sqlite3_flutter_libs`、`freezed`+`freezed_annotation`、`json_serializable`、`build_runner`、`flutter_local_notifications`、`table_calendar`、`uuid`
- [x] T003 [P] 建立 `lib/core/{api,db,sync,storage}` 与 `lib/features/` 目录骨架

## Phase 2: Foundational（阻塞所有 User Story）

- [x] T004 `lib/core/api/api_client.dart`：dio 实例 + Bearer/tenant-id 拦截器 + 401 会话失效回调
- [x] T005 `lib/core/db/app_database.dart`：Drift database 定义 9 类 sync 白名单实体表 + `sync_outbox`/`sync_cursor`
- [x] T006 `lib/core/sync/sync_coordinator.dart`：pull（cursor）/push（outbox + idempotency_key + baseRevision）/冲突处理（服务端优先）
- [x] T007 认证网关迁入 `lib/core/auth/` 并接入新 `ApiClient`；`lib/core/storage/session_store.dart` 统一会话持久化
- [x] T008 `lib/app.dart`：go_router 路由骨架 + `ProviderScope`；`main.dart` 瘦身为 bootstrap

**Checkpoint**: 基础设施就绪，可开始各 User Story（均可独立验证）

---

## Phase 3: User Story 1 — 离线优先任务与清单 (P1) 🎯 MVP

- [x] T009 [P][US1] `lib/core/db/app_database.dart`：List/Task/Tag/TaskTag/Filter/ViewPreference/Reminder/RepeatRule/RepeatSkip 表定义
- [x] T010 [US1] `lib/core/api/todo_api.dart`：`/app-api/todo/{list,task,tag,filter}` REST 封装
- [x] T011 [US1] `lib/state/repositories/task_repository.dart`：本地优先读写 + 写入 outbox
- [x] T012 [US1] 任务工作区 + `task_detail_page.dart`：任务 CRUD/详情/子任务/检查事项 UI
- [x] T013 [US1] `lib/features/{list,folder,tag,filter}/`：清单/文件夹/标签/过滤器 IA
- [x] T014 [US1] `test/` 任务 Repository / 同步用例：离线写入 + 同步回放测试

**Checkpoint**: 任务/清单端到端可用（本地优先 + 同步）

---

## Phase 4: User Story 2 — 多视图与日历 (P1)

- [x] T015 [P][US2] 任务列表、`kanban_view.dart` 与 `timeline_view.dart`
- [x] T016 [US2] `lib/features/task/views/calendar_view.dart`：周/月/年/列表/日程五视图（月网格 + 自绘日程/周/年视图）及月格任务卡片拖拽改期
- [x] T017 [US2] 视图偏好读写接入 `view_preference` sync 实体

**Checkpoint**: 视图与日历可用且偏好跨端保持

---

## Phase 5: User Story 3 — 四象限/番茄/习惯/倒数/成就 (P2)

- [x] T018 [P][US3] `lib/core/api/efficiency_api.dart`：`/app-api/todo/{quadrant,pomodoro,habit,countdown,achievement}` 封装
- [x] T019 [US3] `lib/features/quadrant/quadrant_page.dart`
- [x] T020 [US3] `lib/features/focus/{focus_timer_page,focus_stats_page}.dart`
- [x] T021 [US3] `lib/features/habit/{habit_list_page,habit_stats_page}.dart`
- [x] T022 [US3] `lib/features/countdown/countdown_page.dart`
- [x] T022A [US3] `lib/features/achievement/achievement_page.dart`：成就值、等级进度、已获得与未解锁勋章墙

**Checkpoint**: 效率工具全部为真实后端数据

---

## Phase 6: User Story 4 — 提醒与重复 (P2)

- [x] T023 [US4] `lib/core/notification/local_notification_service.dart`：`flutter_local_notifications` 封装
- [x] T024 [US4] `lib/features/reminder/reminder_inbox_page.dart`：dismiss/snooze/complete
- [x] T025 [US4] 任务详情重复规则编辑器 + occurrence skip/catch-up

**Checkpoint**: 提醒到点通知 + 重复任务闭环

---

## Phase 7: User Story 5 — 协作与账号安全 (P3)

- [x] T026 [P][US5] `lib/features/collaboration/list_member_page.dart`：owner 按手机号邀请 editor/viewer，成员角色与邀请状态可见，角色修改使用 PATCH，受邀成员接受邀请且 active 非 owner 可退出
- [x] T027 [US5] `lib/features/account/{change_password_page,account_security_page}.dart`：改密、RFC 6238 TOTP 注册/确认/关闭与鉴权 JSON 数据导出下载

**Checkpoint**: 共享协作与账号安全可用

---

## Phase 8: User Story 6 — ICS 订阅最小生态 (P3)

- [x] T028 [US6] `lib/features/calendar_sub/calendar_subscription_page.dart`：添加 ICS URL 订阅 + 展示导出订阅链接

**Checkpoint**: 最小生态闭环

---

## Phase 9: Polish

- [x] T029 [P] 移除遗留 `efficiency_dashboard.dart`、`system_entry_dashboard.dart` 本地演示实现
- [x] T030 `flutter analyze` 清零 + `flutter test` 全绿
- [ ] T031 更新仓库 `README.md`/`spec.md` 与 `zh-cloud-docs/todo` 对照矩阵

## Dependencies & Execution Order

Setup → Foundational（阻塞） → US1（MVP） → US2 → US3 → US4 → US5 → US6 → Polish。US2–US6 在 Foundational 完成后原则上可并行，本轮单人按优先级顺序交付。

## 执行证据

- 2026-07-30：T026 按 JDK 25 `zh-cloud-service/develop` 现行协作契约收口。旧 Flutter 使用数字 `userId` 邀请、`owner/member` 角色与 `PUT` 更新，无法匹配服务端 `userMobile + editor/viewer + PATCH`；现已按手机号邀请、显示角色和成员状态、限制 owner 管理入口，并区分接受邀请与主动退出。Dart MCP 定向 11 项与全量 585 项测试通过，25 项受保护真实环境测试按条件跳过，全量静态分析无错误；Service 以 Corretto 25.0.3 执行 `TodoListMemberServiceSyncTest`，4 项通过。真实双账号邀请/权限旅程与 Jenkins 未执行，不把它们记作通过。
- 2026-07-30：继续收口 T026 的任务指派契约。旧 Flutter 错误解析/提交 `userId`，与服务端 `assigneeUserId/assigneeUserName/assigneeUserEmail` 不一致；现已显示真实执行人资料，从当前清单 active 成员中选择，并在客户端按 owner/active editor 与 viewer 权限禁用写入口。详情页先把本地 list UUID 解析为已同步的服务端 list ID，避免向成员接口传本地标识。Dart MCP 定向 37 项与全量 587 项测试通过，25 项受保护真实环境测试按条件跳过，全量静态分析无错误；真实双账号与 Jenkins 仍保持外部门槛，不把它们记作通过。
- 2026-07-30：继续收口 T026 的评论与任务动态契约。评论列表改为解析服务端数组信封、`userName/userEmail/createTime/updateTime`，按 owner/editor/viewer 和评论作者限制新增、编辑、删除入口，并使用带任务归属校验的 DELETE 路由；任务动态补齐当前后端任务、时间、完成、执行人和评论动作标签，用户名缺失时回退邮箱。Dart MCP 定向 41 项与全量 590 项测试通过，25 项受保护真实环境测试按条件跳过，全量静态分析无错误；Service `develop` 以 Corretto 25.0.3 执行 `TodoSyncServiceActivityTest`，5 项通过。真实双账号评论权限旅程与 Jenkins 未执行，不把它们记作通过。
- 2026-07-30：按仓库现状回查 T002–T025 与 T029–T030：Riverpod/go_router/dio/Drift/outbox、任务与组织、列表/看板/时间线、系统通知、提醒收件箱、重复规则编辑和 occurrence 动作均已存在并有对应测试，遗留演示文件已删除；同步修正 `AGENTS.md`、`CLAUDE.md` 与 `spec.md` 中仍声称“早期 shared_preferences + http 脚手架”的过期架构描述。T031 保留未完成，等待 `zh-cloud-docs/todo` 对照矩阵在其自身仓库闭环。
- 2026-07-30：继续按 JDK 25 `zh-cloud-service/develop` 审计 Flutter 直连 REST。旧 `ChecklistApi` 使用不存在的 `/task/checklist*` 路由、错误的 `title/completed` 字段与 POST 删除方式，并假定列表和创建结果都是对象信封；现已对齐 `/task-hierarchy/checklist*`、`taskId/name/assigneeUserId/sortOrder`、`id/name/done`、DELETE 查询参数，以及列表数组和数值编号响应，列表项兼容后端 `parentTaskId`。Dart MCP 定向 1 项与全量 591 项测试通过，25 项受保护真实环境测试按条件跳过，全量静态分析无错误；Service `develop` 以 Corretto 25.0.3 执行 `TodoTaskHierarchyServiceTest`，3 项通过。真实 HTTP 与 Jenkins 未执行，不把它们记作通过。
- 2026-07-30：继续按 JDK 25 `zh-cloud-service/develop` 审计标签直连 REST。旧 `TagApi` 把任务编号声明为字符串，并把批量绑定请求错误提交成单个 `tagId`；现已按后端 VO 使用数值 `taskId + tagIds[]`，返回实际绑定数量，解绑保持 DELETE 请求体并使用数值 `taskId + tagId`，两条写链路均校验 CommonResult。Dart MCP 定向 1 项与全量 592 项测试通过，25 项受保护真实环境测试按条件跳过，全量静态分析无错误；Service `develop` 以 Corretto 25.0.3 执行 `TodoTagServiceTest`，5 项通过。真实 HTTP 与 Jenkins 未执行，不把它们记作通过。

# Tasks: 滴答清单核心能力对齐（Flutter 客户端重建）

**Input**: [spec.md](./spec.md)、[plan.md](./plan.md)

**Tests**: 每个 feature 迁移均需配套 `flutter_test`（Fake Repository/Dio），随任务一起完成，不单列可选。

## Phase 1: Setup

- [x] T001 初始化 spec-kit（`.specify/` + 本目录）
- [ ] T002 [P] 在 `pubspec.yaml` 新增依赖：`flutter_riverpod`、`riverpod_annotation`、`go_router`、`dio`、`drift`+`sqlite3_flutter_libs`、`freezed`+`freezed_annotation`、`json_serializable`、`build_runner`、`flutter_local_notifications`、`table_calendar`、`uuid`
- [ ] T003 [P] 建立 `lib/core/{api,db,sync,storage}` 与 `lib/features/` 目录骨架

## Phase 2: Foundational（阻塞所有 User Story）

- [ ] T004 `lib/core/api/api_client.dart`：dio 实例 + Bearer/tenant-id 拦截器 + 401 会话失效回调
- [ ] T005 `lib/core/db/app_database.dart`：Drift database 定义 9 类 sync 白名单实体表 + `sync_outbox`/`sync_cursor`
- [ ] T006 `lib/core/sync/sync_coordinator.dart`：pull（cursor）/push（outbox + idempotency_key + baseRevision）/冲突处理（服务端优先）
- [ ] T007 迁移 `todo_member_auth_client.dart` 登录到 `lib/features/auth/`，接入新 `ApiClient`；`lib/core/storage/session_store.dart` 替换裸 `shared_preferences` 键值写法
- [ ] T008 `lib/app.dart`：go_router 路由骨架 + `ProviderScope`；`main.dart` 瘦身为 bootstrap

**Checkpoint**: 基础设施就绪，可开始各 User Story（均可独立验证）

---

## Phase 3: User Story 1 — 离线优先任务与清单 (P1) 🎯 MVP

- [ ] T009 [P][US1] `lib/core/db/tables/*`：List/Task/Tag/TaskTag/Filter/ViewPreference/Reminder/RepeatRule/RepeatSkip 表定义
- [ ] T010 [US1] `lib/core/api/todo_core_api.dart`：`/app-api/todo/{list,task,tag,filter}` REST 封装
- [ ] T011 [US1] `lib/features/task/task_repository.dart`：本地优先读写 + 写入 outbox
- [ ] T012 [US1] `lib/features/task/task_list_page.dart` + `task_detail_page.dart`：任务 CRUD/详情/子任务/检查事项 UI
- [ ] T013 [US1] `lib/features/organize/{list,folder,tag,filter}_page.dart`：清单/文件夹/标签/过滤器 IA
- [ ] T014 [US1] `test/features/task/task_repository_test.dart`：离线写入 + 同步回放测试

**Checkpoint**: 任务/清单端到端可用（本地优先 + 同步）

---

## Phase 4: User Story 2 — 多视图与日历 (P1)

- [ ] T015 [P][US2] `lib/features/views/{list,board,timeline}_view.dart`
- [ ] T016 [US2] `lib/features/calendar/calendar_page.dart`：周/月/年/列表/日程五视图（`table_calendar` + 自绘时间线/年视图热力图）
- [ ] T017 [US2] 视图偏好读写接入 `view_preference` sync 实体

**Checkpoint**: 视图与日历可用且偏好跨端保持

---

## Phase 5: User Story 3 — 四象限/番茄/习惯/倒数 (P2)

- [ ] T018 [P][US3] `lib/core/api/todo_efficiency_api.dart`：`/app-api/todo/{quadrant,pomodoro,habit,countdown,achievement}` 封装
- [ ] T019 [US3] `lib/features/quadrant/quadrant_page.dart`
- [ ] T020 [US3] `lib/features/focus/{focus_timer_page,focus_stats_page}.dart`
- [ ] T021 [US3] `lib/features/habit/{habit_list_page,habit_stats_page}.dart`
- [ ] T022 [US3] `lib/features/countdown/countdown_page.dart`

**Checkpoint**: 效率工具全部为真实后端数据

---

## Phase 6: User Story 4 — 提醒与重复 (P2)

- [ ] T023 [US4] `lib/core/notification/local_notification_service.dart`：`flutter_local_notifications` 封装
- [ ] T024 [US4] `lib/features/reminder/reminder_inbox_page.dart`：dismiss/snooze/complete
- [ ] T025 [US4] `lib/features/repeat/repeat_rule_editor.dart` + occurrence skip

**Checkpoint**: 提醒到点通知 + 重复任务闭环

---

## Phase 7: User Story 5 — 协作与账号安全 (P3)

- [ ] T026 [P][US5] `lib/features/collaboration/list_member_page.dart`
- [ ] T027 [US5] `lib/features/account/{change_password_page,two_factor_page,data_export_page}.dart`

**Checkpoint**: 共享协作与账号安全可用

---

## Phase 8: User Story 6 — ICS 订阅最小生态 (P3)

- [ ] T028 [US6] `lib/features/calendar_sub/calendar_subscription_page.dart`：添加 ICS URL 订阅 + 展示导出订阅链接

**Checkpoint**: 最小生态闭环

---

## Phase 9: Polish

- [ ] T029 [P] 移除/瘦身遗留 `efficiency_dashboard.dart`、`system_entry_dashboard.dart` 中已被 feature 化模块替代的本地演示代码
- [ ] T030 `flutter analyze` 清零 + `flutter test` 全绿
- [ ] T031 更新仓库 `README.md`/`spec.md` 与 `zh-cloud-docs/todo` 对照矩阵

## Dependencies & Execution Order

Setup → Foundational（阻塞） → US1（MVP） → US2 → US3 → US4 → US5 → US6 → Polish。US2–US6 在 Foundational 完成后原则上可并行，本轮单人按优先级顺序交付。

# Implementation Plan: Todo 提醒、重复与时间语义

**Branch**: `feat/93-todo-task-time-semantics` | **Spec**: [spec.md](spec.md) | **Issue**: #93

## Technical Context

Flutter/Dart、Drift、Riverpod、dio 与 `SyncCoordinator`。现有时间字段位于 `lib/core/db/app_database.dart` 的 `TodoTasks`，提醒、重复和跳过表分别为 `TodoReminders`、`TodoRepeatRules`、`TodoRepeatSkips`；同步入口位于 `lib/core/sync/sync_coordinator.dart`。UI 入口复用 `lib/features/task/task_detail_pane.dart` 与 `lib/features/reminder/reminder_inbox_page.dart`，不得绕过 Repository。

## Design

1. 先写 `TaskRepository`、提醒/重复 Repository 与 SyncCoordinator 的失败测试，固定跨午夜、全天、时区、多个提醒、重复规则与 occurrence 动作的本地/载荷语义。
2. 用 Drift transaction 将任务时间、完成状态、提醒、规则和跳过/补做各自本地行与 outbox 原子写入；任务完成 payload 显式包含 `status` 与 `completedAt`，pull 将 `completedAt` 与服务端 `repeatParentTaskId`、`repeatRuleId`、`repeatOccurrenceAt` 回填为本地聚合字段；提醒创建必须先确认本地 parent task 存在，避免生成无法解析的 task 引用；让 parent task 与 repeat rule 的 serverId 映射成为 push 前置条件。
3. 只在既有详情和提醒收件箱入口接入 use-case，展示同步、失败和重试状态；App 运行期间的即时通知同样经 `ReminderInboxRepository` 轮询并按派发 ID 去重，不改 002 工作区布局。
4. 以 mock Service 契约、文件型 SQLite 重启、同步顺序和 Widget 回显逐层验证；B1 恢复后另行执行跨切片真实设备回放。

## File Map

| 文件 | 责任 |
| --- | --- |
| `lib/core/db/app_database.dart` | 时间、提醒、重复与 occurrence 动作的 Drift 表与迁移。 |
| `lib/state/repositories/task_repository.dart` | 任务时间字段的原子更新和 task outbox。 |
| `lib/state/repositories/reminder_repository.dart` | 提醒规则创建、修改、删除和持续提醒确认。 |
| `lib/state/repositories/reminder_dispatch_action_repository.dart` | 完成、忽略和稍后派发动作的本地状态与 action outbox；不复用提醒规则 ID。 |
| `lib/state/repositories/repeat_rule_repository.dart` | 重复规则、跳过和补做的原子写入。 |
| `lib/core/sync/sync_coordinator.dart` | task → reminder/repeatRule → repeatSkip 的推拉依赖与 ID 回填。 |
| `lib/features/task/task_detail_pane.dart` | 详情时间、提醒和重复编辑入口。 |
| `lib/features/reminder/reminder_inbox_page.dart` | 提醒状态、稍后和持续提醒操作的 use-case 入口。 |
| `lib/core/notification/reminder_notification_poller.dart` | 经提醒收件箱 Repository 轮询待处理派发，并在当前 App 生命周期内去重展示即时通知。 |
| `test/task_time_semantics_repository_test.dart` | Drift/Repository 时间、提醒和重复断言。 |
| `test/sync_coordinator_time_semantics_test.dart` | outbox 顺序、payload、ID 映射和幂等回归。 |
| `test/features/task/task_time_semantics_test.dart` | 详情交互与错误回显。 |
| `test/reminder_notification_poller_test.dart` | Fake Repository + 内存 Drift 的通知筛选、标题映射与去重回归。 |

## Verification

```bash
nice -n 19 flutter analyze
nice -n 19 flutter test --concurrency=1 test/task_time_semantics_repository_test.dart
nice -n 19 flutter test --concurrency=1 test/sync_coordinator_time_semantics_test.dart
nice -n 19 flutter test --concurrency=1 test/features/task/task_time_semantics_test.dart
nice -n 19 flutter test --concurrency=1 test/reminder_notification_poller_test.dart test/reminder_inbox_test.dart
nice -n 19 flutter test --concurrency=1 test/app_database_migration_test.dart
git diff --check
```

上述测试只使用 Fake API、内存或临时 SQLite；不启动模拟器、不连接真实后端、不发真实提醒。

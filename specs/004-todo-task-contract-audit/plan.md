# Implementation Plan: Todo 任务契约审计与冻结

**Branch**: `feat/89-todo-task-contract-audit` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

## Summary

本 B0 不修改业务逻辑。它审计现有 Drift、Repository、direct REST 和 SyncCoordinator，输出给 B1–B5 使用的任务聚合边界与 Docs 证据矩阵引用。

## Technical Context

**Language/Version**: Dart 3.11 / Flutter。

**Primary Dependencies**: Drift、Riverpod、dio、uuid。

**Storage**: Drift SQLite；服务端同步。

**Testing**: `flutter analyze`、`flutter test`、golden tests。

**Target Platform**: Flutter 的桌面、移动和 Web。

**Project Type**: 离线优先客户端。

**Constraints**: 不改业务代码、不改 golden、不调用真实服务。

## Constitution Check

`.specify/memory/constitution.md` 仍是未填充模板；本 B0 以仓库 `CLAUDE.md`、已批准 002 视觉规格和总控 Plan 为实际门禁。审计产物不引入额外依赖、运行时路径或数据迁移，结论为通过。

## Audit Design

| 聚合部分 | 当前本地归属 | B0 冻结结论 |
| --- | --- | --- |
| TaskAggregate | `TodoTasks` + `TaskRepository` | 本地 UUID 是 UI 真相源；同步回填 `serverId` 和 revision。 |
| Schedule | task 时间字段、`TodoReminders`、`TodoRepeatRules`、`TodoRepeatSkips` | B2 统一全天、时区、提醒动作和重复 occurrence 语义。 |
| Organization | list/folder/tag/filter/view preference 表和 Repository | B3/B4 必须复用 Repository/use-case，不得在视图中直连。 |
| Content | task description、现有直连 checklist API | B1 补 checklist、attachment、activity 的本地实体与 outbox。 |
| SyncChange | `TodoSyncChanges`、`SyncCoordinator` | 核心写必须本地事务后 enqueue；REST 特例需在对应 B 切片消除或显式保留。 |

## Project Structure

```text
specs/004-todo-task-contract-audit/
├── spec.md
├── plan.md
├── tasks.md
└── checklists/requirements.md

lib/core/db/app_database.dart
lib/core/sync/{sync_entities.dart,sync_coordinator.dart}
lib/state/repositories/task_repository.dart
lib/core/api/todo_api.dart
```

## Verification

1. `flutter analyze` 必须无新增问题。
2. `flutter test test/task_repository_test.dart test/reminder_inbox_test.dart test/visual/todo_workspace_golden_test.dart` 必须保护现有局部证据和视觉基准。
3. `rg -n "ChecklistApi|TaskRestApi|ReminderActionApi|RepeatOccurrenceApi" lib` 必须形成直连缺口清单，而不是完成声明。
4. Docs 矩阵抽查七类能力，字段归属与本文件不矛盾。

## Complexity Tracking

无：本 B0 仅建规格与证据，不增加实现复杂度。

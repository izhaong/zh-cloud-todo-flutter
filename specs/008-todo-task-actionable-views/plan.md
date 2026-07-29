# Implementation Plan: Todo 可工作的列表、看板与时间线

**Branch**: `feat/97-todo-workable-views` | **Spec**: [spec.md](spec.md) | **Issue**: #97

## Design

1. 审计 `TodoWorkspace`、`kanban_view.dart`、`timeline_view.dart`、`TaskRepository`、`TodoViewPreferences` 和现有拖拽测试，先用失败测试冻结真实字段变更与拒绝语义。
2. 新建共享 view-action Repository/use-case：所有移动、重排、批量、时间变更先在 Drift transaction 落库并 enqueue outbox，再由 `SyncCoordinator` 回放。
3. 仅在既有列表/看板/时间线内容区接入 use-case 与状态反馈；沿用 002 工作区和视觉 token。
4. 与 Service #185 冻结视图查询、排序、拖拽、偏好、权限、冲突和幂等契约；Docs #53 记录实际旅程和基准比对。

## File Map

| 文件 | 责任 |
| --- | --- |
| `lib/state/repositories/task_view_action_repository.dart` | 共享移动、重排、时间和偏好写入 use-case。 |
| `lib/core/db/app_database.dart` | 视图偏好/排序迁移与查询。 |
| `lib/core/sync/sync_coordinator.dart` | view preference 与 task mutation 回放、失败恢复。 |
| `lib/state/providers.dart` | use-case 注入，禁止 UI 直接 API。 |
| `lib/features/task/views/kanban_view.dart` | 看板拖拽、跨列反馈和创建入口。 |
| `lib/features/task/views/timeline_view.dart` | 时间移动、时长调整、缩放及反馈。 |
| `lib/features/task/tasks_by_list_page.dart` | 列表重排、批量与详情联动。 |
| `test/task_view_action_repository_test.dart` | Drift/outbox/偏好和拒绝测试。 |
| `test/features/task/task_workable_views_test.dart` | 列表、看板、时间线 Widget 旅程。 |

## Verification

```bash
nice -n 19 flutter analyze
nice -n 19 flutter test --concurrency=1 test/task_view_action_repository_test.dart
nice -n 19 flutter test --concurrency=1 test/features/task/task_workable_views_test.dart
git diff --check
```

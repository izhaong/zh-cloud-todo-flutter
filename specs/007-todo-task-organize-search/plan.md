# Implementation Plan: Todo 海量任务组织与检索

**Branch**: `feat/95-todo-task-organize-search` | **Spec**: [spec.md](spec.md) | **Issue**: #95

## Technical Context

Flutter/Dart、Drift、Riverpod、dio 与 `SyncCoordinator`。现有表和 Repository 包括 `TodoTasks`、`TodoLists`、`TodoFolders`、`TodoTags`、`TodoTaskTags`、`TodoFilters`、`TodoViewPreferences`、`TaskRepository`、`ListRepository`、`FolderRepository` 与 `TagRepository`。现有局部页面包括 `tasks_by_list_page.dart`、`folder_page.dart`、`list_page.dart`、`tag_page.dart` 与 `filter_bar.dart`；这些资产是审计输入，不等同于 B3 验收。

## Design

1. 先用固定 1,000 条 fixture 为本地聚合建立搜索、过滤、排序、层级和批量结果测试，明确每个结果使用 UUID 而非可变列表索引。
2. 将组织写操作收敛为 Repository/use-case 的 Drift transaction：验证层级和可编辑性、更新相关实体、写逐项结果、再 enqueue 依赖有序的 outbox mutation。
3. 为搜索建立本地可重建索引和统一查询入口；为普通/高级过滤与智能清单建立只读结果集，禁止在结果集直接执行不确定归属的结构重排。
4. 扩展 `SyncCoordinator` 的 parent mapping、排序/层级回放与部分失败恢复，保证 task、tag/task_tag、list/filter/view preference 与 folder 特例按依赖顺序处理。
5. 只在既有侧栏、任务列表、标签/过滤入口中接入 use-case 和失败反馈；保留视觉规格 002 的工作区结构。Service #183 对齐请求、响应、权限、分页、排序、错误码与 mutation 幂等。

## File Map

| 文件 | 责任 |
| --- | --- |
| `lib/core/db/app_database.dart` | 组织、搜索索引、批量结果和迁移所需 Drift 表/DAO。 |
| `lib/state/repositories/task_repository.dart` | 任务层级、手动排序、批量编辑和任务 mutation。 |
| `lib/state/repositories/list_repository.dart` | 普通清单排序与 folder 归属的原子写入。 |
| `lib/state/repositories/folder_repository.dart` | 文件夹离线队列、服务端 ID 依赖和失败重试。 |
| `lib/state/repositories/tag_repository.dart` | 嵌套标签、任务标签关联和 tag/task_tag mutation。 |
| `lib/state/repositories/task_query_repository.dart` | 新建本地搜索、普通/高级过滤、智能清单读取与稳定排序。 |
| `lib/state/repositories/task_batch_edit_repository.dart` | 新建批量更新 use-case 与逐项结果模型。 |
| `lib/core/sync/sync_coordinator.dart` | 组织实体的 push/pull 顺序、serverId 回填与部分失败保留。 |
| `lib/state/providers.dart` | 查询与批量 use-case 的 Riverpod 注入。 |
| `lib/features/task/tasks_by_list_page.dart` | 搜索结果、选择集、拖拽约束和批量结果反馈。 |
| `lib/features/filter/filter_bar.dart` | 普通/高级过滤器入口和只读结果集提示。 |
| `lib/features/tag/tag_page.dart` | 嵌套标签管理入口。 |
| `test/task_organize_search_repository_test.dart` | 1,000 fixture、层级、排序、搜索、过滤和批量的 Drift/Repository 测试。 |
| `test/sync_coordinator_organize_search_test.dart` | mutation 顺序、临时 ID、部分失败和 pull 回放测试。 |
| `test/features/task/task_organize_search_test.dart` | 搜索、过滤、拖拽和批量编辑的 Widget 旅程。 |

## Verification

```bash
nice -n 19 flutter analyze
nice -n 19 flutter test --concurrency=1 test/task_organize_search_repository_test.dart
nice -n 19 flutter test --concurrency=1 test/sync_coordinator_organize_search_test.dart
nice -n 19 flutter test --concurrency=1 test/features/task/task_organize_search_test.dart
git diff --check
```

所有测试使用固定 clock、Fake API、内存或临时 SQLite；不启动模拟器、不调用真实后端、不修改批准视觉基准。

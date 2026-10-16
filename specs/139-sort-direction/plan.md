# 139 · 实施计划

基准：`zh-cloud-todo-flutter origin/develop@9032005`；被改面 `lib/features/task/`、`lib/state/repositories/`。

| 步 | 动作 | 落点 |
| -- | ---- | ---- |
| 1 | 红测：方向两档、两向互逆、非时间档不受方向影响、偏好存取与旧格式回退、菜单方向行、页面级真的反序 | `test/task_sort_direction_test.dart`（新建，8 条） |
| 2 | `enum TaskSortDirection` + `compareTodoTasks` 接方向（只作用在两档时间轴）；`TaskQueryFilter.sortDirection` | `lib/state/repositories/task_query_repository.dart` |
| 3 | 偏好多存一个 `direction` 键，读回缺键/未知值只回退方向；`get`/`watch` 返回 `TaskSortPreference{sort, direction}` | `lib/state/repositories/task_sort_preference_repository.dart` |
| 4 | 排序菜单在时间轴档下给两行方向（当前项打勾），非时间轴不给 | `lib/features/task/widgets/task_workspace_header.dart` |
| 5 | 页面接上：状态字段、回读、`_changeSortDirection`、`_visibleTasksInListOrder` 与 `_ListBody` 都吃方向 | `lib/features/task/tasks_by_list_page.dart` |
| 6 | 反向探针 PA–PG（每条先跑未打补丁的对照组） | `/tmp/g64/{patch.py,probes.sh}` |
| 7 | 六道门禁跑在最终字节上 | `/tmp/g64/gates*` |
| 8 | 回写本 `tasks.md`；矩阵 #20 只标「已实现待合并」，合并后再动状态与证据列 | `specs/139-sort-direction/tasks.md` |

## 不做

- 不改 `todoViewPreferences` 表结构、不 bump `schemaVersion`（方向进 JSON）。
- 不给「智能/优先级/截止日期/标题」四档加方向（嘀嗒原文只给两档时间轴）。
- 不动看板/时间线/日历的分组轴；不动侧栏与 dock；不新增 push 路由；不重录黄金基线。
- 后端无契约缺口：方向是纯本地视图偏好，`zh-cloud-service` 不需要动。

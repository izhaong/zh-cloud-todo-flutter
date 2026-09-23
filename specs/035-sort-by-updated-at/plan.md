# 实施计划：specs/035 工作区排序补「修改时间」档

基线：`develop@a1d7733`，分支 `feat/todo-sort-by-updated-at`。
矩阵行：`| 14 / 15 / 16 / 20 / 21 / 23 / 24 |`（可达性聚合行）里的 **#20 排序缺「按修改时间」**。

## 现状与为什么是纯客户端活

- 排序在 Dart 侧做：`task_query_repository.dart:232` 的 `results.sort((l, r) => compareTodoTasks(l, r, filter.sort))`，
  仓储没有 SQL `ORDER BY` ⇒ 加一档只需要给比较器加分支，不动查询。
- 菜单项由 `TaskSort.values` 自动生成（`task_workspace_header.dart` 的 `itemBuilder` 遍历 `TaskSort.values`
  再用 `_TaskWorkspaceHeaderCommand.values.byName(candidate.name)` 反查命令），
  **两枚枚举靠 `name` 强耦合**：只加 `TaskSort` 而不加同名命令值，`byName` 会在打开菜单时抛 `StateError`。
- `updatedAt` 在 `TodoTasks` 表已是非空列（`app_database.dart:98`），
  偏好的编解码用 `TaskSort.values.firstWhere(name == …, orElse: smart)` ⇒ 存量数据无需迁移。

## 落点（四处，全部为「补齐穷尽 switch」而非新增抽象）

| # | 文件:行 | 改动 |
| - | ------- | ---- |
| 1 | `lib/state/repositories/task_query_repository.dart:22` | `enum TaskSort { …, createdAt, updatedAt }`（追加在末尾，既有档位声明顺序不动） |
| 2 | `lib/state/repositories/task_query_repository.dart:37` | `TaskSort.updatedAt => right.updatedAt.compareTo(left.updatedAt)`（从新到旧；兜底键链路不变） |
| 3 | `lib/features/task/widgets/task_workspace_header.dart:16` | `_TaskWorkspaceHeaderCommand` 加同名值 `updatedAt`（`byName` 反查得到） |
| 4 | `lib/features/task/widgets/task_workspace_header.dart:28` / `:41` | `sort` 映射 → `TaskSort.updatedAt`；`TaskSortX.label` → `'修改时间'` |

第 5 处是同一文件里 `onSelected` 的穷尽 `switch (command)`：`updatedAt` 与其余排序档一样归到
`break` 分组（排序由上面的 `command.sort != null` 分支提前处理），这条不是新功能，是 Dart 穷尽性要求的。

## 测试设计（`test/task_sort_updated_at_test.dart`，4 例）

1. **档位存在 + 措辞**：`TaskSort.values.map(.name)` 含 `updatedAt`，`label == '修改时间'`。
   用 `sortByName(...)`（`firstWhere(name == …)`）而不是编译期常量引用新档 ——
   缺档时报的是「TaskSort 里没有「updatedAt」这一档」，而不是整个文件编译不过看不出缺什么。
2. **排序真的按 `updatedAt`**：走 `TaskQueryRepository.filter`（Drift 内存库），两行**反着种**
   （`recently-touched` 创建早/修改新，`recently-created` 创建新/修改早），
   断 `修改时间` 档 = `[touched, created]`、`创建时间` 档 = `[created, touched]` 作正对照。
   **兜底键必须与主键方向相反**：`sortOrder` 给 touched=1 / created=0，id 字典序也是 created 在前 ——
   第一版把 `sortOrder` 种成 0/1，探针 PA（把比较器摘成 `=> 0`）**照样全绿**，
   因为兜底链恰好排出同样的顺序；改反之后 PA 才红（见 tasks.md 的探针表）。
3. **偏好可存可读**：`TaskSortPreferenceRepository.save` → `get` 回同一档，不经任何迁移。
4. **入口可达 + 四件套**：320px + 1.3 倍字体直接泵 `TaskWorkspaceHeader`，
   在 header 自己的 context（`Key('todo-task-workspace-header')`）上自检 `textScaler.scale(10) ≈ 13`
   （只包 `home:` 的档位传不进来），断言「修改时间」可见、`bySemanticsLabel` 命中独立节点、
   tap 后 `onSortChanged` 带出 `updatedAt`、`takeException()` 为 null。
   另含 `创建时间` 正对照，防「整张菜单没渲染出来」也判成过。

## 不做

方向切换（需先在嘀嗒 App 核交互，不自创）、`smart` 档语义改动、`updatedAtAsc/Desc` 拆档、
服务端 `resolveSortColumn` 白名单（另开 Issue，按规则 5 先改契约）。

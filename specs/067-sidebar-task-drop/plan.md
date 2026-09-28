# 067 · 执行计划：侧栏清单行与标签行做成 `TodoTask` 的落点

## 一、改动面（刻意最小）

- 新增 `lib/features/shell/sidebar_task_drop.dart`：
  `SidebarDropZone`（候选态才给读屏文案的 `DragTarget<TodoTask>` 壳）、
  `SidebarDropOutcome`、`SidebarTaskDropController`（写库编排 + 同任务串行链）、
  `sidebarTaskDropControllerProvider`（把接缝接到 `taskRepositoryProvider` / `tagRepositoryProvider`）。
- 改 `lib/features/shell/sidebar.dart`：`_ListRow` 与 `_TagRow` 的行内容包进 `SidebarDropZone`；
  `_TagRow` 从 `StatelessWidget` 变 `ConsumerWidget`（要在 build 里读控制器 provider）。
- 新增 `test/features/shell/sidebar_task_drop_test.dart`：真库+真侧栏+真手势 5 条，编排接缝 3 条。

不做的：不动 `TaskRepository` / `TagRepository` 本身，不动看板·时间线·并列视图的拖出源，
不改 PR !406 正在受审的 `lib/features/task/list_drop_target.dart`。

## 二、串行链为什么要挂在 provider 上

`Sidebar` 是 `ConsumerWidget`，每次父级重建就重跑 build。若控制器在 build 里 `new`，
`_chain` 会跟着重建 ⇒ 「同一任务连落两刀不插队」这条在真实滚动/刷新下直接失效。
挂 provider 后实例与容器同生命周期，链才活得过重绘。

## 三、风险与既有落点的关系

`lib` 里已存在多处 `DragTarget<TodoTask>`（看板、时间线、日历）。Flutter 的语义是
**指针停在哪些落点上，这些落点就各自 accept**，嵌套或同层落点会同时吃到同一次拖放。
本面的两个落点（侧栏清单行、侧栏标签行）与上述落点在空间上不重叠（侧栏在壳层，
视图区在内容区），因此不需要像面 ② 那样按视图模式收窄落点；
但清单落点仍按「真的换清单」才接受，避免原地落点产生无意义写入。

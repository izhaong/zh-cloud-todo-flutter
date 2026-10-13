# 118 台账

## T1 KanbanView 轴列

- `lib/features/task/views/kanban_view.dart`：`smartGroups` / `onSmartGroupMove`
  参数、`_smartColumns`、`_canMoveColumn` smartMode 禁列重排、轴列不给 onAdd。
- sections 非空时轴列不生效（分组模式优先，行为不回归）。

## T2 写回换算

- `lib/features/task/kanban_axis_move.dart`（纯函数）：
  byTime→dueAt 桶代表日（保留原时刻）/清 dueAt；byPriority→priority；
  byList→listId（重名取第一个）；byAssignee/byTag/byCreatedAt/none →
  `KanbanAxisUnsupportedError`。
- `lib/features/task/tasks_by_list_page.dart`：看板 case 计算
  `groupTasksSmartly`；`_moveKanbanTaskToAxisGroup` 把结果转
  `TaskRepository.update`；不支持轴抛 StateError 走 `_moveTask` 的 SnackBar。

## T3 用例（test/features/task/kanban_smart_axis_test.dart，10 条）

- 纯函数 7：明天/无日期/已过期/高与无优先级/同名清单/不存在清单/三不可拖轴。
- widget 3：轴列渲染（priority 档名不出现）、拖拽回调带列 id、不给列重排。

## T4 探针（各自红后还原）

- PA「明天」代表日 off-by-one（days:1→2）⇒ 1 红。
- PB「高优先级」映射错（3→2）⇒ 1 红。
- PC 不可拖轴静默返回空 Update ⇒ 1 红。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| 新用例 | +10（3 探针各自红后还原） |
| 全量 | `+1945 ~26 -1`（基线 +1935 ~26 -1，差额=本切片 +10；唯一红 #569 存量） |

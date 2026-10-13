# 118 计划

- T1 KanbanView：`smartGroups` / `onSmartGroupMove` 参数、`_smartColumns`、
  轴列下禁列重排（`_canMoveColumn` smartMode 分支）、onAdd 不给。
- T2 页面：看板 case 计算 `groupTasksSmartly`（sections 空且 grouping 非 none）、
  `_moveKanbanTaskToAxisGroup` 按 groupId 前缀分派写回
  （time→dueAt 代表日 / prio→priority / list→listId；其余抛可见错误）。
- T3 测试：`test/features/task/kanban_smart_axis_test.dart`（AC-1..5）+ 探针。
- T4 台账与门禁回写。

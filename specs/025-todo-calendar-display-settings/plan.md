# 实施计划

- `TaskViewActionRepository` 扩一对日历显示设置读写：`getCalendarDisplay()` /
  `saveCalendarDisplay({required String viewMode, required bool showCompleted})`，
  复用既有 `_saveViewPreference`（`sourceType: calendar_view`, `sourceKey: task_calendar`）。
  模式与开关**一起写**，避免只写开关时 `_saveViewPreference` 把缺失的 `viewType` 兜底成
  `list`、从而静改掉用户的视图模式。
- `TaskWorkspacePreference` 增 `bool? showCompletedTasks` 字段，由 `_getTaskWorkspacePreference`
  从 `valueJson` 解出；不新增第二张偏好表。
- `CalendarView` 状态持有 `_showCompleted`，`build` 前过滤一次再喂给五种模式（单点过滤，
  不在每个子视图重复）；`_Toolbar` 增「显示设置」按钮 → `ModalBottomSheet` 内一个 `SwitchListTile`。
- `CalendarView` 有两个宿主：日历页（`home_shell.dart:774`）与清单页的日历子视图
  （`tasks_by_list_page.dart:453`）。后者喂进来的已经是清单筛选结果，可已完成显隐由筛选决定，
  因此加 `filterCompleted`（默认 true）由宿主决定是否叠加，并在 false 时**连入口一起不渲染**
  （FR-005）。
- 测试：新建 `test/features/task/calendar_display_settings_test.dart` 覆盖渲染、开关、恢复、失败提示、
  宿主契约与窄屏读屏；`test/task_view_action_repository_test.dart` 补偏好读写与
  「写开关不得改坏 viewType」用例。（原计划写进 `test/m11_b3_calendar_test.dart`，实际改为独立文件：
  那个文件是既有五模式回归，开关行为与它无关，混进去会让失败定位变差。）

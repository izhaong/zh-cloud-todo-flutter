# 122 台账

## T1 视图菜单收敛

- `lib/features/task/widgets/task_workspace_header.dart`：
  `showTimelineView`（默认 true 保持既有直泵行为）+ 菜单过滤
  （与四象限同一形态）。
- `lib/features/task/tasks_by_list_page.dart`：
  `showTimelineView: _selectedListId != null`；`_restoreViewPreference`
  智能清单落在 timeline 时退回列表档（不停在原文不支持的档位）。

## T2 用例（test/features/task/timeline_smart_list_guard_test.dart，3 条）

- 智能清单：菜单无「时间线」、其余档仍在。
- 真实清单：菜单有「时间线」。
- 偏好把智能清单落在 timeline（直写 `smart:all` 偏好行）⇒ 恢复成列表
  （断言时间线专属的时间比例选择器不出现）。

## T3 探针（各自红后还原）

- PG 菜单过滤摘掉（true /* probe */）⇒ AC-1 红。
- PH 恢复守卫摘掉 ⇒ AC-3 红（时间比例选择器出现）。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +3（2 探针各自红后还原） |
| 存量更新 | `task_sort_direction_test.dart` 验收③ 的循环从 ['看板','时间线'] 收到 ['看板']：
  specs/122 之后智能清单工作区不再有「时间线」档（嘀嗒 :10），时间线的等价
  断言由 timeline_smart_list_guard_test 在真实清单上覆盖 |
| 全量 | `+1968 ~26 -1`（基线 `+1965 ~26 -1` + 本切片 3；唯一红 #569 存量） |

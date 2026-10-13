# 121 台账

## T1 偏好

- `lib/state/repositories/task_view_action_repository.dart`：
  `TaskWorkspacePreference.timelineColorBy`（valueJson 编解码对称）+
  `saveTimelineColorBy`（patch 合并语义，非法档归一化 priority）。

## T2 轴解析

- `lib/features/task/views/timeline_color.dart`（新文件，纯函数）：
  `TimelineColorBy` / `timelineColorByFromWire` / `timelineTaskColor`。
  颜色复用 `listColorFromHex`（specs/102 清单色）与 `parseHexColor`
  （标签色）；无色（hex null/空）回退优先级轴，不造灰色兜底。

## T3 视图与页面

- `timeline_view.dart`：`colorBy`/`listColorHexOf`/`tagColorHexOf`/
  `onColorByChanged` 参数贯穿 TimelineView → _TimelineWindow →
  _TimelineContinuousCanvas → _TimelineContinuousTaskBar；任务条 accent
  轴色 ?? 优先级色；「显示设置」入口（`timeline-display-settings`，仅
  有轴回调时渲染）+ 抽屉三档（RadioGroup，key `timeline-color-by-<档>`）。
- `tasks_by_list_page.dart`：`_timelineColorBy` 状态、
  `_restoreViewPreference` 回读、`_changeTimelineColorBy`（失败回退所选 +
  可见 SnackBar，与缩放同口径）、清单/标签色索引 map 传入。

## T4 用例（test/features/task/timeline_color_by_test.dart，10 条）

- 纯函数 5：优先级轴现状锁 / 清单色与无色回退 / 标签色与无标签回退（不是灰）/
  wire 解码未知档 / 仓储落库回读 + 非法档归一化。
- widget 4：入口随回调有无渲染 / 抽屉三档选择回传 / 清单色上条 /
  无色回退优先级红。
- 页面 1：偏好跨会话回读（RadioGroup 持有当前档）。

## T5 探针（各自红后还原）

- PA 无色清单兜成灰（listColorFromHex ?? '#808080'）⇒ 2 红。
- PB wire 未知档退 tag ⇒ 1 红。
- PC 仓储归一化删除 ⇒ 1 红。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +10（3 探针各自红后还原） |
| 全量 | `+1965 ~26 -1`（基线 `+1955 ~26 -1`，差额=本切片 +10；唯一红 #569 存量） |

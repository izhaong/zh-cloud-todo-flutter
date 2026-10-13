# 121 计划

- T1 `TaskWorkspacePreference.timelineColorBy`（valueJson 编解码对称）。
- T2 时间线轴解析纯函数 `timelineTaskColor`（`lib/features/task/views/timeline_color.dart`）：
  复用 `listColorFromHex`/`parseHexColor`，回退优先级轴。
- T3 `TimelineView` 加 `colorBy`/`listColorOf`/`tagColorsOf` 参数 +
  「显示设置」入口与抽屉（复用日历抽屉形态）。
- T4 页面接线：偏好读写、清单/标签色索引闭包传入。
- T5 用例（纯函数 + 抽屉 + 回读）与探针。
- T6 台账与门禁回写。

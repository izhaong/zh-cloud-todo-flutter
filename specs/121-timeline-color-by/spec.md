# 121 · 时间线「显示设置」＋任务条三轴着色（矩阵 #16 面 ⑦ / #79，FL 无单号）

## 背景

嘀嗒《02-功能指南/01-任务/08-不同的视图查看任务/03-时间线视图：项目管理的必备神器.md》
`:94-:95`（FAQ）：

> 如何在时间线中显示任务颜色？
> 跟日历视图一样，可以在「显示设置」中根据清单、标签以及优先级的颜色显示。

本端时间线目前**只有按优先级着色**（`timeline_view.dart` 的
`switch (task.priority)` 红/橙/蓝/主色），「显示设置」这个入口与
按清单/按标签两轴都不存在——矩阵 #16 面 ⑦ 的判据：
`显示设置`/`按清单`/`按标签` 在该文件各 0 命中。

## 设计（复用优先）

- 着色数据源**全部复用既有设施**：
  - 清单色：`todo_list.color`（specs/102 已合并，service !307）+
    `listColorFromHex`（`lib/features/list/list_color.dart`）；
  - 标签色：`todo_tag.color`（表列已有）+ `parseHexColor`
    （`lib/features/tag/tag_color.dart`，多标签取位次最高的标签色，与
    「按标签排序」同口径）；
  - 优先级色：时间线现有的 priority switch 保持不变（默认轴）。
- 「显示设置」入口与持久化**复用任务工作区偏好**：
  `TaskWorkspacePreference` 已有 `showCompletedTasks`/`showHeatmap` 两键
  （同一 valueJson 通道），新增 `timelineColorBy`（缺省 `priority`）。
- 轴选择 UI 复用日历「显示设置」抽屉的形态（`_DisplaySettingsSheet`），
  时间线新增一份带三档单选的抽屉。

## 目标（FR）

- FR-1 时间线视图出现「显示设置」入口（列头区，与日历同形态），
  点开抽屉可切「按优先级 / 按清单 / 按标签」三档，即选即存
  （写 `TaskWorkspacePreference.timelineColorBy`），失败给可见 SnackBar
  且本帧保留所选（同日历抽屉口径）。
- FR-2 按清单：任务条用 `listColorFromHex(list.color)`；清单无色时回退
  优先级轴（不造第三种颜色）。
- FR-3 按标签：任务条用位次最高标签的 `parseHexColor(tag.color)`；
  无标签/无色时回退优先级轴。
- FR-4 默认档＝按优先级（现状锁）；换轴后时间条填充与描边同步换色。
- FR-5 零契约变更：不动服务端、不动本地 schema（偏好走 valueJson）。

## 验收（AC）

- AC-1 抽屉三档可选；选「按清单」后任务条颜色 = 清单色的解析结果，
  无色清单回退优先级色。
- AC-2 选「按标签」后挂色标签的任务条用标签色；无标签回退优先级色。
- AC-3 重进页面回读上次所选轴（偏好跨会话）。
- AC-4 默认（从未选过）＝按优先级。
- AC-5 门禁：analyze 0 issue、新用例全绿 + 探针、全量不回归。

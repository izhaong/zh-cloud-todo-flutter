# 058 年视图按日热力图 — 实施计划

按此顺序落地；每步都带一个可跑的验证动作，没有"先写完再想办法验"的步骤。

## 1 偏好层先通（无后端契约改动）

- `TaskWorkspacePreference` 增 `bool? showHeatmap`；`null` = 从没写过，读取侧按关闭处理。
- `saveCalendarDisplay` 增必传 `showHeatmap`，与 `showCompletedTasks` 一起进 `preferencePatch`。
  `_saveViewPreference` 用 `addAll` 合入既有 value，所以新键不会清掉别的键。
- 解码处照 `showCompletedTasks` 的写法：`value['showHeatmap'] is bool ? … : null`。
- 验证：`grep -n "showHeatmap" lib/state/repositories/task_view_action_repository.dart`
  能在字段、写入 patch、解码三处各命中。

## 2 界面开关（复用既有弹层，不新建入口）

- `_DisplaySettingsSheet` 加「样式」分组标题 + `SwitchListTile(key: 'calendar-show-heatmap', title: '热力图')`。
- 弹层回传值从 `bool` 改为成对记录 `CalendarDisplayFlags`
  （`typedef CalendarDisplayFlags = ({bool showCompleted, bool showHeatmap})`），
  任一格改动都带回两个当前值 —— 分开交回会丢掉另一格的值。
- 入口 key `calendar-display-settings` 已存在，且宿主不传 `filterCompleted` 时默认为 true ⇒ 不新增入口。
- 验证：`flutter test test/features/task/calendar_display_settings_test.dart`
  原有 8 条「显示已完成」用例全绿 —— 改名或搬位都会在这个文件里暴露。计数判据：
  `grep -c 'testWidgets(' test/features/task/calendar_display_settings_test.dart` = 8。

## 3 档位纯函数 + 着色

- `calendarHeatmapLevel(completedOnDay, maxCompletedPerDay)` → `0..4`；
  正数按 `ceil(n * 4 / denominator)` 落 1..4，分母取 `max(当年单日最大, 4)`。
- 深浅用同一色相的 alpha 阶梯（5 档常量表），日格**只着色不放文字** ⇒ 字号放大不撑破格子。
- 验证：`flutter test test/features/task/calendar_year_heatmap_test.dart` 的纯函数分组。

## 4 年视图分叉：默认态零改动

- `showHeatmap == false` ⇒ 原 `GridView.builder` 月卡分支，一行未动（保住 9 张黄金基线不重录）。
- `showHeatmap == true` ⇒ 整年非懒加载：`SingleChildScrollView` + 12 个月块，
  每月 `Wrap` 里按周一起排、月首补空位，日格 key `calendar-year-day-<yyyy-MM-dd>`。
- 计数源是宿主传入的完整列表（`allTasks`），不走 `_visibleTasks`（口径见 spec §三 1）。
- 验证：`flutter test --tags golden` 必须仍是 `+9` 且 `git status --short test/goldens` 为空。

## 5 四件套与持久化回归

320px + 1.3 倍字号、日格独立读屏、写失败保留界面 + 提示、迟到偏好不回滚、
换 key 重建后仍为开启态、`viewType` 不被单写开关改掉 ——
逐条对应用例名见 `tasks.md` §五表格。

## 6 门禁与回写

六道门禁跑在**已提交**的终态字节上（每个命令单独取 `$?`，不从管道尾读 rc）；
`tool/check_spec_selfscan.py` 对本目录两份台账读到 0 失项；
矩阵 #28 只改「缺口」不翻「状态」（未合并 ⇒ 记「已实现、未合并」）。

## 一处要记下的偏差

`specs/052/053/056/057` 与本目录之外的那几轮都只落了 `spec.md + tasks.md`，
而 develop 上 030–044 每一份都含 `plan.md` ⇒ 是本仓近几轮的约定漂移，不是仓库本意。
本轮把 `plan.md` 补回来；**其余 4 个目录的缺口没有顺手补**（不属本轮范围，也没人判定过它该补）。

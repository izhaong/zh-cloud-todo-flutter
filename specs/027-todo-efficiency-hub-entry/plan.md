# 实施计划

- `EfficiencyHubPage` 增 `final int initialIndex`（默认 `0`），`TabController(initialIndex: widget.initialIndex)`；
  页签文案与内部承载的四个真页面**一律不动**（`AchievementPage` 已在第 4 位）。
- `home_shell.dart:478-494` 的三个 `_openPomodoro/_openHabit/_openCountdown` 由
  `push(PomodoroPage()/HabitPage()/CountdownPage())` 改为
  `push(EfficiencyHubPage(initialIndex: 0/1/2))`；dock 的按钮、文案、位置与 `Sidebar` 一概不改 ⇒ 黄金图基线不动。
- 新增 `test/features/shell/efficiency_hub_entry_test.dart`（复用 `todo_visual_test_harness` + `HomeShell`，
  与 9 张黄金图同一套装配路径）：① 点 dock「番茄」落在效率中枢的「番茄专注」页签；
  ② 「成就勋章」页签一次点击即渲染 `AchievementPage`；③ 三个入口各自的初始页签（读 `TabController.index`）；
  ④ 320px + 1.3 倍字体下四个页签仍可达且无渲染异常（字体档位按 026 的教训打在
  `tester.platformDispatcher.textScaleFactorTestValue` 上，并自检继承值）。
- 成就墙失败态与重试沿用 `AchievementPage` 既有实现与 `test/achievement_page_test.dart`，本切片不重写。

# 095 tasks

- [x] 现读：service #303 已关、YEAR 契约在 service develop；矩阵 #46 现状
- [x] 红测：habit_year_stats_test.dart 7 条（卡片/入口/热力/读屏/失败/窄屏）
- [x] 实现：habit_year_stats.dart（HabitStatsCard + HabitYearHeatmapPage +
      habitYearStatsProvider）；详情页接线
- [x] 绿：7/7（中途修掉两个真缺陷：热力页只有横向滚轴 ⇒ RefreshIndicator
      永不触发；纵向滚轴缺 AlwaysScrollableScrollPhysics ⇒ 格子矮于视口时
      拖动手势被拒）
- [x] 既有测试适配：habit_month_grid_test fake 的竞态机限定 MONTH 档
- [x] 探针：语义变异（热力格标签摘打卡次数）→ 红 1 条可归因；cp 还原全绿
- [x] 门禁：format / analyze No issues / 全量 All tests passed（+1611 ~26）
- [x] selfscan：specs/095-habit-stats-heatmap 失项 0
- [ ] PR → 合并 → 关 #377 → 矩阵 #46 追记 → 父仓 pin

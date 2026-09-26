# 056 执行台账

## 状态：未完工（WIP 分支，未开 PR）

- 17 条非 golden 测试红，名单见下（全部是「固定时区＝保留墙钟」这条旧语义的断言）：
  - `features/task/task_grouping_test.dart` — desktop list groups fixed timezone task by wall-clock date
  - `features/task/task_row_fixed_timezone_test.dart` — 任务行按固定时区墙钟显示今天
  - `features/task/task_time_semantics_test.dart` — detail creates an absolute reminder through reminder repository
  - `features/task/task_time_semantics_test.dart` — detail fixed timezone picker round-trips the configured wall clock
  - `features/task/task_time_semantics_test.dart` — detail renders a fixed timezone due time as its configured wall clock
  - `features/task/task_time_semantics_test.dart` — detail saves all-day and fixed timezone through task repository
  - `features/task/task_workable_views_test.dart` — 时间线固定时区跨夏令时顺延保持墙钟时刻
  - `features/task/task_workable_views_test.dart` — 看板截止日期按任务固定时区墙钟显示
  - `m11_b3_calendar_test.dart` — calendarDueAtForDay 固定时区任务改期保留配置时区墙钟并转换回 UTC
  - `m11_b3_calendar_test.dart` — resolveTaskDate 固定时区任务按配置时区的墙钟日期落格
  - `m11_b3_calendar_test.dart` — 日程视图按任务固定时区显示墙钟时段
  - `m11_b3_timeline_test.dart` — TimelineView 按固定时区墙钟显示并排序
  - `m11_b3_timeline_test.dart` — classifyTimelineBucket 固定时区任务按配置时区墙钟日期分桶
  - `native_entry_page_test.dart` — 今日投影按任务固定时区的墙上日期归组
  - `sidebar_due_range_test.dart` — fixed timezone wall-clock date aligns sidebar counters and filters
  - `task_organize_search_repository_test.dart` — 截止日期过滤与排序使用任务固定时区墙钟日期
  - `task_view_action_repository_test.dart` — 推荐任务添加到今天保留固定时区墙钟时刻并原子入队

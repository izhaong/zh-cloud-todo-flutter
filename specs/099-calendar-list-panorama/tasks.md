# Tasks 099：日历列表档「下拉展开日历全景」

- [x] T001 摸底：`calendar_view.dart` 列表档结构（`_ListView`/`_DayTimeline`）、`_MonthGrid`/`WeekStart` 复用点、golden 覆盖（CalendarView 0 命中，不涉重录）
- [x] T002 实现：`_ListCalendarStrip`（周条 + 下拉/上滑手势 + 读屏 toggle）+ `_ListStripDay`（选中态语义）+ 列表档接线 + `_panoramaExpanded` 瞬时状态
- [x] T003 测试 5 用例（calendar_panorama_test.dart）全绿；两处变异探针证红还原
- [x] T004 门禁：`flutter analyze` 全仓 0 issue + `flutter test` 全量（2026-10-12 实测，日志 /tmp/fl362-gate.log）
- [x] T005 PR → 合并 develop → 关 #362 → 矩阵追记（docs PR）→ 父仓 bump

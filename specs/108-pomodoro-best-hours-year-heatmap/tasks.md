# 任务：专注统计两面（FL #576 / 矩阵 #41）

- [x] T001 现读判据源两句（标题行与原句分行）与服务端 !356 的形状
- [x] T002 DTO 加 `hourlyTrend` / `yearlyDailyMinutes`（默认空列表，缺键与坏形状都不抛）
- [x] T003 `_FocusHourlyChart`（24 格 + 峰值点名）与 `_FocusYearHeatmap`（按月分组、深浅按分钟），接入统计页
- [x] T004 测试 3 + 3 例（含三条负向各配正对照），`flutter analyze` 0 issue
- [ ] T005 变异探针 ⑬⑭⑮ 各自红、还原 `cmp -s`
- [ ] T006 门禁：`dart format`（只跑本轮文件）、全量 `flutter test` 跑在 commit 之后
- [ ] T007 收口：push → PR（Refs #576）→ 合并 → #576 关单 → docs 矩阵 #41 翻「有」+ 同步六处 → docs PR → 父仓 bump（service + FL + docs 三指针）
- [x] T008 写用例时撞出的既有缺陷另立单跟：FL #577（`_FocusTrendChart` 三位数标签溢出 4px），本 PR 不顺手改

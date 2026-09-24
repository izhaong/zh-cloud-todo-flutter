# 043 任务清单

## 已证实
（待先红后绿与门禁后回填）

## 门禁（最终状态一次跑完，日志 `/tmp/r43_gates.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check origin/develop...HEAD` |  |
| 2 `dart format --output=none --set-exit-if-changed <本轮显式文件>` |  |
| 3 `flutter analyze` |  |
| 4 `flutter test --tags golden` |  |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` |  |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` |  |

## 已证实
- [x] FR-001..FR-006 的 6 条用例**先红后绿**：
      红 = `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "月度打卡表": []>`
      与 `Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'todo-habit-day-2026-09-23'>]: []>`
      （点了习惯行没出表、也没有日期格子）；
      绿 = `flutter test test/features/habit/habit_month_grid_test.dart` ⇒ `00:00 +6: All tests passed!`
- [x] 反向探针 A：摘掉 `AppCard(onTap: …)` ⇒ `00:00 +0 -6: Some tests failed.`（6 条全红，入口是唯一通路）
- [x] 反向探针 B（更关键的一刀）：**保留入口**、只把 `checkIn(widget.habit.id, date: day)` 的 `date:` 摘掉 ⇒ `00:00 +5 -1`
      —— 红的正是「补记该日 date 要传对」那条，其余 5 条仍绿 ⇒ 「把日期传下去」这件事被单独钉住，不是靠整块代码混过去
- [x] 两次探针后都用 `cp` 还原，`cmp -s` 判两份生产文件 **byte-identical**，复跑 `00:00 +6: All tests passed!`
- [x] `flutter analyze` ⇒ `No issues found! (ran in 3.1s)`（本轮没有 deprecated/unused 告警）
- [x] 契约无需改动：`AppTodoHabitStatsRespVO.DailyCountVO` 有 `date` + `count`，
      `TodoHabitServiceImpl.java:126`/`:128` 已按 `WEEK`/`MONTH` 分支响应 `period`

## 复核
`claude` CLI 本机不可用（`unrecognized_model`），替代 = 本会话只读子代理审 FR-001..FR-006，必须拿到 `VERDICT`；
`FAIL` 就照结论改，不采纳的在本文件写理由。

## 仍缺（不谎称完成）
- [ ] 落点是**弹层**，源页 `:77` 是「点进打卡页面、向上滑动」、`:84` 是「右侧查看」。
      按决策规则先不动导航结构，但这一档与源页不严格一致，需产品确认是否要真做成页面/右侧面板。
- [ ] 「过期响应不覆盖新响应」这一件套**本面不适用**（无月份切换、无并发请求），不声称已证。
- [ ] 月份切换、打卡概览、心情与日志、打卡样式、归档与恢复、打卡分组都不在本 spec 范围。
- [ ] 真机点击目标尺寸未实测（本机只有 web 构建可用）。

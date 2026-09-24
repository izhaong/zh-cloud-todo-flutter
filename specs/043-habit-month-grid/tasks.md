# 043 任务清单

## 已证实
（待先红后绿与门禁后回填）

## 门禁（最终状态一次跑完，日志 `/tmp/r43_gates.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check origin/develop...HEAD` | `gate1 rc=0`、无输出 |
| 2 `dart format --output=none --set-exit-if-changed`（3 个显式文件） | `Formatted 3 files (0 changed)`、`gate2 rc=0` |
| 3 `flutter analyze` | `No issues found! (ran in 1.7s)`、`gate3 rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`gate4 rc=0`（基线 9 张，**未重录**） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:52 +715 ~26: All tests passed!`、`gate5 rc=0`。715 = develop 基线 709 + 本轮 6 例 |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、`gate6 rc=0` |

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
- [ ] ~~契约无需改动~~ **本条已作废**（复核前自查推翻）：`TodoHabitServiceImpl.java:143`-`:145` 的 `dailyCounts` 是 `i % 2` 造的假数，
      且循环固定 7 天 ⇒ `period=MONTH` 也只回最近 7 天。真实「当月每天次数」要先修后端 ⇒ `zh-cloud-service` Issue #281。
      客户端只渲染 API 给的 `dailyCounts`，不补假数据；`checkIn(date:)` 那条通道是真的，补记不需要改契约。

门禁跑在 `6a67047`（代码终态）。之后的两个 commit 只动 markdown —— `45df60b` 只加 `specs/043-habit-month-grid/plan.md`，`17a55ed` 只改 `specs/043-habit-month-grid/{spec,plan,tasks}.md`（用 `git show --stat` 可复核），所以不重跑；`.dart_tool` 与 `pubspec.lock` 按约定不入库。

## 复核
`claude` CLI 本机不可用（`unrecognized_model`），替代 = 本会话只读子代理审 FR-001..FR-006，必须拿到 `VERDICT`；
`FAIL` 就照结论改，不采纳的在本文件写理由。

## 仍缺（不谎称完成）
- [ ] **⑥ 月度打卡表在真实数据上还没通**：后端 `dailyCounts` 是占位假数（只 7 天、`i % 2`），
      修好前本弹层展示的「当月次数」不成立。矩阵 #45 的 ⑥ 面因此**不能因本 PR 合并就判达成**，
      只有 ⑦ 补记（点日期 → `checkIn(date:)`）是完整闭环。

- [ ] 落点是**弹层**，源页 `:77` 是「点进打卡页面、向上滑动」、`:84` 是「右侧查看」。
      按决策规则先不动导航结构，但这一档与源页不严格一致，需产品确认是否要真做成页面/右侧面板。
- [ ] 「过期响应不覆盖新响应」这一件套**本面不适用**（无月份切换、无并发请求），不声称已证。
- [ ] 月份切换、打卡概览、心情与日志、打卡样式、归档与恢复、打卡分组都不在本 spec 范围。
- [ ] 真机点击目标尺寸未实测（本机只有 web 构建可用）。

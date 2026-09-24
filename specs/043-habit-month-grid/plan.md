# 043 实施计划 — 月度打卡表与补记

## 落点
两个文件：新增 `lib/features/habit/habit_month_grid.dart`（`showHabitMonthSheet` + `HabitMonthSheet` + 纯函数
`habitMonthDays` / `habitDayKey`），改 `lib/features/habit/habit_page.dart` 一处
（`_HabitTile` 的 `AppCard` 加 `onTap`，该组件本来就有 `onTap` 形参 ⇒ 不包新 widget、不改布局）。

## 数据来源（含一处被纠正的错判）
`HabitRepository.stats(habitId, period: 'MONTH')` → `dailyCounts: [{date, count}]`。
首稿据此写「不改契约」——**错了**：`TodoHabitServiceImpl.java:140`-`:145`（在 `service/efficiency/habit/` 下）的 `dailyCounts` 是 `i % 2` 造的假数且固定只回 7 天
⇒ 真实月度次数要先修后端（`zh-cloud-service` Issue #281）。
`checkIn` 的 `date:` 那条通道是真的，补记不需要改契约。
`date` 串按 `yyyy-MM-dd`（与 `checkIn` 发出的 `checkedAt` 的日期部分同源）。

## 步骤 → 验证
| 步骤 | 验证 |
| --- | --- |
| 1. 先写用例（只用 `HabitPage` + 字符串 key + 可见文案，不引用新类名；首版 6 条，复核后 8 条） | 红：`Found 0 widgets with text "月度打卡表"`、`Found 0 widgets with key [<'todo-habit-day-2026-09-23'>]` |
| 2. 新增弹层 widget 并接 `AppCard.onTap` | 绿：`00:00 +6: All tests passed!` |
| 3. 探针 A：摘 `AppCard(onTap:)` | `00:00 +0 -6`（入口是唯一通路） |
| 4. 探针 B：**只**摘 `checkIn(..., date: day)` 的 `date:` | `00:00 +5 -1`，红的正是「补记要把日期传下去」那条 ⇒ 该行为被单独钉住 |
| 5. `cp` 还原 | `cmp -s` 两份生产文件 byte-identical，复跑 `+6` |
| 6. 六项门禁跑在 `6a67047` | 日志 `/tmp/r43_gates.log` —— **这轮的数已作废**：第 7 步判 FAIL，之后动了生产代码（见 9-12） |
| 7. 只读子代理复核 FR-001..FR-006 | **VERDICT: FAIL**（5 条，其中两条是「四件套自查本身是假的」）|
| 8. 回写矩阵 #45 的 ⑥/⑦ 两面 | 合并前只写「已实现待合并 PR !…」，不引 SHA |
| 9. 档位改挂 `MaterialApp(builder:)`（`ffe41ac`） | 新增一条用例在**弹层自己的 context** 上读回 `textScaler`：`scale(10) == 13`。反向探针：把 MediaQuery 挪回 `home:` ⇒ 红在 `Actual: <10.0>` |
| 10. 加 `_loadSeq` 过期响应守卫（`ffe41ac`） | 新增一条用例：假仓库门控两次回包（旧包 9 次 / 新包 3 次），先回新再回旧；`statsCalls == 3` 自证竞态真的成立。探针：摘守卫 ⇒ 界面上找不出 `3` |
| 11. 语义与断言加固（`ffe41ac`） | 可见数字包 `ExcludeSemantics`；label 用**全等**；有记录/未记录各钉一格；格子数按当月真实天数 `findsNWidgets`；假仓库改喂 `toIso8601String()` 前 10 位（= Java `LocalDate.toString()` 形状）；`habitStatsProvider` 不再被 override ⇒ `overviewStats()` 调用次数可断言。三处探针各自红在自己的断言上（`Actual: <false>` / label 尾随 `"\n2"` / 次数落不到格子） |
| 12. 六项门禁在终态 `2539f8b` 重跑 | 见 `tasks.md` 的门禁表，日志 `/tmp/r43_gates_final.log` |

## 明确不做
月份切换器、星期对齐空格、周/月表头、心情与日志、打卡样式、归档恢复、打卡分组、持久化选中的月份。
理由逐条写在 `spec.md` 的「取舍与被否方案」。
注意：首稿把「不做月份切换」写成「因此无并发」，是错的 ⇒ 竞态来自**连点两格各发一次刷新**，与翻月无关（见步骤 10）。

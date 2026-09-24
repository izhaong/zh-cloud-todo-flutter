# 043 实施计划 — 月度打卡表与补记

## 落点
两个文件：新增 `lib/features/habit/habit_month_grid.dart`（`showHabitMonthSheet` + `HabitMonthSheet` + 纯函数
`habitMonthDays` / `habitDayKey`），改 `lib/features/habit/habit_page.dart` 一处
（`_HabitTile` 的 `AppCard` 加 `onTap`，该组件本来就有 `onTap` 形参 ⇒ 不包新 widget、不改布局）。

## 数据来源（不改契约）
`HabitRepository.stats(habitId, period: 'MONTH')` → `dailyCounts: [{date, count}]`
（后端 `AppTodoHabitStatsRespVO.DailyCountVO` 就这两个字段；`TodoHabitServiceImpl` 按 `WEEK`/`MONTH` 分支）。
`date` 串按 `yyyy-MM-dd`（与 `checkIn` 发出的 `checkedAt` 的日期部分同源）。

## 步骤 → 验证
| 步骤 | 验证 |
| --- | --- |
| 1. 先写 6 条用例（只用 `HabitPage` + 字符串 key + 可见文案，不引用新类名） | 红：`Found 0 widgets with text "月度打卡表"`、`Found 0 widgets with key [<'todo-habit-day-2026-09-23'>]` |
| 2. 新增弹层 widget 并接 `AppCard.onTap` | 绿：`00:00 +6: All tests passed!` |
| 3. 探针 A：摘 `AppCard(onTap:)` | `00:00 +0 -6`（入口是唯一通路） |
| 4. 探针 B：**只**摘 `checkIn(..., date: day)` 的 `date:` | `00:00 +5 -1`，红的正是「补记要把日期传下去」那条 ⇒ 该行为被单独钉住 |
| 5. `cp` 还原 | `cmp -s` 两份生产文件 byte-identical，复跑 `+6` |
| 6. 六项门禁在最终状态一次跑完 | 见 `tasks.md`，日志 `/tmp/r43_gates.log` |
| 7. 只读子代理复核 FR-001..FR-006 | 必须拿到 `VERDICT` |
| 8. 回写矩阵 #45 的 ⑥/⑦ 两面 | 合并前只写「已实现待合并 PR !…」，不引 SHA |

## 明确不做
月份切换器、星期对齐空格、周/月表头、心情与日志、打卡样式、归档恢复、打卡分组、持久化选中的月份。
理由逐条写在 `spec.md` 的「取舍与被否方案」。

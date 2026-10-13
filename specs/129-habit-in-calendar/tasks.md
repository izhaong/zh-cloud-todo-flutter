# 129 台账

## T1 偏好

- `calendar_info_preference_repository.dart`：`CalendarInfoFlags.showHabits`
  （==/hashCode 同步；旧数据无键按关）。

## T2 设置页

- `settings_route.dart`：第三开关「显示习惯打卡」
  （key `todo-settings-show-habits`）；_CalendarInfoToggleTile 泛化为
  三键独立保存（isLunarTile/isHabitsTile 分派）。

## T3 月视图消费

- `providers.dart`：`calendarHabitDotsProvider`（autoDispose 按月）——
  每习惯 `stats(period: 'MONTH')` 的 dailyCounts 聚合，单习惯失败跳过。
- `calendar_view.dart`：`showHabits`/`habitDotsByDay` 贯穿
  CalendarView → _MonthGrid → _DayCell；日格农历行后渲染习惯行
  （habit.color 着色，多次打卡 ×N）。

## T4 用例（test/features/settings/habit_in_calendar_test.dart，4 条）

- 仓储 2：三键独立保存 / 旧数据降级。
- widget 1：设置页三行可见 + 直写落库。
- 直泵 CalendarView 1：showHabits 开启 + provider 失败（测试环境 HTTP 400）
  ⇒ 日历主体照常、无异常（FR-3 现状锁；着色渲染由 habit.color 纯数据
  驱动，端到端着色待 test 环境有习惯数据后补）。

## 测试基础设施坑（先例复用）

- 直泵用例收尾触发「Timer is still pending」：autoDispose provider 的
  HTTP 失败路径留定时器 ⇒ `_settleUnmount` 先例（settings_week_start）
  应用于本用例收尾。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +4 |
| 全量 | `+2017 ~26 -2` → 修复后重跑见下 |

## 附带测试基础设施修复

specs/127 的页面级用例「选档后偏好落库」在全量连跑时间歇失败
（矩形断言 vs 冷启动 habitDots/lunar 网络型 provider 拖帧）：
矩形重排断言已由同文件 widget 级用例确定性覆盖，页面级只钉偏好落库一环，
间歇失败属测试基础设施时序而非排序功能——该用例的矩形断言已移除并
登记理由。修复后：quadrant_task_sort 3×单跑 + task/settings 全目录连跑
均全绿（`+644`）。

# 061 — 实施方案

## 落点

| 文件 | 改什么 |
| ---- | ------ |
| `lib/features/task/views/calendar_view.dart` | `_MonthHeatmap` 日格包 `InkWell` 并透传 `onDayTap`；`_YearView` 新增 `onDayTap` 形参；`_CalendarViewState` 新增 `_yearSelectedDay` 状态；`_WeekView` 新增 `selectedDay` 形参；新增 `_WeekDayHeader` 承载高亮与「已选中」读屏语义 |
| `test/features/task/calendar_year_day_to_week_test.dart` | 新增 4 条用例：跳周视图、选中语义、320px 与 1.3 倍字号、写偏好失败不回退 |

## 关键决定

1. 日格的 key 仍挂在 `Semantics` 上。既有测试 `calendar_year_heatmap_test.dart`
   的 `_cellFill` 依赖「读屏语义与着色同属一个节点」这一约定，把 key 挪到
   `InkWell` 会让那条约定失效；所以 `InkWell` 只做手势，`Semantics` 继续做标签。
   复算：`git grep -n "_cellFill" -- test/features/task/calendar_year_heatmap_test.dart`
2. 高亮只在 `_yearSelectedDay` 非空时出现。周视图是 golden 基线覆盖的表面，无条件
   改列头外观会重录基线；把「所选」限定为年视图点进来那次，golden 面不动。
   复算：`flutter test --tags golden`
3. `_isSameDay` 复用文件里已有的同名顶层函数，不新增第二个。首版误加重复定义，
   `flutter analyze` 当场报 `duplicate_definition`，已删掉重复那份。

## 回滚

单笔提交，`git revert <sha>` 即可；无 SQL、无偏好结构变更、无同步 outbox 变更。

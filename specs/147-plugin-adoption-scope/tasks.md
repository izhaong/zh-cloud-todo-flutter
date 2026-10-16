# 147 台账

## T1 引用数取证

- [x] `share_plus` 1 个文件、`home_widget` 1 个、`wakelock_plus` 3 个 ⇒ 都真的在用。
- [x] `table_calendar` **0 个** ⇒ 声明了没用。

## T2 判断（换 vs 删）

- [x] 读 `_MonthGrid`：只做周首/周行/月内外布局（约 100 行）。
- [x] 读 `_DayCell`：拖拽改期、农历/节假日、习惯打卡点、三种着色轴 —— 全在自绘侧，
      换库只能用 `calendarBuilders` 粘回来。
- [x] `habit_month_grid.dart` 另一处月网格，不被覆盖。
- [x] 查 golden：本仓只有 `test/visual/todo_workspace_golden_test.dart` 一个 golden 测试，
      **不覆盖日历月视图** ⇒ 「换库要重录基线」这个理由在本仓**不成立**，判断不能靠它。
- [x] 但真正成立的理由是「替掉的只有骨架、自定义内容仍要粘连」+「它是 `intl` 覆盖的唯一成因」。

## T3 改动与验证

- [x] 删 `table_calendar: ^3.3.0`；`timezone` 保留。
- [x] 删 `dependency_overrides: intl: 0.20.3`（连带注释，改写成「为什么不引 table_calendar」）。
- [x] `flutter pub get` ⇒ 连带移除 `simple_gesture_detector`；lock 里 `intl` 回落到 **0.20.2**。
- [x] `flutter analyze` ⇒ 0 issue。
- [x] 全量测试（见下）。

## 过程教训

**评审给的理由要自己复核，别照抄**：两轮交叉验证都说「月视图已自绘且**带 golden**，
换库要重录基线」。我实测本仓只有一个 golden 测试且**不覆盖日历** —— 那条理由不成立。
结论本身（删依赖）仍然对，但支撑它的必须是成立的证据：
「换库只替掉骨架、自定义内容仍要粘连」+「它是 `intl` 覆盖的唯一成因」。
**引用了一条不成立的证据，等于没证明。**

## 最终门禁

| 门 | 读数 |
| --- | --- |
| `flutter pub get` | `Changed 3 dependencies!`，`table_calendar` + `simple_gesture_detector` 移出 |
| `pubspec.lock` 的 `intl` | `0.20.2`（无覆盖、无 0.20.3） |
| `flutter analyze` | `No issues found!` |
| 全量（exclude golden/performance） | `+2095 ~26`，**0 失败**（与删前同读数 ⇒ 无回归） |
| `flutter test --tags golden` | `+9 All tests passed!`（基线未受影响） |
| `dart format --set-exit-if-changed lib test` | `rc=0` |

# 130 台账

## T1 仓储

- `habit_smart_list_preference_repository.dart`（新文件）：
  `HABIT_SMART_LIST/global` 偏好行（view_preference 出箱通道，零迁移）；
  默认关，损坏 JSON 降级。
- `providers.dart`：`habitSmartListPreferenceRepositoryProvider` /
  `habitSmartListVisibilityProvider`（autoDispose 流）/
  `habitSmartListEntriesProvider`（按月聚合 + 打卡周期判定——今天属周期
  未打卡的习惯也在列）。

## T2 习惯页入口

- `habit_smart_list_visibility.dart`（新文件）：
  `HabitSmartListVisibilityAction`（习惯页右上角，key
  `habit-smart-list-entry`，toggle 语义 + 可见回执）。
- `habit_page.dart`：app bar 挂入口。

## T3 智能清单习惯段

- `tasks_by_list_page.dart`：`showSmartListHabits` ctor 参数（默认 true，
  直泵测试可关）；`_SmartListHabitSection`（智能清单 list 模式尾部，
  key `smart-list-habit-section`，习惯行 + 打卡按钮，打卡走既有
  check-in 通道并 invalidate 段数据，失败可见提示）。

## T4 用例（test/features/habit/habit_smart_list_test.dart，5 条）

- 仓储 3：默认关 + 往返 / 损坏 JSON 降级 / 同步入箱。
- widget 1：入口存在 + 切换落库两向。
- 隔离 1：面⑤偏好与面③日历开关互不影响（交叉验证的归属收紧）。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +5 |
| 全量 | 待回填 |

# 125 台账

## T1 仓储与 API

- `lib/core/api/todo_api.dart`：`CalendarInfoApi`（holidays/lunarDate）+
  `CalendarHoliday`/`CalendarLunarDate` 模型；挂进 `TodoRestApi.calendarInfo`。
- `lib/state/repositories/calendar_info_preference_repository.dart`：
  `CALENDAR_INFO/global` 偏好行（view_preference 出箱通道，零迁移）。
- `lib/state/providers.dart`：`calendarInfoPreferenceRepositoryProvider`、
  `calendarInfoFlagsProvider`（autoDispose 流）、`calendarHolidaysProvider`
  （按年）、`calendarLunarMonthProvider`（按月，逐天打 lunar-date）。

## T2 设置页

- `settings_route.dart`「日期与时间」组两个开关
  （key `todo-settings-show-lunar` / `todo-settings-show-holidays`）；
  SwitchListTile 用 `Material(type: transparency)` 包裹（同 _Tile 先例，
  否则全页触发 ListTile background 框架断言）。

## T3 月视图消费

- `calendar_view.dart`：日格农历行（节气优先）+ 休/班角标；
  数据按锚点月/年 autoDispose 缓存，失败按无数据渲染。

## T4 用例（test/features/settings/calendar_info_settings_test.dart，5 条）

- 仓储 3：默认双关 + 双键独立保存 / 损坏 JSON 安全降级 / 同步入箱不落半条。
- widget 2：两行存在；真仓储直写（与回调同写入）。

## 探针（测试基础设施坑，均按仓内先例修正）

- SwitchListTile 未包 Material transparency ⇒ 全页 ListTile background
  框架断言（_Tile 同款包裹已补）。
- 测试收尾未在测试体内卸载 ProviderScope ⇒ drift 零时长定时器炸
  「Timer is still pending」卡 10 分钟（settings_week_start 的
  `_settleUnmount` 先例已应用）。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +5 |
| 全量 | `+1987 ~26 -1`（基线 `+1982 ~26 -1` + 本切片 5；唯一红 #569 存量） |

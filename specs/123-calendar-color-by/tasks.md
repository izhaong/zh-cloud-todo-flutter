# 123 台账

## T1 仓储

- `lib/state/repositories/task_view_action_repository.dart`：
  `saveCalendarDisplay` 加 `colorBy`（三档白名单归一化 priority）+
  `TaskWorkspacePreference.calendarColorBy` 解码。

## T2 视图

- `lib/features/task/views/calendar_view.dart`：
  `CalendarDisplayFlags` record → `CalendarDisplaySettings` 类；
  抽屉加「颜色」节（RadioGroup 三档，key `calendar-color-by-<档>`），
  内容可滚动（颜色轴进抽屉后总高超一屏，-60px 溢出是 22 条存量一起红的根因）；
  月视图任务块走 `timelineTaskColor`（specs/121 复用，无色回退优先级轴），
  解析闭包由 `listsStreamProvider`/`tagsStreamProvider`/`taskTagIndexProvider`
  闭包出来；「显示设置」入口常显（旧 filterCompleted 门随颜色轴取消）。

## T3 用例（test/features/task/calendar_color_by_test.dart，3 条）

- 抽屉三档可选且选「按清单」后 `calendarColorBy='list'` 落库。
- 跨会话回读（RadioGroup 当前档 = tag）。
- 非法档仓储归一化 priority。

## T4 存量更新

- `calendar_display_settings_test` 「宿主自行决定已完成显隐」一条按新口径
  改判：specs/123 后「显示设置」含颜色轴、任何上下文都有可见效果 ⇒ 入口
  常显；宿主决定显隐的契约（日历不叠加过滤）保留钉住。
- `calendar_year_heatmap_test` / `calendar_year_day_to_week_test` 的
  `_ThrowingRepository.saveCalendarDisplay` 签名加 `colorBy` 形参。

## T5 探针

- PA 仓储归一化删除（colorBy 原样落 JSON）⇒ 1 红（AC-3）。
- PB 轴色上块：CalendarView 的轴状态由偏好驱动、直泵无注入通道 ⇒
  纯函数 `timelineTaskColor` 用例 + 页面级偏好管线共同覆盖，登记为口径
  而非缺探针。

## 最终门禁（TZ=Asia/Shanghai）

| 门 | 读数 |
| --- | --- |
| flutter analyze | No issues found! |
| dart format（改动文件） | 0 changed |
| 新用例 | +3（PA 探针红后还原） |
| 全量 | `+1982 ~26 -1`（基线 `+1968 ~26 -1` + 本切片 3 + 存量计数差；唯一红 #569 存量） |

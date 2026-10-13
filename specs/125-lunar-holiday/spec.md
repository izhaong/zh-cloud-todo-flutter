# 125 · 「显示农历 / 显示节假日调休」开关与月视图消费（矩阵 #31 面 ①）

## 背景

嘀嗒《02-功能指南/02-日历/06-日历显示设置.md》:5-21：

> 在「设置」-「日期与时间」里开启「显示农历」和「显示节假日调休」即可。

BE 端点早已有（`GET /todo/calendar/holidays?year&region`、
`GET /todo/calendar/lunar-date?date`，`AppTodoCalendarController`），
FL 一直未消费——矩阵 #31 面 ①。

## 设计（复用优先）

- `CalendarInfoApi`（holidays/lunarDate）挂进 `TodoRestApi`，模式照抄
  `RecommendationApi`。
- 双布尔位偏好复用 `todo_view_preferences`（`CALENDAR_INFO/global`）+
  view_preference 出箱通道（同 `WEEK_START` 落法），零迁移。
- 月视图日格：农历行（节气优先展示）+ 休/班角标；数据 autoDispose 按月/年
  缓存，失败按无数据渲染，不影响日历主体。

## 目标（FR）

- FR-1 「设置 → 日期与时间」出现「显示农历」「显示节假日调休」两个开关，
  双键独立保存与回读；保存走出箱通道（跨端同步）。
- FR-2 月视图在开关开启时渲染农历行与休/班角标；关闭时不渲染、不请求。
- FR-3 损坏偏好 JSON 安全降级为双关；拉取失败不阻塞日历。

## 验收（AC）

- AC-1 仓储默认双关；save 后回读一致、双键独立。
- AC-2 损坏 JSON 降级默认档。
- AC-3 save 同步入箱且不落半条。
- AC-4 设置页两行可见（key `todo-settings-show-lunar` /
  `todo-settings-show-holidays`）。
- AC-5 门禁：analyze 0 issue、全量不回归。

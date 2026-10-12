# 规格：专注统计「最佳专注时间」区块与按天年度热力图（FL #576，矩阵 #41）

## 判据源（嘀嗒原文，zh-cloud-docs 镜像）

`todo/99_参考资料/dida365-help-center/02-功能指南/04-番茄专注/04-专注数据统计.md`：
- `:26` 标题行「# 最佳专注时间」，`:27` 原句「按月统计你的最佳专注时间区域。」
- `:31` 标题行「# 年度热力图」，`:32` 原句「总览你一年的专注情况，色块深浅代表每天专注时间的长短。」

## 契约前提（服务端已合并）

zh-cloud-service PR !356 合并 develop `a06f24635c1a`（其 Issue #355、specs/038）：`GET /app-api/todo/pomodoro/stats` 多给两键——`hourlyTrend`（长度恒 24 的 `{hour, minutes}`）、`dailyMinutesTrend`（`{date: yyyy-MM-dd, count}`，**仅 period=year 非空**）；`trend`/`minutesTrend` 的 `yyyy-MM` 形状不变。

## 需求与裁定

1. **DTO**：`PomodoroStatsDto` 加 `hourlyTrend`（`PomodoroHourlyStatsDto`）与 `yearlyDailyMinutes`，两个新字段都给 `const []` 默认值（不给 `required`，否则既有 20+ 处构造与 golden 用例的命名参数表全要改，噪声盖过本次改动）。缺键、值不是数组 ⇒ 一律空列表，不抛、不猜。
2. **「最佳专注时间」区块**（`_FocusHourlyChart`）：0-23 一排柱，柱高按 `minutes / max` 插值，**0 分钟的小时也出一格**（否则形状随数据变）；峰值小时（`minutes == max` 且 > 0）用 `tertiary` 标出并在下方文案点名（`pomodoro-stats-hourly-summary`）。原「高效时段」那一格 `bestHour` 保留在指标卡里不动。
   区域 = 并列峰值小时集合，本端裁定（嘀嗒配图是一段时间带，但没有可抄的分档定义）；连续区间合并留作后续。
3. **年度热力图**（`_FocusYearHeatmap`）：`dataPeriod == 'year'` **且** `yearlyDailyMinutes` 非空 ⇒ 渲染按月分组的日格（横向滚动、月标签 `yyyy-MM`、深浅按 `count / max` 插值）；否则保持今天的行为（非 year 出「专注日历」，year 无按天数据时两块都不出）。
   形态取 `calendar_view.dart` 的 `_MonthHeatmap` 那种"按数值分档"的路线，**不抄**习惯侧 `habit_year_stats.dart` 的二值盘——`:32` 说的是"深浅代表长短"。
4. 读屏：两块各一个 `Semantics(container: true, label: …)` 汇总节点，内部柱与格子 `ExcludeSemantics`/`Tooltip` 兜住。
   ⚠️ `container: true` 是必需的：不加时该 `Semantics` 会并进最近的语义节点而被丢掉，`bySemanticsLabel` 恒 0——本轮就是这么被自己的用例抓出来的。

## 诚实登记

- 「最佳专注时间」在老服务端（无 `hourlyTrend`）整块不出现，年度盘同理 ⇒ 客户端不假装有数据。
- 写本用例时发现既有 `_FocusTrendChart` 的日柱标签在三位数（如单日 110 分钟）会溢出 4px（`Column` 宽 34 换行），与本单两面无关 ⇒ 另立 FL #577 跟，本 PR 不顺手改（它一动就是统计页像素，牵扯 golden）。本单用例的数值因此刻意用两位数。
- 年度盘的"月分组 + 一格一天"是本端形态裁定（嘀嗒配图是一整张 12 月网格），未做"按周对齐"的行列布局。

## 测试与探针

- `test/core/pomodoro_stats_dto_test.dart` 3 例：两键缺席 ⇒ 空列表；带键 ⇒ 按形状解析；键在但形状不对（给 Map/字符串）⇒ 仍空列表不抛。
- `test/pomodoro_page_contract_test.dart` 追加 3 例：有 `hourlyTrend` ⇒ 标题 + 峰值点名文案 + 0 分钟那格仍在 + 语义汇总；无两键 ⇒ 两块都不出现（同一条里先正对照「专注节奏/专注日历」还在）；year + 按天数据 ⇒ 出「年度热力图」、两格 day key、月份标、语义，且「专注日历」不同时出现。
- 变异探针：⑬把 `_FocusHourlyChart` 的渲染条件改成恒真 ⇒ 第二条负向红；⑭把 year 分支退回只 `if (dataPeriod != 'year')` ⇒ 第三条红；⑮把 `container: true` 摘掉 ⇒ 两条语义断言红。

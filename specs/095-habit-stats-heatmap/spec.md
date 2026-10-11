# 095 习惯「打卡数据」卡片 + 年度热力统计页（FL #377）

## 判据源

嘀嗒《02-功能指南/05-习惯打卡/03-习惯数据统计.md》：
- `:6`「我们提供了「月度打卡表」和「打卡数据」，你可以随时查看自己的打卡情况」
  ——详情页要有「打卡数据」数据块（「月度打卡表」已由 specs/043 落地）。
- `:10`「在单个习惯页面中向上滑动就能够看到这个习惯整体的打卡数据」
  ——移动端形态：详情页滚动区内的数据卡片。
- `:24`「在打卡数据中点击「更多」，还能够进入到该习惯的年度热力统计页」
  ——卡片右上「更多」→ 年度热力统计页。

## 契约

- `HabitStatsCard`（habit_year_stats.dart，key `habit-stats-card`）挂在
  详情页 body 滚动区副标题卡之后：
  - 数据源 `habitYearStatsProvider`（family by habitId，`stats(habitId, period: 'YEAR')`），
    窗口钉 YEAR——服务端 #303 的日历规则（本年 1 月 1 号起），标签「本年」与之对齐；
  - 只展示服务端已给且窗口内可复算的三项：totalCheckIns / continuousDays /
    longestContinuous。不造「完成率」——服务端 !283 已把写死的 0.85 摘成 null
    （zh-cloud-service #281）；
  - 加载中给占位（非错误态），失败给 AppRefreshFailedHint（key
    `habit-stats-retry`，带重试）；`_seen` 缓存保留最近一次成功数据——
    FutureProvider 错误态拿不到 valueOrNull，与 specs/045 同形。
- `HabitYearHeatmapPage`（key `habit-year-heatmap-page`，标题「年度热力统计」）：
  - 复用同一 provider（卡片已在飞的 YEAR 请求不重复拉，`yearCalls == 1` 钉死）；
  - 格子逐日渲染服务端 `dailyCounts`，第一天按周一为首列对齐
    （`(order.first.weekday - 1) % 7`，与仓内 timeline/calendar 视图同一口径）；
    首列空格不带语义（避免念出假日期）；横向滚轴展开 13px 格子，不缩字号；
  - **外层必须有一根纵向滚轴 + `AlwaysScrollableScrollPhysics`**：
    RefreshIndicator 只认纵向 ScrollNotification，且整年格子高约百来 px 小于
    视口时默认 Clamping 物理会拒绝拖动——缺任一，下拉刷新永远不触发（真机
    同样中招，不只是测试问题）；
  - 刷新失败：`_seen` 保留整年格子 + 底部 AppRefreshFailedHint（key
    `habit-year-retry`）；onRefresh 内部 catch（异常抛进 RefreshIndicator
    会成未处理错误），失败态交给提示呈现；
  - 每格 `Semantics(label: 'M月d日 打卡N次')`——0 次日只有颜色差异，
    读屏必须把 0 也念出来（不能只靠颜色）。

## 测试台账

test/features/habit/habit_year_stats_test.dart，7 条：
1. 详情页出「打卡数据」卡：YEAR 只拉一次、三项数字与「本年」标签逐一断言
2. 「更多」入口在卡片上且只有一处；详情菜单仍只有「月度打卡表」不重复
3. 热力页格子数 == 服务端窗口天数，首格 01-01、末格 07-15，无重复 YEAR 请求
4. 读屏：热力格念「M月d日 打卡N次」，0 次也念（不能只靠颜色）
5. 热力页下拉刷新失败：保留已加载数据并给可见提示（yearCalls==2 钉死
   「下拉真的触发了第二次请求」，否则后面全在空转；drag 300px ≥
   RefreshIndicator 25% 视口阈值）
6. 打卡数据卡片加载失败：无数字、失败提示可见，重试仍失败不崩
7. 320px + 1.3 倍字体：详情页（含打卡数据）与热力页都排得下

既有测试适配（非回归）：
- habit_month_grid_test.dart 的 `_FakeHabitRepository.stats`：竞态队列/闸门
  只对 MONTH 档成立，YEAR（本单卡片）直接回空不掺进 statsCalls 计数——
  该 fake 的闸门按调用序号索引，不隔离档位会把 YEAR 读进第 2/3 次回包。

## 变异探针

- 变异：`_cell` 语义标签摘掉打卡次数（`打卡${count}次` → 仅日期）。
  结果：红 1 条——用例 4（读屏打卡次数断言），全落在该钉上；其余 6 条
  走非语义路径变异下仍绿，符合预期。用 `cp` 备份还原（不用
  `git checkout --`，防误伤未提交改动），cmp 校验字节一致。

## 门禁

- `dart format`：3 个改动文件折行调整，0 遗留
- `flutter analyze`：No issues found
- 全量 `flutter test`：+1611 ~26，All tests passed
- selfscan：specs/095-habit-stats-heatmap 失项 0

# specs/096-habit-week-stats 习惯统计页「周视图」

- Issue: zh-cloud-todo-flutter #542（矩阵 #46 面④「回顾习惯打卡情况」）
- 分支: feat/542-habit-week-stats（base FL develop `c51dfb170e3`）
- 原文依据: 嘀嗒帮助中心《05-习惯打卡/03-习惯数据统计》
  - :28/:29 「点击习惯页面中的统计图标，就能够查看到所有习惯的打卡情况」
  - :33/:34 「周、月视图」——周视图本单落地；整月视图按 2026-09-23 范围裁定属商业化，不做
  - :43/:44 「记录回顾」时间轴依赖打卡日志（矩阵 #45 ④，未落地）不在本单

## 契约

- 入口：习惯列表页 AppBar 图标（key `habit-stats-entry`，读屏标签「打卡统计」），点击进入统计页（key `habit-week-stats-page`）。
- 周视图：每个习惯一行（key `habit-week-row-<id>`）× 7 列（本周一..周日）；列起点取服务端 `stats(period: 'WEEK')` 的 `dailyCounts` 最早一天，不依赖本地时钟。
- 未来档：服务端 `dailyCounts` 只覆盖到今天 ⇒ 今天之后的列照常画出但语义为「还没到」，不是 0 次打卡。
- 读屏：有打卡格「M月d日 打卡N次」、零打卡格「M月d日 没有打卡」、未来格「M月d日 还没到」；次数文本用 `ExcludeSemantics` 包裹，避免并入节点标签。
- 失败隔离：单个习惯统计失败不拖垮整页（`failedIds` 收集），已加载行照常显示 + 可见提示与重试（key `habit-week-retry`）。
- 小屏兜底：行内横向滚动，320px + 1.3 倍字体不溢出。

## 测试

`test/features/habit/habit_week_stats_test.dart` 7 条（复算：`grep -c 'testWidgets(' test/features/habit/habit_week_stats_test.dart` ⇒ 7）。
2026-10-11 全绿；全量门禁 1618 通过 / 26 跳过。

1. 列表页「打卡统计」入口：图标唯一且带读屏标签，点进统计页
2. 周视图：每个习惯一行 7 格，表头周一..周日，格子次数来自服务端
3. 窗口满 7 列：今天之后的格子是「还没到」，不是 0 次打卡
4. 读屏：有打卡 / 零打卡 / 还没到三种格子各自念得出（按行作用域断言）
5. 一个习惯统计失败：其余行保留 + 可见提示 + 重试入口
6. 全部习惯统计失败：空页给失败提示，重试仍失败不崩
7. 320px + 1.3 倍字体：统计页排得下（行内横向滚动兜底）

## 探针与门禁（2026-10-11 实测）

- 语义变异探针：摘掉 `ExcludeSemantics`（还原「次数并入节点标签」旧缺陷）⇒ 用例 4 红（0 命中），`cp` 还原后 `cmp -s` 字节一致。
- 门禁：`flutter analyze` No issues（含修掉 `unnecessary_brace_in_string_interps`）；`flutter test` 全量 `All tests passed!`（+1618 ~26）。
- 台账自检：`tool/check_spec_selfscan.py specs/096-habit-week-stats/spec.md` 失项 0。

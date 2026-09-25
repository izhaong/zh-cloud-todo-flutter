# 规格：设置「日期与时间」-「星期开始于」（Issue #349）

## 来源与判定依据（嘀嗒帮助中心原文，逐字引用）

镜像 `zh-cloud-docs/todo/99_参考资料/dida365-help-center/`，基准 `origin/develop`（!70 已合并）。

| 锚点 | 原文 | 说明 |
| --- | --- | --- |
| `01-欢迎/03-常见问题.md:125` | `:::::::::spoiler 如何设置一周开始于？` | 标题行 |
| `01-欢迎/03-常见问题.md:134`（tab `[mobile]`） | 「点击「设置」-「日期与时间」-「星期开始于」，你可以选择“周日”、“周一”、或”周六“任意一天为一周的开始。」 | 原句行；引号是嘀嗒原文本身的错配（`“…”` 与 `”…”` 混用），照抄不修 |
| `01-欢迎/03-常见问题.md:143`（tab `[macOS]`）<br>`01-欢迎/03-常见问题.md:159`（tab `[Windows]`） | 「点击「头像」-「设置」-「日期与时间」-「每周开始于」，你可以选择…」 | 桌面端这一项叫「**每周**开始于」，移动端叫「星期开始于」。本仓是移动端多端 App，**采用移动端措辞「星期开始于」**；差异如实登记 |
| `02-功能指南/02-日历/08-常见问题.md:145` | `:::::::::spoiler 如何修改日历一周开始？` | 标题行 |
| `02-功能指南/02-日历/08-常见问题.md:149`（tab `[mobile]`） | 「在「设置」-「日期与时间」里修改「星期开始于」即可。」 | 原句行 —— 与上一行合起来证明：**这一项的可见作用面就是日历** |

三条可抄的硬事实：① 入口在「设置」-「日期与时间」（本仓设置页当前只有 账号/任务/主题/关于 四个分组，无「日期与时间」）；② 档位是 **周日 / 周一 / 周六** 三档，不是任意 7 档，也不是「周日/周一」两档；③ 效果落在「日历一周开始」。

> ⚠️ 本行不是《06-日历显示设置》的内容。矩阵 #31 已明确记着「初稿曾用猜出来的 `隐藏周末|firstDayOfWeek|周起始` 作证据 —— 那几个开关嘀嗒页面上根本没有」，那条判定**至今成立**：`星期开始于` 不在日历「显示设置」弹层里，而在「设置-日期与时间」。本轮不推翻 #31 的措辞，只在 #31 的缺口列里把这一项补上（它的缺口列本来就收了同为「设置-日期与时间」的农历、节假日调休）。

## 现状（基准 `origin/develop@9032005`，`git grep` 逐行读取）

一周起点在 **8 处**被写成「周一」。判据是两条可复跑的命令，实测计数不是估的：

```
$ git grep -nE "Duration\(days: [a-zA-Z]+\.weekday - 1\)" origin/develop -- lib   # 6 命中
$ git grep -nE "weekday - 1" origin/develop -- lib | grep -v "Duration(days:"    # 1 命中
```

= **6 处**同型 `subtract(Duration(days: x.weekday - 1))` + **1 处**把 `weekday - 1` 直接当填充天数 + **1 处**整行 `const` 表头（它不是算式，但同样是"周一"这个决定）：

| 文件:行 | 现状 | 形态 | 作用面 |
| --- | --- | --- | --- |
| `lib/features/task/views/calendar_view.dart:732` | `anchor.subtract(Duration(days: anchor.weekday - 1))` | 同型 | 周视图取哪 7 天 |
| `lib/features/task/views/timeline_view.dart:242-246` | `todayStart.subtract(Duration(days: todayStart.weekday - 1))` | 同型（跨 3 行） | 「本周 / 下周」分桶边界 |
| `lib/features/task/views/timeline_view.dart:377` | `day.subtract(Duration(days: day.weekday - 1))` | 同型 | 周档窗口标签 `M/d–M/d` |
| `lib/features/task/views/timeline_view.dart:682` | `today.subtract(Duration(days: today.weekday - 1))` | 同型 | 周档时间轴取值范围 |
| `lib/features/task/views/timeline_view.dart:916` | `today.subtract(Duration(days: today.weekday - 1))` | 同型 | 周档 7 个全天槽 |
| `lib/features/task/views/timeline_view.dart:1280` | `weekStart ?? todayStart.subtract(Duration(days: todayStart.weekday - 1))` | 同型（兜底支） | 分桶函数的默认周界 |
| `lib/features/task/views/calendar_view.dart:333` | `final leadingBlanks = firstOfMonth.weekday - 1;` | 非 subtract | 月视图网格起点 |
| `lib/features/task/views/calendar_view.dart:487-493` | `const [_DayHeader('一'), … _DayHeader('日')]` | `const` 行 | 月视图表头顺序（整行是 `const`，无参数可注入） |

设置侧：`git grep -n "日期与时间" origin/develop -- lib` **0 命中**（同形态正控 `git grep -c "_Section(title:" origin/develop -- lib/features/settings/settings_route.dart` = 4：账号/任务/主题/关于 ⇒ grep 确实在扫，词也确实没有）。

## 功能需求

- **FR-1 三档且只有三档**：档位是「周日」「周一」「周六」，文案逐字取嘀嗒。不接受「周二…周五」，不自造第四档。
- **FR-2 默认 = 周一**：`WeekStart.defaultFirstDay == DateTime.monday`。默认值必须等于 develop 的既有行为，否则 9 张黄金基线会因首屏网格变化而重录（本轮明确不重录基线）。
- **FR-3 纯函数可测**：`WeekStart.startOf(DateTime day, {int firstDay})` 返回该日所在周的起始日（当日 0 点）；`WeekStart.columnOrder({int firstDay})` 返回 7 个 ISO 星期序号的排列。二者不依赖 Riverpod / Drift / 上下文。
- **FR-4 偏好持久化并跨端**：`WeekStartPreferenceRepository` 复用 `todoViewPreferences` 表（`sourceType='WEEK_START'`、`sourceKey='global'`），走 `SyncEntities.viewPreference` outbox，**不升 `schemaVersion`**、不加列。`_decode` 必须同时读本地 `save` 写的 `{weekStart}` 与 sync pull 保留的服务端实体包装（嵌套 `valueJson` 字符串）—— 这是 specs/035 实测过的第二设备静默退回默认值的坑。
- **FR-5 日历两个模式都跟着走**：月视图表头顺序、月视图网格起点、周视图取的 7 天，必须来自同一个 `firstDay`（表头与网格错位是最容易被漏掉的一半）。
- **FR-6 时间线跟着走**：「本周 / 下周」分桶与周档窗口（标签、取值范围、全天槽）用同一个 `firstDay`。
- **FR-7 读不到偏好时的取值规则**（第 74 轮 `AsyncValue` 的教训）：已有旧值 → 用旧值；报错且无值 → 用 FR-2 默认；**首值未到达 → 也用 FR-2 默认**。日历与时间线是主视图，不允许为了「不闪一下」而整块空白。
- **FR-8 改档位后即时生效**：保存成功后当前可见的日历/时间线立刻按新周首重排，不必退出重进。
- **FR-9 保存失败可见**：`save` 抛错时给可见提示，且不改变当前生效的档位（不许先乐观改状态再失败回滚）。

## 明确不做（并写清为什么）

- **习惯「本周完成」不随档位变**：`lib/features/habit/habit_page.dart:51` 的数值来自 `s['weeklyDone']`，由 `habitStatsProvider`（`lib/state/efficiency_providers.dart:78`）向服务端 `/app-api/todo/habit/stats` 取值 ⇒ 周界在**服务端**算。按「先改契约再动前端」，需要 service 侧新增周首参数才可能对齐，本轮不做，也不假称已对齐。
- **不做「任意一天」**：嘀嗒自己也只给 3 档。
- **不做农历 / 节假日调休 / 辅助时区**：同属「设置-日期与时间」，是矩阵 #31 剩下的缺口，各自需要 Service 侧区间端点（`LunarUtil` 现只有单日查询），另轮处理。
- **不动日历「显示设置」弹层**（specs/025）：这一项不属于它，见上方 ⚠️。

## 取舍

1. **为什么默认周一而不是跟随 `Localizations`/系统区域**：默认值一旦不是周一，首屏网格就与 develop 不同 ⇒ 9 张黄金基线全部要重录（属须请示项）。且嘀嗒的档位是显式三选一、没有「跟随系统」这一档，引入即自创。
2. **为什么作用面含时间线**：嘀嗒只写了「日历一周开始」，但时间线的「本周 / 下周」桶与周档窗口是同一个「自然周」概念，只做日历会让两处对「本周」的理解不一致。这一步是**超出嘀嗒字面**的，如实记在这里。
3. **为什么冷启动可能重排一次**：偏好是异步流。选周日的首屏会先按周一画一帧。反面方案（等首值再画 = 日历空白；同步读缓存 = 本仓无此约定，所有偏好仓储都是 `await`）代价更大。写进 FR-7 而不是当成 bug。
4. **为什么「日期与时间」分组插在「任务」之后**：嘀嗒未给分组顺序。放在任务类之后、外观类（主题）之前，与「新任务默认值」「日历订阅」同属行为设置，读屏滚动顺序不破坏既有四项。

## 四件套（新增界面 = 设置页新分组 + 「星期开始于」档位弹层）

- ① **320px + 1.3 倍字号**在设置路由自己的 context 上实测（分组标题、行标题+副标题、弹层三档标题与勾选标记都不溢出）。
- ② **独立读屏语义**：档位行要有可断言的 Key 与语义（当前档位通过勾选标记 + `Semantics` 表达，不靠颜色）。
- ③ **失败保留已加载数据**：`save` 抛错时弹层已选值不落到界面，日历/时间线仍按原档位显示。
- ④ **过期响应不覆盖新响应**：连续改档位时以最后一次点中值为准；写入的是"点中的那个字面值"而非"当前值取反"。

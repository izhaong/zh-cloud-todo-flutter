# 045 · 刷新失败不得丢掉已加载的数据（Issue #375 批次 1）

## 判据源

本面**不是**嘀嗒的功能面，因此**没有** `99_参考资料/dida365-help-center/` 对应页，
对照矩阵也**没有**对应行（⇒ 本轮不回写矩阵、不翻任何状态）。需求来自两条既有约束：

1. 每轮固定动作里的四件套之一：**「失败保留已加载数据」**（`AGENTS.md` / 用户口径）。
2. FL Issue **#375**：把全仓 `.when(...)` 的读法按「失败时会不会丢掉已加载的 value」逐处清点，
   16 处里 A 组 11 处（运行期有 `invalidate`/`refresh`）+ B 组 5 处（`StreamProvider`，失败以流错误到达）。
   批次 1 = 本 spec 覆盖的三处：`habit_page` 统计格、`habit_page` 列表、`countdown_page` 列表。

## 前提（实测，非假设）

Riverpod `2.6.1`（`pubspec.lock` 锁 `flutter_riverpod 2.6.1`）在**有监听者在场**时，
`FutureProvider.autoDispose` 被 `invalidate` 后重取失败，页面拿到的形状是：

```
kind=AsyncError  isLoading=false  hasValue=true  valueOrNull≠null  hasError=true
```

⇒ **框架没丢数据，丢数据的是 `.when` 的分支判别**：它按 `error:` 分支渲染，不再回看 `value`。
所以修法不需要局部缓存、不需要 `keepPreviousData`，只需要把读法换成「先取 `valueOrNull`」。
边界要说准：`habit_page_test.dart` 第 1 条用例钉的是**渲染结果**（失败后行与统计卡仍在、提示可见），不是上面这行字段值本身；字段值这一形状另有两条支撑——`pubspec.lock` 锁定的 riverpod 2.6.1 源码（`AsyncError.copyWithPrevious` 把 `hasValue` 带过去），以及反向探针 PA 把实现退回 develop 后该用例必红。第 1 轮复核也按这个口径判过（不算夸大）。

## 需求

- **FR-001 有值就先渲染值**：三处受影响的 `.when` 改判据为 `valueOrNull`；
  只要上一次的值还在，页面就继续渲染它（列表行、统计三格），不得整页换成失败态。
- **FR-002 失败要看得见**：保留旧值的同时追加一条**可见**提示（复用 `AppRefreshFailedHint`），
  带「重试」出口。提示用 `Semantics(liveRegion: true)` 包，使读屏在其余界面未变时仍会播报
  （与已合并的 `recommendation_panel.dart` 同一口径）。
- **FR-003 首值就没读到才走失败态**：`valueOrNull == null` 且 `hasError` 时才是整页失败。
  习惯页在此形态补一个「重试」按钮（原来只有一行错误文本、无出口）；
  倒数日页保持 develop 的错误文本形态不变（本轮不顺手改它的失败态）。
- **FR-004 统计格的既有行为不扩大**：首屏就失败时 develop 是「不渲染统计卡」（`SizedBox.shrink`），
  本轮**保留**这一形态——只补「刷新失败但卡片已有值」这一新可见的失败面，不擅自新增首屏失败 UI。
- **FR-005 日历订阅页不属本形**（复核前的自我纠正）：`calSubscriptionProvider`
  （`lib/features/calendar_sub/calendar_subscription_page.dart:19-29`）把异常 `catch` 成
  `CalSubState(items: const [], error: …)`，失败是以 **data** 的形状到达的 ⇒
  `.when(error:)` 那一条对拉取失败根本不可达，`valueOrNull` 改法对它无效。
  这一处连同其余 A 组改判为**批次 2/3**，本轮不碰。

## 验收

| 判据 | 载体 |
| --- | --- |
| FR-001/FR-002 习惯页列表与统计格各一条 | `test/features/habit/habit_page_test.dart` · 「刷新失败保留已加载的列表与统计，并给可见提示」 |
| FR-003 首值失败态 + 重试恢复 | 同上 · 「首值就没读到才走失败态，「重试」成功后恢复列表」 |
| FR-002 读屏语义 | 同上 · 「提示条有独立读屏语义（liveRegion）」 |
| 四件套·窄屏大字号 | 同上 · 「320px + 1.3 倍字号…」；`test/features/countdown/countdown_keep_loaded_test.dart` 同名一条 |
| 四件套·过期响应不覆盖新响应 | 习惯页 · 「两次连发刷新：过期的旧响应不得覆盖新响应」（实测框架自身已丢弃被顶替的 future，见 plan 取舍 3） |
| FR-001/FR-002 倒数日页 | `countdown_keep_loaded_test.dart` 三条 |
| FR-005 反例不落代码 | 本轮 `calendar_subscription_page.dart` 不在触达文件清单内（`git diff --name-only` 可验） |

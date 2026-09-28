# 045 · 计划与取舍

## 触达文件（批次 1）

| 文件 | 改动 |
| --- | --- |
| `lib/core/widgets/app_widgets.dart` | 新增 `AppRefreshFailedHint`（`Semantics(liveRegion)` + 文案 + 可选「重试」，`Key('app-refresh-failed-hint')`） |
| `lib/features/habit/habit_page.dart` | 统计格与列表两处 `.when` 换成 `valueOrNull` 判据；抽出 `_HabitList`、`_ListLoadFailed`（首值失败的整页态，带「重试」） |
| `lib/features/countdown/countdown_page.dart` | 列表 `.when` 换成 `valueOrNull` 判据；列表体抽成 `_countdownList`（两条渲染路径共用） |
| `test/features/habit/habit_page_test.dart` | 新增 5 条（四件套全覆盖 + 前提钉桩） |
| `test/features/countdown/countdown_keep_loaded_test.dart` | 新增 3 条（保留数据 / 读屏 / 窄屏大字号） |

矩阵与 `zh-cloud-docs` 本轮**不改**（见 spec「判据源」）。

## 取舍

1. **改读法，不改 provider**。曾考虑三种：
   (a) 页面局部缓存上一次的 value；(b) provider 里 catch 后返回旧值；
   (c) 只把 `.when` 换成 `valueOrNull` 优先。选 (c)：实测框架已把值留在 `AsyncError` 里
   （spec「前提」），(a)(b) 都是把同一份状态抄第二遍，多一个会漂移的真相源。
   仓内既有先例同形：`lib/features/shell/sidebar.dart:60-63`、
   `lib/features/habit/habit_detail_page.dart:28` 都用 `valueOrNull`。
2. **提示条做成共享 widget 而不是三处复制**。三处语义完全一致（保留旧值 + 一条可见说明 + 重试出口），
   且必须带同一个 `liveRegion` 判据；抄三份的后果是下一次改文案只会改到一处。
   放在 `app_widgets.dart` 与 `AppCard`/`AppEmptyState` 同族，命名沿用 `App` 前缀。
3. **「过期响应不覆盖新响应」这一件量下来是框架负责的**：`myHabitsProvider` 连发两次 `invalidate`、
   让第二次后发先回、再放出第一次的迟到结果，界面上不出现旧数据
   （用例「两次连发刷新：过期的旧响应不得覆盖新响应」，反向探针下同样成立）。
   ⇒ 本轮**不**在页面加 requestId，`task_summary_sheet.dart` 那种手写 requestId 只属于它自己的
   setState 局部加载路径，不能当成通用要求抄过来。
4. **统计格首屏失败仍然不渲染**（FR-004）：develop 用 `error: (_, _) => SizedBox.shrink()`，
   改成整卡失败会把一条汇总条变成错误面板，超出「保留已加载数据」的范围；
   本轮只让**新出现的**失败面（有旧值时刷新失败）可见。
5. **`calendar_subscription_page` 移出批次 1**（FR-005）：它的 provider 把异常吞成
   `CalSubState(items: const [], error: …)`，失败以 data 到达 ⇒ `valueOrNull` 改法无效，
   真修法是「provider 不再 catch，让 `.when(error:)` 可达」或「保留上一次 items」，
   两种都会牵动该页既有的 `s.error` 分支与「重试」UI，属另一切片。
6. **其余站点分批，计数以 Issue #375 的清点表为准**（本处不重抄，避免两处数字漂移）：
   批次 1 覆盖 `myHabits`/`habitStats`/`countdowns` 三个 provider 的读点；
   批次 2 = 任务详情三面（`taskAssign`/`listMembers`/`taskComments`）+ 日历订阅页（见取舍 5 的不同机制）；
   批次 3 = `quadrantRules`/`achievementWall`/`inbox` + B 组 `StreamProvider` 族（按 #353 口径处理流错误）。

## 不做

- 不引入 `AsyncNotifier` 重写这些 provider（超出范围）。
- 不改各页首屏 loading 形态。
- 不动 `pubspec.lock`、不加依赖。

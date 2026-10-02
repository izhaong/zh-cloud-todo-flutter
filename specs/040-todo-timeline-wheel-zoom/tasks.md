# 任务清单：时间线视图的 Ctrl/⌘ + 滚轮缩放

规格：[spec.md](./spec.md) · 计划：[plan.md](./plan.md) · Issue：[#298](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/issues/298) · PR：[!299](https://gitea.zh04.com/izhaong/zh-cloud-todo-flutter/pulls/299)
分支：`feat/todo-timeline-wheel-zoom`（base `origin/develop@a1d7733`）

## 已证实

- [x] **T1 红测先行**：生产代码不含滚轮入口时该测试文件即红（`Expected: [1.25] / Actual: []`）。缺口判据：`git grep -nE 'PointerSignal|MouseScrollEvent|PointerScrollEvent' origin/develop -- lib` 无输出（复核员复验：同一命令 rc=1，正向对照 `git grep -cE '.' origin/develop -- lib | wc -l` = 109 证明文件被扫到）。
- [x] **T2 最小实现**（FR-001、FR-002）：纯函数 `timelineWheelZoomTarget`（`lib/`lib/features/task/views/timeline_view.dart`1`）+ `_TimelineWindowState.build` 外层 `Listener(onPointerSignal:)`（`:468-476`）。**步长 `0.25` 是引用同一份常量**（`_TimelineZoomToolbar._step`，`:502`）；**`0.75/1.5` 这对边界在文件里是字面量散布在以下位置：`:87` 归一化、`:614`/`:616` 与 `:632`/`:634` 两颗按钮的禁用判断与 clamp、本函数 `:753`）—— 该 widget 里原本就没有 min/max 常量，本轮没有新增第四处之外的常量，也没有顺手把三处收成一个常量（属未要求的重构，见「仍缺」最后一条）。
- [x] **T3 方向纠正**：第一版 `zoom + dy.sign * step`（向下放大）与 `:614`/`:632` 按钮的 +/- 语义、同页《调整界面字号》（`:109`/`:111`）相反，已改为 `zoom - dy.sign * step`（向上放大）。嘀嗒 `:107` 原文确实未写方向（复核员确认「doc 未指定方向」为真），所以这是一次**基于既有语义的取舍**，不是照抄，理由写在 plan.md。
- [x] **T4 负向不回归**（FR-003）：裸滚轮、Shift + 滚轮仍只滚动画布（用例 3、4 的 `calls.isEmpty`）。
- [x] **T5 只读宿主不抛异常**（FR-004）：`onZoomChanged == null` ⇒ `takeException()` 为 null（用例 7）。
- [x] **T6 正向对照 + 受控宿主**：
  - 前提断言 `maxScrollExtent > 0`，再用 Shift（`pointerAxisModifiers` 翻轴）证明画布真被滚轮推动，之后才允许「Ctrl+滚轮后 `pixels` 不动」这句断言存在。
  - **第一轮复核指出**：宿主把 `zoom` 写成常量 ⇒ 画布宽度永不随缩放变化 ⇒ 那句 `pixels` 断言结构性无法失败。已加受控宿主 `_WheelZoomHost`（测试文件末尾）把 `onZoomChanged` 的新值 `setState` 回 `TimelineView.zoom`，让缩放真正生效、该断言可失败。改后该文件仍 `00:00 +7: All tests passed!`。
- [x] **T7 反向探针（最终 7 用例状态，输出已入 `/tmp/r35_gates.log`，时间戳 2026-09-24 15:36:13）**：摘掉 `Listener` 包装、保留纯函数以维持编译后：

  ```
  00:00 +0: Ctrl + 滚轮向上放大时间轴（嘀嗒 :107）
  Expected: [1.25]
    Actual: []
  Expected: [0.75]
    Actual: []
  Expected: [1.25]
    Actual: []
  00:01 +4 -3: Some tests failed.
  ```

  ⇒ 红的是 3 条修饰键用例（1、2、4），绿的是 4 条负向（3、5、6、7）。`cp` 还原后 `cmp` 无差异。⚠️ 第一版把 `RESTORE: byte-identical` 只打到终端、没进日志（第二轮复核 NIT(b) 抓到），现以「探针还原复验」行补进 `/tmp/r35_gates.log`，复核员另用 `cmp` 独立验过 `.bak` 与 HEAD blob `8c733fe…` 相同。
  ⚠️ 更正记录：第一轮复核前我写的是 `+3 -3` 与「三条负向仍绿」——那是**只有 6 条用例时**的探针结果；补上第 7 条（下限边界）后没有立刻重跑探针，等于把旧数字当新证据。现已按最终状态重测为 `+4 -3`。
- [x] **T8 六道门禁**：最终状态一次跑完，日志 `/tmp/r35_gates2.log`；第一轮那次的日志留在 `/tmp/r35_gates.log`）：

  | 门禁 | 结果原文 |
  | ---- | -------- |
  | `git diff --check`（`a1d7733`..工作树） | `exit=0` |
  | `dart format --output=none --set-exit-if-changed` 本轮两文件 | `Formatted 2 files (0 changed)`，`exit=0` |
  | `flutter analyze` | `No issues found!` |
  | `flutter test --tags golden` | `+9: All tests passed!`（基线 9 张未变，无需重录） |
  | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:13 +716 ~26: All tests passed!`（本分支 base 709 + 本轮 7 = 716） |
  | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` |

- [x] **T9 不随 PR 提交 `pubspec.lock`**：本机新 SDK 把它整树重解析改脏；`git diff --name-only a1d7733 HEAD` 只含 `timeline_view.dart`、新测试文件与 `specs/040-*`（复核员独立验过，含「matrix/docs 无命中」）。

## 复核记录

`claude` CLI 本机不可用（`unrecognized_model`），按既定口径改用**本会话只读子代理**审本轮 FR（自己跑 `git show`/`grep`/`flutter test` 复验并回 `VERDICT`）。

- **第一轮：`VERDICT: FAIL`**（1 BLOCKER + 6 NIT）。
  - BLOCKER（T7/plan 的探针记录失实）→ **采纳**：按最终状态重跑探针、把真实输出 `+4 -3` 写进日志与本文件，并把那句无法失败的 `pixels` 断言改成可失败（T6 受控宿主）。复核员预测的 `+4 -3` 与实测完全一致。
  - NIT「上下限是字面量的又一处拷贝，与『未新写一套常量』措辞不符」（复核员另数出 `:616`/`:634`，合计五处）→ **采纳（改措辞，不改代码）**：见 T2 的精确表述；把三处收成 `_minZoom`/`_maxZoom` 属未要求的重构，留给「仍缺」。
  - NIT「`calendar_view.dart:52` 不是 `hour|小时` 命中」→ **采纳**：spec.md 改为「`hour` 在 `calendar_view.dart` 只有 `:871` 一个命中；`:52` 是另一行与小时无关的注释」。
  - NIT「Flutter SDK 的 scrollable.dart（不在本仓 git 索引内，行号随 SDK 版本漂） 实为 932-951」→ **采纳**，plan.md 已改。
  - NIT「plan.md 提『先注册者赢』在此处无关注入」→ **采纳**，改写为「本例没有任何注册者，关键是外层 Listener 能看到事件且不消费」。
  - NIT「gate6 日志标题没写两个 --dart-define」→ **采纳**：第二轮日志标题写全；命令本身一直是带 dart-define 跑的。
  - NIT「日志头 `HEAD=a1d7733` 应为 base」→ **采纳**，第二轮日志已写 `base=`。
  - 未采纳 1 条：NIT「建议注入 `Offset(120,-120)` 证明信号未被吞」——**不采纳理由**：那会把断言方向改成"缩放与滚动可以叠加"，而本 FR 的验收语义是 Ctrl+滚轮只缩放；「未 resolve」这一事实已在 plan.md 与「仍缺」里显式承认为边界，不需要用一条新用例去固定一个我们并不打算保证的行为。
- **第二轮：`VERDICT: PASS`**。复核员独立推导「摘掉 Listener 时该文件必为 3 红 4 绿」与我重跑得到的 `+4 -3` 一致，并验过测试文件不直接调用生产 helper、`pubspec.lock` 不在任何提交里、门禁表与日志里的读数逐字相符、`base 709 + 7 = 716` 有 一次性留痕（今已不可取） 的 `+709 ~26` 背书。采纳的 NIT 是三条：边界字面量数「三处」实为五处、RESTORE 未入日志、测试注释里的 `scrollable.dart` 行号区间。余下为表述性提醒，已在「仍缺」相应条目里体现（`:899-913` 的 day 档小时槽、clamp 路径在当前用例里是潜在的）。

## 仍缺 / 边界（不得当已完成）

- **矩阵 #87 不因本 PR 进「已证」**：嘀嗒《:107》那一面是**日历日/周视图的小时轴**；本端 `calendar_view.dart:168` 的 `CalendarMode` 无 `day` 档，且 `hour` 在该文件唯一命中是 `:871` 的排序键（`:52` 另有注释「锚点归零到当天 00:00」，与小时刻度无关）⇒ 那个面的前置能力仍缺。本 PR 只结掉「缩放能力已有、快捷入口未做」这半条。（复核员补充：真正的小时刻度其实在**时间线视图** `timeline_view.dart:899-911` 的 `_slots()`（day 档逐小时铺整点槽），所以 spec 里"横向日期轴"一句低估了它——这条已按实改写。）
- **滚轮信号未被 resolve**：`Listener.onPointerSignal` 只观察；当前 Ctrl+滚轮不滚动，是因为该画布只有横向 `SingleChildScrollView`（`:816`）且 `_pointerSignalEventDelta`（Flutter SDK 的 scrollable.dart（不在本仓 git 索引内，行号随 SDK 版本漂））对鼠标取 `scrollDelta.dx`。若将来嵌入纵向滚动区，需改用 `PointerSignalResolver`，否则缩放与滚动叠加。
- **上下限常量收拢未做**：`0.75/1.5` 仍是散落的字面量：`:87`、`:614`/`:616`、`:632`/`:634`、`:753`）。收成 `_minZoom`/`_maxZoom` 是 5 个点的小重构，本轮按「不顺手重构」跳过，留作后续。
- 未验证桌面/移动原生端：门禁只有 Web release 与 Dart 侧测试，本机无 Android SDK、iOS 卡 SPM，不替代原生编译与真机手感。
- `tasks.md`/`plan.md` 里的行号基准是本分支工作树；合并后若 develop 行位漂移须复校。

## 下一轮入口

- 嘀嗒《:101》「快速切换日/周视图中的日期」（Shift + 滚轮，`:103`）与本行的日历小时轴缺口同源；若要做，得先决定是否为日历新增 day 档 + 小时刻度（会改可见布局 ⇒ 先申请重录 9 张黄金图基线）。

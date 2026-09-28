# 064 任务清单（矩阵 #30 日程视图）

Gitea：zh-cloud-todo-flutter Issue #401 · 分支 `feat/401-calendar-agenda-timeline` · 基准 `origin/develop@9032005`

## 一、红测先行（实现之前，树上只有测试文件）

日志 `/tmp/g401/red.log`，命令 `flutter test test/features/task/calendar_agenda_timeline_test.dart`（跑在 `_AgendaView` 还是单日过滤的那棵树上）：

```
00:01 +0 -5: Some tests failed.
```

五条各自红在哪一条断言（不是红在崩溃，判据面都真的执行到了）：

| 用例 | 红在 |
| --- | --- |
| 跨日时间轴：过去与未来在同一条轴上 | `Expected: true / Actual: <false>`（滚 12 次仍找不到「下下周的排期评审」⇒ 轴上根本没有未来的日子） |
| 按日期线性分组、当天标「今天」 | `Found 0 widgets with text "6月15日"`（旧实现压根不画日头） |
| 月视图点日期格仍把那一天滚进视口 | `Found 0 widgets with text "6月26日"` |
| 日头带分组读屏语义 | `Expected: true / Actual: <false>` |
| 320px + 1.3 倍字号不溢出 | `takeException` 为 null（这条在旧树也过，红在后续的滚到断言）⇒ 它当反向对照用：证明旧树"没溢出"不代表有轴 |

引文逐字复算（基准 zh-cloud-docs `origin/develop@d816e0a`）：把 `:5`、`:7`、`:14` 三句原文喂进
`git show "origin/develop:todo/99_参考资料/dida365-help-center/02-功能指南/02-日历/05-日程视图：以时间串联任务.md"` 的逐行包含判断，
读数 `OK :[5]`、`OK :[7]`、`OK :[14]`、`总行数 16`。

## 二、实现（`lib/features/task/views/calendar_view.dart`）

`git diff --stat` ⇒ `162 insertions(+), 38 deletions(-)`。改了四件事：

- `_AgendaView` 由 `StatelessWidget` 变成 `StatefulWidget`（要持 `ScrollController`），单日过滤换成 `_timelineRows()`：按 `resolveTaskDate` 分组、日期升序、日内沿用原有的 `_compareByTime`。
- 统一行高 88（`itemExtent`）⇒ 锚点偏移等于 `锚点行号 × 88`，用 `ScrollController(initialScrollOffset:)` 给到初帧；锚点变化时走 `addPostFrameCallback` 里的 `jumpTo`，不在 build 期间改滚动位置。
- 日头 `Semantics(header: true)`，key `calendar-agenda-day-<y>-<m>-<d>`；当天在日头后加「今天」。
- 任务行 key `calendar-agenda-task-<id>`，标题与副标题各 `maxLines: 1` + 省略号（配合 320px 那条用例）。
- 文件头注释第 21 行那句「日程模式：单日任务按时间顺序展示」按 `:5` 改正；空态文案「当日暂无日程 / 切换日期…」换成跨日轴上成立的说法。

## 三、六道门禁（首轮 head `9ac7d59`，合并 develop 之前）

§九 是本轮最终字节 `3543c25` 的重跑读数。这张表留着是因为它记录了基线比对的做法，
但**别拿它当合并后 head 的门禁证据** —— head 已前进，门禁必须重跑。

| 门禁 | 读数 | 日志 |
| --- | --- | --- |
| 1 `git diff --check` | `rc=0`、无输出 | 本轮终端输出 |
| 2 `dart format --output=none --set-exit-if-changed` 只带本轮两个文件 | `Formatted 2 files (0 changed)`、`rc=0` | `/tmp/g401/` |
| 3 `flutter analyze` | `No issues found!`、`rc=0` | `/tmp/g401/g5-full.log` 同批 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`；`ls test/goldens/todo_workspace/*.png` ⇒ `9`；`git status --short test/goldens` ⇒ 空 ⇒ 一张基线都没重录 | `/tmp/g401/g4-golden.log` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:42 +903 ~26: All tests passed!` | `/tmp/g401/g5-full.log` |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | `/tmp/g401/g6-build.log` |

门禁 5 的基线比对（不比对就没法说"没引入新失败"）：在 `origin/develop@9032005` 的独立工作树上跑同一条命令 ⇒
`02:42 +898 ~26: All tests passed!`（日志 `/tmp/g401/baseline-full.log`）。`903 - 898 = 5`，正好等于本轮新增用例数
（`grep -c "testWidgets(" test/features/task/calendar_agenda_timeline_test.dart` ⇒ `5`），跳过数 26 前后一致。

`pubspec.lock` 不在改动清单里（`git status --short` 只有本轮那两个文件加台账目录）。

## 四、原地格式化的安全性

`dart format` 在这轮确实改了文件（第一遍 `--set-exit-if-changed` 报 `2 changed`）。为排除"顺手改无关代码"：
先把 `origin/develop` 那份 `calendar_view.dart` 落到 `/tmp/g401/base_calendar_view.dart` 跑同一条命令 ⇒ `0 changed`，
证明基线那版本来就符合格式；格式化后与格式化前副本（`/tmp/g401/pre-format-lib.dart`）对比，
`diff` 只落在本轮新增的 `956`-`1021` 这些行上。

## 五、被推翻的初判

写第一版测试时打算用 `Scrollable.ensureVisible` + 每组一个 `GlobalKey` 把锚点滚进视口。
量过之后否掉：懒加载下不保证那一组已经 build，`ensureVisible` 就可能在"没建出来的节点"上落空，
而每条日头都挂 `GlobalKey` 在几百天的数据上是额外负担。换成统一行高后偏移是可算的，不需要等布局。
这条不是原文层面的取舍，是实现手法，记在这里以免下轮又走一遍。

## 六、四件套的适用性判定

`spec.md` §五 已写：320px/1.3× 与读屏语义两条有用例；「失败保留已加载数据」「过期响应不覆盖新响应」两条
在本档不适用 —— 这一档是 `List<TodoTask>` 的纯派生渲染，它自己不发请求，异步与过期都在上层 `repo.watchAll()` 那条既有链路里。

## 七、只读复核（待回填）

被审 SHA：本轮提交后填。派单提示词、日志路径与 `VERDICT` 行号在此登记；FAIL 的每条要回源复验，驳回的写书面理由。

## 八、矩阵回写（含死锁解除条件）

zh-cloud-docs 的行 #30 目前在 `docs/parity-replay-combined`（PR !102）上，本仓不动它：
「已实现待合并 + PR 号」这段文本走 docs 侧留言排队（该分支正被并行会话书写，见记忆「子模块工作区被并行会话共用」）。
合并进 develop 之前，矩阵状态不得翻转成「有」。

⚠️ 只留言排队有个死锁：若 `docs/parity-replay-combined` 迟迟不合，`develop` 上那行会永久停在「部分」，
而实现早已落地 ⇒ 第 1 轮复核把这条判成阻塞项（`/tmp/g401/verdict-402-r1.stream.jsonl` ⑨ 段）。
处置：在 docs 仓立了 **zh-cloud-docs Issue #112**，里面带（a）可机器判的触发命令
`git -C zh-cloud-todo-flutter merge-base --is-ancestor <MERGE_SHA> origin/develop`、
（b）现状行逐字（按行首 `| 30 ` 定位，不按行号）、（c）翻转后的整行文本（合并 SHA 留空由执行人回填）、
（d）改完要跑的校验器 `python3 scripts/todo/check_parity_matrix.py`。
⇒ 本仓合并 !402 之后，矩阵翻转不再依赖 !102 的合并时机，只需在 #112 上执行一次。

## 九、合并 develop 的收尾与最终字节门禁（head `3543c25`）

### 撞在哪、为什么

`origin/develop@cdba014` 已含 !364（列表视图「显示时间轴」），它把日程档定义成「选中日单日过滤」，并用
`test/features/task/calendar_list_timeline_test.dart:415`「议程档顺序 = tasksOnDayByTime 的顺序」把这件事钉成防副本判据。
本轮把日程档改成跨日时间轴 ⇒ 同一条断言的**范围那一半**正是矩阵 #30 要推翻的现状。

### 三笔提交（别把这段当成干净合并）

| 提交 | 内容 |
| --- | --- |
| `aa2d8ba` | `git merge origin/develop`。**这一笔里混进了冲突标记与一份重复的 `_compareByTime`** —— 清理脚本的断言索引用错（冲突块是 7 行不是 8 行），断言先抛但同一条命令链已经 `git add` + `git commit`。记在这里是因为它说明「有合并提交的 PR 必须重跑全部门禁」不是套话 |
| `d528bf2` | 清标记：删掉 `_AgendaViewFormat`（develop 已把 `_compareByTime`/`_formatClock`/`_displayTime`/`_compareWallClock` 提成库级函数，留两份就是两个事实源），三处限定名调用改成库级调用，`_formatTime` 提为库级函数（逐字搬，未改逻辑） |
| `7034396` + `3543c25` | 防副本断言改按跨日口径 + `dart format` 折行 |

### 防副本判据没有因为改口径而变弱

`titles` 现在等于「10/1 与 10/2 各自的 `tasksOnDayByTime` 按日升序拼接」。反向探针（日志
`/tmp/g402-r2-probe-sortcopy.log`）：把 `_timelineRows` 的日内排序换成自抄副本 `..sort((a, b) => a.title.compareTo(b.title))`
⇒ 这条用例红（`00:00 +0 -1`），还原后 `cmp` 与 HEAD 逐字节相同。

### 六道门禁在最终字节上的读数（head `3543c25`）

| 门禁 | 读数 | 日志 |
| --- | --- | --- |
| 1 `git diff --check`（另对合并提交跑 `git show --check`） | `rc=0`、无输出 | `/tmp/g402-r2-g1.log` |
| 2 `dart format --output=none --set-exit-if-changed` 只带本轮三个文件 | `Formatted 3 files (0 changed)`、`rc=0` | `/tmp/g402-r2-g23b.log` |
| 3 `flutter analyze` | `No issues found!` | 同上 |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`；`git status --short test/goldens` 空 ⇒ 一张没重录 | `/tmp/g402-r2-g4b.log` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `03:01 +1028 ~26: All tests passed!` | `/tmp/g402-r2-g5b.log` |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | `/tmp/g402-r2-g6b.log` |

合并前置的试算这一步不需要 `merge-tree`：`git merge-base --is-ancestor origin/develop HEAD` 为真
（`origin/develop = cdba014` 已是本分支祖先）⇒ 合并必然干净，冲突已在 `aa2d8ba`/`d528bf2` 里手工解掉。
`pubspec.lock` 跑完六道门禁后仍无改动（`git status --short` 为空）。

门禁 5 的基线这次**重新量过**（head 变了，§三 那个 898 已过期）：在 `origin/develop@cdba014` 的一次性
detached 工作树上跑同一条命令 ⇒ `03:03 +1023 ~26: All tests passed!`（日志 `/tmp/g402-r2-base.log`）。
`1028 - 1023 = 5` = 本轮新增用例数（`grep -c "testWidgets(" test/features/task/calendar_agenda_timeline_test.dart` ⇒ `5`），
跳过数 26 前后一致。

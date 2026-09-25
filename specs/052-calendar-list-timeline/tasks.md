# 任务清单：日历「列表视图 - 显示时间轴」（specs/052 / FL Issue #361 / 矩阵 #29）

分支 `feat/361-calendar-list-timeline`，基线 `origin/develop@9032005`。
提交链：`899dcf2`（实现 + 用例）→ `d1ee8ba`（第 76/77 轮文档与矩阵回写）→
`324f23d`（**第 77 轮只读复核 F1/F2/F3 的修复**）。PR !364。

## 完成情况

- [x] `spec.md` 来源表：《04-列表视图：按天查看任务.md》`:7/:9/:16/:18/:23` 逐字引用；
      《08-常见问题.md》按 tab 分类（`:11` mobile 长按 / `:19` desktop 点击 / `:32` 全天任务栏拖拽 /
      `:79`+`:83` 隐藏时段 / `:41`+`:172-175` 桌面缩放）⇒ 四条进「明确不做」并各给理由
- [x] 红测（步骤见下「红测读数」——**这一条是编译红，不是行为红**，如实标注）
- [x] `tasksOnDayByTime` 共享取数 + `_DayTimeline` + 工具条「显示时间轴」图标（FR-1/FR-2/FR-4/FR-8）
- [x] 列表档锚点按天移动（FR-7，仅开启时）+ 生产调用点注入 `now`（FR-6）
- [x] 四件套：320×568 + 1.3 倍在日历列表档自己的 context 上量（`MaterialApp(builder:)` 传档位 +
      用例内自检继承值）、独立读屏语义（label 全等 + `isButton` + `isSelected`）、
      开→关→开行集合不变；④「过期响应不覆盖新响应」**不适用**（本面零异步新增，理由见 `spec.md` 五-4）
- [x] 六道门禁跑在**已提交终态 `899dcf2`** 的字节上，日志 `/tmp/r77/gates.log`
- [x] 九条反向探针 PN–PV，全部红在该咬的用例名上，`/tmp/r77/probes-final.log`
- [ ] 只读复核：第 1 轮 **`VERDICT: FAIL`**（三条全在本轮举证侧，已逐条回源复验并采纳，见下节）；
      第 2 轮派单基准 `origin/develop..feat/361-calendar-list-timeline`（head 取本轮**终态**）。
      **第 2 轮 `VERDICT` 没回来 ⇒ 这一格仍是欠的**，不得当作已通过，也不得据此谈合并
- [ ] 矩阵 #29 回写（含本轮查出的"按天"错判纠正）——未合并前状态一律不翻，只写「已实现待合并」
- [ ] 第 78 轮入口：FL #362「列表视图下拉展开日历全景」（`spec.md` 已登记，不混进本单）

## 红测读数

```
$ flutter test test/features/task/calendar_list_timeline_test.dart
00:00 +0 -1: Some tests failed.
  Error: Method not found: 'tasksOnDayByTime'.        ×7
```

⚠️ **计数停在 `+0`、状态是 `loading …[E]` ⇒ 这是编译红**（新章节日的第一版测试引用了还不存在的 API）。
它只证明"接口没实现"，不证明"行为错"。真正钉行为的是绿测之后那九条反向探针。

绿测（同一条命令，实现接线后）：

```
$ flutter test test/features/task/calendar_list_timeline_test.dart
00:02 +17: All tests passed!      # 首版（head 899dcf2）
00:01 +18: All tests passed!      # 复核 F3 修完后（head 324f23d，多一条尺子自检）
```
九条探针的**对照组**在 `324f23d` 上重跑也全是 `+18` ⇒ 新增那一条不靠改既有用例取绿。

## 六道门禁（基准：已提交 `899dcf2`；日志 `/tmp/r77/gates.log`）

| # | 命令 | 读数 |
| --- | --- | --- |
| 1 | `git diff --check origin/develop HEAD` / `git diff --check HEAD` | rc=0 / rc=0（另：每次提交前 `git diff --cached --check` 均 rc=0） |
| 2 | `dart format --output=none --set-exit-if-changed <本轮 3 个显式文件>` | `Formatted 3 files (0 changed)` rc=0 |
| 3 | `flutter analyze` | `No issues found! (ran in 2.6s)` rc=0 |
| 4 | `flutter test --tags golden` | `00:06 +9: All tests passed!` rc=0；`git status --porcelain -- test` 为空 ⇒ **9 张基线一张都没重录** |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:38 +915 ~26: All tests passed!` rc=0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` rc=0 |

计数对账：门 5 末行的新增数减掉本轮新增用例数，落回 develop 的全量基线 **898**。
基线 898 有**实跑日志**，不靠减法反推：

- `/tmp/r68/baseline_develop.log:1152` = `02:53 +898 ~26: All tests passed!`（在 `origin/develop` 副本上直接跑出来的末行）；
- `specs/045-sort-direction/tasks.md:120` 另在 `9032005`（本轮同一基线）上复跑出 `+898`。

⚠️ **第 77 轮复核 F1 驳回了我原来的写法**：原文说这个 898"与第 72 轮复核独立推导出的基线相互印证（那轮是 `905 − 7`）"。
回源复验：第 72 轮的 `specs/043-habit-month-grid/tasks.md:197-198` 自己写着「全量 develop 基线**始终没有实跑日志**，
只对账到分支内 903 → 905」；而 `905 − 7` 在第 72 轮的 md 和两份复核 transcript 里都不存在
（`grep -o "905-7"` 的 4 处命中经逐条看上下文，全是 UUID 片段）。⇒ 那句"相互印证"是虚指，已删。
**教训**：两条互不相干的分支各自减回同一个数不是证据，是算术自洽；能当证据的只有"在 develop 副本上直接跑出末行"那种日志。
`~26` 与既有各轮一致（未新增 skip）。`pubspec.lock` 未进提交：`git log --stat origin/develop..HEAD -- pubspec.lock` 为空。

## 反向探针（九条，`/tmp/r77/probes-final.log`，末行「异常计数 = 0」）

每条都：起跑前 `lib/` 干净 → 对照组先绿 → 打补丁 → 跑测试 → copy 回 + `cmp -s` 逐字节一致。

| 编号 | 摘掉的是什么 | 读数 | 红在哪 |
| --- | --- | --- | --- |
| PN | `tasksOnDayByTime` 不按天过滤（时间轴退化成"全部任务"） | `+3 -15` | 判据面 5/15 命中预期名；**参考面 `m11_b3` `+19` 绿** |
| PO | 列表档恒渲染旧 `_ListView`（开关完全不接线） | `+10 -8` | 8/8 命中 |
| PP | 「全天」栏整段消失，全天任务被塞进时点段 | `+16 -2` | 2/2 命中 |
| PQ | 入口图标在所有档都出现（把全局开关塞进来） | `+17 -1` | 1/1 命中「列表档才有这个图标」 |
| PR | 生产调用点不再把注入的 `now` 喂给 `CalendarView` | `+17 -1` | 1/1 命中「锚定注入的今天」 |
| PS | 列表档关闭时也照议程档移动锚点（FR-7 的"仅开启时"条件被摘） | `+17 -1` | 1/1 命中「不动锚点」那条；参考面 `+19` 绿 |
| PT | 工具条标题恒写「全部任务」（开启后仍给假口径） | `+13 -5` | 5/5 命中 |
| PU | 图标选中态写死 `false`（读屏念不出当前是时间轴） | `+17 -1` | 1/1 命中「选中态随开关翻转」 |
| PV | 议程档自己抄一份取数并丢排序（长出第二个事实源） | `+17 -1` / 既有套件 `+18 -1` | 两条各 1/1 命中 |

重跑在 `324f23d`（F3 修完）后**唯一实质变化**：PN 的 15 条红里现在含「四件套 1」那条
（原来那条红是撞在只查 `calendar-timeline-allday` 的旧守卫上，现在查的是「选中日每一条的行键都在树里」，按天过滤被摘掉时确实少行）；PP 则从 3 条红降到 2 条（全天任务被挪进时点段后，10 条行键仍然齐 ⇒ 守卫放过，红只剩两条真按形态断言的用例）。这两处都如实记，不解释成「判据变强/变弱」。日志 `/tmp/r77/probes-r2.log`。

**两条如实记录、不算覆盖的结论**（参考面绿，不是探针失败）：

- PN 打补丁后 **`test/m11_b3_calendar_test.dart` 19 条全绿** ⇒ 既有日历套件**不覆盖"按天过滤"**这个机制
  （它有一条 `CalendarView 列表模式按日期排序`，但那条测的正是"跨日清单"，摘掉按天过滤对它零作用）。
  这条恰好反过来印证本轮查出的矩阵事实：**develop 的列表档从来就不是按天的**（`spec.md` 现状表 ⚠️）。
- PS 打补丁后同一套件也全绿 ⇒ "列表档锚点动不动"在既有套件里不可见，只有本轮新写的
  「关闭态拨『下一个』不动锚点：随后开启仍从原选中日开始」钉得住。
  这条断言的设计原因：关闭态下锚点移动与否**对用户不可观察**（内容不看锚点），
  所以只能借"关闭时拨一格、再开启，看到的仍是原选中日"把它变成可观察的。

成对 grep 判据（同一日志末尾）：

```
ABSENT  议程档内联按天过滤（date.year == anchor.year）      命中 0（期望 0）
PRESENT tasksOnDayByTime 消费者                             命中 3（定义 + 议程档 + 时间轴）
PRESENT 正对照：按天过滤仍在（收在 _isOnDay 里）             命中 1
PRESENT 正对照：resolveTaskDate 全仓仍在用                  命中 10（证明 grep 本身有牙）
```

## 第 77 轮只读复核（第 1 轮）：`VERDICT: FAIL` 与逐条处置

复核是只读的（未 commit/push/未改被审文件）。三条 **全部采纳**，没有驳回项——
三条都经我自己回源复验成立，且都在**举证侧**（行为侧复核判「与嘀嗒口径相符，不超出也不缺失」）。

| 编号 | 复核的主张 | 我复验到的事实（可复现命令） | 处置 |
| --- | --- | --- | --- |
| **F1** | 计数对账里"与第 72 轮独立推导出的基线 898 相互印证（那轮是 `905 − 7`）"是虚指 | `git show fix/348-month-grid-future-day:specs/043-habit-month-grid/tasks.md \| sed -n '197,198p'` ⇒ 第 72 轮自己写着「全量 develop 基线始终没有实跑日志」；`grep -o "905-7"` 在两份 transcript 里的 4 处命中全是 UUID 片段（逐条看过上下文） | 换成 `/tmp/r68/baseline_develop.log:1152` 的实跑末行 + `specs/045` 在 `9032005` 上的复跑；"相互印证"那句删除（见上节） |
| **F2** | 「`:32` 独立证明『全天任务栏』是这条时间轴的一部分」被 `:32` 自己反驳 | `git -c core.quotePath=false show origin/develop:"…/02-日历/08-常见问题.md" \| sed -n '27,37p'` ⇒ `:32` 在《如何在日历视图里安排任务》mobile tab，句意是"从**全天任务栏**拖到**时间轴上**"，两个区域；且它属《日历视图》不属《列表视图》 | `spec.md` FR-2 那条、`calendar_view.dart` 的 `_DayTimeline` 文档注释、测试文件头三处统一改为「全天是轴**之外**的上方独立栏（全天行不画轴线）」。**行为一行没改**——代码本来就是这个形状 |
| **F3** | 溢出判据的"已先断最坏内容真在树里"说过头，且九条探针里它从没开过火 | `sed -n '449,456p'` 旧守卫只查 `calendar-timeline-allday`（ListView 第一个子节点，恒在）；`/tmp/r77/probes/PP_0_*.log:132-155` ⇒ 「四件套 1」红在守卫上而非 `_flexOverflows` 返回值；九条日志里 `hits` 无一次非空 | 两步都做：①守卫换成"选中日每一条的 `calendar-timeline-row-<id>` 都在树里"（当天铺到 10 条，含两条 20 字以上长标题）；②新增**尺子自检**用例：已知溢出 80px 必须报 1 条且像素数对得上，等宽不溢出必须沉默 ⇒ 这条判据不再可能悄悄变成死代码 |

四条**非阻塞**也一并处理了（除 N4 只能登记）：

- **N1** 「每次提交前 `git diff --cached --check` 均 rc=0」结构上不可能留日志（cached diff 是瞬态）⇒ 门 1 的两条读数已覆盖承重部分，本行不再写成"证据"。
- **N2** 参考面只跑了 2 个 `CalendarView` 套件里的 1 个 ⇒ 复核代读了 `calendar_display_settings_test.dart` 8 条（议程那条同样只有单日），结论不变；措辞改为"既有 `m11_b3` 套件"不写成"既有日历套件"。
- **N3** 三处 develop 行号偏差（`:113-116`→`114-117`、`:139-140`→`140-141`、`:108`→`96-98`）已改；引文里我自加的 `**` 强调号（嘀嗒源页字节里没有）已从四处删除；
  顺带撤掉 `:41` 这个错锚（它其实与 `:32` 逐字节相同，是 desktop 的拖拽句，缩放三句在 `:173`-`:175`）。
- **N4** 《04-列表视图》`:20` 那张图才是嘀嗒**形态**的权威，镜像里只有图片 URL、本轮没读它 ⇒ 已在 `spec.md` 登记为「余留未证」，
  明写"本面形态只由 `:18` 文字支撑"，不许下一轮把这格当成已对齐嘀嗒形态。

**运维侧采纳的一条**：`probes77.py` 的脏检查原先只看 `lib/`，本机没有 `PUB_HOSTED_URL` 时 `flutter test` 的隐式 pub get
会把 `pubspec.lock` 里 150 处镜像 URL 改写成 `pub.dev`（复核会话遇到并已复原，blob 回到 `7ef8030` = develop 那份）。
脏检查已扩成 `git status --porcelain -- lib pubspec.lock`。

## 本轮我自己造成的缺陷（逐条登记，不藏）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| 首跑 `Failed to load`，报 `The getter 'hasSize'/'size' isn't defined for the type 'RenderObject'` + `'first' isn't defined` | 我在溢出测量里把 `RenderObject` 当成 `RenderBox` 用，并对 `tester.renderObject(finder)` 的返回值再取 `.first`（它本来就返回单个） | 按编译器给出的**源文件绝对路径**读真实签名后改：子节点 `is! RenderBox` 先 cast、根节点直接用。**教训仍是记忆里那条：别猜 harness API，编译器报错会印出文件路径，一条 grep 就能确认** |
| 断言 `expect(… isSelected, isFalse)` **恒红**，失败写着 `Actual: Tristate:<Tristate.isFalse>` | 本机 Flutter 3.44.8 的 `SemanticsFlags.isSelected` 是 **`Tristate`**，不是 `bool`（`isButton` 才是 bool） | 改成 `Tristate.isFalse` / `Tristate.isTrue`（配 `import 'dart:ui' show Tristate;`）。已在测试里留注释，防止下一个人再按 bool 写 |
| 探针脚本 `py_compile` 直接 `SyntaxError` | 我在描述里用 ASCII 双引号包中文短语（`"全部任务"`），把 Python 字符串截断 | **靠"先 py_compile 再 check"这两道前置挡住**（第 76 轮那次是没人挡，四条探针一次都没跑）。这次锚点干跑 10/10 命中后才进 `all` |
| PV 首跑判"归因未证实" | 我的预期用例名只写了新文件那条，漏了既有套件里真实红掉的 `日程视图按任务固定时区显示墙钟时段` | 回源码确认它钉的正是"议程档排序"这一机制（不是撞巧红）⇒ 补进预期名，单跑 PV 转 OK。**没有为了让脚本绿而放宽判据** |
| 首版「开→关→开」用例用 `find.descendant(of: byType(ListTile))` 收集行 | 时间轴的行**不是** `ListTile`（自定义 Row），那样会静默量到空集，`orderedEquals(空)` 就恒真 | 改成按固定标题清单取"当前看得见哪些"，两种档共用同一判据，不依赖行 widget 的形状 |
| 导入 `/tmp/r77/sync_gitea_r76.py` 复用它的 API helper，结果**该脚本没有 `__main__` 守卫**，import 即把第 76 轮的同步全流程重跑一遍 | 我要的是 `call()`，随手挑了个同名脚本 import | 副作用：PR !360 与 Issue #349 各多出一条**逐字重复**的留言（id 9333 / 9336），PR !360 正文被同内容重写（无差异）。已 `DELETE` 两条重复留言并读回确认（!360 回到 2 条、#349 回到 7 条，9333/9336 均不在）。**今后只 import 带守卫的 `/tmp/r74/gitea.py`**；顺带记：跑任何"看起来是库"的脚本前，先 `tail` 一眼有没有 `__main__` 守卫 |

## 遗留与下一轮

- **只读复核第 2 轮**（第 1 轮 `VERDICT: FAIL` 已闭环，见上节）：派单基准
  `origin/develop..feat/361-calendar-list-timeline`，**必须审本轮的终态 head**（本文件最后一次改动的提交）。
  第 2 轮要它咬定的三件事，都是第 1 轮我改动的地方，别让它只看新字：
  ① F3 的新守卫是不是真的会漏（"选中日每条行键都在树里"这条判据，配 PP 从 3 红降到 2 红这个变化，
  要它判"这是判据变准还是变松"，不接受我本文件的自述）；② F2 换掉的举证口径（"全天在轴之外"）
  是否仍不超出也不缺失《04-列表视图》`:18`；③ F1 的两个 898 日志指针是否真能指到末行、
  以及"算术自洽不是证据"这句本身有没有被我另处又用回去。
- **矩阵 #29**：本轮把「显示时间轴」这一格从"缺"变成"已实现待合并"，
  同时要把 develop 主表那句 **「`_ListView`：按选中日过滤 = 确实是『按天』」改判**
  （代码里 `CalendarMode.list => _ListView(tasks: _visibleTasks, …)` 从未收到 `anchor`）。
  按"未合并不得翻转状态"，状态列仍是「部分」，改动只落在说明/缺口列。
- **FL #362**（列表视图下拉展开日历全景）另起一轮，不夹带。
  ⚠️ 它和本单**撞同一处代码**（`CalendarMode.list` 分支 + `_ListView`）：
  #362 要改的正是"列表档下拉展开全景"，而本单刚把该分支改成"开关分流"。
  ⇒ 在 !364 进 develop 之前动 #362 必然互撞，本条**阻塞在 !364 合并**上（合并需要授权）。
- **第 79 轮入口（不撞 !364 的那条）**：`/tmp/wt-fl-362` 上有一张**未提交**的第 78 轮半成品
  （清单动作表补「共享协作」入口，FL Issue #359，落地情况见该 Issue 留言）——
  它只动 `lib/features/list/`、`lib/features/task/task_detail_pane.dart`，与本单的 `calendar_view.dart` 不相干，
  所以 !364 挂着不合并也不阻塞它。剩余工作：把那 3 条过窄断言按 Issue 里记的口径收窄到 6/6 绿
  → 补 ≥3 条反向探针 → 六道门禁跑在已提交终态 → 回写 `specs/053-list-share-entry/tasks.md`
  与矩阵 #52 的说明格（未合并前只写「已实现、未进 develop」）。
- 明确不做清单里那三条（长按落点建任务、全天栏拖拽改时间、隐藏时段）各自需要新交互管线或新首选项，
  要做得各开一张 Issue。

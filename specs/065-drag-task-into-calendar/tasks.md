# 065 · 将清单中的任务拖入日历（面 ①）— 执行台账

基准：`zh-cloud-todo-flutter` `origin/develop@2d0aa127`（本轮开工时与工作树基的同一尖，
`git rev-parse --short=8 origin/develop` ⇒ `2d0aa127`）
分支：`feat/397-drag-task-into-calendar` · 工作树 `/private/tmp/wt-fl-397`
Gitea：Issue #397 · 判据源与口径见 `spec.md` §一–§二 · 落点端：FL

## 一、前置复核：#397 正文那句「等 !380 合并」已成立

Issue #397 正文「前置（四面共用）」写着本单不得排在 PR !380（并列视图）合并之前。
本轮开工时现查 `GET /repos/izhaong/zh-cloud-todo-flutter/pulls/380`
（读数存 `/tmp/r136/gates-397/pr380.json`）⇒ `merged=true`、head `8c3f020f`、base `develop`，
且并列视图的文件确在 develop 上（`git ls-tree -r --name-only origin/develop | grep -c workspace_companion` ⇒ 2）。
⇒ 前置解除，本轮可以开工。

**缺口复算**（同一条命令形状，develop 侧必须 0 行、本轮侧必须 1 行，并配一条必然命中的正对照）：

| 命令 | 读数 |
| ---- | ---- |
| `git grep -c -e Draggable origin/develop -- lib/features/task/tasks_by_list_page.dart` | rc=1、stdout 0 字节（develop 侧确实没有拖出手势） |
| `git grep -c -e CalendarView origin/develop -- lib/features/task/tasks_by_list_page.dart` | `origin/develop:lib/features/task/tasks_by_list_page.dart:1` ⇒ 正对照，同形状同选项能命中 |
| `git grep -c -e Draggable -- lib/features/task/tasks_by_list_page.dart` | `lib/features/task/tasks_by_list_page.dart:1` ⇒ 本轮字节上有了 |

⚠️ `git grep -c` 在"无命中"时**什么都不打印**（不是打印 0）⇒ "0 命中"要写成"rc=1 且 stdout 0 字节"，
并把上面那条正对照一起写进来，否则下一轮没法区分"真没有"和"命令没扫到"。

## 二、六道门禁读数（最终字节各跑一次，日志目录 `/tmp/r136/gates-397/`）

| 门禁 | 命令 | 读数 | 日志 |
| ---- | ---- | ---- | ---- |
| g1 | 提交前：`git diff --cached --check`（三个 Dart 文件 + 本轮 specs 全部 `git add` 之后跑）；复核后可复算的等价命令：`git diff origin/develop...HEAD --check` | rc=0；**日志 `g1.log` 里只有生成脚本写的 `g1_rc=0` 一行，不是原始 stdout** ⇒ 「stdout 0 字节」这半边改由下面 §七 NIT-2 那条现跑命令证明：`git diff origin/develop...HEAD --check \| wc -c` = 0 | `/tmp/r136/gates-397/g1.log` |
| g2 | `dart format --output=none --set-exit-if-changed` + 本轮显式 3 个文件 | `Formatted 3 files (0 changed)` 在 `/tmp/r136/gates-397/g2.log:1` | 同上 |
| g3 | `flutter analyze` | `No issues found!` 在 `/tmp/r136/gates-397/g3.log:66` | 同上 |
| g4 | `flutter test --tags golden` | `+9: All tests passed!` 在 `/tmp/r136/gates-397/g4.log:75` | 同上 |
| g5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `+1063 ~26: All tests passed!` 在 `/tmp/r136/gates-397/g5.log:1337`，全文 1337 行（复算 `wc -l /tmp/r136/gates-397/g5.log` ⇒ 1337；先前写的「全文 1338 行」是首跑读数，复核 NIT-1 已按现测改准） | 同上 |
| g6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` 在 `/tmp/r136/gates-397/g6.log:81` | 同上 |

**g2 差点是假绿**：第一次跑成 `dart format --output=none --set-exit-if-changed $FILES`（zsh 对 `$FILES`
**不做词切分** ⇒ 三个文件被当成一个不存在的路径），打印 `Formatted no files in 0.00 seconds` 且 rc=0。
改成把三个文件名逐字写在命令行上重跑，才得到表中那条 `Formatted 3 files (0 changed)`。

黄金基线一张没重录：`git ls-files test/goldens | grep -c '\.png$'` ⇒ **9**，
`git status --short test/goldens` ⇒ 0 行（上表 g4 的 `+9` 与之一致）。
`pubspec.lock` 没随 PR 带出去：门禁跑完后 `git status --short` 的条目里没有它
（本轮全部改动 = 2 个 Dart 文件改动 + 1 个测试文件新增 + `specs/065` 三个 markdown）。

用例对账（**在被测对象副本上直接跑出基线**，不是减法推的）：
基线在 `/tmp/r136-base`（`git worktree add --detach /tmp/r136-base origin/develop`，
即 `2d0aa127` 的纯字节）跑同一条 g5 命令 ⇒
`+1056 ~26: All tests passed!` 在 `/tmp/r136/gates-397/baseline-develop.log:1329`
（全文 1330 行）。
本分支同一命令 ⇒ `+1063 ~26`（`/tmp/r136/gates-397/g5.log:1337`）。
守恒 `1056 + 7 = 1063` 由本次生成脚本断言成立；
`~` 两边同为 26 ⇒ 本轮没动任何 skip。
本文件两个口径别混：`grep -c "^  testWidgets(" test/features/home/drag_list_task_into_calendar_test.dart`
⇒ 声明 **7** 处；`flutter test <本文件>` 统计行 `+7: All tests passed!` 在
`/tmp/r136/gates-397/green-file.log:73` ⇒ 实跑 **7** 条（本文件无循环展开，两数相同）。

## 三、红测与变异探针（`/tmp/r136/probe397b.py`，逐个摘实现后只跑本文件）

| 探针 | 摘要行 | 归因 |
| ---- | ------ | ---- |
| baseline（未摘） | `+7` | 7 条全绿 |
| A 摘掉桌面分支（ReorderableListView）拖出源 | `+5 -2` | 主路径 + 失败反馈两面失去拖出源 ⇒ 红 |
| B 摘掉普通分支（ListView.builder）拖出源 | `+7` | **全绿 = 这条分支没有用例覆盖**，见 §四 |
| C 摘掉日历接收端 `onTaskDateChanged` | `+5 -2` | 接收端回到 develop 的死状态 ⇒ 红 |
| D 摘掉 `now:` 注入 | `+2 -5` | 月视图落回真实时钟那个月，无处可放 ⇒ 红掉 5 条 |
| restored（全部还原） | `+7` | 还原后仍全绿；脚本对每处摘改都做了"字节与进入前一致"的断言 |

红测在实现之前也成立过：本文件先写完 6 条用例（当时还没有 §四 那条失败反馈用例）跑一次 ⇒
`00:03 +2 -4: Some tests failed.`，四条红因分别是"并列副栏画的是 9 月不是 7 月"与"清单行没有拖出源"。

## 四、覆盖面缺口：普通 ListView 分支的拖出源无用例（登记，不粉饰）

`_CalendarDragSource` 挂在两条列表分支上（`lib/features/task/tasks_by_list_page.dart:1765`
桌面 `ReorderableListView` 分支、`:1803` 普通 `ListView.builder` 分支，类定义在 `:2160`），
包层形状见 `:2171`（`LongPressDraggable<TodoTask>` + `delay: 300ms`，载荷与
`calendar_view.dart:618` 的 `DragTarget<TodoTask>` 对齐）。
分支选择条件在 `tasks_by_list_page.dart:330`：`_selectedListId == null`（智能清单）
或 `taskSections.isNotEmpty`（清单内有分组）时 `onTasksReordered` 置空 ⇒ 走普通分支。

**探针 B 全绿 ⇒ 普通分支这条包层当前没有任何用例量得到。** 为把它变成可证的，
本轮试过三条复现路径，全部落空（读数如实登记）：

| 想走的配置 | 实测 |
| ---------- | ---- |
| 给当前清单建分组（`TaskSectionRepository.create`） | 抛 `StateError: 清单不存在`（`task_section_repository.dart:196` 的 `_requireWritableList`）——fixture 的任务全在合成清单 `inbox`，`todo_lists` 里没有这一行 |
| 点侧栏「全部」智能清单 | `find.byType(ReorderableListView)` 确实 0 命中（分支切过去了），但清单行按 `ValueKey(task.id)` 找得到 0 个；换成拖出源自己的 key 再滚 12 次 × 300px 仍找不到主任务 ⇒ 该视图里主任务不可见，用例无从拖起 |
| 点侧栏「今天」智能清单 | 同样 `visual-task-today-primary` 0 命中 |

⇒ 本轮决定：**保留两条分支的包层**（普通分支是 `:47` 并列视图下的真实配置，
只包一条分支会在智能清单里留下功能洞），
但**不写"两侧都覆盖"的话**，也不留下只为凑数而写的用例（曾经写过一条「全部」用例，
因其判据无法成立已从本文件删掉，删改前后各跑过一次：删前 `+6 -1`、删后 `+7`）。
**待办**：下一条轮次要先把"普通分支 + 并列副栏"做成可拖的可达配置（要么给 fixture 补一行真实清单 + 分组，
要么让智能清单视图的行也带 `ValueKey(task.id)`），再补这条用例；补上之前 B 探针必须一直打印全绿。

## 五、四件套逐面（本轮改动 = 在手势层加包层，不新增界面）

| 面 | 落点与读数 |
| -- | ---------- |
| 320px + 1.3 倍字号 | 本轮没有新增路由/sheet，也没改布局常量：拖拽 feedback 复用行本身并限宽 320（`tasks_by_list_page.dart:2171` 上一行的 `SizedBox(width: 320)`），落点格与日历 chip 的既有几何不变 ⇒ g4 `+9` 与 g5 `+1063 ~26` 未动即证据 |
| 独立读屏语义 | 用例「包一层拖出源不吞掉清单行的读屏语义」：`ensureSemantics()` 下标题仍在该行内且 `bySemanticsLabel` 可命中 ⇒ 若包层被写成 `ExcludeSemantics`/`Semantics(container:true)` 这条会红 |
| 失败保留已加载数据 | 用例「写不下去时给可见反馈，本地日期保持原值」：用 `_FailingTaskViewActionRepository` 让 `moveCalendarTask` 抛错 ⇒ 断言可见反馈出现且 `dueAt` 保持 `2026-07-11 11:00`。反馈本身不新写：`calendar_view.dart:694` 已 try/catch 并在 `:703` 播 `日历改期失败，请重试`，本轮的 `home_shell.dart:870` 回调与该调用点同形状（另一处同形状先例在 `tasks_by_list_page.dart` 的日历视图分支） |
| 过期响应不覆盖新响应 | 落点写的是本地 Drift 事务（`moveCalendarTask` 内 `transaction` + outbox 入队），没有"后发先至"的回包可覆盖；`onWillAcceptWithDetails`（`calendar_view.dart:618`）用"落点日期 ≠ 当天"做拒收，同一天重复拖拽不产生第二次写入，由「拖到任务原本那一天不改日期」用例钉住 |

## 六、下轮入口

1. 先补 §四 那条待办（普通分支的可达配置 + 用例），补完必须让探针 B 从全绿变红。
2. 面 ② = Issue #398（源页 `:53`「将日历中的任务拖入清单详情区域」+ `:55`），
   现有详情区 `DragTarget` 只吃检查事项 id，需另立载荷；面 ③ = #399（`:57`/`:59`）；
   面 ④ = #400（`:61`/`:63`）。四面都吃 `:47` 的并列视图前提。
3. FL 队列里 `!402`（specs/064）仍 open（head `c613fc39`），本轮基线是 `2d0aa127`，
   合并次序与冲突面见父仓 task #145。
4. **复核 NIT-3 未消化**：用例⑥「包一层拖出源不吞掉清单行的读屏语义」用的是全树
   `find.bySemanticsLabel(RegExp(前 6 字))` + `findsWidgets`，旁侧 `Text`（日历 chip 同题文案）
   就能满足它 ⇒ 判据打不到「包层吞语义」的要害。收口做法：把 matcher 限定成
   `find.descendant(of: _row, matching: …)`，或直接对 `_row` 子树走 `SemanticsHandle` 遍历断言
   该节点没有 `ExcludeSemantics`。**这条改的是测试代码**，会解除本轮 PASS 的绑定，
   所以下一轮单独开 PR 做，做完必须让「把包层换成 `ExcludeSemantics(child: …)`」这条探针变红。
5. **复核 NIT-4 未消化**：用例⑤是**前提守卫**（钉 `:47` 并列关闭时无处可放），不是行为守卫。
   升级为行为守卫的做法（交叉验证给过、复核员同向）：在那条用例里**真做一次长按拖拽**，
   判据换成结构判据 `find.byType(DragTarget<TodoTask>)` ⇒ `findsNothing`，
   并在并列开启的用例里补同一条 finder 的 `findsWidgets` 正对照（防它恒 0）。
   同样改测试代码 ⇒ 与 NIT-3 并到下一轮。

## 七、只读复核

### 第 1 轮 ⇒ `VERDICT: PASS`（0 条 FAIL、4 条 NIT）

- 通道：`claude -p --permission-mode plan`，被审 ref = `d6fbacb`（= 当时的 PR head，`git ls-remote` 核对过），
  结论流 `/tmp/r136/review-405-r1.jsonl`（82 次工具调用，1 个 `type=result` 事件，其 `result` 文本里
  `VERDICT: PASS` 出现 1 次）。工作树在此期间未被改动。
  复算命令（**别用 `grep -c "^VERDICT:"` 去数这份 jsonl ⇒ 实测 0**，因为结论在 JSON 字符串内部，
  不在行首；本仓既有那种「末行哨兵」口径只适用于纯文本日志）：
  `python3 -c "import json,sys; print(sum((json.loads(l).get('result') or '').count('VERDICT: PASS') for l in open(sys.argv[1], errors='replace') if l.strip().startswith('{')))" /tmp/r136/review-405-r1.jsonl` ⇒ 1
- 复核员逐项独立复算并判成立的：① 面 ① 三处接线（`home_shell.dart:870` 的 `now:`/`onTaskDateChanged`、
  两条分支各包 `_CalendarDragSource`、类型/载荷/key 对齐）；② 7 条用例无「永远绿」假判据
  （`findsNothing` 都有正向镜像、`_sortOrderById` 因 fixture 的 sortOrder 互异而有鉴别力）；
  ③ §四 覆盖缺口的处置（保留两条分支包层 + 登记待办）成立，且**没有**宣称「两侧都覆盖」；
  ④ 门禁六个数字在 `/tmp/r136/gates-397/` 逐行命中，基线 `+1056 ~26` 来自独立 detached 工作树
  `/tmp/r136-base` 的实跑（不是减法推演）；⑤ 四件套三面有字节证据（含 feedback 的
  `SizedBox(width: 320)`）；⑥ spec/plan/tasks 引用的 12 处 `file:line` 锚点与源页 `:45`–`:63`
  逐字命中；⑦ 无夹带改动（6 个文件、single-parent、无 `pubspec.lock`、黄金 png 仍 9 张）。
- **逐条 NIT 的处置**：
  - NIT-1（`g5.log` 行数写错）⇒ **本轮已改**：本节 §二 g5 行按现测改成 1337。
    复算：`wc -l /tmp/r136/gates-397/g5.log` = 1337、`sed -n '1337p'` = `03:12 +1063 ~26: All tests passed!`。
  - NIT-2（g1 的原始 stdout 不可复现）⇒ **本轮已改**：§二 g1 行改列可复算命令，
    复算：`git diff origin/develop...HEAD --check` 的 rc=0 且 `… \| wc -c` = 0。
  - NIT-3（读屏用例判定力偏弱）⇒ **不本轮改**，登记 §六 第 4 条。理由：改的是断言本身，
    会让本轮 PASS 绑定的字节作废，需重跑门禁 + 补探针 + 二轮复核，收益不足以在本轮做。
  - NIT-4（用例⑤是前提守卫）⇒ **不本轮改**，登记 §六 第 5 条，与 NIT-3 同一轮收口。
    ⚠️ 交叉验证（`/tmp/r136/xcheck-405.out`）在本轮之前就把这条判为「假判据」（从不触发拖拽、
    删拖出源也绿），复核员判的是「措辞可更准」⇒ 两边方向一致（都要升级成行为守卫），
    按更强的那个说法办：不写「已验证并列关闭时无处可放」这种行为习惯，只写「前提没满足」。
- 覆盖面绑定（本轮改的是 markdown，代码树号必须不动）：
  `git diff d6fbacb..HEAD -- lib test` 输出 0 行 ⇒ `VERDICT: PASS` 仍绑定最终代码字节。

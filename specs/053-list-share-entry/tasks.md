# 任务清单：清单动作表补「共享协作」入口（specs/053 / FL Issue #359 / 矩阵 #52）

分支 `feat/359-list-share-entry`，基线 `origin/develop@9032005`，PR !365。
提交 `727b646`（实现 + 用例 + 规格）。

## 完成情况

- [x] `spec.md` 来源表：《07-共享与协作/01-如何共享清单》`:6`/`:8` 逐字引用（基准 docs `origin/develop`）
- [x] 现状取证：`showListActions` 定义 `list_actions.dart:65`（第 1 轮复核失3 把 `:63` 改成 `:65`；第 2 轮复核 F1 又抓到我修的时候把 `];` 记成 `:63` —— develop 字节上 `:62` 才是 `];`、`:63` 是空行）；唯一调用点 `sidebar.dart:626`；
      `ListMemberPage` 唯一调用点 `task_detail_pane.dart:1332`；`共享协作` 在 develop 的 `lib` **0 命中**
- [x] FR-1/FR-2 动作表补第三项 + `openListCollaboration`（`serverId` 前置校验、提示语、开成员页一份口径）
- [x] FR-2 的去重**真的做了**：任务详情面板的 `members` 分支改为调用同一函数，
      不再就地 `push` `ListMemberPage`（成对 grep 判据见下）
- [x] FR-3 未同步的可见原因，措辞两处统一成「清单尚未同步，无法打开共享协作」
- [x] FR-4 可达性边界钉住（且按**实测机制**写：`_SmartRow` 根本没有 `onLongPress`，
      是结构性拿不到，不是我们显式判了 `:6`）
- [x] 四件套：①320×568 + 1.3 在 sheet 自己的 context 上量（档位自检 + 遍历 `RenderFlex` 量越界）；
      ②读屏 label 全等 + `isButton` + `bySemanticsLabel` 成对；③失败提示出现时侧栏仍在；
      ④「过期响应不覆盖新响应」**不适用**（零异步新增，理由见 `spec.md` 五-4）
- [x] 反向探针六条 X1–X6 + 成对 grep 判据 + CX1 反例：
      首跑 `/tmp/r79/probes-all.log`（X2 有 1 条「名单外的红」靠我手写补记）⇒ 第 2 笔把判据脚本改强后
      在最终字节（`3ea931e`）上重跑 `/tmp/r79g/probes-all.log`：X1 `1/1`、X2 `5/5`、X3 `1/1`、
      X4 `1/1`、X5 `1/1`、X6 `4/4`，末两行「结论：异常计数 = 0」+「收尾工作树（lib + pubspec.lock）：干净」
      （每次重跑用**独立 LOGDIR**：`PROBE_LOGDIR=/tmp/r79g/probes`，上一轮的日志不许被覆盖；
      `/tmp/r79f/probes-all.log` 是被格式化那一笔之前的复跑，异常计数同样 0，保留不动）
- [x] 六道门禁跑在**已提交终态 `e3c9d88`** 的字节上，六项 rc 全 0，日志 `/tmp/r79/gates79.log`（下表读数由脚本从该日志现算）
- [ ] 只读复核：**第 1 轮 `VERDICT: FAIL`**（四条失项全部回源复验为真，见下节）⇒ 已修；
      **第 2 轮未回 ⇒ 这一格仍是欠的**，不得当作已通过，也不得据此谈合并
- [x] 矩阵 #52 回写：docs `4e85598`（PR !102，**未合并**）⇒ 状态不翻，措辞用「已实现、未进 develop」，
      两条形态偏差写进说明格。⚠️ 其中「第 3 步本仓无对应控件」按复核 N5 收准为「无独立入口、由常驻『邀请』按钮内联提交」
      ⇒ 这句在 docs 侧另起一笔修（见「遗留」）

## 红测 → 绿测

```
$ flutter test test/features/list/list_share_entry_test.dart
00:01 +6: All tests passed!          # 首版是 3 绿 / 3 红，见下"本轮我自己造成的缺陷"
$ flutter test test/collaboration_widget_test.dart test/features/list/list_share_entry_test.dart
00:01 +16: All tests passed!         # 与既有协作套件同跑：10 + 6 = 16
                                     # ⚠️ 这 10 条与本改动**路径不相交**（它们直接泵 ListMemberPage，
                                     #    不经过动作表）⇒ 只证「没误伤」，不证「覆盖了机制」；
                                     #    探针日志里参考面恒绿正是同一件事（复核 N10）
```

## 六道门禁（基准：已提交终态 `3fcd1c6`；日志 `/tmp/r79h/gates-r2.log`）

这张表随每轮终态推进：`e3c9d88` → `gates79.log`（第 1 轮复核前的终态）、
`3ea931e` → `/tmp/r79e/gates-r2.log`（第 1 轮修完 + 一句 `dart format`）、
**`3fcd1c6` → `/tmp/r79h/gates-r2.log`（本表，第 2 轮修完）**。
⚠️ `3fcd1c6` 这一笔**动了代码**（T5 的两条负断言），所以门禁必须重跑 —— 就是本表。
它之后如果还有填值笔，那笔只动 md ⇒ 用 `git diff --name-only 3fcd1c6..HEAD` 复验。
三次末行读数：门 5 `+904 / +904 / +904`（`gates79.log`、`r79e/gates-r2.log`、本表），
第 2 轮只加强了**已有**用例里的断言、没新增用例 ⇒ 计数本该不动（可复验：
`git diff --name-status 3ea931e..3fcd1c6 -- test` 只有一个 `M`，且
`grep -c "  testWidgets("` 前后都是 6）。
⚠️ 中途有一次门禁**没跑完就被我自己停掉**：门 2 在 `53d55d1` 上报 `Changed list_share_entry_test.dart`
rc=1（我手写换行不合 formatter），所以那一份日志不作证据；`3ea931e` 才是最终字节。
另留了一次**同字节重复跑** `/tmp/r79g/gates-final.log`（两次都得七 rc 全 0 才算稳）。

| # | 命令 | 读数 | rc |
| --- | --- | --- | --- |
| 1 | `git diff --check origin/develop HEAD`（**有信息量的那条**）；`git diff --check HEAD` 在同一树状态下必然空 ⇒ 只作附带 | 两条都无输出（`HEAD=3fcd1c6 工作树：0 项脏`） | 0 / 0 |
| 2 | `dart format --output=none --set-exit-if-changed` 本轮 3 个显式文件 | `Formatted 3 files (0 changed) in 0.07 seconds.` | 0 |
| 3 | `flutter analyze` | `No issues found! (ran in 2.1s)` | 0 |
| 4 | `flutter test --tags golden` | `00:05 +9: All tests passed!`；`基线目录脏项数=0` ⇒ **9 张基线一张都没重录** | 0 |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:38 +904 ~26: All tests passed!` | 0 |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` | 0 |

计数对账：门 5 末行 `+904` 减掉本轮新增 6 条 = **898** = develop 全量基线。
**898 不靠减法取证**（第 77 轮复核 F1 的教训），它有自己的实跑日志：
`/tmp/r68/baseline_develop.log:1152` = `02:53 +898 ~26: All tests passed!`（在 `origin/develop` 副本上直接跑出来的末行）。
⚠️ 本来还想引 `specs/045-sort-direction/tasks.md:120` 作第二处佐证，落笔前 `ls` 过：**这个目录不在本分支**
（`specs/045-sort-direction/` No such file or directory，它在未合并的分支上）⇒ 不引，
免得又写成一个指不到的指针（第 77 轮复核 F1 的原罪就是这个）。
新增 6 条这一侧的前提也可验：`git diff --name-status origin/develop..HEAD -- test` 只有一个 `A`（本表日志收尾 `工作树脏项数=0`），
`grep -c "  testWidgets(" test/features/list/list_share_entry_test.dart` = 6。
`~26` 与既有各轮一致（未新增 skip）。收尾 `工作树脏项数=0`、`pubspec.lock` 未进提交。

## 反向探针（六条 X1–X6 + 四条反例 CX1–CX4）

每条都：起跑前 `lib` + `pubspec.lock` 干净 → 对照组先绿 → 锚点干跑（`check` 模式 6/6 命中 1）
→ 打补丁跑 → `cmp -s` 逐字节还原。判据面 = 本面新套件；参考面 = 既有 `collaboration_widget_test.dart`。

| 编号 | 摘掉的是什么 | 读数 | 红在哪 |
| --- | --- | --- | --- |
| X1 | `serverId` 缺失时兜一个假 id（未同步也硬推成员页） | `+5 -1` | 判据面 1/1 命中「清单还没同步时不跳转…」；参考面 `+10` 绿 |
| X2 | 动作表里根本没有「共享协作」这一项 | `+1 -5` | 判据面 **5/5** 命中（首跑是 4/5 + 一条「名单外的红」：320px 那条红在它自己的前置 `expect(find.text('共享协作'), findsOneWidget)` 上，属真实覆盖面）。第 2 笔把这条**收进预期名单**，并把「名单外的红」改成脚本自己判异常 ⇒ 现在这类事不靠作者手写补记 |
| X3 | 顺序反了：「共享协作」压在「编辑」之前 | `+5 -1` | 1/1 命中排序那条 |
| X4 | 未同步时静默 `return`，不给原因 | `+5 -1` | 1/1 命中「给得出原因」 |
| X5 | 开成员页不带清单名 | `+5 -1` | 1/1 命中「带的是这条清单」（顶栏整串 '协作成员 · 清单名' 那条判据） |
| X6 | **只把 `sidebar-list-action-share` 这个键改个名**（文案、项数、宽度一律不动） | `+2 -4` | 4/4 命中（T1–T4）。结论方向按复核失4 改写：**主读法是「键耦合的成本」**——改一个私有键名会误红 4 条，其中溢出量测那条（T6）原本是纯假警报，本轮已把它换成按文案定位 ⇒ 不再因改名而红；对**可见行为**的覆盖证据来自 X1/X3/X4/X5 那四条完全不碰键的补丁 |

反例 CX1（复核失2 的修法验证，脚本 `/tmp/r79d/probe_cx.py`；
**最终字节上的复跑**在 `/tmp/r79g/cx/control.log`（`+6` 绿）与 `/tmp/r79g/cx/CX1.log`（`+5 -1`，
红的那条用例名逐字打印在日志里），首次复现在 `/tmp/r79d/`）：
**不是**摘代码，而是**造一个违反嘀嗒 `:6` 的实现**——给 `_SmartRow` 的长按接 `showDialog` +
`AlertDialog(content: Text('共享协作'))`（既不用 `BottomSheet`、也不用那两个私有键）。

反例 CX2–CX4（**第 2 轮复核 N-A 的修法验证**，脚本 `/tmp/r79h/probe_cx2.py`，
日志 `/tmp/r79h/run.log`）—— N-A 量出 `find.text` 只认"恰好等于"，三种真违反的形状放过：

| 编号 | 逃逸形状 | 读数 | 是哪条断言咬住的（按 reason 现读，不是猜） |
| --- | --- | --- | --- |
| CX2 | `AlertDialog(content: Text('共享协作 · 邀请成员'))` —— 文案带后缀 | `+5 -1`，红的就是 T5 | `textContaining`（reason 命中「不支持共享协作」） |
| CX3 | 长按弹 `SnackBar(content: Text('去共享协作'))` —— 文案在别处 | `+5 -1`，红的就是 T5 | `textContaining`（同上） |
| CX4 | `IconButton(icon: Icon(Icons.share))` —— **树上根本没有 Text** | `+5 -1`，红的就是 T5 | `byIcon`（reason 命中「图标型共享入口没有任何」） |

三条各自 `cmp -s` 逐字节还原（日志里 3 次「还原后 … 是」），对照组 `+6` 绿，末行「异常计数 = 0」。
⚠️ **每条都指定了"该由哪条断言咬住"**：只判"红没红"的话，两条新断言里白写一条也测不出来 ——
CX2/CX3 只有 `textContaining` 能咬、CX4 只有 `byIcon` 能咬，脚本对 reason 字符串做了断言。
判据**上界**仍然如实写：这三形是复核员量出来的，不是全部；不声称拦得下任意形态（见 spec FR-4）。

| 面 | 读数 | 判读 |
| --- | --- | --- |
| 对照组（未打补丁） | `00:01 +6: All tests passed!` | 反例本身没把基线弄脏 |
| 补丁后（旧版负断言只断 `BottomSheet` + 两个键） | `+6` **全绿** ⇒ 复核实测 | FR-4 被真实违反而套件不红 ⇒ 那条负断言**不够**（失2 成立） |
| 补丁后（本轮补 `find.text('共享协作') findsNothing`） | `+5 -1`，红的正是「智能清单行压根没有长按动作表…」 | 判据面 1/1，异常计数 0 |

⚠️ 这条反例第一轮我自己的**判据脚本也是坏的**：`-r expanded` 的红行形态是 `… [E]`（`[E]` 在**行尾**），
我按行首匹配 ⇒ 红行数恒 0，把「真咬住了」读成「判据没牙」。修完才有上表。

成对 grep 判据（同一日志末尾）：

```
ABSENT  详情面板就地 push 成员页（ListMemberPage）        命中 0（期望 0）
PRESENT openListCollaboration（1 定义 + 2 调用点）        命中 3（期望 3）
PRESENT 正对照：动作表仍是 showModalBottomSheet 起的       命中 2
PRESENT 正对照：侧栏仍把长按接到 showListActions           命中 1
```

## 第 78 轮只读复核（第 2 轮）：`VERDICT: FAIL`（三条都是文档字节，代码未再动）

第 2 轮复核**独立复现了失2 的修法**（旧判据 `+6` 全绿 / 新判据 `+5 -1`，红的逐字是 T5 那条），
并判「22 处 / **6 个文件**」这个读数**我赢**（第 1 轮记的 7 是换了松散子串 `todo-sidebar` 才得到的）；
门禁两次独立跑、`53d55d1` 返工登记、成对 grep、898 实跑源四条全部复验为真。三条失项：

| # | 复核指什么 | 我复验的命令与读数 | 处置 |
| --- | --- | --- | --- |
| F1 | 修失3 时把 `];` 记成 `:63`；develop 上 `:62` 才是 `];`、`:63` 空行 ⇒ 一个括号里混了两套基准 | `git show origin/develop:lib/features/list/list_actions.dart \| awk 'NR>=61&&NR<=66'` → `62  ];`、`63`空、`64  ///`、`65  Future<void> showListActions(` | spec `:17` + 现状行 + 缺陷表三处改成 `:62/:63/:64` 并显式标基准 |
| F2 | N3 只改了测试：spec 五-1 仍写 `byKey('sidebar-list-action-share')`，交付字节是 `find.text('共享协作')` | `grep -n "textScalerOf" -A2` 两侧对读，确实不一致 | spec 补 2b 条与测试同口径 |
| F3 | N5 只改了 §六.2：同一文件 `:33` 还写「没有对应的控件」，被 `:88` 显式否定 | `grep -n "没有对应" spec.md` → `:33`、`:88` 同时命中 | `:33` 改「没有独立入口」 |

非阻塞采纳 **N-A（本轮最有价值的一条）**：`:6` 那条负断言的**上界**原先没写下来，复核量出三种逃逸形状
（子串文案两种、图标型入口一种，当时六条全绿）⇒ 用例改 `textContaining` + 新增 `find.byIcon(Icons.share)`，
FR-4 写死"能拦什么、不声称拦什么"。另采纳 N-B（解耦只由 T6 贡献）、N-C（遗留段死句）、
N-E（一处日志同时背书两件事 ⇒ 拆成 `R1_counterexample.log` / `cx/CX1.log`）、N-F（docs 那笔已完成）、
N-G（复验命令行号已漂）。**登记不改**：N-D（`probes-check.log` 自身不记 HEAD，时效靠 mtime + `lib` 未变支撑）、
N-H（`协作成员` 在 develop 另有 `:1214` 注释与 `list_member_page.dart:183` 未枚举）。

## 第 78 轮只读复核（第 1 轮）：`VERDICT: FAIL`

任务书 `/tmp/r79/review_r78.md`；复核自己写的反例日志留在 `/tmp/r79c/`
（`R1_counterexample.log` = 旧版判据下 `+6` 全绿、`R2_bottomsheet_variant.log`、`R3b_fixed_assertion.log`）。
四条失项我**全部回源复验为真、0 条驳回**：

| # | 复核指什么 | 我复验的命令与读数 | 处置 |
| --- | --- | --- | --- |
| 失1 | 我把一次**用例装配错误**写成"develop 上不存在的键" | `git grep -n "Key('todo-sidebar')" origin/develop -- lib` → `todo_workspace.dart:150`、`:198`；`grep -rn` 全 `test/` → **22 处 / 6 个文件**（复核记 7 个文件，本机实测 6） | spec.md 五-3 与缺陷表根因重写；键本身不动 |
| 失2 | T5 的负断言只断弹层类型 + 私有键，**低于 spec 自述判据** | 我自己跑 CX1（见上表）复现：旧版 `+6` 全绿、补文案断言后 `+5 -1` | 断言换成按文案判；spec.md FR-4 补"按文案不按键"的理由 |
| 失3 | `showListActions` 定义行写 `:63` | `git grep -n showListActions origin/develop -- lib` → `:65`（`:63` 是 `];`） | 改 `:65` |
| 失4 | X6 的日志标题（"压回两档宽度"）与实际补丁（改键名）不是同一件事 | 当年能指的字节是 `probes-all.log:45` 那行旧标题；**注意** `probes79.py` 后来被我原地改强（04:20），行号已漂 ⇒ 现在 `sed -n '63,66p'` 落在 X5 的补丁上，这句复验命令只剩日志那一半能用（第 2 轮复核 N-G） | 标题改成与补丁一致；结论改写为"键耦合成本 + 可见行为由 X1/X3/X4/X5 证明"，并按新名单重跑 |

复核**判为通过**的三项也记在这里，免得下轮重查：FR-2 的「共用一份口径」结构成立（HEAD 上构造 `ListMemberPage` 只剩 1 处）
且 `?? t.title` 确为不可达死代码；`:6`/`:8` 行号与命名照抄无误；门禁表四项 + 898 的独立实跑来源（`/tmp/r68-baseline@9032005`）都对得上。

## 本轮我自己造成的缺陷（逐条登记，不藏）

| 现象 | 根因 | 处置 |
| --- | --- | --- |
| 首版 6 条里 3 条红：`Found 0 widgets with type "ListMemberPage"` | 我以为是跳转坏了，其实是**顶栏文案形状猜错**：成员页 AppBar 打的是 `'协作成员 · 清单名'`（`list_member_page.dart:183`），不是单独一个 `Text(清单名)`；断 `find.text(标题本身)` 是越界要求 | 改成断整串（由 `pushed.title` 现拼，不硬编码清单名）。**同一文件 137 行的 `listServerId` 早已绿**（复核 N6：138 行是 `pushed.title` 那句） ⇒ 跳转本身没坏，红的是我的断言口径 |
| `Found 0 widgets with key [<'todo-sidebar'>]` | **我写下的根因是假的**（复核失1）：该键在 develop 上**存在**（`todo_workspace.dart:150`/`:198`，`grep -rn "Key('todo-sidebar')" test/` = 22 处、6 个文件在用），红的真因是本用例 `_TestSidebar` 只泵裸 `Sidebar`、没渲染 `TodoWorkspace` ⇒ 键不在**那棵树**里 | 改成 `find.byType(Sidebar)`（**本用例装配下**的选择，不是仓库事实）；`spec.md` 五-3 已按实测重写 |
| `pageBack()` 之后弹层仍在 | 动作表是 `showModalBottomSheet`，`pageBack()` 找路由返回按钮（实测 `Found 0 widgets with type "CupertinoNavigationBarBackButton"`）⇒ 它关不掉 sheet，于是"收集箱没有这一项"是在**旧弹层之上**测的 ⇒ 假绿通道 | 先用 `ModalBarrier` 关，实测关掉后 `scrollUntilVisible` 又抛 `Bad state: No element`（那棵树的滚动容器不可依赖）⇒ **最终改成反例另起一条用例、正对照留在第 1 条**，不在同一棵用过的树上断负结论 |
| 一条用例里 `_pump` 两次，drift 打 `WARNING … AppDatabase multiple times` | 为了在同一条里做"正对照 + 反例"而复用了场景 | 拆成两条用例各自一棵树；正对照的引用写进注释。负向断言不建立在"上一棵树的残留状态"上 |
| 未使用的 `providers.dart` import | 改版过程中留下的 | 删（门 3 `flutter analyze` 会报 `unused_import`，不是可忽略项） |
| N8 的留痕指针**两处写偏**（派复核前自查出来的）：① 写成「`probes-r2.log` **首行**」，实际那文件第 7 行才是「锚点干跑：异常 0」；② 那份日志是**改判据之前**那次的产物，而最终字节的 `/tmp/r79g/probes-all.log` 里**根本没有干跑留痕**（`grep -c 锚点干跑` = 0，因为 `all` 模式不会自动打印 `check`） | 位置词（"首行"）凭印象写、没 `head` 过；以及把"我跑过 check"当成"最终日志里有 check 的留痕" | ① 措辞改成标行号；② 在最终字节上另出 `/tmp/r79g/probes-check.log`（X1–X6 各命中 1、第 7 行异常 0）并引它，**不往已引为证据的 `probes-all.log` 里追加**（追加会让"末两行是结论 + 收尾"那句失效） |

## 遗留与下一轮

- **门禁现跑在 `3fcd1c6`**（上表；`e3c9d88`、`3ea931e` 是前两版的基准，已被推进）；**复核第 1、2 轮 FAIL 已修并各有反例证明修上了、第 3 轮未派** ⇒ 本 PR 不谈合并。
  要它咬定的：① FR-2 的「共用一份口径」是真做了还是只改文案（`openListCollaboration` 消费者数 + 四条分支行为等价性，含原实现`title: list?.name ?? t.title` 那个兜底到底是不是死代码）；
  ② X6「只改 key 名就全红」算覆盖面还是锚得太死 —— **已判**：主读法是锚得太死（失4 采纳），
     改键名的误红**只由 T6 一处贡献**（第 1 轮那版里 T5 本就不因改名红；它今天还留着一句 `expect(find.byKey(_shareKey), findsNothing)` ⇒ 说"T5/T6 两处都解耦"偏强，复核 N-B），现读数 `+2 -4`；
  ③ 「智能清单结构性拿不到动作表」这条负断言够不够硬 —— **已判：不够**（失2 采纳），
     按文案补强并由 CX1 反例证明现在有牙。
- **复核第 1 轮的 11 条非阻塞**：N1（FR-1 自相矛盾）、N3（T6 解耦）、N4（`:6` 引文加粗范围照抄原文）、
  N5（取舍 2 措辞 + `:242`/`:246` 定位）、N6（138→137）、N7（「末行」实为日志第 62 行）、
  N8（`check` 干跑留痕：最终字节上**另出一文件** `/tmp/r79g/probes-check.log`，第 7 行
  「锚点干跑：异常 0」，X1–X6 各命中 1；改前我先引 `/tmp/r79e/probes-r2.log` 并写成"首行"，
  实为第 7 行，且那份是改判据前那次的产物 ⇒ 两处都已按实测改见下表最后一行）、N10（套件不相交）、
  N11（门 1 两读数的信息量差）已改掉。**但第 2 轮复核 F2/F3 抓到 N3、N5 当时各只修了一半**（N3 只改了测试没改 spec 五-1；N5 只改了 §六.2 没改 §二 `:33` ⇒ 同一文件自相矛盾）⇒ 本笔补全；
  **N2**（名单外的红）改的是判据脚本本身；
  **N9 未在本面补测**：详情面板 `members` 分支的新提示语与共用函数调用**零用例覆盖**（只由那条 ABSENT grep 守着，
  而 grep 在探针脚本里、不在 CI）⇒ 已立 **FL Issue #366** 跟踪（判据①②我在建单前自己跑过：
  `git grep -n "无法打开共享协作" -- test` 只命中 `list_share_entry_test.dart:162`；
  `git grep -cE "协作|[Mm]ember" -- test/features/task/task_detail_pane_test.dart` rc=1（0 命中）），
  不在本 PR 里扩面。
- 形态偏差两条（入口在侧栏长按而非清单详情右上角「···」；「添加新成员」在本仓是内联提交流程、无独立入口）
  已写进矩阵 #52 说明格（docs `4e85598`），**不能算"已与嘀嗒一致"**。
  ⚠️ docs 那一笔**已经收了**（`870f42f`，04:24，早于最终字节 13 分钟）⇒ 原文写"待再收一笔"是时效错（复核 N-F）；该格里的 FL head 仍写 `a3262f2`（本 PR 现 tip 已推进到 `6e5a5df`），不跟着 bump 的理由见 !365 留言。
- 下一轮候选（不撞本单也不撞 !364）：docs #104 里剩下 5 条**非第三方凭据**的弱证据行
  #7/#11/#19/#21/#24（`check_parity_matrix.py` 现算：13 条告警里 8 条属 #55–64/#66 那族，
  按口径不排进自主轮次）。

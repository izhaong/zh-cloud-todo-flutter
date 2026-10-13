# 执行记录：指令菜单补「帮助」那一层（FL #606，矩阵 #86 最后一面）

## 落地的文件

| 文件 | 干什么 |
| --- | --- |
| `lib/features/home/command_palette.dart` | `TodoPaletteCommand` 加可选 `group`；`_rowsWithHeaders`/`_row` 按组渲染，标题只在组内有命中时出现 |
| `lib/features/home/todo_workspace.dart` | 「显示键盘快捷键」那条命令带上 `group: '帮助'`（`:28` 那条路径上的那一层） |
| `test/features/home/command_palette_test.dart` | 分组四组新用例；真实 ⌘K 那条一路走到"改键落库" |

## 测试与结果

`flutter test --no-pub test/features/home/command_palette_test.dart` ⇒ 12 条全绿
（本轮之前 8 条，新增 4 条）。复算：
`git grep -c "testWidgets(" -- test/features/home/command_palette_test.dart` ⇒ 12。

`flutter test --no-pub -r json` 的基线读数把 `loading` 事件也数进去了（报 13），
所以台账里的用例数只认 `testWidgets(` 的计数。

## 变异探针（`/tmp/probe298.py`，逐条：断言 needle 命中 1 次 → 改 → 跑 → 还原 → 比对）

驱动脚本在每条探针后用 `finally` 还原，并在结尾断言两个被改文件与开跑前逐字节相同；
日志 `/tmp/probe298b.log`，基线（无变异）`rc=0 failing=0`。

| 探针 | 改哪 | 结果 |
| --- | --- | --- |
| P1 | 工作区那条命令去掉 `group: '帮助',` | 红：`接进工作区（真实 ⌘K）` 那条 |
| P2 | 组名从 `widget.commands` 取（第一版还多摘了一道闸门，见下方「P2 的自我更正」） | 红：`输入把整组筛空时，组标题跟着消失；清空后又回来` |
| P3 | 未分组命令改到分组之后 | 红两条：`未分组命令在前、组标题在其后…` 与 `多个分组按首次出现排序…` |
| P4 | 组内顺序改倒序（`inGroup.reversed`） | 红：`多个分组按首次出现排序，组内保持调用方给的顺序` |
| P5 | 回车从 `widget.commands` 取第一条而非命中项 | 红：`只有分组命令命中时，回车执行的是命令本身` |
| P6 | `_showKeyboardShortcuts` 不给 `onSave`（只读态） | 红：`接进工作区（真实 ⌘K）` 那条（断在 `keyboard-shortcuts-edit-showShortcuts`） |

**P2 的自我更正（两步）**：第一版只把组名的来源从 `matches` 换成 `widget.commands`，跑完全绿 ——
因为 `if (inGroup.isEmpty) continue;` 那道闸门本来就挡住了空组，那次变异根本没造出缺陷；
补上"同时摘掉闸门"的第二步才红。记这条是为了下次别把"改了一处"当成"证了一处"。
本笔随后**把那道死闸门删了**（`groupNames` 只从 `matches` 收，空组进不了循环 ⇒ 它今天到不了），
删完再跑同一个单点变异：`输入把整组筛空时，组标题跟着消失` 自己就红（量过：删闸门后文件级 `+12` 全绿，
只改来源 ⇒ 红在那条用例）。也就是说这道闸门此前一直在替用例挡着，判据反而更钝。

**交叉验证的采纳与不采纳**（`/tmp/cc298.out` 与 `/tmp/cc298c.out`，两条都以当前字节复验过）：

- 采纳：`:26`/`:27`/`:28` 三条进法都成立；`:13` 与「灰色不可改」都不占功能面；
  「0 张重录」要用量化的 diff（见下）而不是只看失败清单里没有 `test/visual`。
- 它报「主表第 203 行仍写『部分』」——**不成立**：它读的是 `zh-cloud-docs` 主工作树那份，
  那里停在别的会话的分支上；develop 上 #86 自第 290 轮起就是「有」。
- 它对 P5/P6 的批评成立，逐条记在这儿，不靠改文案糊过去：
  **P6 钉不到落库那半句** —— 摘掉 `onSave` 后用例停在"有没有修改按钮"（`:413-416`），
  走不到 `:446` 的 `showShortcuts == ctrl+alt+0x6a`；落库本身由 `#579` 那轮的
  `test/state/shortcut_overrides_repository_test.dart` 钉（复算 `git grep -c "test(" origin/develop -- test/state/shortcut_overrides_repository_test.dart` ⇒ 5）。
  **P5 只红新用例** —— 变异把 `_runFirstMatch` 的来源换成 `widget.commands` 时，
  老的那条「回车执行第一条匹配命令」红不到（它的种子首条命中与首条命令同为一个），
  所以"标题不是可执行项"这句**没有等值变异**：标题按构造就不是 `TodoPaletteCommand`，
  那条用例防的是日后有人把标题做成可点项或塞进命令表，不是本轮已经证出来的缺陷。


## 有意差异 / 不占面的两处

见 `spec.md`：`:13`「Mac 应用程序暂时不支持此功能」是嘀嗒自己客户端的限制说明；
`:29`「显示为灰色的快捷键不能修改」是限制而非功能，本端两档都可改，
兑现方式是整个对话框的只读态 + `validateShortcutOverride` 两道闸门。

## 门禁读数（跑在合并 `origin/develop@0c6ef40b` 之后的产物上）

分支先并了 develop（5 个提交，全是「默认提醒」那一面，与本三个文件不相交），
再在产物上跑：

- `flutter analyze` ⇒ `No issues found!`
- 产物全量 `flutter test --no-pub` ⇒ 计数取整份日志 `+N ~N -N` 的**最大值**，不读末行
  （尺子随这笔进仓：`bash tool/gate_counts.sh --selftest` ⇒ `SELFTEST PASS`）
  ⇒ 复算 `flutter test --no-pub 2>&1 | tee /tmp/gate.log | tail -1 >/dev/null; bash tool/gate_counts.sh /tmp/gate.log`
  ⇒ **pass 1935 / skip 26 / fail 5**
- develop 单独全量（`git worktree add --detach /tmp/wt-fl-298dev origin/develop` 后跑上面那命令）
  ⇒ **pass 1931 / skip 26 / fail 5**
- 对账：`1935 - 1931 = 4` ＝ 本轮新增的 4 条用例（`testWidgets(` 8→12 复算过）；
  五条红的**名字逐条相同** ⇒ 本轮净新增红 **0 条**
- 黄金基线 0 张重录的量化判据：`git diff --name-only 0c6ef40b 356d8df4eb -- test/visual | wc -l` ⇒ `0`
  （develop 与 PR head 之间 `test/visual` 一个文件都没动；跑完 `flutter test --no-pub` 也没报 golden 差异）

**读数方法本身是一次自我更正（订正两遍才对）**：
第一版我把错因写成"末行那一拍没并完"——**那是错的**：`grep -n "+1935" /tmp/gate298.log` 复验，
带终止标记那一拍（`Some tests failed.`）自己就带全数 ⇒ 复算 `grep -n "Some tests failed" /tmp/gate.log`
命中的那一行行号即末条进度行，数出来的就是 `+1935 ~26 -5`（本轮那份日志里它在 `:43`，全文非空 51 行）。

真正的原因是**我读的是进程还没写完的日志尾部**（`tail` 那一刻最后一行停在 `+1934`）。
尺子据此改成三件事一起报：`last`（末条进度行）、`max`（全日志峰值）、`complete`（有没有终止标记）。
复算 `bash tool/gate_counts.sh --selftest` ⇒ `SELFTEST PASS`（四条样本：省略段、零值段、
拼接日志要报 `last!=max`、没写完要报 `complete=no`）；
摘掉终止标记那条规则后同一条 selftest 判红 ⇒ 这把尺是活的（`bash` 逐条变异验过）。
本笔读数：产物 `last=1935/26/5 max=1935/26/5 complete=yes`、
develop `last=1931/26/5 max=1931/26/5 complete=yes`。

**顺带更正 117 那轮的读数**：PR !602 正文写的"全量 `+1922 ~26 -1`、唯一那 1 项红是
`raw_error_text_gate_test`"不成立（117 的台账当时**根本没写全量门禁这一节**，
所以尺子没兜住它 —— 这一节随本笔补进去）。在 117 合并后的 tip 上跑

`git worktree add --detach /tmp/wt-fl-298dev b2449a74` 后
`flutter test --no-pub test/features/habit/habit_year_stats_test.dart test/task_organize_search_repository_test.dart`
⇒ 失败清单为 `habit_year_stats_test` 2 项 + `task_organize_search_repository_test` 2 项（见下表），
说明那轮读的是末行计数而漏了这 4 项。117 的台账与 PR 正文按本节口径订正
（另开一笔 docs(specs) 提交，见 PR 正文）。



## 存量红（本轮没碰、也没顺手修）

| 红 | 判据 | 去处 |
| --- | --- | --- |
| `habit_year_stats_test.dart` 2 条 | 断言找 `habit-heat-cell-2026-07-15`，`Found 0 widgets` —— 种子写死一个绝对日期，热力窗口按今天算，跨了边界就没有那一格 | FL #607（上一轮已立） |
| `task_organize_search_repository_test.dart` 2 条 | `Expected: ['task:task-search-17'] Actual: []`、`Expected: ['task-1'] Actual: ['task-2']`、`Expected: empty Actual: [...]`。**测过不是时钟**：同一 HEAD 上 `TZ=Etc/GMT+12`（本机日期退回 10-12）仍红；过滤区间与种子都是绝对日期（`DateTime.utc(2026, 8, 10)`、`DateTime(2026, 7, 20)`）；在 117 那轮的 tip `b2449a74` 上跑同样红 ⇒ 存量，不是本轮也不是跨天引入 | 本轮新立一张（见 PR 正文） |

| `tooling/raw_error_text_gate_test.dart` 1 条 | 「lib 下没有任何文案在插异常原文」的门禁判红 | FL #569（存量） |

这三组都在 develop 上就红，本轮不顺手改：改法各不相同（前两组是把用例种子改成相对今天
算，第三组是产品侧文案），混进这个 PR 会让"补帮助分组"这一笔变得不可评审。


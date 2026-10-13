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
| P2 | 组名从 `widget.commands` 取 + 摘掉 `if (inGroup.isEmpty) continue;` | 红：`输入把整组筛空时，组标题跟着消失；清空后又回来` |
| P3 | 未分组命令改到分组之后 | 红两条：`未分组命令在前、组标题在其后…` 与 `多个分组按首次出现排序…` |
| P4 | 组内顺序改倒序（`inGroup.reversed`） | 红：`多个分组按首次出现排序，组内保持调用方给的顺序` |
| P5 | 回车从 `widget.commands` 取第一条而非命中项 | 红：`只有分组命令命中时，回车执行的是命令本身` |
| P6 | `_showKeyboardShortcuts` 不给 `onSave`（只读态） | 红：`接进工作区（真实 ⌘K）` 那条（断在 `keyboard-shortcuts-edit-showShortcuts`） |

**P2 的自我更正**：第一版只把组名的来源从 `matches` 换成 `widget.commands`，跑完全绿 ——
因为 `if (inGroup.isEmpty) continue;` 那道闸门本来就挡住了空组，那次变异根本没造出缺陷。
补上"同时摘掉闸门"的第二步才红。记这条是为了下次别把"改了一处"当成"证了一处"。

**另一次自我更正**：交叉验证（`/tmp/cc298.out`）点名的"缺从面板点进可改对话框并落库的用例"
这条，报告写于我补那条用例之前 —— 采纳前对着当前工作树复验过，那条其实已经在
真实 ⌘K 用例里落地（P5/P6 两次变异能把它判红，说明它是活的判据）。


## 有意差异 / 不占面的两处

见 `spec.md`：`:13`「Mac 应用程序暂时不支持此功能」是嘀嗒自己客户端的限制说明；
`:29`「显示为灰色的快捷键不能修改」是限制而非功能，本端两档都可改，
兑现方式是整个对话框的只读态 + `validateShortcutOverride` 两道闸门。

## 门禁读数（跑在合并 `origin/develop@0c6ef40b` 之后的产物上）

分支先并了 develop（5 个提交，全是「默认提醒」那一面，与本三个文件不相交），
再在产物上跑：

- `flutter analyze` ⇒ `No issues found!`
- `flutter test --no-pub` ⇒ `+1934 ~26 -5`
- 同 5 条红在 `origin/develop@0c6ef40b` 单独跑同样三个文件也红，名字逐条对得上
  （复现命令：`git worktree add --detach /tmp/wt-fl-298dev origin/develop`
  → `flutter test --no-pub test/features/habit/habit_year_stats_test.dart
  test/task_organize_search_repository_test.dart test/tooling/raw_error_text_gate_test.dart`
  ⇒ `+33 -5`，五条名称与本节列出的五条一致）⇒ 本轮净新增红 **0 条**。
- 黄金基线在那 1934 条里（`test/visual/`），五条红里没有一张是 golden ⇒ **0 张重录**。

## 存量红（本轮没碰、也没顺手修）

| 红 | 判据 | 去处 |
| --- | --- | --- |
| `habit_year_stats_test.dart` 2 条 | 断言找 `habit-heat-cell-2026-07-15`，`Found 0 widgets` —— 种子写死一个绝对日期，热力窗口按今天算，跨了边界就没有那一格 | FL #607（上一轮已立） |
| `task_organize_search_repository_test.dart` 2 条 | `Expected: ['task:task-search-17'] Actual: []`、`Expected ['task-1'] Actual ['task-2']、Expected: empty Actual: [...]` —— 也是按今天算的日期窗口/闭区间边界 | 本轮新立一张（见 PR 正文） |
| `tooling/raw_error_text_gate_test.dart` 1 条 | 「lib 下没有任何文案在插异常原文」的门禁判红 | FL #569（存量） |

这三组都在 develop 上就红，本轮不顺手改：改法各不相同（前两组是把用例种子改成相对今天
算，第三组是产品侧文案），混进这个 PR 会让"补帮助分组"这一笔变得不可评审。


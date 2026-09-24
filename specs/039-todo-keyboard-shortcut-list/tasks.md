# 任务清单 039：键盘快捷键列表

- [x] T1 注册表成为唯一事实源：`todoShortcutBindings` 同时驱动工作区映射与对话框列表。
- [x] T2 `?`（= Shift+/，另加字符 `?` 的 CharacterActivator）在工作区打开「键盘快捷键」对话框。
- [x] T3 焦点在输入框内时 `?` 不触发快捷键（守卫让位给文字输入）。
- [x] T4 设置页有「键盘快捷键」入口，打开与 `?` 同一个界面。
- [x] T5 对话框内容逐行等于注册表（动作名 + 键位文案），列表不会多写也不漏写。
- [x] T6 四件套之适用项：320px + 1.3 倍不溢出（对话框自身 context 自检）；标题与每行动作名独立读屏语义。
- [ ] T7 ⌘K/Ctrl+K → 全局搜索的既成行为不回退（由 `task_organize_search_test.dart` 的
      `wide workspace opens local search with control K` 守着）。
      已证实：该文件在全量门禁里未红；仍缺：本轮未单独跑它一次留日志。
- [ ] T8 六项门禁 + 反向探针。已证实：探针三条 + 新用例 6 条绿；门禁日志见下（跑完回填）。
- [ ] T9 回写矩阵 #86 —— 属 `zh-cloud-docs`，且**未合并前只能写「已实现待合并」**。
- [ ] T10 指令菜单（⌘K 键位归属）与「可修改键位」：本轮不做，理由见 spec.md。

## 引文校正（自查，未进复核就被自己抓到）

首稿「嘀嗒原话」表里的四处行号与一处引文全错，原因是**没有用 `git show` 逐字核**，把
凭印象的行号写了进去。实测基准 `zh-cloud-docs@origin/develop`（工作树同内容）：

| 首稿 | 实为 | 原文 |
| --- | --- | --- |
| `:13` | `:18` | 「你可以输入「?」，方便的查看快捷键列表。」 |
| `:20` | `:26` | 「在设置里查看快捷键界面，可以修改。」 |
| （未引） | `:27` | 「在侧边栏打开快捷键界面，可以修改。」 |
| （未引） | `:28` | 「在「指令菜单」-「帮助」-「显示键盘快捷键」打开快捷键界面，可以修改。」 |
| `:7`（⌘K） | `:9` | 「使用 **⌘+K** 或者 Ctrl+K 打开「指令菜单」…」——首稿把 `⌘+K` 转写成 `⌘K` |
| `:24`（灰色不可改） | `:29` | 「显示为灰色的快捷键不能修改。」 |

旁证补记：`…/03-特色功能/09-桌面快捷操作.md:23`「更多快捷键可以前往桌面端应用左下角「？」-「快捷键」查看。」
——嘀嗒桌面端该界面还有底部「？」入口，即本端「侧边栏入口」那条的对位物。

## 实现期被测试反驳的三处（不是我想出来的，是跑出来的）

1. **`showDialog` 的 Future 要等弹层关闭才完成**：`_pumpDialog` 里 `await showKeyboardShortcutsDialog(...)`
   把用例挂到 `TimeoutException after 0:10:00`（首轮只有 1 条真跑完，其余各烧 10 分钟）。改 `unawaited(...)`。
2. **一行只渲染一个 `Text`**（键位用 `" / "` 连接），逐 `display` 的 `find.text('Ctrl+K')` 必然 0 命中
   ——`Actual: Found 0 widgets with text "Ctrl+K"`。改为断言整串 `row.displays.join(' / ')`。
3. **320px + 1.3 倍真的溢出**：`A RenderFlex overflowed by 13 pixels on the right.`
   原因是只把动作名放成 `Expanded`，键位列按自身宽度参与布局。改两侧 `Flexible`（3:2）后端对齐。

## 复核手段的替换

`claude` CLI 本机不可用（`unrecognized_model "Top1"`，加 `--model` 无效），
按既定口径改用**本会话只读子代理**审本轮 FR，要求它必须回 `VERDICT`；结论与处置记在本文件末尾。

## 反向探针（2026-09-24，`/tmp/reg.bak` 为还原基准）

| 探针 | 改动 | 必红的用例 | 结果 |
| --- | --- | --- | --- |
| P1 摘掉守卫 | `if (!withModifier && primaryFocusIsEditing() && false)` | 「焦点在输入框里时 ? …不被吞掉」 | `+5 -1`，红的确为该条 |
| P2 解绑 `?` | `slash+shift` → `slash+shift+alt`、`CharacterActivator('?')` → `'!'` | 「无编辑焦点时按 ? 打开…」 | `+5 -1`，红的确为该条 |
| P3 清空注册表 | `todoShortcutBindings = <TodoShortcutBinding>[]` | 「列表逐行显示…」与「按 ? 打开…」 | `+4 -2`，两条都红 |

还原后 `cmp -s /tmp/reg.bak lib/core/shortcuts/todo_shortcut_registry.dart` ⇒ **RESTORE cmp OK**。

用例最终状态：`flutter test test/features/home/keyboard_shortcut_list_test.dart` ⇒
`00:01 +6: All tests passed!`（`/tmp/r32_green7.log`）。

## 六项门禁（最终状态 `3b5411b` 一次跑完，日志 `/tmp/r32_gates.log`，2026-09-24）

| # | 命令 | 结果原文 |
| --- | --- | --- |
| 1 | `git diff --check` | `exit=0` |
| 2 | `dart format --output=none --set-exit-if-changed`（本轮显式 5 文件） | `Formatted 5 files (0 changed)`（首跑 exit=1，见 `/tmp/r32_gate2.log`，只原地格式化了我那个测试文件） |
| 3 | `flutter analyze` | `No issues found! (ran in 1.5s)` |
| 4 | `flutter test --tags golden` | `00:03 +9: All tests passed!`（基线 9 张，未重录） |
| 5 | `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:18 +715 ~26: All tests passed!` |
| 6 | `flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` | `Compiling lib/main.dart for the Web... 25.7s` / `✓ Built build/web` |

### 关于「715 vs 记录里的 713」——已实测澄清，不是回归

目标里记的基线是 `2026-09-23：713 passed / 26 skipped`，本轮新增 6 条 ⇒ 期望 719，实得 715。
为免把"基线数字对不上"当成回归，**新建干净 worktree 在 `origin/develop`（`a1d7733`）实测一次**：

```
git worktree add --detach /tmp/tw-base-check origin/develop && flutter pub get
flutter test --exclude-tags 'golden || performance' --concurrency=1
02:22 +709 ~26: All tests passed!
```

⇒ develop 自身是 **709**，本分支 **715 = 709 + 6**（恰等于本轮新增用例数），skipped 两侧同为 26。
「713」是当时在含未合并用例的状态上测的，不是 develop 的数；测完已 `git worktree remove` 清掉临时目录。

- [x] T7 ⌘K/Ctrl+K → 全局搜索不回退：`task_organize_search_test.dart` 随上面第 5 项一起跑绿（未单独跑一次，
      故此前保留未勾；结论：既成行为未回退，机制仍由该文件守着）。

## 第一轮复核（只读子代理，对 `3b5411b`）：**VERDICT: FAIL** → 已按结论改

复核手段替换理由：`claude` CLI 本机 `unrecognized_model`，不可用。

| 编号 | 复核主张 | 我复现到的事实 | 处置 |
| --- | --- | --- | --- |
| B1 | spec.md「范围外」残留 `:20`/`:24`/`:21` 三个错行号 | `grep -o '\`:[0-9]*\`' spec.md` 确为这三处；真值 `:26`/`:29`/`:27` | **采纳**：三处改成真值，并把 `:27` 引全 + 补 `09-…:23` 旁证 |
| B2 | plan.md 四条「已付过学费的约束」失实 | ① test:75 就是 `expect(rows.length, 2)`；② 先例 `native_entry_page_test.dart:282` **正是** `pumpAndSettle`（该文件 7 处），无限进度在 `settings_route.dart:219` 的 `_TaskCaptureDefaultsPage`，不在 `SettingsRoute`；③ `Expanded` 是 13px 主因、已改 `Flexible`；④ 写「3 个文件」列了 4 个 | **全部采纳**并按代码回写（含 shift 为何不能算进守卫的"修饰键"） |
| B3 | 门禁日志与 `715 = 709 + 6` 的实测澄清不在被审提交里，冻结 SHA 下 T7 的「已证实」无日志支撑 | `git diff 3b5411b -- tasks.md` 显示 committed 版仍是占位行 | **采纳**：把那 33 行并入本 PR（`pubspec.lock` 仍单独不提交） |
| N1 | 注册表无"activator 互不相同"的护栏，两个 kind 共用 activator 时 Map 静默覆盖 | 成立：`todoShortcutActivators` 是 Map 字面量 | **采纳**：新增 `runtimeType:$activator` 集合大小 == bindings 长度的断言 |
| N2 | 读屏 finder 未限定在弹层内 ⇒ 钉的是"全树唯一"不是"归属弹层"，且键位串没有独立节点断言 | 成立 | **采纳**：`find.descendant(of: dialog, …)`，并补每条键位串的语义断言 |
| N3 | 长键位串（如 `Ctrl+Shift+Space`）超宽只会静默裁字，`takeException()` 抓不到 ⇒ 该用例对"键位变长"是瞎的 | 成立（本轮只有 `Ctrl+K / ⌘K`，实际不触发） | **记为边界**，本轮不加为未来设计的容器，避免无需求的可配置项 |
| N4 | `spec.md:9` 引 `task_organize_search_test.dart:363-379`，实为 362-380 | `sed -n '360,382p'` 核到 testWidgets 在 362 | **采纳** |
| N5 | 验收标准里「`?` 正常进文本」与用例的免责不一致 | 成立 | **采纳**：验收标准改成"不出现对话框"，并就地写明本地测不到字符插入 |
| N6 | 工作树 `pubspec.lock` 是 tracked 文件，`git add -A` 会误带 | 成立 | 记着；本 PR 全程按路径 `git add` |

复核员对**主张 4** 的更正值得留下：320px 不溢出的真实机制是 `dialog.dart:275` 的 `minWidth: 280`
与 `:32` 的水平 `insetPadding: 40` 把弹层强制收到 240，再被内容区约束 ⇒ 结构上只会换行、抛不出
`RenderFlex`。所以"两侧 `Flexible`"是对的写法，但**13px 那个红是修之前的真实溢出**（修复前键位列不是 Flexible）。

修完复跑：`flutter analyze` `No issues found! (ran in 2.2s)`；
`flutter test test/features/home/keyboard_shortcut_list_test.dart` ⇒ `00:03 +6: All tests passed!`
（新增的护栏断言全部随该文件跑绿）。

**下一轮入口**：#86 行只能在 !297 合并后翻，且需引合并 SHA；指令菜单另开规格（⌘K 归属先定）；
可改键位需要嘀嗒"哪些可改"的集合（帮助页只有截图）。


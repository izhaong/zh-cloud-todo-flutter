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

## 六项门禁（最终状态一次跑完，日志 `/tmp/r32_gates.log`）

（跑完回填：diff --check / format 显式 5 文件 / analyze / golden 9 张 / 全量 / build web）


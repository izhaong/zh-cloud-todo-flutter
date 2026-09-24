# 实施计划 039：键盘快捷键列表

## 落点（4 个文件：2 新增 + 2 最小改）

| 文件 | 动作 | 内容 |
| --- | --- | --- |
| `lib/core/shortcuts/todo_shortcut_registry.dart` | 新增 | `TodoShortcutKind`、`todoShortcutBindings`（唯一事实源）、`todoShortcutRows`（按动作去重展示）、`todoShortcutActivators(forKind:)`、`TodoShortcutManager`（裸键让位输入框） |
| `lib/features/home/keyboard_shortcuts_dialog.dart` | 新增 | `showKeyboardShortcutsDialog(context)` + `KeyboardShortcutsDialog`：标题「键盘快捷键」，逐行 `动作名 + 键位`，关闭按钮 |
| `lib/features/home/todo_workspace.dart` | 改 | `Shortcuts` → `Shortcuts.manager(manager: TodoShortcutManager(todoShortcutActivators(...)))`；新增 `_ShowKeyboardShortcutsIntent` 及其 `CallbackAction`；清掉因此变成多余的 `services.dart` 导入 |
| `lib/features/settings/settings_route.dart` | 改 | 「原生增强」下方加一个 `_Tile`：`键盘快捷键 / 查看当前可用的组合键（?）`，`onTap` 调同一对话框 |

## 关键实现约束（都已付过学费）

1. **列表不许说谎**：对话框只渲染 `todoShortcutRows`；`Shortcuts` 的映射也由同一张表生成 ⇒ 二者不可能分叉。
   用例既逐行比对界面与注册表，也**硬断 `rows.length == 2`**（`keyboard_shortcut_list_test.dart:75`）——
   两个动作是嘀嗒这一面的全部，注册表被清空时必须当场红（P3 探针已证）。
2. **`?` 不是逻辑键**：绑 `SingleActivator(slash, shift: true)` **与** `CharacterActivator('?')` 两条
   （各平台把这次按键交给 Flutter 的形态不同）。测试里要发
   `sendKeyDownEvent(shiftLeft)` → `sendKeyDownEvent(slash, character: '?')` → 各自 up，
   才能同时命中两种 activator；只发 `sendKeyEvent(slash)` 不带 character 时字符路径不成立。
3. **输入框优先**：`TodoShortcutManager.handleKeypress` 在无 Ctrl/⌘/Alt 且
   `primaryFocus.context` 的 widget 是 `EditableText`（或其后代）时返回 `KeyEventResult.ignored`。
   shift **不算**在这里的"修饰键"里 —— 否则搜索框里 Shift+/ 会被抢走（那正是要避免的行为）。
4. **别把 `pumpAndSettle` 当禁区，要看是哪个页面**：`SettingsRoute` 本身可用 `pumpAndSettle`
   （既有先例 `test/native_entry_page_test.dart:282`，该文件共 7 处）；会永不返回的是
   `settings_route.dart:219` 那个 **`_TaskCaptureDefaultsPage`** 分支上的无限 `CircularProgressIndicator`。
   本轮用例仍用 `pump()`（够用且与该页解耦），但**理由不是"SettingsRoute 有持续动画"**。
5. 四件套：对话框 320px + 1.3 倍不溢出。行**两侧都用 `Flexible`（3:2）**——
   只把动作名放成 `Expanded` 时键位列按自身宽度参与布局，实测 `RenderFlex overflowed by 13 pixels`。
   标题与每行动作名各自独立语义节点（不用 `ListTile`，它会把两列合成一个节点）。

## 不在本轮

指令菜单（⌘K 键位归属）、可修改键位、侧边栏入口——理由见 `spec.md`「范围外」。

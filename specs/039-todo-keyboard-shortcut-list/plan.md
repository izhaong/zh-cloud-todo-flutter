# 实施计划 039：键盘快捷键列表

## 落点（3 个文件，全部新写或最小改）

| 文件 | 动作 | 内容 |
| --- | --- | --- |
| `lib/core/shortcuts/todo_shortcut_registry.dart` | 新增 | `TodoShortcutKind`、`todoShortcutBindings`（唯一事实源）、`todoShortcutRows`（按动作去重展示）、`todoShortcutActivators(forKind:)`、`TodoShortcutManager`（裸键让位输入框） |
| `lib/features/home/keyboard_shortcuts_dialog.dart` | 新增 | `showKeyboardShortcutsDialog(context)` + `KeyboardShortcutsDialog`：标题「键盘快捷键」，逐行 `动作名 + 键位`，关闭按钮 |
| `lib/features/home/todo_workspace.dart` | 改 | `Shortcuts` → `Shortcuts.manager(manager: TodoShortcutManager(todoShortcutActivators(...)))`；新增 `_ShowKeyboardShortcutsIntent` 及其 `CallbackAction`；清掉因此变成多余的 `services.dart` 导入 |
| `lib/features/settings/settings_route.dart` | 改 | 「原生增强」下方加一个 `_Tile`：`键盘快捷键 / 查看当前可用的组合键（?）`，`onTap` 调同一对话框 |

## 关键实现约束（都已付过学费）

1. **列表不许说谎**：对话框只渲染 `todoShortcutRows`；`Shortcuts` 的映射也由同一张表生成 ⇒ 二者不可能分叉。
   测试因此断言"每一行 label/display 都在界面上"，而不是数一个硬编码的 2。
2. **`?` 不是逻辑键**：`SingleActivator(LogicalKeyboardKey.slash, shift: true)`；测试里发键要
   `sendKeyDownEvent(shiftLeft)` + `sendKeyEvent(slash)` + `sendKeyUpEvent(shiftLeft)`。
3. **输入框优先**：`TodoShortcutManager.handleKeypress` 在无 Ctrl/⌘/Alt 且
   `primaryFocus.context` 的 widget 是 `EditableText`（或其后代）时返回 `KeyEventResult.ignored`。
4. **设置页测试不要用 `pumpAndSettle`**：`SettingsRoute` 上有持续动画（同步状态），`pumpAndSettle` 永不返回
   ——既有先例 `test/native_entry_page_test.dart:275-284` 全程只用 `pump()`。
5. 四件套：对话框在 320px + 1.3 字体下不溢出（在对话框自身 context 上自检，行用 `Expanded` 包名称）；
   标题与每行动作名各自独立语义节点（不用 `ListTile`，它会把两列合成一个节点）。

## 不在本轮

指令菜单（⌘K 键位归属）、可修改键位、侧边栏入口——理由见 `spec.md`「范围外」。

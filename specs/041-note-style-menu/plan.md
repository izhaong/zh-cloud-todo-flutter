# 041 实施计划

1. 红测：`test/features/note/note_style_menu_test.dart` —— 复用 `test/features/note/note_page_test.dart`
   的 harness（`noteRepositoryProvider.overrideWithValue` + 点 `Key('todo-note-add')` 开弹窗），
   断言 tooltip「加粗」「高亮」存在、包裹结果、折叠光标结果、标题不受影响、320px/1.3x 无异常。
2. 最小实现：`lib/features/note/note_page.dart`
   - 顶层纯函数 `noteWrapWithMarker(TextEditingValue, String marker)`（可单测、无副作用）；
   - `_NoteEditorDialogState._applyMarker(marker)` ⇒ `_content.value = noteWrapWithMarker(_content.value, marker)`；
   - 内容框上方一行 `Wrap`（两个 `IconButton`，key `todo-note-style-bold` / `todo-note-style-highlight`）。
3. 反向探针：摘掉 `Wrap` 里两个 `IconButton` ⇒ 用例必须红；`cmp -s` 证明还原后逐字节一致。
4. 六项门禁一次跑完（日志 `/tmp/r38_gates.log`）。
5. 复核：`claude` CLI 本机不可用（`unrecognized_model`），改用本会话只读子代理审 FR-001..FR-005，
   必须拿到 `VERDICT`；采纳与否逐条记在 `tasks.md`。
6. 回写矩阵第 89 行 ②：把「样式菜单缺失」改为「已实现待合并（分支 `feat/todo-note-style-menu`）」，
   未合并前不上浮行状态。

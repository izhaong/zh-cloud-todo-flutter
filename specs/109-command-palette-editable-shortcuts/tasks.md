# 任务：⌘K 指令菜单与可修改快捷键（FL #579 面①②③ / 矩阵 #86）

- [x] T001 现读判据源 `:9`/`:13`/`:26`-`:29` 原句与 specs/039 当年写下的倾向
- [x] T002 注册表改判 `openSearch` → `openCommandPalette`（`Ctrl+K` / `⌘K` 两条 activator 都留）
- [x] T003 `command_palette.dart`（输入即过滤、回车执行首条、空态、禁用项讲原因）
- [x] T004 `TodoWorkspace.paletteCommands` + `HomeShell._paletteCommands()`；删掉改判后无人触发的
      `_OpenGlobalSearchIntent`
- [x] T005 用例 8 例（复算 `grep -c 'testWidgets(' test/features/home/command_palette_test.dart` ⇒ 8）；
      另两处连带改判：`test/features/home/keyboard_shortcut_list_test.dart` 里两处 `forKind` 跟着 kind 改名，
      `test/features/task/task_organize_search_test.dart` 那条 Ctrl+K 用例改成走面板）
- [x] T006 变异探针 ⑯⑰⑱⑲⑳㉑㉒㉓ 八发各自红、且红在期望的那条用例上、还原后与提交字节一致（第一版还多摘了一处闸门，见 spec.md「第一版探针抓出的一处自欺」）
- [x] T007 门禁：`dart format`（只跑本轮 5 个文件，改前逐份证过 develop 基线本身是干净的，所以改动都是我的）；
      commit 后 `flutter analyze` ⇒ 0 issue，全量 `flutter test` ⇒ 1753 通过 / 26 跳过 / 1 失（/tmp/fl-gate-288.log）。
      那 1 失是 `test/tooling/raw_error_text_gate_test.dart`，主干存量红（FL #569）：本分支基线 develop `73c26db8` 上
      `lib/core/update/desktop_update_io.dart:34` 那句 `debugPrint('desktop update check failed: $error')` 就在，
      而 `git diff --name-only origin/develop..HEAD` 十个文件里没有它 ⇒ 不是我这次改动带的，也不在本 PR 顺手改。
- [x] T008 面① 收口：FL PR !580 合并 develop `46d00e98ee9c`、#579 留言（当时只做面①）、
      docs PR !190 合并 `baa82d5c840b`（矩阵 #86 追记、docs #189 关）、父仓 PR !260 合并 `907d8169d0`（#259 关）
- [x] T009 面③ 改键与持久化（第 289 轮）：`todo_shortcut_combo.dart` 规范串 +
      `todo_view_preferences` 的 `shortcut.<动作名>`（单键 patch、重置删键、`viewPreference` outbox）+
      快捷键界面的捕获/校验/重置 + 生效值同时驱动 `Shortcuts` 映射与列表文案
- [x] T010 面③ 用例三份：`test/core/shortcuts/todo_shortcut_combo_test.dart` 13 例
      （复算 `grep -c '^ *test(' test/core/shortcuts/todo_shortcut_combo_test.dart` ⇒ 13）、
      `test/state/shortcut_overrides_repository_test.dart` 5 例（同命令换成该文件路径 ⇒ 5）、
      `test/features/home/keyboard_shortcut_edit_test.dart` 9 例
      （复算 `grep -c '^ *testWidgets(' test/features/home/keyboard_shortcut_edit_test.dart` ⇒ 9，
      末两条是端到端"键真的换人"：改键后旧键不开面板/新键开，删覆盖后旧键又开）
- [x] T011 面③ 变异探针 ㉔–㉜ 九发各自红、红在期望的那条用例上、还原后与提交字节一致（逐发读数见 spec.md「面③ 的用例与探针」）
- [ ] T012 门禁：commit 后 `flutter analyze` + 全量 `flutter test` + golden 9 张复跑
- [ ] T013 收口：push → PR（Refs #579）→ 合并 → #579 留言并关单 → docs 矩阵 #86 判定与追记 → 父仓 bump
- [ ] T014 另立单跟：嘀嗒 `:27`「在侧边栏打开快捷键界面」那第三种进法（要改工作区像素 ⇒ 连着 golden 重录一起做）

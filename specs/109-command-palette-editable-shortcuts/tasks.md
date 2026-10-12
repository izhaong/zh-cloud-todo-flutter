# 任务：⌘K 指令菜单（FL #579 面① / 矩阵 #86）

- [x] T001 现读判据源 `:9`/`:13`/`:26`-`:29` 原句与 specs/039 当年写下的倾向
- [x] T002 注册表改判 `openSearch` → `openCommandPalette`（`Ctrl+K` / `⌘K` 两条 activator 都留）
- [x] T003 `command_palette.dart`（输入即过滤、回车执行首条、空态、禁用项讲原因）
- [x] T004 `TodoWorkspace.paletteCommands` + `HomeShell._paletteCommands()`；删掉改判后无人触发的
      `_OpenGlobalSearchIntent`
- [x] T005 新用例文件 `test/features/home/command_palette_test.dart` 共 8 例（复算 `grep -c 'testWidgets(' test/features/home/command_palette_test.dart` ⇒ 8）；
      另两处连带改判：`test/features/home/keyboard_shortcut_list_test.dart` 里两处 `forKind` 跟着 kind 改名，
      `test/features/task/task_organize_search_test.dart` 那条 Ctrl+K 用例改成走面板）
- [x] T006 变异探针 ⑯⑰⑱⑲⑳㉑㉒㉓ 八发各自红、且红在期望的那条用例上、还原后与提交字节一致（第一版还多摘了一处闸门，见 spec.md「第一版探针抓出的一处自欺」）
- [x] T007 门禁：`dart format`（只跑本轮 5 个文件，改前逐份证过 develop 基线本身是干净的，所以改动都是我的）；commit 后 `flutter analyze` ⇒ 0 issue，全量 `flutter test` ⇒ 1753 通过 / 26 跳过 / 1 失（/tmp/fl-gate-288.log）。
      那 1 失是 `test/tooling/raw_error_text_gate_test.dart`，主干存量红（FL #569）：本分支基线 develop `73c26db8` 上
      `lib/core/update/desktop_update_io.dart:34` 那句 `debugPrint('desktop update check failed: $error')` 就在，
      而 `git diff --name-only origin/develop..HEAD` 十个文件里没有它 ⇒ 不是我这次改动带的，也不在本 PR 顺手改。
- [ ] T008 收口：push → PR（Refs #579）→ 合并 → #579 留言（只做面①）→ docs 矩阵 #86 追记
      （保持「部分」）→ 父仓 bump FL 指针
- [ ] T009 面③（改键 + 持久化 + 不可改项说明）另轮接续：复用 `todo_view_preferences`
      那条通道与 specs/107 的单键 patch 读法，默认值必须等于今天的键位

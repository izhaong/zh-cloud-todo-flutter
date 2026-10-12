# 任务：⌘K 指令菜单（FL #579 面① / 矩阵 #86）

- [x] T001 现读判据源 `:9`/`:13`/`:26`-`:29` 原句与 specs/039 当年写下的倾向
- [x] T002 注册表改判 `openSearch` → `openCommandPalette`（`Ctrl+K` / `⌘K` 两条 activator 都留）
- [x] T003 `command_palette.dart`（输入即过滤、回车执行首条、空态、禁用项讲原因）
- [x] T004 `TodoWorkspace.paletteCommands` + `HomeShell._paletteCommands()`；删掉改判后无人触发的
      `_OpenGlobalSearchIntent`
- [x] T005 用例：面板 4 条 + 工作区 3 条；两处连带改判（`keyboard_shortcut_list_test.dart`、
      `task_organize_search_test.dart` 的 Ctrl+K 那条）
- [x] T006 变异探针 ⑯⑰⑱⑲ 各自红、还原后 `cmp -s` 一致
- [ ] T007 门禁：`dart format`（只跑本轮文件）、commit 后 `flutter analyze` + 全量 `flutter test`
- [ ] T008 收口：push → PR（Refs #579）→ 合并 → #579 留言（只做面①）→ docs 矩阵 #86 追记
      （保持「部分」）→ 父仓 bump FL 指针
- [ ] T009 面③（改键 + 持久化 + 不可改项说明）另轮接续：复用 `todo_view_preferences`
      那条通道与 specs/107 的单键 patch 读法，默认值必须等于今天的键位

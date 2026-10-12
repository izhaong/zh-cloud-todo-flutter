# 任务：侧栏「快捷键」入口（FL #581 / 矩阵 #86 第三种进法）

- [x] T001 现读判据源那三句入口（设置 / 侧栏 / 指令菜单-帮助），确认本单只补侧栏那一扇
- [x] T002 `_EfficiencyDock` 加第四枚「快捷键」，点击走同一个 `showKeyboardShortcutsDialog`
      （带生效键位与落库通道，`Sidebar` 自己就是 `ConsumerWidget` ⇒ 不再从 `HomeShell` 透传）
- [x] T003 用例 3 例（复算 `grep -c '^ *testWidgets(' test/features/shell/sidebar_shortcut_entry_test.dart` ⇒ 3）：
      进去可改且落库、显示的是生效键位、关掉番茄专注后这枚不许跟着消失
- [x] T004 现量黄金基线影响面：5 张变、4 张不变；三条排除性证据（几何一致、无溢出、
      无改动重跑零差异）与逐张 bbox 记在本目录 spec.md「黄金基线」那段
- [ ] T005 变异探针 ㉝–㊱ 各自红、还原后与提交字节一致
- [ ] T006 门禁：`dart format`（只跑本轮文件）、commit 后 `flutter analyze` + 全量 `flutter test` + golden 复跑
- [ ] T007 收口：push → PR（Refs #581）→ 合并 → #581 关单 → docs 矩阵 #86 那条差额注记订正 → 父仓 bump
- [x] T008 顺手把 specs/109 的 T013 勾掉（上一轮的收口格，当时写不进已合并的那笔提交）

# tasks：specs/142 侧栏标签桌面右键

- [x] 现读：`d2d96bdfb254` 上侧栏标签行无次键（判据 0 命中 + task_row_host/kanban 正向对照）、
      左滑表只有置顶；TagPage `_edit`/`_delete` 是真流程但私有。
- [x] cursor-agent 交叉验证（brief `/tmp/ctx329_brief.md`，回答 `/tmp/ctx329_answer.txt`，3440 字节）：
      推荐三项全真动作 + 共享函数提取 + 左滑表同步补齐；编辑=对话框即够格写成「编辑面」。
- [x] 红测先行：`sidebar_tag_rightclick_test.dart` 5 条（复算 `grep -c "testWidgets(" test/features/shell/sidebar_tag_rightclick_test.dart` ⇒ 5），基线 `d2d96bdfb254` 上 `+0 -5: Some tests failed`（日志 `/tmp/w16_red.log`）。
- [x] 实现：`tag_actions.dart` 增 `showTagContextMenu`/`promptEditTag`/`confirmAndDeleteTag`/
      `promptTagFields`/`canUseAsParent`/`tagPath`/`kRootParentValue`；
      `tag_page.dart` 的 `_edit`/`_delete` 改调共享函数、删除被提取的私有实现；
      `sidebar.dart` 的 `_TagRow` 根部包 `GestureDetector.onSecondaryTapDown`（Semantics 外层）、
      左滑表补两个 ListTile。
- [x] 实现过程中踩掉的两个红：① GestureDetector 包在 Semantics 内层会把读屏节点
      `focus`/`isFocusable` 挤掉 ⇒ 移到外层；② 同用例二次右键触发 MouseTracker
      配对断言 ⇒ `removePointer` 后再 add。
- [x] 定向复跑：`sidebar_tag_rightclick_test.dart` + `sidebar_tag_pin_test.dart` +
      `test/features/tag/` + `task_focus_entry_test.dart` ⇒ `+31: All tests passed!`
      （日志 `/tmp/w16_targeted3.log`）。

## 门禁读数（跑在 commit 之后的最终字节上）

- [x] `flutter analyze` ⇒ rc=0，`No issues found!`（rebase 到 `63c5cc6` 后重跑，日志 `/tmp/w16_analyze_final.log`）。
- [x] 全量 `flutter test` ⇒ rc=0，尾行 `01:15 +1582 ~26: All tests passed!`（日志 `/tmp/w16_full_final.log`）。
- [x] 反向探针（脚本 `/private/tmp/w16_probe.py`，锚点命中各 1 次、还原后字节 `cmp` 相等）：P1 右键菜单缺「编辑」⇒ 红 2 条；P2 摘右键手势 ⇒ 红 4 条（左滑用例绿，归因干净）；P3 左滑表缺「删除」⇒ 红 1 条。

## 台账自扫

- [x] `python3 tool/check_spec_selfscan.py specs/142-tag-rightclick/spec.md` 与 `.../tasks.md` 各自单独成命令跑（spec 失项 0、tasks 失项 0；tasks 曾因「全量」+量词无同行复算命令红过一条，已补）。

## 复核

- [ ] claude VERDICT 通道近几轮持续 0 字节 ⇒ **未做独立复核**；替代判据：红测先行的
      5 条（复算 `grep -c "testWidgets(" test/features/shell/sidebar_tag_rightclick_test.dart` ⇒ 5）+ 三把反向探针 +
      analyze/全量 test 读数，已写进 PR 正文。

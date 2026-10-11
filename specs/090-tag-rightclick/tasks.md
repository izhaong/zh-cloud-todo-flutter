# tasks：specs/090 侧栏标签桌面右键

- [x] 现读：`d2d96bdfb254` 上侧栏标签行无次键（判据 0 命中 + task_row_host/kanban 正向对照）、
      左滑表只有置顶；TagPage `_edit`/`_delete` 是真流程但私有。
- [x] cursor-agent 交叉验证（brief `/tmp/ctx329_brief.md`，回答 `/tmp/ctx329_answer.txt`，3440 字节）：
      推荐三项全真动作 + 共享函数提取 + 左滑表同步补齐；编辑=对话框即够格写成「编辑面」。
- [x] 红测先行：`sidebar_tag_rightclick_test.dart` 5 条，基线 `d2d96bdfb254` 上
      `+0 -5: Some tests failed`（日志 `/tmp/w16_red.log`）。
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

- [ ] `flutter analyze` ⇒ rc=0，`No issues found!`（日志见下）。
- [ ] 全量 `flutter test` ⇒ 尾行 `All tests passed!`（日志见下）。
- [ ] 反向探针 P1/P2/P3 各自「先红、还原后 `cmp -s` 回原样」证据（见下）。

## 台账自扫

- [ ] `dart run tool/check_spec_selfscan.py specs/090-tag-rightclick/spec.md` 与
      `.../tasks.md` 各自单独成命令跑（rc 不串任何写操作链）。

## 复核

- [ ] claude VERDICT 通道近几轮持续 0 字节 ⇒ **未做独立复核**；替代判据：红测先行的
      5 条 + 三把反向探针 + analyze/全量 test 读数，已写进 PR 正文。

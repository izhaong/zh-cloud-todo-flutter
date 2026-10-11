# tasks：specs/091 桌面右键任务 →「标签」

- [x] 现读：`b66bca1338a4` 上右键菜单只有「开始专注」「更多操作」（`git grep -c "Text('标签')" b66bca1338a4 -- lib/features/task/widgets/task_row_host.dart` ⇒ 0，同命令换 `sidebar.dart` 得 1 ⇒ 判据非恒假）；`#408`/`#328`/`#332` 已被并行会话收口（Issue 均 closed），#331 是 #21 翻「有」前的最后一个缺口面。
- [x] 红测先行：`task_row_rightclick_tag_test.dart` 5 条（复算 `grep -c "testWidgets(" test/features/task/task_row_rightclick_tag_test.dart` ⇒ 5），基线 `b66bca1338a4` 上 5 条全红且红点全在「标签」项缺失本身（tap `find.text('标签')` 找 0 个）。
- [x] 实现：`task_row_host.dart` 枚举加 `tags`、菜单插第三项（key `todo-task-context-tags`）、`_pickTags` 复用 `BatchTagPickerSheet.show` + `setTaskTags`；`batch_tag_picker_sheet.dart` 增可选 `initialSelected`（默认空集，批量入口行为零变化）。
- [x] 实现过程中踩掉的红：① `SyncChangeQueue()` 无参构造不存在 ⇒ `SyncChangeQueue(db)`（照 `detail_hash_tag_test.dart`）；② 真库/同步队列去抖计时器挂起 ⇒ `addTearDown(db.close)` + `settleTimers`（先拆树再推 8s）；③ 种子任务无 `serverId` ⇒ 菜单里本就没有「开始专注」，用例 1 不断言它。
- [x] 定向复跑：`flutter test test/features/task/task_row_rightclick_tag_test.dart` ⇒ `+5: All tests passed!`。

## 门禁读数（跑在 commit 之后的最终字节上）

- [ ] `flutter analyze` ⇒ 待 commit 后重跑并回填读数。
- [ ] 全量 `flutter test` ⇒ 待 commit 后重跑并回填读数（预跑读数 `+1587 ~26`，含本分支 5 条新用例）。
- [ ] 反向探针 ⇒ 待 commit 后重跑并回填（预跑：P1 红 5、P2 红 2、P3 红 2，日志 `/tmp/w31_probe2.log`）。

## 台账自扫

- [ ] `python3 tool/check_spec_selfscan.py specs/091-task-rightclick-tag/spec.md` 与 `.../tasks.md` ⇒ 待跑并回填。

## 复核

- [ ] claude VERDICT 通道近几轮持续 0 字节 ⇒ **未做独立复核**；替代判据：红测先行的 5 条（复算 `grep -c "testWidgets(" test/features/task/task_row_rightclick_tag_test.dart` ⇒ 5）+ 三把反向探针 + analyze/全量 test 读数，写进 PR 正文。

# 规格：桌面右键任务 →「标签」添加/创建（矩阵 #21 面 ⑧ 的 `:57` 半面）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#331（`:65` 拖到标签半面已随 !407 合并，本单只剩 `:57`）
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/04-用标签管理任务.md`
  - `:57`「- 方式一：右键单击任务，选择「标签」添加已有标签或创建新标签。」

## 缺口（改动前，基准 `origin/develop@b66bca1338a4`）

- 桌面右键菜单只有「开始专注」「更多操作」两项：
  `git grep -c "Text('标签')" b66bca1338a4 -- lib/features/task/widgets/task_row_host.dart` ⇒ 0
  （正向对照：同一条命令换 `lib/features/shell/sidebar.dart` 得 1 命中 ⇒ 判据非恒假）。
- `BatchTagPickerSheet` 无预选参数：`git grep -c initialSelected b66bca1338a4 -- lib/features/tag/batch_tag_picker_sheet.dart` ⇒ 0。

## 契约

1. **入口**：`task_row_host.dart` 的 `_showDesktopContextMenu` 增第三项
   `PopupMenuItem(value: _TaskRowContextAction.tags, key: Key('todo-task-context-tags'), child: Text('标签'))`，
   夹在「开始专注」「更多操作」之间；`switch` 加 `tags` 分支。
2. **选择器复用 `BatchTagPickerSheet`**（表内有「新建标签」一行，FL #493 那套，
   满足 ：57「添加已有标签**或创建新标签**」）；`_pickTags` 读 `tagRepo.getAll()` +
   `tagRepo.tagIdsOf(task.id)`，应用后 `tagRepo.setTaskTags(task.id, selected)`。
3. **预选当前已挂标签（`initialSelected`）**：表的「应用」是 `setTaskTags`
   全量替换语义（与详情 `_TagChips` `task_detail_pane.dart` 的 `setTaskTags(widget.taskId, _selected.toList())`
   同款），不预选就会在只勾一个新标签时把旧标签静默清掉。
   `BatchTagPickerSheet` 增可选参数 `initialSelected`（默认空集，批量入口零变化）。
4. **失败路径**：`tagRepo == null` 时 SnackBar「标签暂不可用，请稍后重试」不弹空表；
   `setTaskTags` 抛错时 SnackBar「标签保存失败，请重试」。
5. **不做的事**：移动端「更多」菜单里既有的「编辑标签」死磁贴（`onTap` 只 pop）
   是存量欠债，不在本单顺手改；桌面 hover 操作条、批量编辑入口不动。

## 红测（先写后实现，基线 `b66bca1338a4` 上 5 条全红，红点全在「标签」项缺失本身）

`test/features/task/task_row_rightclick_tag_test.dart`（复算 `grep -c "testWidgets(" test/features/task/task_row_rightclick_tag_test.dart` ⇒ 5）：
1. 右键菜单里有「标签」一项；
2. 点「标签」弹出 `BatchTagPickerSheet` 且当前已挂标签预选中、未挂的为 false；
3. 勾选并应用后 `tagIdsOf` 变为 [旧, 新]（`setTaskTags` 落库）；
4. 表内新建「新标」→ 应用后任务挂上新标签（`:57`「或创建新标签」）；
5. 标签仓库没就绪（override null）时给「标签暂不可用」SnackBar、不弹空表。

夹具照 `detail_hash_tag_test.dart`：真内存库 `AppDatabase.forTesting(NativeDatabase.memory())`
+ `appDatabaseProvider`/`syncChangeQueueProvider` 覆盖、`SyncChangeQueue(db)`；
收尾要 `addTearDown(db.close)` + `settleTimers`（拆树后把时间推过去抖窗口，
否则 "A Timer is still pending even after the widget tree was disposed."）。

## 反向探针（锚点命中各 1 次，变异前 cp 备份、还原后字节相等；日志 `/tmp/w31_probe2.log`）

- P1 删掉「标签」`PopupMenuItem` ⇒ 红 5 条（入口没了，5 条全走它）；
- P2 摘掉 `initialSelected: currentIds.toSet()` ⇒ 红 2 条：预选断言那条 +
  「应用换标签」那条（后者依赖预选保住旧标签，归因链条明确）；
- P3 把 `setTaskTags(...)` 替换成 no-op ⇒ 红 2 条（落库断言：应用换标签、新建挂上）。

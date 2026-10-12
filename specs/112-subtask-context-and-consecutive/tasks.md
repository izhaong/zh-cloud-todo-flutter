# 任务：右键添加子任务与子任务连续创建（FL #589 / 矩阵 #23 两面）

- [x] T001 现读判据源：该页是 mobile|desktop 两个 tab，`:51`（右键添加子任务）与 `:15`/`:56`（建完一条继续下一条）
      各一句；顺带发现矩阵 #23 行引的路径 `01-任务/08-…` 是死锚（真身 `02-功能指南/01-任务/09-…`），交 docs 订正
- [x] T002 抽共享入口 `lib/features/task/subtask_flow.dart`：`addSubtaskFlow(context, ref, parent, {stillCurrent})`，
      深度守卫与文案只有一份；详情层 `_addSubtask` 改成一层转调，它自己那条 stale 判定用回调留在原地
- [x] T003 右键那档：`_TaskRowContextAction` 加 `addChild`，菜单项 key `todo-task-context-add-child`，排在「标签」之后，
      点击走 `addSubtaskFlow`（不新做第二个界面）
- [x] T004 连续档：`TaskQuickAddSheet._consecutive = parentTaskId != null`；`_afterSaved()` 清空标题、
      抢回焦点、**复位 `_savedTaskId`**、把刚建的那条写进 `todo-quick-add-feedback`；主建表（无 parentTaskId）行为不改
- [x] T005 用例 9 条（复算 `grep -c "testWidgets(" test/features/task/subtask_context_and_consecutive_test.dart` ⇒ 9）：
      右键菜单里有这一档且旧的三档没被挤掉、点开是同一张表（标题「新建子任务」）、第 6 层只给守卫文案不开表、
      建完第一条表留着且能建第二条、键盘换行同样建一条、优先级保留、主建表照旧关、320px+1.3 连建两条不溢出、
      详情层那条路仍开同一张表
- [x] T006 变异探针七发，各自红在期望用例上、还原后 `git status --porcelain` 为空：
      P-a 去掉 `_savedTaskId = null` ⇒ 红「建完第一条表留着」那条（第二次保存只补提醒，库里少一条）；
      P-b `_consecutive` 恒 false ⇒ 红连续档四条，而「主建表照旧关」仍绿（证明我没把快速添加整体改成连续档）；
      P-c 右键那档不接线 ⇒ 红"弹出同一张表"+"第 6 层守卫"两条；
      P-d 把 `depth >= 5` 抬成 `>= 99`（等于摘掉守卫）⇒ 只红第 6 层那条；
      P-d2 把守卫整段删掉（开了表再拒）⇒ 也只红那一条 ⇒ 「守卫必须在开表之前」这条判得住；
      P-e 不清标题 ⇒ 红"建完第一条表留着"；
      P-f 回执置空 ⇒ 红"建完第一条表留着"。
      **踩到的一次假探针**：P-f 第一版写成 `savedTitle == ''`，落在三元的条件位上、else 分支照旧 ⇒ 变异是空操作、
      九条全绿。第二版改成直接把回执置 null 才红。⇒ 每次变异先问"它到底改了哪一侧"，别把"跑完没红"当"测试无效"。
- [x] T007 结构约束复算（守卫复制两份在控件层测不出来，只能这样钉）：
      `git grep -c 已达最大嵌套层数 -- lib` ⇒ 只有 `lib/features/task/subtask_flow.dart:1` 一处
- [x] T008 门禁（三项都跑在最后一笔**代码**提交 `c54aedef` 之后；其后 `9d2ad02d` 只动本目录两份 md，
      `git diff --name-only c54aedef..HEAD` 为证）：`dart format` 只跑本轮文件，跑前逐文件证过
      `task_detail_pane.dart`/`task_quick_add_sheet.dart`/`task_row_host.dart` 在 `origin/develop` 字节上已是
      格式化干净的（`--set-exit-if-changed` rc=0、0 changed）；`flutter analyze --no-pub` ⇒ **No issues found**；
      全量 `flutter test --no-pub` ⇒ **1816 通过 / 26 跳过 / 1 失**，那 1 失是主干存量红
      `test/tooling/raw_error_text_gate_test.dart`（两条 Finding 逐字在 `origin/develop` 上，FL #569 家族，本分支没碰）；
      通过数与上一轮 1807 差 **9** = 本轮新增用例数（复算 `grep -c "testWidgets(" test/features/task/subtask_context_and_consecutive_test.dart` ⇒ 9）；
      golden ⇒ **9 张全过**；门禁后 `git status --porcelain` 为空（没有 pub get 顺手改 lock 文件）
- [ ] T009 收口：push → PR（Refs #589）→ 合并 → #589 关单 → 矩阵 #23 追记（四面减到两面，状态仍「部分」）
      → docs 死锚订正 → 父仓 bump

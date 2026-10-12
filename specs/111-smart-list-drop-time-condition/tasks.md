# 任务：拖动到智能清单上（FL #400 / 矩阵 #32 拖动排期 ④）

- [x] T001 现读前置：`pulls/380` 回读 `merged: true` ⇒ #400 单正文那条「不排进 !380 合并之前」已解除；
      判据源 `:61`/`:63` 两句取原文
- [x] T002 口径取定：落点日＝该档智能清单过滤谓词窗口首日（不新造规则）。
      这一步走 `cursor-agent` 交叉验证（`CROSSCHECK: A`），三条追问（范围只含三档、区间取首日、
      窗口内即 skip）都被推荐为 A 侧；推荐里那句「移至收集箱已有独立动作」不是本单裁定的依据，
      收集箱不做落点的依据是 `:63` 那句「关联的时间条件」在它身上没有语义可落（代码注释逐档写明）
- [x] T003 `lib/features/shell/smart_list_time_condition.dart`：窗口 + 落点日 + `satisfiedBy`；
      `smartListTimeConditionOf` 对无日期窗口的五档返回 null
- [x] T004 三层接线：`TaskViewActionRepository.scheduleTaskToDay`（由 `addToToday` 泛化，
      `addToToday` 只剩一层转调）→ `SidebarTaskDropController.acceptsSmartList` /
      `applySmartListTimeCondition`（provider 加第三条接缝 `scheduleToDay`）→
      `sidebar.dart` 的 `_SmartListDropZone` 包住今天/明天/最近七天三行
- [x] T005 用例 5 + 5 + 8 + 4 例（复算：`grep -c '^ *test(' test/features/shell/smart_list_time_condition_test.dart` ⇒ 5；
      `grep -c '^ *test(' test/features/shell/sidebar_smart_list_drop_test.dart` ⇒ 5；
      `grep -c 'testWidgets(' 同文件` ⇒ 8；仓储新增一组 ⇒ 4）。
      变异探针七发，各自红在期望用例上、还原后 `git status --porcelain` 为空：
      P1 最近七天上界 +8d→+9d ⇒ 红「逐日对账」+「窗口边界」；
      P2 今天的落点日挪到明天 ⇒ 红「落点日都落在自己的窗口里」+「拖到「今天」行」；
      P3 摘掉 `applySmartListTimeCondition` 里的 skip（与 P3b 对照，见下）⇒ 红「截止已在今天 ⇒ skipped」；
      P3b `acceptsSmartList` 恒 true ⇒ 红「截止已在今天 ⇒ skipped」+「截止已在「最近七天」窗口里（+3 天）」；
      P4 落点 key 改名 ⇒ 八条控件用例全红（含「收集箱行不是落点」那条的正向对照）；
      P5 摘掉仓储同一天兜底 ⇒ 红「截止日已在目标日 ⇒ 一行都不写」，并顺带把既有那条
      「无日期推荐任务添加到今天…不重复入队」也弄红（证明 `addToToday` 确实还走这条路）；
      P6 provider 接缝多加一天 ⇒ 红「拖到「今天」行」+「拖到「最近七天」行」。
      **分层事实（不是遗漏）**：P3 只红在编排层、P5 只红在仓储层，控件层那两条各自被 P3b/P4/P6 咬住 ——
      落点侧 `accept` 与编排侧 `acceptsSmartList` 是两道闸，摘掉任意一道都还有另一道兜底，
      所以「+3 天已在窗口内」那条控件用例专门设计成仓储兜底拦不住的样子（注释写明）
- [x] T006 门禁（全部跑在最后一笔代码提交 `61bcc3b8` 之后；其后的 `f13c73b0` 只动本目录两份 md，
      `git diff --name-only 61bcc3b8..f13c73b0` 为证）：
      `dart format` 只跑本轮四个改动文件 + 一个新文件，跑前逐文件证过它们在 `origin/develop` 字节上
      已是格式化干净的（`sidebar.dart`/`sidebar_task_drop.dart`/`task_view_action_repository.dart`/
      `sidebar_task_drop_test.dart`/`task_view_action_repository_test.dart` 五个全部 develop-clean）；
      `flutter analyze --no-pub` ⇒ **No issues found**（/tmp/fl-291-analyze.log）；
      全量 `flutter test --no-pub` ⇒ **1805 通过 / 26 跳过 / 1 失**（/tmp/fl-291-fulltest.log）。
      那 1 失是主干存量红 `test/tooling/raw_error_text_gate_test.dart`，两条 Finding
      （`lib/core/update/desktop_update_io.dart:24` 与 `:34` 的 `debugPrint('… $error')`）
      都逐字存在于 `origin/develop`（`git grep -c "update check failed" origin/develop -- 同文件` ⇒ 2），
      本分支一行没碰那两处 ⇒ 不顺手修，跟 FL #569 那单走。
      通过数与上一轮（第 290 轮 1783）差 **22** = 本轮新增用例数 5+5+8+4，两条账对得上；
      golden `flutter test test/visual/todo_workspace_golden_test.dart` ⇒ **9 张全过、零重录**
      （套一层 `DragTarget` 在无候选时原样返回 child，这条预期由实测兑现，不是推理）
- [ ] T007 收口：push → PR（Refs #400）→ 合并 → #400 关单 → 矩阵 #32 行「拖动排期」只剩的这一面翻「有」
      （六处数字同批同步）→ 父仓 bump

# 任务：拖动到智能清单上（FL #400 / 矩阵 #32 拖动排期 ④）

- [x] T001 现读前置：`pulls/380` 回读 `merged: true` ⇒ #400 单正文那条「不排进 !380 合并之前」已解除；
      判据源 `:61`/`:63` 两句取原文
- [x] T002 口径取定：落点日＝该档智能清单过滤谓词窗口首日（不新造规则）。
      这一步走 `cursor-agent` 交叉验证（`CROSSCHECK: A`），三条追问（范围只含三档、区间取首日、
      窗口内即 skip）都被推荐为 A 侧；推荐里那句「移至收集箱已有独立动作」不是本单裁定的依据，
      收集箱不做落点的依据是 `:63` 那句「关联的时间条件」在它身上没有语义可落（代码注释逐档写明）。
      第二轮（`CROSSCHECK2: B`）是只读复核判红之后追加的：A 案（挪日改成按设备当地日写）会同时改掉
      `addToToday`、`calendarDueAtForDay`（`calendar_view.dart:323`）与时间线挪动（`timeline_view.dart:1255`、`:1506`）
      四处已合并行为，且 `taskDateTimeForDisplayDay` 的注释写着锚点域是刻意的 ⇒ 本单采 B：收窄口径 + 加现状锁 + 另立 #587
- [x] T003 `lib/features/shell/smart_list_time_condition.dart`：窗口 + 落点日 + `satisfiedBy`；
      `smartListTimeConditionOf` 对无日期窗口的五档返回 null
- [x] T004 三层接线：`TaskViewActionRepository.scheduleTaskToDay`（由 `addToToday` 泛化，
      `addToToday` 只剩一层转调）→ `SidebarTaskDropController.acceptsSmartList` /
      `applySmartListTimeCondition`（provider 加第三条接缝 `scheduleToDay`）→
      `sidebar.dart` 的 `_SmartListDropZone` 包住今天/明天/最近七天三行
- [x] T005 用例 5 + 5 + 8 + 6 例（复算：`grep -c '^ *test(' test/features/shell/smart_list_time_condition_test.dart` ⇒ 5；
      `grep -c '^ *test(' test/features/shell/sidebar_smart_list_drop_test.dart` ⇒ 5；
      `grep -c 'testWidgets(' 同文件` ⇒ 8；仓储新增一组 ⇒ 6，同文件整体 26 条）。
      变异探针七发，各自红在期望用例上、还原后 `git status --porcelain` 为空：
      P1 最近七天上界 +8d→+9d ⇒ 红「逐日对账」+「窗口边界」；
      P2 今天的落点日挪到明天 ⇒ 红「落点日都落在自己的窗口里」+「拖到「今天」行」；
      P3 摘掉 `applySmartListTimeCondition` 里的 skip（与 P3b 对照，见下）⇒ 红「截止已在今天 ⇒ skipped」；
      P3b `acceptsSmartList` 恒 true ⇒ 红「截止已在今天 ⇒ skipped」+「截止已在「最近七天」窗口里（+3 天）」；
      P4 落点 key 改名 ⇒ 八条控件用例全红（含「收集箱行不是落点」那条的正向对照）；
      P5 摘掉仓储同一天兜底 ⇒ 红「截止日已在目标日 ⇒ 一行都不写」，并顺带把既有那条
      「无日期推荐任务添加到今天…不重复入队」也弄红（证明 `addToToday` 确实还走这条路）；
      P6 provider 接缝多加一天 ⇒ 红「拖到「今天」行」+「拖到「最近七天」行」。
      P7 只把侧栏 `accept:` 闭包改成恒 true ⇒ **全 13 条仍绿，且这是对的**：编排层那道闸还在 skip，
      这次变异是行为等价的，所以不存在能咬住它的用例（只读复核指出这点，我实测复现了）。
      上一条的原文「摘掉任意一道都还有另一道兜底」是对的，但我据此写的
      「+3 天那条是唯一能咬住摘掉条件判断的」过头了 —— 它咬住的是**共享判据 `acceptsSmartList` 被摘**（P3b），
      不是「侧栏那层单独被绕过」（P7 证明那种绕过不改变行为）。台账与提交信息按 P7 的读数改成上面这版。
      P8 把 `taskDateTimeForDisplayDay` 的钟点基准从 `_storageLocation` 换成 `_displayLocation`（＝#587 的 A 案）
      ⇒ 只红在新加的那条「固定时区档挪的是锚点区日历日」，同文件其余 25 条仍绿
      ⇒ 这条用例锁住的正是那个"写哪一个日历日"的域选择；顺带量出 A 案的爆炸半径是四条入口共用一个 helper
- [x] T006 门禁（全部跑在最后一笔代码提交 `61bcc3b8` 之后；其后的 `f13c73b0` 只动本目录两份 md，
      `git diff --name-only 61bcc3b8..f13c73b0` 为证）：
      `dart format` 只跑本轮四个改动文件 + 一个新文件，跑前逐文件证过它们在 `origin/develop` 字节上
      已是格式化干净的（`sidebar.dart`/`sidebar_task_drop.dart`/`task_view_action_repository.dart`/
      `sidebar_task_drop_test.dart`/`task_view_action_repository_test.dart` 五个全部 develop-clean）；
      `flutter analyze --no-pub` ⇒ **No issues found**（/tmp/fl-291-analyze.log）；
      全量 `flutter test --no-pub` ⇒ **1807 通过 / 26 跳过 / 1 失**（/tmp/fl-291-fulltest2.log；
      加了两条口径用例的那一轮之后重跑，第一次跑的是 1805 = 1807 − 2，两次都对得上）。
      那 1 失是主干存量红 `test/tooling/raw_error_text_gate_test.dart`，两条 Finding
      （`lib/core/update/desktop_update_io.dart:24` 与 `:34` 的 `debugPrint('… $error')`）
      都逐字存在于 `origin/develop`（`git grep -c "update check failed" origin/develop -- 同文件` ⇒ 2），
      本分支一行没碰那两处 ⇒ 不顺手修，跟 FL #569 那单走。
      通过数与上一轮（第 290 轮 1783）差 **24** = 本轮新增用例数 5+5+8+6，两条账对得上；
      golden `flutter test test/visual/todo_workspace_golden_test.dart` ⇒ **9 张全过、零重录**
      （套一层 `DragTarget` 在无候选时原样返回 child，这条预期由实测兑现，不是推理）
- [x] T006.5 只读交叉复核（`cursor-agent -p --trust`，输出 3612 字节，`REVIEW: FAIL`）提了两条，两条都自己复验过：
      ① 固定时区跨午夜时「拖完出现在那一档」不成立 —— 我用一次性探针复现（`stored=2026-10-13 16:30Z`、
      `display=2026-10-14 00:30`、`inDeviceLocalTodayWindow=false`），处置见 T002 与 spec.md 需求 1，另立 #587；
      ② 侧栏 `accept` 闭包单独改成恒 true 不会让任何用例红 —— 实测复现（P7，13 条全绿），
      那条不是测试缺口而是行为等价，我把台账里过头的那句改掉了（见 T005）。
      探针文件 `test/tz_probe_test.dart` 是临时的，跑完即删（`git status --porcelain` 为空为证）。
- [ ] T007 收口：push → PR（Refs #400）→ 合并 → #400 关单 → 矩阵 #32 行「拖动排期」只剩的这一面翻「有」
      （六处数字同批同步）→ 父仓 bump

# Todo 日历显示设置任务

- [x] T001 红测：已完成任务默认不出现在日历；开关打开后出现。
- [x] T002 偏好层：`getCalendarDisplay` / `saveCalendarDisplay`，含「只写开关不得把 viewType 兜底成 list」。
- [x] T003 界面：「显示设置」入口 + 「显示已完成」开关 + 恢复与失败提示。
- [x] T004 窄屏与读屏语义用例。
- [ ] T005 全部门禁 + 只读复核 + 回写矩阵 #31。

## 执行证据

- 2026-09-22：立项依据经实地核对成立 —— `calendar_view.dart` 全文对 `TodoTask.completed` 零消费，日历任务直接来自 `TaskRepository.watchAll()`（`home_shell.dart:766-774`），即**已完成任务无条件出现在五种模式里**；嘀嗒默认隐藏，由「显示设置 → 显示已完成」控制（《02-功能指南/02-日历/06-日历显示设置.md》「其他显示选项」）。
- 2026-09-22：偏好层新增 `getCalendarDisplay()` / `saveCalendarDisplay({viewMode, showCompletedTasks})`，复用既有 `calendar_view`/`task_calendar` 那一行；`TaskWorkspacePreference` 增 `showCompletedTasks`。**模式与开关必须成对写**：`_saveViewPreference` 在 `viewType` 缺失时会兜底成 `list`，只写开关会静默把用户的视图模式改掉，用例 `开关与视图模式同行持久化…写开关不会改掉视图模式` 锁住这一点。旧的 `saveCalendarViewMode`/`getCalendarViewMode` 与随之失去调用方的 `_getViewPreference` 已删除，不留兼容壳。
- 2026-09-22：过滤放在一处（`_visibleTasks` getter）再喂给五种模式，不在各子视图重复；`_DisplaySettingsSheet` 是 `ModalBottomSheet` 里的单个 `SwitchListTile`；入口按钮自带 `Semantics(container+button+label:'显示设置'+onTap)` 包 `ExcludeSemantics(IconButton)` —— 实测 `find.bySemanticsLabel('显示设置')` 在只有 `Tooltip` 时命中 0 个，与 024 同一结论：图标按钮的 tooltip 不构成可断言的语义标签。
- 2026-09-22：新文件 `test/features/task/calendar_display_settings_test.dart` 6 项用例全绿：默认隐藏/开启后出现、模式与开关成对持久化并在重进时恢复、日程模式下同样恢复、**写失败时保留已生效状态并提示**（`_ThrowingRepository`）、**未配置仓储时开关仍然生效只是不持久化**（避免把入口做成死按钮）、320px + 1.3 倍字体下入口与开关具备读屏语义且无溢出。`flutter analyze` `No issues found!`。
- 2026-09-22：**发现并修掉自己引入的回归（FR-005）**。`CalendarView` 有两个调用点：`home_shell.dart:774`（日历页）与 `tasks_by_list_page.dart:453`（清单页的日历子视图）。后者喂进来的是 `applyTaskFilter` 的结果，而该筛选支持「只看已完成」（`tasks_by_list_page.dart:2023`）—— 若无条件叠加日历自身的隐藏，用户筛出已完成任务再切到日历会被清成空列表。修法：新增 `filterCompleted`（默认 true）让宿主决定是否叠加，清单页传 false；同时**该上下文里不再渲染「显示设置」入口**（`onOpenSettings: null` → `SizedBox.shrink()`），因为一个改了没有可见效果的开关是死控件。用例 `宿主自行决定已完成显隐时…` 同时断言两条契约；RED 有效性用两次独立探针验证：把 `_visibleTasks` 的 `!widget.filterCompleted ||` 去掉 → 该用例失败；把 `onOpenSettings` 改回无条件传 → 同样失败；两次后 `cmp -s` 确认 `calendar_view.dart` 与探针前逐字节一致。
- 2026-09-22：本轮早前还跑过 `/tmp/gate-025.log`，**作废**。原因是我自己的操作失误：一条原地写盘的 `dart format` 误传了目录参数 `lib/state test/features`，把 7 个与本轮无关的 tracked 文件重排了。用 `git diff -w` 逐处确认为纯折行合并、零语义变化后 `git checkout --` 还原并重跑。坑已强化进记忆：formatter 的原地写盘参数只能是本轮明确改过的文件路径，一个目录都不给。
- 2026-09-22：最终状态六项门禁重跑（权威日志 `/tmp/gate-025d.log`，取代 `gate-025c.log`/`gate-025b.log`）：`git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 对 4 个显式路径 `Formatted 4 files (0 changed)` exit=0；`flutter analyze` `No issues found!`；`flutter test --tags golden` `00:03 +9: All tests passed!`（9 张黄金图未变，无需申请重录）；`flutter test --exclude-tags 'golden || performance' --concurrency=1` `01:45 +717 ~26: All tests passed!`；`flutter build web --release --dart-define=TODO_API_BASE_URL=… --dart-define=TODO_TENANT_ID=1` `✓ Built build/web`。
- 2026-09-22：**存量排版欠债不混入本切片**，并用只读方式证明本轮没加重它。`tasks_by_list_page.dart` 在 HEAD 就已经不过 `dart format` 门禁（属那 15 个存量文件之一），所以本轮那两行是按周围风格手工插入的，未整文件重排。验证方式：分别把 HEAD 版与工作树版复制到 `/tmp/fmt025/` 后各自格式化再 diff，输出只有本轮新增的两行（`454a455,456`：一行注释 + `filterCompleted: false,`），即偏离集合与 HEAD 完全相同。
- 2026-09-22：**只读复核未获得 VERDICT，且原因不是代码问题**。`claude -p … --permission-mode plan` 那一次运行没有产出任何审查正文，`/tmp/review-025.out` 里只有工具自身的报错：`"Top1" isn't described by this version's model catalog`（`[claude-code:unrecognized_model]`）。按诚实规则记为**未执行**，不记为通过。第二次尝试加 `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` 后跑通，拿到 `VERDICT`，见下方 2026-09-23 条。
- 2026-09-22：计数核对（避免把分支差异误读成回归）：**717 = 712 减 3 加 8**。减的 3 项是 020 的分页用例，已随 `fix/020-search-page-cursor` 提交、不在本分支工作树，而 712 正是在那 3 项仍未提交时量到的；加的 8 项全部来自本切片（6 项开关行为 + 宿主契约 + 过期响应守卫）。另记一笔防误读：024 的 11 项用例已移到 `feat/024-countdown-manage`（`daf2145`），本分支工作树里没有它们 —— 跨分支比测试数前必须先确认本树含哪些用例。
- 2026-09-23：只读复核返回 **`VERDICT: FAIL`**（`/tmp/review-025c.out`），一条 Important 成立并已按结论修：
  **FR-003「重启后恢复」此前是假阳性** —— 两条「重进页面恢复」用例的第二次 `_pump` 复用同一 Widget 树且**没传 key**，
  Flutter 会**复用 `_CalendarViewState`**，`initState` 不再执行、`_restoreDisplay` 从未被跑到，
  断言通过靠的是上一次 pump 遗留在内存里的 `_showCompleted`/`_mode`。即「恢复」这条 FR 的唯一生产路径零覆盖。
  修法：`_pump` 增 `viewKey`，两处恢复用例传 `viewKey: 'reloaded'` 强制重建 State。
  **改后实测**：把 `initState` 里 `Future<void>.microtask(_restoreDisplay)` 那一行摘掉后跑本文件 →
  `00:01 +1 -2: Some tests failed.`，失败正是那两条恢复用例；恢复该行后 `00:01 +8: All tests passed!`，
  `cmp -s` 确认 `calendar_view.dart` 与探针前逐字节一致。故这两条现在真的依赖恢复路径，不再是内存态自证。
- 2026-09-23：同一条用例顺带修掉复核点出的**空转断言** —— `find.bySemanticsLabel('显示设置') findsNothing`
  在未 `ensureSemantics()` 时恒 0 命中（语义树没开，永远查不到），已补 `ensureSemantics` 让它成为有效断言；
  同用例另有 `find.byKey(..., findsNothing)` 独立兜底，所以原判定结论没被这条影响。
- 2026-09-23：复核的两条 Minor **判定不采纳**，理由如下（不沉默丢弃）：
  ① 「`_persistDisplay` 应在 `filterCompleted=false` 时短路」—— 清单页与日历页**共用同一行偏好**
  （`calendar_view`/`task_calendar`），整条短路会连带丢掉清单页视图模式的持久化，而收益只是少写一个
  无副作用的字段（复核自己也确认「无可见危害」）；要只写模式就得再加一个 mode-only 写入口，属未要求的抽象。
  ② 「错误文案应改为 `…保存失败，请重试` 以对齐本仓惯例」—— 现文案「日历显示设置保存失败，当前修改仅本次生效」
  多带了 FR-003 承诺的语义（**不回滚、仅本次生效**），比惯例文案更准确，保留。
  ③ 复核建议的 `int _restoreRevision` 序号守卫，已由上文的 `_displayTouched` 覆盖同一失效场景
  （每个 State 只有一次恢复，序号法与「用户已动过」判定在此等价），采用后者因其语义更直白。
- 2026-09-22：按目标要求补读该仓 Issue：`zh-cloud-todo-flutter` 与 `zh-cloud-docs` 的 open Issue 里除我本轮建的 #258–#263、docs #68/#69 外，最新人类评论停在 docs #55 `2026-07-30`（Flutter #202–#205 合并记录、并明确「T031 对照矩阵仍未在 Docs 仓闭环」），与本切片结论不冲突。025 尚未建 Issue（建 Issue 属外部状态，待授权）。
- 2026-09-23：**不再加复核轮次**（用户既定口径：不为拿 `PASS` 反复重跑同一环节）。本轮复核已实际执行并拿到 `VERDICT`，
  其成立结论已全部修掉并实测；`gate-025d` 之后又改过测试文件，故六项门禁在最终状态重跑一遍，日志 `/tmp/gate-025e.log`。

- 复核的 Important-2 成立，但属提交卫生而非代码问题：工作树里 `pubspec.lock` 有 ~150 处
  `pub.dev → pub.flutter-io.cn` 的换源翻转与真实版本变更（`4.1.1→4.1.6`、`2.2.0→3.2.0`），
  与本轮无关，按目标约定**永不提交**；提 PR 时 `git add` 必须精确到本轮 5 个代码/测试路径 + `specs/025-*`，不得 `git add -A`。
  本轮文件集：`lib/features/task/views/calendar_view.dart`、`lib/state/repositories/task_view_action_repository.dart`、
  `lib/features/task/tasks_by_list_page.dart`（仅两行传参）、`test/features/task/calendar_display_settings_test.dart`、
  `test/task_view_action_repository_test.dart`。

- 2026-09-22：**自查发现并修掉一处过期响应覆盖**。`_restoreDisplay` 由 `initState` 的 microtask 发起、里面还要 `await` 一次 Drift 读，而 `_Toolbar` 在第一帧就已可点 —— 用户若在偏好读回来之前切了视图，`_changeMode` 先把 `_mode` 设成「日程」，随后迟到的旧值（`month`）会在同一个 `setState` 里把它弹回去。目标要求的「过期响应不覆盖新响应」正是这一条，此前的 6 项用例结构上测不到（它们都是 `pumpAndSettle` 之后才动作，恢复必然先完成）。修法用最小的一处状态：`bool _displayTouched`，在 `_changeMode` 与 `_showDisplaySettings` 入口置位，`_restoreDisplay` 在 `mounted`/`saved == null` 之外多一道 `_displayTouched` 早退。
- 2026-09-22：该竞态是**先红后绿实测出来的**，不是纸面论证。用 `_SlowRepository`（`getCalendarDisplay` 挂在一个 `Completer` 上）写新用例：修复前 `00:01 +6 -1 ... 偏好读取在途时用户已切换视图，迟到的旧值不得回滚 [E]`（断言点在 `calendar_display_settings_test.dart:248`，即 release 之后日程标签已被换回月标签）；修复后本文件 `00:01 +8: All tests passed!`。规格侧同步把这条约束写进 FR-003（恢复是异步的，迟到的旧值必须作废）。
- 2026-09-22：按嘀嗒原文收紧了本切片范围 —— 《06-日历显示设置》「其他显示选项」写的是「显示已完成」管**任务、打卡与订阅日历事件**三类内容，本 FR-001 只接**任务**一类（习惯打卡与倒数纪念日目前根本不进日历），已在 `spec.md` 边界里显式记一条，避免后来者把这个开关误读成已全量对齐。


## 未勾项与下一步

- T005 未勾，剩余条件**只剩一条**：矩阵 #31 的状态翻转要引**已合并**的 commit SHA，而本切片改动目前只在 `zh-cloud-todo-flutter` 工作树（分支未建、PR 未开，**待授权**）。已满足的部分：六项门禁在最终状态全绿（`/tmp/gate-025e.log`）、只读复核已实际执行并拿到 `VERDICT: FAIL` 且其成立结论全部修掉并实测。
- 下一轮（第 3 轮）入口改成了第 0 轮第二批新暴露的那条：把 `ListPage`/`FolderPage` 与 `EfficiencyHubPage` 接进导航 —— 对照矩阵已把 `19`、`18`、`76–78` 判为「部分」，缺口全部是「实现齐但无入口」，属可离线自足的小改动面、用户可感知度高（清单连改名都做不到）。嘀嗒侧的入口口径见《01-任务/08-如何管理海量任务/02-用清单管理任务》：侧边栏**左滑**清单 → 「置顶 / 编辑 / 删除」，编辑页含名称、颜色、所属文件夹；文件夹则经「添加-清单-更多设置-文件夹」创建、左滑/长按解散。
- 本轮新登记的实现细节：`specs/024` 的 T005 与本切片共用同一个工作树，`filterCompleted` 只影响 025 的两个文件与清单页那一行传参，不触碰 024 的倒数日文件集。
- 下一个门槛（同属 #31，需先改后端契约）：显示农历与节假日调休。BE `AppTodoCalendarController.java:40/50` 有 `/holidays?year` 与 `/lunar-date?date`，但农历是**单日查询**，月视图 42 格要 42 次请求 → 须先加区间端点，不得由 Flutter 内置农历表绕过。
- 再下一个门槛（纯客户端）：已完成项在开启后的可辨识呈现（删除线/次要色），嘀嗒在日历里对已完成任务是可辨识的。

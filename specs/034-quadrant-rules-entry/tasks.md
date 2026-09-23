# 四象限规则入口 任务清单

## 已证实（每条都有命令输出或反向探针为凭）

- [x] T001 入口只出现在四象限视图的「...」菜单里，其它视图一项不多（FR-1、FR-3）。
  证据：`test/features/task/quadrant_rules_entry_test.dart` 用例 1 —— 列表视图下打开 `todo-sort-menu`
  断 `find.text('编辑象限规则')` `findsNothing`，切到四象限后同一条 finder 断 `findsOneWidget`。
  反向探针 PA（把回调改成四种视图常驻）⇒ 该用例**红**，证明负向半边不是空转。
- [x] T002 点入口真的进到 `QuadrantRulesPage`，返回后仍停在四象限视图（FR-2）。
  证据：用例 2 断 `find.byType(QuadrantRulesPage)` `findsOneWidget` + 标题「四象限规则」，
  `BackButton` 返回后断 `find.byType(EisenhowerView)` `findsOneWidget`。
  反向探针 PB（点击不导航）⇒ 该用例红。
- [x] T003 失败要说出来，不伪装成空态（四件套之「失败保留已加载数据」在本页的可执行形式）。
  证据：用例 2 断「规则加载失败」+「重试」在，且「还没有四象限规则」
  （空态文案 `quadrant_rules_page.dart:371`）不在 ⇒ 报错没被当成「一条规则都没有」。
  **归因经复核更正**：取数必然失败**不是**夹具的 `_NoNetworkApiClient` 拦的 —— 它覆写的是 `ApiClient.get/post`
  （`test/support/todo_visual_fixture.dart:462`），而 `QuadrantApi` 拿的是 `apiClient.raw` 那个 Dio
  直连（`state/efficiency_providers.dart:21`、`core/api/efficiency_api.dart:496-502`）⇒ 绕过覆写，
  被 flutter_test 默认掐断真实 socket 才失败。这条更正很重要：
  以后有人「用 provider override 造一个成功态」并不会让这条用例变绿，机制得说对才不误导。
- [x] T004 320px + 1.3 倍字体不溢出，且档位**在 push 出来的路由自己的 context 上**自检（四件套）。
  证据：用例 4（第 13 轮第 2 次修订后它在文件里的位置是第 4 条，本段编号按**文件内出现顺序**）
  以 `Size(320, 720)` 泵壳、切四象限、点开菜单项，然后
  `MediaQuery.textScalerOf(tester.element(find.text('四象限规则'))).scale(10) ≈ 13` + `takeException()` 为 null。
  该用例在第 2 轮复核后又多验了一层：失败态下从入口点 AppBar「新建规则」打开编辑器弹窗不溢出
  （AppBar 动作 `quadrant_rules_page.dart:20-24` 无条件渲染 ⇒ 不需要数据态）。
  这条同时否掉了「窄屏根本切不到四象限视图」的怀疑 —— 320px 下 `todo-view-menu`、`todo-sort-menu`、
  菜单项与规则页全链路可点且不溢出。
- [x] T005 读屏：菜单项与规则页标题各有独立语义节点（FR-4 之语义）。
  证据：用例 5 用 `ensureSemantics()` + `try/finally`，
  `find.bySemanticsLabel(RegExp('编辑象限规则'))` `findsOneWidget`，
  并 `getSemantics(find.text('四象限规则')).label` 含标题。
  反向探针 PC（把菜单项包 `ExcludeSemantics`）⇒ 该用例红。
- [x] T006 六项门禁一次跑完 —— **本段是「修订前那一版字节」（4 例）的读数**，最终字节见下面「最终门禁」表。
  日志 `/tmp/gate-034.log`（2026-09-23 22:06）：
  `git diff --check` exit=0；
  `dart format --output=none --set-exit-if-changed` 三个显式文件 **exit=1**，红只在
  `lib/features/task/tasks_by_list_page.dart` —— 同一检查跑在 `git show HEAD:` 出来的该文件副本上
  同样 exit=1（`/tmp/gate-034.log` 第 2b 段），且我另两个文件单独跑是 `Formatted 2 files (0 changed)` exit=0
  （第 2c 段）⇒ 本轮红**是存量欠债**（`rename`/`_moveTaskSection` 两处排版，HEAD 里就在），
  不混进本 PR，也不为此原地格式化整文件（原地跑会顺手改掉无关代码）。
  `flutter analyze` ⇒ No issues found!；
  `flutter test --tags golden` ⇒ `00:03 +9: All tests passed!`（**未重录基线**，第 7 段 `goldens/` 改动计数 0）；
  `flutter test --exclude-tags 'golden || performance' --concurrency=1` ⇒ `02:05 +713 ~26: All tests passed!`；
  `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`
  ⇒ `✓ Built build/web`。
  **该版**字节 sha256 前 8：`155bc7ba` tasks_by_list_page.dart、`885f1447` task_workspace_header.dart、
  `13f1c927` quadrant_rules_entry_test.dart（第 1 轮复核后字节又变过，最终值在「最终门禁」表里，别引这一段）。
  对照口径：同一条全量命令在**独立 worktree 的基线点 `develop@a1d7733`** 上实测
  `02:17 +709 ~26: All tests passed!`（`/tmp/base-034.log`，跑完已 `git worktree remove`），
  该版 `+713 ~26` ⇒ **709 + 当时新增 4 例 = 713，逐一对上、无回归**（用例数后续见最终表）。
  目标里记的「基线 713/26」与该版数字相同纯属巧合 —— 那是在别的分支状态上数的，
  本规格的对照以 `709 → 最终版` 这组同口径复算为准。

## 未做 / 仍缺

- [ ] T007 规则页的**数据层竞态**（「过期响应不覆盖新响应」）没有用例。
  **第 2 轮复核把我原来的理由判成事实错误，已复验并接受**：我原先写「`pumpTodoVisualScenario` 不支持
  provider overrides 透传（该能力在未合并的 !269 上）」—— 错。实测
  `TodoVisualFixture.create` 在 **develop 上就有** `overridesBuilder` 参数
  （`git show origin/develop:test/support/todo_visual_fixture.dart` 的 `:60` 形参、`:90` `...?overridesBuilder?.call(database)`），
  且 5 个已合并用例在用它（`reminder_notification_navigation_test.dart:125`、`task_focus_entry_test.dart:81`、
  `task_kanban_reorder_widget_test.dart:23/81`、`task_list_reorder_widget_test.dart:22/63/105`）。
  真正的限制只在一层：本仓的包装 `pumpTodoVisualScenario` 没把它往下传
  （`test/support/todo_visual_test_harness.dart:35` 只 `TodoVisualFixture.create(set: fixtureSet)`）。
  ⇒ 欠债性质从「等 !269 合并」改成「要么给 harness 加一个透传参数，要么本测试自己
  `TodoVisualFixture.create(overridesBuilder:)` + 泵 `UncontrolledProviderScope`」，两者都不需要等谁。
  本轮没做的原因回到实质：绕开真实入口自己泵页测竞态，证的不是本轮这条链路；而竞态本身属
  #34/#35 的规则读取面，不属「补入口」这一格。保持未勾。
- [ ] T008 「拖动任务改象限即改优先级/时间」与嘀嗒的两套默认规则组合未动 —— 属矩阵 #34/#35 面，不在本切片。
- [ ] T009 真机/网页端手手感未做（无第二台可登录 test 的设备；`flutter build ios` 卡 SPM）。
- [ ] T010 远端 CI 未跑（runner `cgroup is not mounted`、Jenkins `zh-cloud-todo-flutter` Job 不可达）；
  本地门禁不替代远端证据。
- [ ] T011 矩阵 A 段 #34/#35/#36 三行（`dida-parity-matrix.md:105-107`）仍以已废弃的
  `zh-cloud-client` PR #44 作 FL 证据，属"轨道 A 逐行复校"未清理的存量；本轮只改有实测结论的 #36 修订行。

## 复核手段与结论

`claude` CLI 本机不可用（`unrecognized_model`），按目标约定改用本会话**只读子代理**审 FR-1..FR-5 与测试假阳性，
结论以 `VERDICT:` 行为准；复核回来前不宣称通过。

### 第一轮复核（`VERDICT: FAIL`，三条 BLOCKER）逐条处置

- **B1「`pubspec.lock` 被本机镜像重写，必须从提交中剔除」——不采纳，属事实错误。**
  复核员看到的是工作区的脏文件。实测：`git log --oneline origin/develop..HEAD -- pubspec.lock` 输出 **0 行**、
  `git diff --stat origin/develop..HEAD -- pubspec.lock` 空，PR !284 的文件清单里也没有它
  （`git diff --name-only origin/develop...HEAD` 只有 4 个代码/测试文件 + 3 个 specs 文件）。
  它从头到尾只是本机新 SDK 重解析的工作区噪音，按既定口径不入库。
- **B2「FR-3/FR-4 把没证的子句写成判据」——采纳。** FR-3 原先只在列表视图做负向断言，
  现改为遍历 看板/时间线/日历/列表 四种视图逐个负向，并在每个视图里先断「批量编辑」在（正对照，
  证明菜单确实展开、`findsNothing` 不是空转）；FR-4 的「同一入口连点只叠一层」**从判据里撤掉**，
  理由是 `PopupMenuMenuItem` 选中即关菜单 ⇒ 不存在可叠的第二次导航，留着就是一条永远绿的假判据。
  复核员同时独立确认负向断言机制咬得住（`WidgetController.hitTestWarningShouldBeFatal` 默认 true ⇒
  tap 落不到 `todo-sort-menu` 会直接抛，不会静默空转）。
- **B3「失败态归因错」——采纳，已按上面 T003 更正。**

### 第二轮复核（针对第 1 轮修订后的字节，`VERDICT: FAIL`：B4/B5 两条 BLOCKER + 四条 NIT）逐条处置

复核员独立复算了全量计数（`+714 ~26`、基线 `709` + 5 例逐一对上）、analyze 干净、
`dart format` 的红只在 `tasks_by_list_page.dart` 的 `rename`/`_moveTaskSection` 且在 `develop:` 副本上复现同两处
⇒ 存量结论成立；并认可 B1 的证伪。两条 BLOCKER 都是**文档/证据**问题，不涉代码：

- **B4「`tasks.md` 自称最终字节却记着修订前的数」——采纳。** 三处已改：T006 明确标成「修订前那一版（4 例）」
  的读数（`+713`、`13f1c927` 都归到那一版名下，最终值只在「最终门禁」表里给）；
  我写的「`gate-034b.log` 留着不覆盖」是**指向一个不存在的文件**（磁盘上叫 `gate-034b-superseded.log`），已改；
  最终表补上此前漏记的 `quadrant_rules_page.dart` sha256。
- **B5「`overridesBuilder` 未合并」是事实错误——采纳并复验。** 见 T007：develop 上就有该形参
  （`git show origin/develop:test/support/todo_visual_fixture.dart` 的 `:60`/`:90`），
  5 个已合并用例在用；限制只在 `pumpTodoVisualScenario` 没往下传（`todo_visual_test_harness.dart:35`）。
  测试文件里那句「数据态只能在这里造」的理由随之改写为按配置分工，并据此**动了用例结构**：
  数据态列表留在直接泵页的用例 3，编辑器弹窗补进真实入口的用例 4（AppBar 动作无条件 ⇒ 不需要数据）。
- **NIT 处置**：① 用例编号与文件顺序错位 ⇒ T001/T002/T003/T005/T012 的编号按文件内顺序改正并写明口径；
  ② `spec.md:14` 的 `:448`、`plan.md:6` 的 `:393` 是 develop 口径却未注明 ⇒ 已标基准；
  ③ `plan.md:26`「4 例」、`:30`「FR-1..FR-4」未跟上 ⇒ 已更；
  ④ `spec.md:44` 的 grep 缺 `-E`（管道被当字面量）⇒ 复核员用 `-E` 复跑仍 0 命中，结论不变，命令已补 `-E`。
- **复核员没提出但我自己复验后推翻的**：我在 T012 与矩阵里把这条写成「生产上的真缺陷 + 36 像素」。
  按 PD/PD2 差分实验（见 T012 的表）它只在默认测试字体下可观测，生产主题配置不红
  ⇒ 定性已下调，矩阵相应措辞同步改。**这条值得记着**：判据成立 ≠ 数字是生产口径，
  换个字体配置就能从红变绿的断言，不能直接写成用户会撞上的缺陷。

### 复核带出的一处排版改动（性质由「真缺陷」改判为「字体度量相关的溢出」）

- [x] T012 规则页**编辑器弹窗**在 320px + 1.3 倍字体下溢出（`A RenderFlex overflowed by 36 pixels on the right`）。
  这条以前照不到：`QuadrantRulesPage` 没有任何 in-app 入口，手机上走不到弹窗；入口一通，它就是本切片的义务。
  成因经探针定位：`DropdownButtonFormField` 未设 `isExpanded` ⇒ 选中项按内容撑宽；
  修复是一行 `isExpanded: true`（`quadrant_rules_page.dart:306`）。
  **反证过程记着有价值**：我先怀疑的是弹窗里硬编码的 `width: 480`，夹成 `min(480, 屏宽-80)` 后溢出**没消失**，
  说明紧约束早被父级夹住、那个改动是 no-op ⇒ 已回退，不把无用代码留在仓里。
  另一条自我更正：我先写的 `AlertDialog` 宽度 `< 320` 断言是错判据（实测盒子就是 320.0，铺满屏是设计行为），
  已删除，溢出才是判据。

  ### 性质改判（第 14 轮，PD/PD2 差分实验，我此前把它写成「生产真缺陷」是过头的）

  第 2 轮复核指出：弹窗那半边**不需要数据态**（`quadrant_rules_page.dart:20-24` 的 AppBar 动作无条件渲染），
  可以从真实入口在生产主题下打开。据此做了差分实验（同一处摘掉 `isExpanded`，跑同一个文件）：

  | 配置 | 用例 | 摘掉 `isExpanded` |
  | ---- | ---- | ----------------- |
  | 默认 `MaterialApp` + 测试字体 Ahem（直接泵页、有数据态） | 用例 3 的弹窗段 | **红**（`A RenderFlex overflowed by 36 pixels on the right`） |
  | 生产主题 `_visualTheme` + `TodoGoldenSans` + 真实入口（失败态） | 用例 4 的弹窗段 | **绿** |

  日志：`/tmp/pd-034-baseline.log`（含 `isExpanded`，5 例全绿）、`/tmp/pd-034-probe.log`（摘掉后 `+4 -1`，
  红的正是用例 3），恢复后 `cmp -s` 逐字节一致。⇒
  **这个溢出与字体度量绑定，`36 像素`不是生产口径的数字**；生产主题+测试字体下拿不到它，
  真机系统字体（比 `TodoGoldenSans` 更窄还是更宽）本地无法测。
  所以 `isExpanded: true` 的定性从「修掉一个生产缺陷」下调为：
  ① 它是 `DropdownButtonFormField` 在紧约束下的正确用法（选中项按可用宽度收缩而不是撑宽），
  ② 在本仓可测的两种配置里，只有默认测试字体配置会因缺它而红，
  ③ 不作为「生产上必然溢出」的证据写进矩阵——矩阵里那句「真缺陷」已按此改口径。
  用例 3 保留（它是唯一能钉住 ①/② 的判据），用例 4 补上生产路径的弹窗断言并明确标注**它抓不到 `isExpanded`**。

### 最终门禁

第 2 轮复核处置完（B4/B5 + NIT）后的最终字节跑在 `/tmp/gate-034d.log`。
它之前的两版：`/tmp/gate-034c.log`（第 1 轮复核后、5 例）、`/tmp/gate-034.log`（修订前 4 例，见 T006）；
`/tmp/gate-034b-superseded.log` 是当时误存的一版，留着不覆盖。原文抄录，供 PR 评论对照：

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 四个显式文件 | `Changed lib/features/task/tasks_by_list_page.dart` / `Formatted 4 files (1 changed)` / `exit=1` |
| 2b 同检查跑在 `git show HEAD:` 版（存量证明） | `Changed /tmp/head_p1_034b.dart` / `exit=1` ⇒ 红的是 HEAD 已有的排版欠债，不是本轮引入。该证明跑在 `gate-034c` 那一版；本轮未重复，因为 `tasks_by_list_page.dart` 的 sha256 两版同为 `155bc7ba`（字节没动） |
| 3 `flutter analyze` | `No issues found! (ran in 1.5s)` |
| 4 `flutter test --tags golden` | `00:03 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `01:53 +714 ~26: All tests passed!` |
| 6 `flutter build web --release …` | `✓ Built build/web` |
| 7 `test/goldens` 改动数 | `0` |
| 8 本轮文件 sha256 | `155bc7ba` `tasks_by_list_page.dart` / `885f1447` `task_workspace_header.dart` / `4395abc0` `quadrant_rules_page.dart` / `e2929f4c` `quadrant_rules_entry_test.dart` |
| 9 工作区脏文件 | `M pubspec.lock`（未 staged，按口径不入库）+ 本轮改动的 specs/测试文件本身 |

5 条用例同基线复算：`develop@a1d7733` 基线 `+709 ~26`（`/tmp/base-034.log`）⇒ 本轮 `+714 ~26`，
多出的正好是本切片新增的 5 例，没有别的路数被顺手改动。

### 复核轮次（截至本文件最后一次提交）

- 复核手段：`claude` CLI 本机不可用（`unrecognized_model`），按口径替换为本会话只读子代理审本轮 FR。
- 第 1 轮 `VERDICT: FAIL`（B1/B2/B3）⇒ 处置见「第一轮复核」节。
- 第 2 轮 `VERDICT: FAIL`（B4/B5 两条 BLOCKER + 四条 NIT，均针对修订后的字节）⇒ 处置见「第二轮复核」节。
  两轮结论**都有新增内容**（第 2 轮推翻了我两处事实陈述），所以按结论继续修是合规的，不是为重跑而重跑。
- **第 3 轮不再派**（两轮上限已到）。⇒ 本切片「复核拿到 PASS」这一条**没有达成**，
  留给合并的人判断：BLOCKER 是文档/证据层面的，已按命令逐条复验并改正；
  代码面第 2 轮没有提出新 blocker（其原文：「BLOCKER（均为文档/证据，不涉代码）」）。
- 第 2 轮之后我又自行复验推翻了自己一处更早写下的结论（`isExpanded` 那条「生产真缺陷」的定性，见 T012）；
  这一处不在任何一轮复核的 finding 里，是本规格目前**唯一一处主动改判**。

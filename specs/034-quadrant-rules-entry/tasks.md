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
  证据：用例 3 以 `Size(320, 720)` 泵壳、切四象限、点开菜单项，然后
  `MediaQuery.textScalerOf(tester.element(find.text('四象限规则'))).scale(10) ≈ 13` + `takeException()` 为 null。
  这条同时否掉了「窄屏根本切不到四象限视图」的怀疑 —— 320px 下 `todo-view-menu`、`todo-sort-menu`、
  菜单项与规则页全链路可点且不溢出。
- [x] T005 读屏：菜单项与规则页标题各有独立语义节点（FR-4 之语义）。
  证据：用例 4 用 `ensureSemantics()` + `try/finally`，
  `find.bySemanticsLabel(RegExp('编辑象限规则'))` `findsOneWidget`，
  并 `getSemantics(find.text('四象限规则')).label` 含标题。
  反向探针 PC（把菜单项包 `ExcludeSemantics`）⇒ 该用例红。
- [x] T006 六项门禁在最终状态一次跑完，日志 `/tmp/gate-034.log`（2026-09-23 22:06）：
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
  最终字节 sha256 前 8：`155bc7ba` tasks_by_list_page.dart、`885f1447` task_workspace_header.dart、
  `13f1c927` quadrant_rules_entry_test.dart。
  对照口径：同一条全量命令在**独立 worktree 的基线点 `develop@a1d7733`** 上实测
  `02:17 +709 ~26: All tests passed!`（`/tmp/base-034.log`，跑完已 `git worktree remove`），
  本分支 `+713 ~26` ⇒ **709 + 本轮新增 4 例 = 713，逐一对上、无回归**。
  目标里记的「基线 713/26」与本分支数字相同纯属巧合 —— 那是在别的分支状态上数的，
  本规格的对照以 `709 → 713` 这组同口径复算为准。

## 未做 / 仍缺

- [ ] T007 规则页的**数据层竞态**（「过期响应不覆盖新响应」）没有用例：
  `pumpTodoVisualScenario` 不支持 provider overrides 透传（该能力在未合并的 !269 上），
  而绕开入口直接泵页 + 自己造竞态，测的就不是本轮要证的这条链路。等 !269 合并后补。
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

### 复核带出的真缺陷（本轮修掉）

- [x] T012 规则页在 320px + 1.3 倍字体下**打开编辑器弹窗会溢出**（`A RenderFlex overflowed by 36 pixels on the right`）。
  这条以前照不到：`QuadrantRulesPage` 没有任何 in-app 入口，手机上根本走不到弹窗；
  入口一通，它就是本切片的义务。新增用例 5 直接泵页 + override provider 造「有数据」态
  （走真实入口只能拿到失败态），断列表不溢出 + 点开「新建规则」后弹窗不溢出。
  成因经探针定位：`DropdownButtonFormField` 未设 `isExpanded` ⇒ 选中项按内容撑宽。
  **反证过程记着有价值**：我先怀疑的是弹窗里硬编码的 `width: 480`，夹成 `min(480, 屏宽-80)` 后溢出**没消失**，
  说明紧约束早被父级夹住、那个改动是 no-op ⇒ 已回退，不把无用代码留在仓里；
  真正生效的是一行 `isExpanded: true`（`quadrant_rules_page.dart:306`），
  反向探针 PD（摘掉 `isExpanded`）⇒ 该用例红，恢复后 `cmp -s` 逐字节一致。
  另一条自我更正：我先写的 `AlertDialog` 宽度 `< 320` 断言是错判据（实测盒子就是 320.0，铺满屏是设计行为），
  已删除，溢出才是判据。

### 最终门禁

第 13 轮修订后的最终状态跑在 `/tmp/gate-034c.log`（T006 记的是修订前那一版，`gate-034.log` /
`gate-034b.log` 留着不覆盖）。原文抄录，供 PR 评论对照：

| 门禁 | 结果原文 |
| ---- | -------- |
| 1 `git diff --check` | `exit=0` |
| 2 `dart format --output=none --set-exit-if-changed` 四个显式文件 | `Changed lib/features/task/tasks_by_list_page.dart` / `Formatted 4 files (1 changed)` / `exit=1` |
| 2b 同检查跑在 `git show HEAD:` 版（存量证明） | `Changed /tmp/head_p1_034b.dart` / `exit=1` ⇒ 红的是 HEAD 已有的排版欠债，不是本轮引入 |
| 3 `flutter analyze` | `No issues found! (ran in 1.6s)` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!` |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:13 +714 ~26: All tests passed!` |
| 6 `flutter build web --release …` | `✓ Built build/web` |
| 7 `test/goldens` 改动数 | `0` |
| 8 本轮文件 sha256 | `155bc7ba` `tasks_by_list_page.dart` / `885f1447` `task_workspace_header.dart` / `4395abc0` `quadrant_rules_page.dart` / `bb07dde7` `quadrant_rules_entry_test.dart` |
| 9 工作区脏文件 | 仅 ` M pubspec.lock`（未 staged，按口径不入库） |

5 条用例同基线复算：`develop@a1d7733` 基线 `+709 ~26`（`/tmp/base-034.log`）⇒ 本轮 `+714 ~26`，
多出的正好是本切片新增的 5 例，没有别的路数被顺手改动。

### 复核轮次（记录到本文件提交为止的真实状态）

- 复核手段：`claude` CLI 本机不可用（`unrecognized_model`），按口径替换为本会话只读子代理审本轮 FR。
- 第 1 轮 `VERDICT: FAIL`（B1/B2/B3），逐条处置见上面两节。
- 第 2 轮针对修订后的最终字节（sha256 见上表第 8 行）已派出，**本次提交时结论未回**，
  因此本切片在「拿到 VERDICT」这一条上**尚未闭环**。
- 「两轮无新结论就停下请示」⇒ 不再派第 3 轮；第 2 轮结论回来后要么据此改，要么在 PR 里说明不改的理由。

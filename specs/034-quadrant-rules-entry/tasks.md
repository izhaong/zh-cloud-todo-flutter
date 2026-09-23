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
  证据：夹具 apiClient 是 `_NoNetworkApiClient`（`test/support/todo_visual_fixture.dart:76` 固定 override）
  ⇒ 走到真实数据通道必然失败；用例 2 断「规则加载失败」+「重试」在，且「还没有四象限规则」
  （空态文案 `quadrant_rules_page.dart:370`）不在 ⇒ 报错没被当成「一条规则都没有」。
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
  对照口径：目标记的基线 713/26 与本分支实测 713/26 **数字相同但未做同基线复算**，
  复算正在独立 worktree 跑（`/tmp/base-034.log`，基线点 `develop@a1d7733`）；
  出数前不写「与基线一致」，只报实测值 —— 本分支含本轮新增 4 例，纯减法对不上是已知事实。

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
结论以 `VERDICT:` 行为准；结果与本文件处置记在下（第几轮、BLOCKER、是否采纳）——复核回来前不宣称通过。

# 推荐任务独立页 任务清单

## 已证实（每条都有命令输出或反向探针为凭）

- [x] T001 四类分组按嘀嗒顺序渲染、空组不占位（FR-1、FR-2）。
  证据：`recommendation_page.dart` `_recommendationGroups` + 用例「四类成组且顺序照嘀嗒，空组不占位」
  断言顺序数组恰为 `['最近添加','长时间未完成','即将到来']`（「多次修改时间」无候选 ⇒ `findsNothing`）。
  反向探针 PB（空组不跳过）⇒ 该用例红；PG（组顺序倒过来）⇒ 同一条用例红。
- [x] T002 「即将到来」按 `dueAt` 拆 明天 / 后天；拆不进的仍留在组里（FR-3）。
  证据：`_dueSoonBucketLabel` + 用例三条候选（明天/后天/大后天）分别命中
  `recommendation-bucket-tomorrow`、`recommendation-bucket-day-after`，且 `recommendation-item-13` 不被丢。
  反向探针 PA（判据恒返回 null）⇒ 该用例红。
- [x] T003 点行进任务详情、行内「+」添加到今天（FR-4、FR-5）。
  证据：用例「点行进任务详情」拿到回调参数 = `taskServerId`；
  用例「『+』添加到今天：在飞只提交一次」断言 `calls == 1` 且**在飞期间 `onPressed` 为 null**，
  放行后 `repository.removeTask(31)` 触发缓存更新 ⇒ 行从页面上消失。
  反向探针 PE（把 `onPressed: adding ? null : …` 换成恒可用）⇒ 该用例红。
- [x] T004 入口在推荐面板标题行，点开即独立页；`home_shell` 零改动（FR-6）。
  证据：用例「入口在推荐面板标题行，点开就是独立页」`tap(find.byTooltip('查看推荐任务'))` 后
  `recommendation-page` 出现。反向探针 PC（把面板那个 tooltip 改名）⇒ 该用例红。
- [x] T005 失败保留数据（四件套之「失败保留已加载数据」，FR-7）。
  证据：用例「刷新失败保留分组结果并说明」断言旧行仍在 + 出现「刷新推荐任务失败，已保留上次结果」；
  用例「添加到今天失败：行还在、要说出来并能重试」断言 `recommendation-item-41` 仍在。
  反向探针 PF（去掉失败提示条）⇒ 该用例红。
- [x] T006 320px + 1.3 倍字体不溢出，且档位**在页面自己的 context 上自检**（四件套）。
  证据：`MediaQuery.textScalerOf(tester.element(byKey('recommendation-page'))).scale(10) ≈ 13` + `takeException()` 为 null。
- [x] T007 读屏：组标题是 header 且带条数、每行是独立节点、「+」有动作名（FR-7）。
  证据：`ensureSemantics()` + `try/finally`；`hasFlag(SemanticsFlag.isHeader)`、
  行节点 label 含标题、`^添加到今天$` 命中一个。
  反向探针 PD（`header: true` 改 false）与该用例红；PJ（去掉「添加到今天」label）亦红。
  **本轮踩到并修掉的真缺陷**：组标题原本写 `Semantics(header: true, excludeSemantics: true)` 却没给 label
  ⇒ 文本节点被排除、节点自身又无名字，读屏什么都不念（用例先红，随后去掉 `excludeSemantics` 修复）。
- [x] T008 六项门禁在最终状态一次跑完，日志 `/tmp/gate-033-final.log`（2026-09-23 20:05）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 三个显式文件 **exit=0**
  （`Formatted 3 files (0 changed)`；本轮两个生产文件与测试文件都是新增/已格式化，不像 032 那样蹭到存量欠债）；
  `flutter analyze` ⇒ No issues found!；`flutter test --tags golden` ⇒ `00:03 +9: All tests passed!`（**未重录基线**）；
  `flutter test --exclude-tags 'golden || performance' --concurrency=1` ⇒ `01:55 +719 ~26: All tests passed!`；
  `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`
  ⇒ `✓ Built build/web`。
  新页用例文件单跑：`00:00 +10: All tests passed!`；与面板同跑（含回归）：`00:00 +16: All tests passed!`。
  对照口径：goal 记的基线 713/26 与本分支实测 719/26 不可直接相减 —— specs/024–032 的用例都在各自未合并分支上，
  本分支基线 `develop@a1d7733`，未做同基线复算，故只报实测值、不宣称「与基线一致」。
  中途还有两版红过的日志留着：`/tmp/gate-033.log`（analyze 报 `deprecated_member_use` ⇒ 第 3 项红）、
  以及更早在 `matchesSemantics` 上把整文件跑挂的那轮（`/tmp/sem.log`）。
- [x] T009 「+」在飞的重复点击只靠禁用态挡：早退守卫是死代码，已删。
  证据：先加的 `if (_addingTaskIds.contains(...)) return;` 摘掉后用例**仍然绿**（探针 PE 第一次跑），
  说明它咬不住任何行为 ⇒ 删除并把探针结论写进代码注释与 plan.md；改用 `onPressed == null` 这条可咬住的断言。

## 未做 / 仍缺

- [ ] T010 三组子档未做：「刚刚/今天/昨天」「超过 5/3/2 次」「超过 7/14/30 天」。
  阻塞在契约：`AppTodoRecommendTaskRespVO` 无 `createdAt`/`rescheduleCount`/`unfinishedDays`，
  已开 izhaong/zh-cloud-service#271。**不做两条捷径**：从 `score` 反推次数、解析 `reason` 自然语言。
- [ ] T011 真机/网页端手手感未做（无第二台可登录 test 的设备；`flutter build ios` 卡 SPM）。
- [ ] T012 远端 CI 未跑（runner `cgroup is not mounted`、Jenkins Job 不可达）；本地门禁不替代远端证据。
- [ ] T013 页面每次打开都订一次流并只在 `initState` 取仓储：若 provider 在页面存活期间被替换成另一个仓储实例，
  页面仍看旧仓储的流。当前 `recommendationRepositoryProvider` 生命周期与登录态一致，未做 `didUpdateWidget` 重订。

## 复核手段

`claude` CLI 本机不可用（`unrecognized_model`），按 goal 约定改用本会话**只读子代理**审 FR-1..FR-7 与测试假阳性，
结论以 `VERDICT:` 行为准；结果记在本文件末尾。

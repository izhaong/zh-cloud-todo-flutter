# 推荐任务独立页 任务清单

## 已证实（每条都有命令输出或反向探针为凭）

- [x] T001 四类分组按嘀嗒顺序渲染、空组不占位（FR-1、FR-2）。
  证据：`recommendation_page.dart:10` `_recommendationGroups` + 用例「四类成组且顺序照嘀嗒，中间空组不占位」
  断言顺序数组恰为 `['最近添加','多次修改时间','即将到来']`（故意抽掉中间那组 `LONG_UNFINISHED` ⇒ 它 `findsNothing`）。
  这一版比第一轮强两处：① 「多次修改时间」的**槽位**被钉住（第一轮四条里根本没seed它，第二轮的三条用例也证不了第二档）；
  ② 它的 `score=1003` 是全场最高 ⇒ 若分组改成按分数排就会跳到第一位，用例当场红。
  反向探针 PB（空组不跳过）⇒ 该用例红；PG（组顺序倒过来）⇒ 同一条用例红。
- [x] T002 「即将到来」按 `dueAt` 拆 明天 / 后天；拆不进的仍留在组里；两档顺序固定（FR-3）。
  证据：`recommendation_page.dart:21` `_dueSoonBucketOrder` + `:203` 每档是一个带 key 的 `Column`
  （`recommendation-bucket-tomorrow` / `-day-after`），用例断的是
  `find.descendant(of: bucket-tomorrow, matching: item-11)` **这一行落在这一档里面**，
  外加 `item-11.top < item-12.top` 钉 明天→后天，`item-13` 不丢。
  反向探针 **PK**（把 `_dueSoonBucketLabel` 的两个返回值互换）⇒ 该用例红；
  **PL**（把 `_dueSoonBucketOrder` 两条倒过来）⇒ 同一条用例红。日志 `/tmp/probe-033-r2.log`、`/tmp/probe-033-po.log`。
  记一笔第一轮的假阳性：那时只断「两个档键 + 三行都在树里」，是**对称断言**，
  明天↔后天 互换时键都还在、文案都还找得到 ⇒ 全绿。探针 PK 当时绿，就是这条不覆盖该机制。
- [x] T003 点行进任务详情、行内「+」添加到今天；重复点击两层屏障（FR-4、FR-5）。
  证据：用例「点行进任务详情」拿到回调参数 = `taskServerId`；
  用例「『+』添加到今天：在飞只提交一次」断言 `calls == 1` 且在飞期间 `onPressed` 为 null（**跨帧**屏障），
  放行后 `repository.removeTask(31)` ⇒ 行从页面上消失；
  用例「同一帧内连点两次『+』」两次 `tap` 之间不 pump ⇒ 第二次仍命中上一次 build 里可用的按钮，
  只有 `_addToToday` 的早退守卫（`if (!_addingTaskIds.add(id)) return;`）挡得住（**同帧**屏障）。
  反向探针 PE（把 `onPressed: adding ? null : …` 换成恒可用）⇒ 跨帧用例红；
  **PM**（摘掉早退守卫）⇒ 同帧用例红（`exit=1`，恢复后 `cmp -s` 一致）。
- [x] T004 入口在推荐面板标题行，点开即独立页，且两个回调原样转发；`home_shell` 零改动（FR-6）。
  证据：用例「入口在推荐面板标题行，点开就是独立页」除了断 `recommendation-page` 出现，
  还**在独立页上**点行 ⇒ `selected == 61`、点「+」⇒ `addedToToday == 61`。
  反向探针 **PO**（面板把 `onTaskSelected` 换成 `(_) {}`）⇒ 该用例红（`Expected: <61> Actual: <null>`）；
  **PP**（只换 `onAddToToday`）⇒ 同一条用例红。第一轮只断「页面出现了」，摘掉转发也照样绿。
  探针第一次跑因锚点缩进写错命中 0 次 ⇒ 脚本自己打印「跳过，不判结论」，修正缩进后才有上面两条。
- [x] T005 失败保留数据（FR-7）。
  证据：用例「刷新失败保留分组结果并说明」断言旧行仍在 + 出现「刷新推荐任务失败，已保留上次结果」；
  用例「添加到今天失败：行还在、要说出来并能重试」断言 `recommendation-item-41` 仍在。
  反向探针 PF（去掉失败提示条）⇒ 该用例红。
- [x] T006 320px + 1.3 倍字体不溢出，且档位**在页面自己的 context 上自检**（四件套）。
  证据：`MediaQuery.textScalerOf(tester.element(byKey('recommendation-page'))).scale(10) ≈ 13` + `takeException()` 为 null。
- [x] T007 读屏：组标题是 header 且带条数、每行是独立节点、「+」有动作名（四件套之语义，FR-8）。
  证据：`ensureSemantics()` + `try/finally`；断 `Semantics.properties.header == true`（不再是已废弃的
  `hasFlag(SemanticsFlag.isHeader)`）、行节点 label 含标题、
  `find.bySemanticsLabel(RegExp('^添加到今天$'))` ⇒ **`findsOneWidget`**（第一轮写的 `findsWidgets` 已收紧）。
  反向探针 PD（`header: true` 改 false）与该用例红；PJ（去掉「添加到今天」label）亦红。
  **本轮踩到并修掉的真缺陷**：组标题原本写 `Semantics(header: true, excludeSemantics: true)` 却没给 label
  ⇒ 文本节点被排除、节点自身又无名字，读屏什么都不念（用例先红，随后去掉 `excludeSemantics` 修复）。
  对复核员一处结论的复验：其称「`findsWidgets` 光靠 tooltip 就能满足」——实测把 label 摘掉（PJ）用例即红、
  且改成 `findsOneWidget` 全绿，说明 `ExcludeSemantics` 已把内层节点排除，tooltip 不另成节点（与 specs/032 的实测一致）。
- [x] T008 第 10 轮六项门禁跑完，日志 `/tmp/gate-033-final.log`（2026-09-23 20:05）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed` 三个显式文件 exit=0；
  `flutter analyze` ⇒ No issues found!；`flutter test --tags golden` ⇒ `00:03 +9: All tests passed!`（未重录基线）；
  全量 ⇒ `01:55 +719 ~26: All tests passed!`；`flutter build web --release …` ⇒ `✓ Built build/web`。
  该日志对应的是**复核修复前**的状态（`1464835`+`96d78d1`）；复核修复后的最终状态见 T016。
- [x] T009 「+」的早退守卫：第一轮判它「死代码」并删掉，**本轮按复核结论恢复**。
  第一轮的探针（跨帧两次点击）确实证明「那条用例咬不住早退守卫」，但据此推出「守卫无用」是**过度结论**：
  它挡的是同一帧内的第二次命中，那条机制需要**不 pump 的两次 tap**才咬得住（见 T003 与探针 PM）。
  教训写进本条：探针绿只说明「这条用例不覆盖该机制」，不说明「这段代码不需要」。
- [x] T015 缓存流自身报错不再伪装成空态（FR-7）。
  证据：`recommendation_page.dart:135` `if (snapshot.hasError)` 分支 ⇒ 念「读取推荐任务失败」；
  用例「缓存流自己报错」断该文案出现且「暂无」`findsNothing`。
  反向探针 **PN**（把该分支短路成 `if (false)`）⇒ 该用例红。
  说明：用 `_FailingStreamRecommendationRepository` 直接让 `watchAll()` 抛错，
  不赌 Drift 关库后抛的具体异常类型 —— 钉的是同一条通道（流抛错）。
- [x] T016 第 11 轮（复核修复后）六项门禁在**最终字节状态**一次跑完，日志 `/tmp/gate-033-r3.log`（2026-09-23 20:32）：
  `git diff --check` exit=0；`dart format --output=none --set-exit-if-changed`（本轮两个显式文件）⇒
  `Formatted 2 files (0 changed)`、exit=0；`flutter analyze` ⇒ `No issues found! (ran in 1.6s)`；
  `flutter test --tags golden` ⇒ `00:03 +9: All tests passed!`（**未重录基线**，`git status test/goldens` 干净）；
  `flutter test --exclude-tags 'golden || performance' --concurrency=1` ⇒ `02:12 +721 ~26: All tests passed!`；
  `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1`
  ⇒ `✓ Built build/web`。跑完时两文件 sha256 记在同份日志末尾
  （`a52ca23a…` 页面、`88cb6ffc…` 用例）。新页用例文件单跑 `00:01 +12: All tests passed!`。
  **第一次跑红在 2 号门禁**（`/tmp/gate-033-r2.log`：`Changed test/features/home/recommendation_page_test.dart`、exit=1）
  —— 是我这轮手写的长行没排版，原地 `dart format` 只作用于本轮显式文件（不整仓跑），修完 exit=0；
  所以 r2 那份日志里的 4/5/6 是在**格式化前**的字节上跑的，最终数字以 r3 为准。
  对照口径同 T008：goal 记的 713/26 与本分支 721/26 不可直接相减（024–032 用例在各自未合并分支上），只报实测值。

## 未做 / 仍缺

- [ ] T010 三组子档未做：「刚刚/今天/昨天」「超过 5/3/2 次」「超过 7/14/30 天」。
  阻塞在契约：`AppTodoRecommendTaskRespVO` 无 `createdAt`/`rescheduleCount`/`unfinishedDays`，
  已开 izhaong/zh-cloud-service#271。**不做两条捷径**：从 `score` 反推次数、解析 `reason` 自然语言。
- [ ] T011 真机/网页端手手感未做（无第二台可登录 test 的设备；`flutter build ios` 卡 SPM）。
- [ ] T012 远端 CI 未跑（runner `cgroup is not mounted`、Jenkins Job 不可达）；本地门禁不替代远端证据。
- [ ] T013 页面只在 `initState` 取一次仓储并订一次流：provider 若在页面存活期间被换成另一个仓储实例，
  页面仍看旧仓储的流。未做 `didUpdateWidget`/`ref.listen` 重订。
  本轮把**后果**改小了：旧写法下这条流的错误会被当成「没有数据」，念成「暂无推荐任务」（假空态）；
  现在（T015）会念「读取推荐任务失败」⇒ 用户至少看得见出问题，但**订阅关系仍不重连**。
- [ ] T014 「过期响应不覆盖新响应」只做到本页面内：`_requestRefresh` 共用同一次请求，
  但面板刷新（`recommendation_panel.dart:70`，`limit: 10`）与 `home_shell.dart:251` 的刷新可以和页面刷新
  （`limit: 50`）交错完成，而 `recommendation_repository.dart:27` 是先 `delete` 再 `insert` ⇒ 最后完成者胜出。
  修法要加代际令牌（或把刷新收敛到单一 controller），本轮**不假装完成**：FR-8 措辞已按实际范围收窄，
  并被动的「页面 limit 50 / 面板 limit 10 不一致」也一并登记在 spec.md「与嘀嗒不一致处」。
- [ ] T017 入口可达性与嘀嗒不一致：面板只在有推荐缓存时渲染 ⇒ 无缓存时「查看推荐任务」这个入口也进不去，
  嘀嗒的头部按钮是常驻的。要修得动首页可见布局（需授权重录 9 张黄金基线），本轮不做。

## 复核手段与结论

手段：`claude` CLI 本机不可用（`unrecognized_model "Top1"`），按 goal 约定改用本会话**只读子代理**
（禁改文件、禁跑测试）审 FR-1..FR-8 与测试假阳性，结论以 `VERDICT:` 行为准。

**第一轮：`VERDICT: FAIL`**（1 blocker + 6 minor + 2 nit）。逐条处置：

- BLOCKER（子档机制没被钉住：`bucketKeyFor` 由 label 反查 ⇒ 明天↔后天 互换全绿）⇒ **采纳**。
  每档包成带 key 的 `Column`，用例改断「这一行在这一档里面」+ 一条反向 `findsNothing`；探针 PK 红。
- M2（子档顺序跟着 `score` 走，后天分数高会排到明天前面）⇒ **采纳**。固定 `_dueSoonBucketOrder`；探针 PL 红。
- M3（FR-8「过期响应不覆盖新响应」超范围：面板/首页刷新可交错，仓储最后完成者胜出）⇒ **采纳其第二个选项**：
  不在这次功能改动里塞代际令牌，而是把 FR-8 措辞按实际范围收窄 + 记 T014。理由：跨面刷新收敛要动 `home_shell`
  与面板的既有已验收接线，属另一件事。
- M4（回调转发没被断）⇒ **采纳**。在独立页上点行/点「+」断面板回调收到 id；探针 PO/PP 各自红。
- M5（流错误伪装成空态；且 `initState` 单次订阅在 provider 被换后指向已关闭 DB）⇒ **采纳前半**（加错误分支，T015），
  后半（改 `ref.listen` 重订）**不采纳**为改动：`recommendationRepositoryProvider` 与登录态同生命周期，
  存活期被换不是当前可达状态；已把真实后果写进 T013，别当成已解决。
- M6（「禁用态是唯一屏障」只在跨帧成立）⇒ **采纳**。恢复早退守卫 + 同帧两次 tap 用例；探针 PM 红。
- M7（`1464835` 之后文档过期：T007 还写着 `hasFlag` 和「命中一个」；FR 标号错）⇒ **采纳**（本文件已改，
  语义那条改断 `properties.header` 并收紧为 `findsOneWidget`；四件套里读屏归 FR-8）。
- N8（自创文案：组标题「（N 条）」、空态第二行「没有待安排的提醒类任务…」；入口图标与常驻性与嘀嗒不一致）
  ⇒ **部分采纳**：空态那句是**说错**（推荐不是「提醒类」）⇒ 删；「（N 条）」与 `Icons.open_in_full`
  与入口可达性不硬改，改为在 spec.md 新增「与嘀嗒不一致处」一节如实登记（含保留理由），并把常驻性缺项记为 T017。
- N9（「多次修改时间」的槽位从没被钉；页面 limit 50 vs 面板 10）⇒ **采纳**：T001 用例改成抽掉中间那组、
  让第二档真正被断；limit 不一致并入 T014/spec.md，不新增可配置项。
- 复核员的一处判断经复验不成立：称 `findsWidgets` 光靠 tooltip 即可满足 —— 实测 PJ（摘 label）用例红、
  收紧成 `findsOneWidget` 全绿。按 goal 的「子代理否定结论要复验」处理，未照其措辞放宽断言。

**本轮（第 11 轮 = 033 复核修复轮）结束状态**：BLOCKER + M2/M4/M5(前半)/M6/M7 + N9 全部落地，
每项都有反向探针（PK/PL/PM/PN/PO/PP 六条，各自红、恢复后 `cmp -s` 逐字节一致）；
新页用例 `+12`（原 `+10`，多两条：同帧连点、流报错）。M3 按「收窄措辞 + 记账」处置，不采纳为代码改动，理由见上。

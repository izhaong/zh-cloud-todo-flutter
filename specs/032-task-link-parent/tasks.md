# Todo 关联主任务任务清单

## 已证实（每条都有命令输出或反向探针为凭）

- [x] T001 「关联主任务」入口在任务详情 `...` 里，术语与帮助中心一致（FR-1），三处容器均已由用例覆盖。
  证据：`_compactMoreActions` 里的 `value: _TaskDetailAction.linkParent`（嵌入态，宽屏页复用）与窄屏全屏页
  内联 `...` 里的同名 `case`/`value`。**本文件的 `文件:行号` 一律以 `feat/todo-link-parent-task@7043323` 为基准**，
  行号会随分支增删漂移，定位优先用下面的符号名。
  反向探针 P1：摘掉嵌入态菜单项 ⇒ 7 条用例红。
- [x] T002 选中候选即写 `parentTaskId` 并进 `task` upsert outbox（FR-2）。
  证据：用例「从无父任务的任务发起关联：写入 parentTaskId 并入队 task upsert」直接读
  `todoTasks.parent_task_id` 与 `todoSyncChanges`；`_applyReparent` 只调 `TaskRepository.reparent`。
- [x] T003 候选排除自己与后代，防成环（FR-2）。
  证据：`TaskRepository.descendantIds`（`task_repository.dart:851`，本轮唯一还准的行号）
  + 用例「候选列表排除自己与自己的后代」；
  反向探针 P3：`excluded` 换成 `{task.id}` ⇒ 该用例当场红。
- [x] T004 已关联时显示「当前主任务：X」并可「取消关联」，取消后 `parentTaskId` 归零（FR-3）。
  证据：`_ParentTaskSheet` 的 `task-parent-unlink` + 用例「已关联时弹层显示当前主任务并可取消关联」。
- [x] T005 子任务详情标题上方主任务行，点击落到主任务详情；主任务改名后跟着变（FR-4）。
  证据：`_buildParentTaskRow` 插在 `_buildEmbedded` body 的第一个子项，标题走 `watchById(parentId)`。
  反向探针 P2：`_buildParentTaskRow(t)` 换成 `SizedBox.shrink()` ⇒ 跳转用例与读屏用例 2 条红。
  改名跟随用例（本轮补）要记**两个探针结果**：P5b「主任务行标题只在首屏取一次」⇒ 该用例当场红（行为确实被咬住）；
  P5「换成每次 build 重新取一次的一次性读取」⇒ 该用例仍绿，因为面板重建会重建流。
  结论：这条只钉「不陈旧」的行为，**不钉 `watchById` 机制**；措辞已写进用例 reason，别拿它当机制覆盖证据。
- [x] T006 失败要说出来且不改已加载数据（FR-5）。
  证据：只读清单用例断言提示含「只读」、`parentTaskId` 仍是原主任务、详情面板仍在。
- [x] T007 过期/卸载后回包不砸已销毁 State（四件套之「过期响应不覆盖新响应」）。
  证据：`_SlowReparentRepository` 悬住 `reparent` → 卸载面板 → 放行，`takeException()` 为 null；
  反向探针 P4：去掉 `sheetContext.mounted` 再 pop ⇒ 该用例红。
- [x] T008 320px + 1.3 倍字体：档位在自己的 context 上自检（`task-parent-sheet`），弹层自身零溢出。
  证据：`MediaQuery.textScalerOf(sheetContext).scale(10) == 13` + `takeException()` 为 null。
  同时把**既有**溢出留在账上：用例先断言「弹层出现前已存在 `RenderFlex overflowed`」，
  定位在 `_buildEmbedded` 的操作头 `Row`（报 "overflowed by 36 pixels on the right"）。
  该缺陷本轮不修（要动已验收的详情操作头布局），另开治理 Issue。
- [x] T009 读屏独立节点：`主任务：X`、`关联主任务`、`取消关联`（FR-7）。
  证据：`ensureSemantics()` + `try/finally` 释放；三条 `findsOneWidget` 全过。
  本轮踩到的两个坑：① `RegExp(r'...$_metadataTitle$')` **raw 字符串不插值** ⇒ 模式恒 0 命中（假阴性）；
  ② M3 `IconButton` 的 `tooltip` 只在气泡出现时才是语义 label（`icon_button.dart:838` 的节点无 label），
  所以「取消关联」必须由外层 `Semantics(container + label + onTap)` 给出。
- [x] T015 「关联主任务」入口有在飞守卫：候选加载期间重复点入口只弹一层。
  证据：`_linkParentOpen` + `try/finally`；用例「候选还在加载时再点一次入口：不得叠两层弹层」
  以 `_SlowLinkPreparationRepository` 悬住 `descendantIds`。反向探针 P11：摘掉守卫 ⇒ `+13 -1` 只红这一条。
- [x] T010 六项门禁在**最终状态**（第二轮复核修复之后）一次跑完并留日志 `/tmp/gate-032-r3.log`（2026-09-23 18:42）。
  `git diff --check` exit=0；`flutter analyze` No issues found；
  `flutter test --tags golden` ⇒ `00:03 +9: All tests passed!`（**未重录基线**，主任务行只在有父任务时渲染）；
  `flutter test --exclude-tags 'golden || performance' --concurrency=1` ⇒ `01:53 +723 ~26: All tests passed!`；
  `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` ⇒ `✓ Built build/web`。
  **红的一行**：`dart format --output=none --set-exit-if-changed` 对三个显式文件 exit=1
  —— `Changed lib/state/repositories/task_repository.dart`，已核实 HEAD 版该文件同样 NEEDS-FORMAT（本机 Dart 3.12
  要把 `_requireSectionInList` 签名收成一行，仓内是旧排版），属既有欠债；本轮把被格式化器顺手改到的那处签名手工还原，
  保证该文件 diff 只有新增 6 行。**并且证清不是本轮代码的问题**：`dart format -o show` 对
  `task_detail_pane.dart` 与 `link_parent_task_test.dart` 输出**零改动**。
  更早还跑过三版：`/tmp/gate-032.log`（`+717`）、`+718`、`/tmp/gate-032-r2.log`（`+721`），日志都留着。
  对照口径说明：goal 里记的基线 713/26 与本轮测得的 723/26 不可直接相减——specs/024–031 的用例在各自未合并分支上，
  本分支基线是 `develop@a1d7733`，未做同基线复算，故不宣称「与基线一致」，只报实测值。

## 未做 / 仍缺（含复核采纳但本轮不修的）

- [ ] T011 真机（iOS/Android）与网页端手手感点击「关联主任务 → 跳主任务详情」未做：
  本机无第二台可登录 test 的设备，`flutter build ios` 卡在 SPM（github 直连超时）。
- [ ] T012 服务端 `parentTaskId` 契约未动：`/app-api/todo/**` 的 task 同步已带该字段（`_taskPayload`），
  本轮无后端缺口，故未在 `zh-cloud-service` 另开 Issue。
- [ ] T014 存量：`_collectDescendants`（`task_repository.dart:856`）无 visited 集，历史脏数据若已成环会死循环
  （`delete()` 同病）。本轮不在功能 PR 里改既有算法，单独记账。
- [ ] T013 清单页子任务树展开/收起、拖动转子任务、拖「+」建子任务（#23 缺项 ①④）不在本规格内：改可见列表布局需先申请重录 9 张黄金基线。

## 复核手段替换说明

`claude` CLI 本机不可用（`unrecognized_model "Top1"`），按 goal 约定改用**本会话只读子代理**
（`qa-engineer`，禁改文件、禁跑测试）审 FR-1..FR-7 与测试假阳性，结论以 `VERDICT:` 行为准。
本轮结论与不采纳理由记在本文件末尾。

## 复核结论

手段：`claude` CLI 本机不可用（`unrecognized_model "Top1"`），按 goal 约定改用本会话**只读子代理**
（`qa-engineer`，禁改文件、禁跑测试）审 FR-1..FR-7 与测试假阳性。

**第一轮：`VERDICT: FAIL`**（6 条 finding）。逐条处置：

- F1（高）窄屏页内联「...」是独立码路且零覆盖 ⇒ **采纳**。补 `embedded:false` @390 用例；
  反向探针 P6：摘掉窄屏那条 `PopupMenuItem` ⇒ 该用例当场红（其余 12 条仍绿，证明确实是另一条码路）。
- F3（中）`StateError('任务层级不能超过五级')` 被套上「关联主任务失败，请重试」⇒ **采纳**。
  `_reparentFailureMessage` 对 `StateError`/`ArgumentError` 直接透传原因；探针 P8：摘掉透传 ⇒ 五级用例红。
- F4（中）连点两个候选会在弹层离场动画期间（`sheetContext.mounted` 仍为 true）二次 `pop`，
  把下层路由一起弹掉 ⇒ **采纳**。一次打开只提交一次；探针 P9：摘掉守卫 ⇒ 连点用例红。
- F2-③ 弹层里 `candidates.isEmpty` 分支不可达（有父 ⇒ 父必在候选内；无候选无父时调用侧已早退）
  ⇒ **采纳**，直接删掉这段没被咬的死代码，而不是给它写用例。
- F5（中低）320px 用例用的是无父任务，主任务行与「当前主任务 + ✖️」在 320/1.3 下从未被拍过；
  `isScrollControlled` 也无人验证 ⇒ **采纳**。改用带父任务的一条，并钉住弹层 ≈ 60% 屏高（探针 P10：
  摘掉 `isScrollControlled` ⇒ 该用例红）。
  未完全照抄建议处：要求异常串包含 `task_detail_pane.dart` 做不到——`takeException()` 只带消息不带出处，
  改用「像素数 36 + 弹层尚未打开」两条钉住同一条溢出，出处由 Issue #279 的 `FlutterError.onError` 记录兜着。
- F6（中低）`pubspec.lock` 本机重解析含 major 跳变（xml 6→7.0.1、dio 5.10→5.11.1）⇒ **确认不入库**，
  三次提交都按显式路径 `git add`（`git show --stat` 可查，无 lock）。风险如实记下：本地这 13 例绿在
  3.44.8 + 新包组合上，CI pin 的是已提交 lock 的旧包集，远端未跑绿之前不得当作通过证据。
- 复核还提出两条**低**：① 主任务行原用「主任务：X」前缀属加料 ⇒ 已改回嘀嗒原样（可见裸标题，前缀只留在语义 label）；
  ② `_collectDescendants` 无 visited 集，历史脏数据成环时会死循环（`delete()` 同病，存量）⇒ **本轮不改**，
  登记在下节「未做」，避免在功能 PR 里顺手改既有算法。
- 复核的 F2-①（「无任何用例改主任务标题」）在其结论之后已由 `08b7214` 补上，且探针边界写进用例 reason，
  属**过期结论**，不再动作。

**第一轮结束状态**：F1/F3/F4/F5/F2-③ 全部落地并有反向探针；13 例用例绿；交第二轮复核。

**第二轮（同一手段，只读子代理逐条复验第一轮处置）**：六条 finding 全部判 **RESOLVED**，
并逐条给了 `文件:行号`；另确认「五级」这条**确实能从 UI 走到**（候选来自 `filter(listId:)`，无深度预筛，
用例点的是真实弹层行，不是只测仓储）。约束项亦确认：diff 纯新增（pane 238/0、repo 6/0）、黄金 9 张未动、
UI 不复制仓储规则、无真机声称。
**如实记下**：第二轮报告的末行未带进本会话的通知里，所以我**不把它写作字面 `VERDICT: PASS`**，
只记录为「六条 finding 全部 RESOLVED、无 blocker」。按 goal「不得为拿 PASS 循环重跑」，**不再派第三轮**去追那个词。

第二轮新提 6 条（1 minor + 5 nit），处置：

- **minor（采纳，已修）**：`_linkParentTask` 没有在飞守卫 —— 候选要等三次 `await` 才拿到，
  期间再点一次「...」→「关联主任务」会**叠两层弹层**，「取消关联」只退一层，看着像按钮失灵；
  第一轮的 `handled` 闩是每次打开各自的，管不到跨两次打开。
  修法：`_linkParentOpen` + `try/finally`（`_prepareAndShowParentSheet` 拆出来承载原逻辑）。
  证据：先写红测「候选还在加载时再点一次入口：不得叠两层弹层」，报 `SafeArea-[<'task-parent-sheet'>]` **is too many**；
  加守卫后 `00:02 +14: All tests passed!`；反向探针 **P11**：摘掉守卫 ⇒ `+13 -1`，只红这一条，恢复后 `cmp -s` 一致。
- **nit（采纳，已修）**：`_reparentFailureMessage` 里 `'${error.message}'` —— `ArgumentError.message` 是 `Object?`，
  缺省时会把字面量 `"null"` 弹给用户。改成 `?.toString() ?? '关联主任务失败，请重试'`。
  **不补用例，理由如实写**：`task_repository.dart` 里 10 处 `ArgumentError` 全是 `ArgumentError.value(...)`（89/93/305/374/377/483/486/536/554/910），
  今天不可能为空，补测等于给不可达分支立法。
- **nit（采纳，本文件已改）**：T001–T008 里的一批行号已漂移（`:2714`→`:2730` 等）⇒ 除 `task_repository.dart:851` 外
  一律改用**符号名**定位，并在 T001 标注本文件行号基准 SHA。
- **nit（不修，记账）**：弹层的 `candidates`/`currentParentTitle` 是打开时的快照，弹层开着时主任务被改名/删除会显示旧标题。
  降级是安全的（提交时仓储报错原样透传，`reparent` 会拒不存在/成环的父），不在本轮加流式订阅。
- **nit（不修，属设计）**：主任务行可见文案是裸标题、语义 label 带「主任务：」前缀 —— 嘀嗒就是这样，
  `ExcludeSemantics` 保证不重读。真正的风险是 `InkWell.onTap` 与 `Semantics.onTap` 两处闭包将来改漏一处，记在这里。
- **nit（不修，已钉住）**：320px 用例硬编码「36 pixels」是刻意的严格性（第一次 `takeException` 恰好消费一条、
  第二条断言 null）；修 Issue #279 时必须同步改这条用例。


## 下一轮入口（第 10 轮）

- 先结一项取证：队列里的「`attachment_upload_api.dart` 调用方」已查实——它由
  `lib/core/sync/sync_coordinator.dart:37` 实例化并在 outbox 上传路径消费（不是死代码），
  且任务详情早已有「附件」小节 `_AttachmentSection`（`task_detail_pane.dart:2324` 附近）。
  所以 #89 的「附件挂载入口」这一半**不需要新轮次**，下一轮只查笔记侧是否真的缺入口。
- 建议门槛：#11 推荐任务独立页（帮助中心 `01-任务/05-推荐任务.md`）。本轮已取证：嘀嗒四组的分组维度**契约里已有**
  （`TodoHelpCenterService.java:173,176,179,183` = `REPEATEDLY_RESCHEDULED`/`DUE_SOON`/`LONG_UNFINISHED`/`RECENTLY_ADDED`），
  做独立页不需要新端点；但每组的**子档**要 `createdAt`/`rescheduleCount`/`unfinishedDays` 三个字段，
  `AppTodoRecommendTaskRespVO.java:10-31` 现在没有 ⇒ 已开 izhaong/zh-cloud-service#271（先改契约）。
  客户端可先落四组 + 「即将到来 明天/后天」（能从 `dueAt` 算），子档在 `spec.md` 里写成仍缺项，不算完成。
  入口优先放进现有 `RecommendationPanel` 的标题行（面板只在有缓存时渲染、push 路由拍不到黄金图）⇒ 不重录黄金基线。
- 需要授权才动的：#23 缺项 ①「清单页渲染子任务树」（改可见列表布局 ⇒ 先申请重录 9 张黄金图）。


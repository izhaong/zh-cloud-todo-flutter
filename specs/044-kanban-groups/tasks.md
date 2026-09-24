# 044 任务清单

## 已证实
- [x] 「跨列拖动」这一面在 develop 上**有实现且有测试**：`kanban_view.dart:540`/`:398` + `tasks_by_list_page.dart:380`，测试 `task_workable_views_test.dart:14`/`:56` ⇒ 源页 `:64` 成立
- [x] 「管理分组」的实体与 CRUD 在 develop 上**已存在**：`tasks_by_list_page.dart:1829`-`:1862`（`todo-section-create`、rename/up/down/delete、tooltip `:1849`「管理分组 <名称>」）⇒ 源页 `:115` 的清单侧入口成立
- [x] 本文件旧注释「拖拽改 priority 暂不实现」与代码矛盾，已纠正；`kanban_view.dart` 的 diff 只落在 `///` 行
      （`git diff origin/develop...HEAD -- lib/features/task/views/kanban_view.dart` 全为 `+///`/`-///`）。
      **注意口径**：这一条只说那一个文件；第 1 轮复核抓到整个 commit 还混进了 `pubspec.lock`，见下方处置。
- [x] 七处源页引文逐字命中（python 扫 `02-看板视图：分类管理任务.md`）：`:14/:64/:99/:100/:101/:108/:115` **全部 OK**，行号与 spec 表一致
- [x] 六项门禁（**终态日志 `/tmp/r45_gates_final.log`**，首行 `head=37528da`、`status_before_gates=[]` ⇒ 跑在已提交的干净树上；下表数字即该日志原文）
  | 门禁 | 结果 |
  | --- | --- |
  | 1 `git diff --check` | `rc=0`、无输出 |
  | 2 `dart format --output=none --set-exit-if-changed lib/features/task/views/kanban_view.dart` | `Formatted 1 file (0 changed) in 0.01 seconds.`、`rc=0` |
  | 3 `flutter analyze` | `No issues found! (ran in 2.1s)`、`rc=0` |
  | 4 `flutter test --tags golden` | `00:03 +9: All tests passed!`、`rc=0`（9 张基线未重录） |
  | 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:11 +709 ~26: All tests passed!`、`rc=0`。计数 = develop 基线 709，本轮**没加用例**（无行为改动），所以数字不动是预期的，不是漏跑 |
  | 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |
  **rc 口径**：3/4/5/6 各跑两遍 —— 一遍 `\| tail -1` 留末行输出（退出码是 tail 的，不可信），一遍把输出丢弃单取 `$?`。
  **两份日志的关系**：`/tmp/r45_gates.log` 是修复前那一次，首行只记 `head=a1d7733` 而树上还挂着未提交编辑 ⇒
  正是它让 `pubspec.lock` 漏进提交（复核 finding 1）。上表数字已全部换成终态那一次；
  旧日志的 `00:04 +9` / `ran in 3.7s` / `02:14` 只是同一棵树的计时抖动，测试计数一致。
  本次六个 `rc=` 全为 0，且门禁跑完后 `lock_pubdev=149 lock_mirror=0`（本机镜像没有覆盖回来）。

## 仍缺（不谎称完成）
- [ ] 看板列头无「···」管理入口（源页 `:108`/`:115` 的看板侧）。
      后半轮之后这一条的含义收窄了：列名**已经**直接读 `TodoTaskSection.name`，清单侧改了名看板立刻跟着变，
      缺的只是"在看板上就地新建/改名/删除"这一步。
- [ ] 「未分组」列固定排在最后 —— 嘀嗒没说该排哪、也没说要这么一列。切换条件（有分组就按分组开列）
      本身也是推断，见 `spec.md` 后半轮「取舍」1。

## 后半轮（Issue #313）已证实
- [x] **看板列绑定 `TodoTaskSection`**：`KanbanView.sections` 非空即按分组开列（列名=分组名、
      顺序=`sortOrder`、末尾「未分组」兜底），跨列拖拽写 `sectionId`，左右移列写 `TaskSectionRepository.reorder`，
      每列「+」按该分组建任务 ⇒ `:99`-`:101`/`:129`/`:141` 成立。矩阵 #15 **不在本轮翻状态**（PR 未合并 + 列头管理入口仍缺）。
- [x] 「拖到未分组」的落库语义已定：`sectionId = NULL`（`TaskViewActionRepository.moveKanbanTaskToSection`
      的 `Value(sectionId)` 直接写 null）。措辞沿用 app 内既有说法，见 `spec.md` 表格最后一行。
- [x] 不需要改后端契约（正面确认，不再是推断）：
      FL 侧 `SyncCoordinator._resolvePayloadRefs` 把 payload 的本地 `sectionId` 换成服务端 id（未同步的走负数临时 id）；
      服务侧 `TodoSyncServiceImpl.applySyncTaskSection` 校验分组存在、`resolvePayloadEntityRef(…, "sectionId", "section_id")`
      做批内解析、`TodoTaskMapper.clearSectionId` 负责删分组清空任务。
- [x] 四件套补齐（本轮**新增界面行为**，所以不再是"不适用"）：
      | 项 | 结果 |
      | --- | --- |
      | 320px + 1.3 倍字号 | 首跑**红**：`A RenderFlex overflowed by 141 pixels on the right.` ⇒ 列标题改 `Expanded` + `ellipsis` 后绿（用例 `320px + 1.3 倍字号下分组列头不溢出`） |
      | 独立读屏语义 | 「+」tooltip 从 `新建任务` 改成 `在<列名>新建任务`；用例 `分组列的「+」读屏能分清是哪一列` 断言三个列各自的 tooltip |
      | 失败保留已加载数据 | 写入抛错 → `移动任务失败，请重试` + `重试`，任务仍在原列（用例 `分组列写入失败会提示并保留原列，不静默吞掉`）；仓储侧拒绝写入时任务与 outbox 都不动（用例 `分组不属于任务所在清单时拒绝写入，任务与 outbox 都不变`） |
      | 过期响应不覆盖新响应 | `reorder` 要求提交全部分组 id，否则抛 `必须包含清单内的全部分组` ⇒ 竞态下可见失败而非静默重排（用例 `分组列左移只提交分组 id，不含未分组哨兵` 钉住提交内容） |
- [x] 六项门禁跑在**已提交终态** `f6400a9` 上，日志 `/tmp/g53/gates-round3.log`。
      溯源头两行都在：`### head=f6400a9  status_before_gates=[]  time=2026-09-24T19:24:39Z`（跑之前）
      与 `### status_after_gates=[]`（跑之后），另附一行 `### pr_files=…` 夹住 `pubspec.lock` 不在 PR 里。
      （第 45 轮复核立的规矩：日志必须同时记 head 与工作树状态，否则 `pubspec.lock` 会像那次一样漏进提交。）
      **这一轮自己又踩了一个假绿**：门禁 2 那次写成 `dart format … $FILES`，zsh **不做词切分** ⇒
      六个路径被当成一个文件名传进去，输出 `No file or directory found at "lib/… lib/…"` +
      `Formatted no files in 0.00 seconds.` 而 **rc 仍是 0**。日志里保留着那一条，
      下面接一条用字面量路径重跑的 `Formatted 6 files (0 changed)` / `gate2 rc=0`。
      ⇒ 规矩补一条：`dart format` 的判据不能只看 rc，必须看 `Formatted N files` 里的 **N 等于本轮文件数**。
      **rc 口径**（第 1 轮复核 NIT 3 抓过 gate5/6 只有 `tail` 输出、没有 rc）：
      本轮六个 rc 全部由"输出重定向到文件、`$?` 单独取"的方式记录，不再有 `| tail` 吞退出码。
      | 门禁 | 结果 |
      | --- | --- |
      | 1 `git diff --check` 与 `git diff --check origin/develop...HEAD` | 两条都 `rc=0`、无输出 |
      | 2 `dart format --output=none --set-exit-if-changed <本轮 6 个显式文件>` | `Formatted 6 files (0 changed)`、`rc=0`。**上面那条 `$FILES` 的假绿已记在表前**，N 必须等于 6 |
      | 3 `flutter analyze` | `No issues found! (ran in 1.9s)`、`rc=0` |
      | 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（9 张基线未重录。推理已由第 1 轮复核**独立跑过**：`test/visual/todo_workspace_golden_test.dart` 只 pump `home_shell`/`quick_add_bar`/`task_detail_page`，三个 support/visual 文件里 `TaskViewMode|TodoTaskSection|Kanban|board` 零命中） |
      | 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:27 +920 ~26: All tests passed!`、`rc=0`（本轮新增 22 条：17 widget + 5 仓储；两轮复核前是 15 条） |
      | 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0`；跑完 `status_after_gates=[]` ⇒ `pubspec.lock` 没被本机镜像改脏，`pr_files` 里也没有它 |
      红测的三次形态：① 首跑编译红（`moveKanbanTaskToSection` 未定义）；② 两条拖拽用例红在
      "落点算到列的右边缘外"（`Actual: <null>` 而不是数字差）⇒ 改成落进列内「空」占位；
      ③ `320px + 1.3 倍字号` 报 `A RenderFlex overflowed by 141 pixels on the right.`
      ⇒ 列标题改 `Expanded` + `ellipsis`。**141 这个数只存在于那次运行输出里，树上锁不住**
      （要复现得把修复改回去），所以本轮补的是形态断言而不是数字：
      `长分组名的列标题用省略号而不是撑破列头` 断言 `overflow == TextOverflow.ellipsis` 且 `maxLines == 1`。

## 后半轮第 1 轮只读复核处置（`VERDICT: FAIL`，2 BLOCKING + 2 NIT）
复核手段同第 45 轮：本机 `claude` CLI 的模型别名仍不可用，改由本会话的只读子代理审。
4 条全部**回源复验成立**，无一条驳回（复验命令与结论逐条如下）：

| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | 分组模式没有「归档」列、已完成任务混排在各自分组列，且看板上改不了完成状态，而 spec 六条取舍与两条仍缺都没提 | `git show origin/develop:…kanban_view.dart` 的归档列是 `t.completed \|\| t.priority >= 3`；`_sectionColumns` 从头到尾不看 `completed` | 承认漏登记。`spec.md` 加取舍 3（写清这是分组方式的必然结果 + 明说代价"看板上改不了完成状态"），`kanban_view.dart` 类注释同步，补 2 条用例（列不聚合、拖进分组列不改 completed） |
| 2 | BLOCKING | 两处文档口径不成立：①「固定四列一字未改」——`新建任务` tooltip 其实两条路径都变了；②我把折叠项从灰显改成不渲染，连带改掉了智能清单（`listId == null` 时回调本就是 null）的老菜单形态，且与同菜单仍灰显的「左移/右移」自相矛盾 | `git show origin/develop:…kanban_view.dart` 第 391-392 行是 `value: 'collapse'` + `enabled: onCollapsedChanged != null`、第 404 行是 `tooltip: '新建任务'`；HEAD 一度变成 `if (onCollapsedChanged != null)` 与 `tooltip: '在${data.title}新建任务'` | ②**回滚代码**：折叠项恢复 `enabled:` 灰显；①**改文档**：spec 点名这一处 tooltip 确实在两条路径上都变了，并说明它是向同列头 `调整X列`/`折叠X`/`展开X` 的既有带列名写法对齐。补 3 条用例（折叠 enabled=false 而右移 enabled=true、偏好塞分组 id 不折叠、固定四列 tooltip） |
| 3 | NIT | `/tmp/g53/gates-final.log` 里没有门禁 1/2 的输出，也缺 `head=` / `status_before_gates=[]` 溯源行 | 那份日志确实只有 analyze/golden/full/build 四段 | 换一份完整日志 `/tmp/g53/gates-round2.log`，六段齐全 + 溯源头，数字全部重跑（+919） |
| 4 | NIT | 「溢出 141px」在树上只是散文，没有断言锁得住 | 确实只有 `expect(takeException(), isNull)` | 用形态断言替代数字（见上面门禁 3 段末），并在 tasks 里写明"数字锁不住"的原因 |

## 后半轮第 2 轮只读复核（`VERDICT: PASS`，5 条 NIT 全部处置）
4 条修复经复核回验成立（折叠那段与 develop 逐字节相同、门禁数字独立重跑吻合、
`git diff 7a56a49 HEAD -- lib test` 为空、引文 `:64/:99-:101/:108/:115/:129/:141/:148/:217-:219` 逐字命中）。
5 条 NIT 我逐条复验，**全部成立，无一条驳回**：

| # | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- |
| 1 | spec 写「只能回卡片勾选」，但看板卡片没有勾选控件 | `grep -n "check_circle\|Icons.check\|radio_button" kanban_view.dart` 0 命中；`_KanbanCard` 只有标题/优先级/日期/把手 | 措辞改「点开卡片、在详情弹窗里勾选」并写明卡片自己没有勾选控件 |
| 2 | 注释把「会溢出 141px」写成无条件事实，而 tasks 自己承认数字锁不住 | 两处口径确实互相打脸 | 注释改成"长名字实测溢出过（短名字不溢出）"；spec 里保留数字但说明它为什么锁不住 |
| 3 | 引用的日志缺 gate5/6 的 `rc=`，也没写 `git status --porcelain`，而我拿它当物证 | 成立：`gates-round2.log` 只到 gate4 的 rc | **不降格证据、改重跑**：`gates-round3.log` 六段 rc 齐全 + 跑前/跑后两行状态 + `pr_files` 行 |
| 4 | `TaskQuickAddSheet.sectionId` → `TaskRepository.create(sectionId:)` 这一环没有用例：删掉两处传参全量仍绿 | 复验成立（`grep -rn sectionId test` 里没有对 `create(` 入参的断言） | 补 `「+」→ 保存真的把 sectionId 交给仓储` 并做**变异探针**：摘掉两处传参 → 该用例 `[E]`；`cp` 还原后 `cmp -s` 判 IDENTICAL |
| 5 | 分组开关与任务流不同源，切清单的首帧可能仍是 priority 四列 ⇒ **那一帧的拖拽写的是 priority** | 成立：`taskSections = watch(...).valueOrNull ?? const []` | 记进 `spec.md` 取舍 7 与「仍缺」；不在本轮修（根治要么两条流同源、要么未就绪不给拖拽，都不是接线量级） |

**一处复核员自己标为「仅提示」的**：`tasks_by_list_page.dart` 里 `repository == null` 时静默 `return`
（拖拽/移列点了没反应也没提示）。我复验：这是 develop 上 `onTaskMove` 的同款写法，本轮照抄而非新引入
⇒ 不在本 PR 顺手改（objective 的"不顺手重构"），但记在这里作为下轮候选。

## 一处自我更正要写在台面上
初判「看板自定义分组缺后端契约」→ 立了 `zh-cloud-service` Issue #282，**错了**：
`TodoTaskSection` 就是那个实体，CRUD 在 develop 已通，我立的是重复契约。
错因是把「矩阵 #15 的证据里只提到 `todo_board_preference`」当成了「不存在分组实体」，
且第一次 `git grep 管理分组` 之前我就先写下了"0 命中"的判据 —— 实际是 1 命中，而那一处正是反证。
⇒ 已在 #282 里撤回并关闭。规则重申：**先跑判据，再写判据的结论。**

## 第 1 轮只读复核处置（`VERDICT: FAIL`，5 条 findings）
复核手段替换：本机 `claude` CLI 不可用（`unrecognized_model`），改由本会话的只读子代理审本轮 FR。
5 条 findings 我逐条回源复验（`git diff --name-only`、`git show HEAD:` 配 `grep -n`、`git grep origin/develop`），
**全部成立并已全部修**，无一条拒绝：

| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | `pubspec.lock` 混进了 `eca4224`（227+/219-），把 149 处 `url: "https://pub.dev"` 全改成 `pub.flutter-io.cn` | `git diff --stat origin/develop...HEAD -- pubspec.lock` 与两侧 `grep -c` 逐一吻合 | 已把 `pubspec.lock` 还原到 merge-base 内容并单独提交；PR 文件表恢复为本轮应有的 4 个文件。错因见下「门禁跑在提交前的树」 |
| 2 | BLOCKING | 新注释自指 `:33`，但注释自己把那一行推到 `:44`；`spec.md:17` 的「本文件自己的 `:398`/`:540`」在 PR 分支上是 `:409`/`:551` | `git show HEAD:…kanban_view.dart \| grep -n` → `44` / `409` / `551`；`origin/develop` → `33` / `398` / `540` | 文件头注释**删掉对本文件行号的引用**，改指符号名 `KanbanView.orderedColumnIds`（自身注释必然随自己漂移，行号在这里永远不可靠）；`spec.md` 保留 develop 行号但显式标 `a1d7733`，并把漂移 +11 写在正文里 |
| 3 | NIT | `orderedColumnIds` 不是「写死」 | `tasks_by_list_page.dart:338` 传 `boardPreference.orderedColumnIds`；`board_preference_repository.dart:16` 有 `defaultColumnIds`、`:58`/`:226` 用它过滤 | 措辞改准：**四列顺序可重排，列 id 词汇锁死** ⇒ 建不出新列。结论（`:99`-`:101` 在看板上不成立）不变 |
| 4 | NIT | `spec.md:25` 把 widget Key 当端点说 | `todo-section-create` 是 `tasks_by_list_page.dart:1840` 的 `Key` | 改引真正的实体与同步通道：`app_database.dart:51`/`:1048` 的 `TodoTaskSection` + `sync_entities.dart:5`/`:31` 的 `task_section`（我自己 `grep` 复验过，非照抄复核员），并加一句措辞提醒 |
| 5 | NIT | 门禁日志首行 `### head=a1d7733 工作树`，即跑在**未提交**的编辑上；且日志里有 `flutter_lints` 解析告警 | 日志首行与 mtime（18:36）早于 commit（18:37:13）吻合 ⇒ 这正是 #1 漏进来的机制 | 接受第 1 半：新日志首行标 `head=` **与工作树 diff 状态**，且门禁跑在已提交终态之后。第 2 半**不成立**：`Failed to resolve package URI` 只出现在日志第 6 行、即 `### gate2`（`dart format`）段内，`dart format` 不需要 lint 规则集，不影响 `Formatted 1 file (0 changed)`；`### gate3`（`flutter analyze`）段无任何告警，`No issues found!` 未被削弱。此条按「定位错段」记录，不改结论 |

## 门禁跑在提交前的树 —— 机制要写清，不然下次还犯
objective 第 2 条早就点名 `pubspec.lock` 会被本机镜像整树重解析改脏、不随功能 PR 提交。
这次仍漏进 commit，原因不是「忘了规则」而是**顺序**：我是「改完 → 跑六项门禁 → commit」，
而 `flutter test`/`build web` 内部会 `pub get` 重写 `pubspec.lock`，于是 `git add` 时它已是脏的。
⇒ 正确顺序：**改完 → commit → 在已提交的终态上跑门禁 → 若门禁把 `pubspec.lock` 改脏则 `git checkout HEAD -- pubspec.lock` 还原**。
本轮按此重跑，日志见 `/tmp/r45_gates_final.log`。


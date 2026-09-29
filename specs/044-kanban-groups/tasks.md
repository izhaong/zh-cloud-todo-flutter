# 044 任务清单

## 已证实
- [x] 「跨列拖动」这一面在 develop 上**有实现且有测试**：`kanban_view.dart:540`/`:398` + `tasks_by_list_page.dart:380`，测试 `task_workable_views_test.dart:14`/`:56` ⇒ 源页 `:64` 成立
- [x] 「管理分组」的实体与 CRUD 在 develop 上**已存在**：`tasks_by_list_page.dart:1829`-`:1862`（`todo-section-create`、rename/up/down/delete、tooltip `:1849`「管理分组 <名称>」）⇒ 源页 `:115` 的清单侧入口成立
- [x] 本文件旧注释「拖拽改 priority 暂不实现」与代码矛盾，已纠正；`kanban_view.dart` 的 diff 只落在 `///` 行
      （`git diff origin/develop...HEAD -- lib/features/task/views/kanban_view.dart` 全为 `+///`/`-///`）。
      **注意口径**：这一条只说那一个文件；第 1 轮复核抓到整个 commit 还混进了 `pubspec.lock`，见下方处置。
- [x] 七处源页引文逐字命中（python 扫 `02-看板视图：分类管理任务.md`）：`:14/:64/:99/:100/:101/:108/:115` **全部 OK**，行号与 spec 表一致
- [x] 门禁表见下（六道，逐道的命令与数字都在表里；**终态日志 `/tmp/r45_gates_final.log`** 首行 `head=37528da`、`status_before_gates=[]` ⇒ 跑在已提交的干净树上，表中数字即该日志原文）
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

## #315 第 2 轮只读复核（`VERDICT: FAIL`，1 BLOCKING + 2 NIT，全部成立）
这一轮复核员实做了两处变异并证明确实会红（对调页面两个回调 ⇒ 页面级两条 `[E]`；视图改成恒取首列 ⇒ 4 条红），
第 1 轮 6 条里 5 条判为已修好。**新抓到的 3 条我也逐条回源，全部成立、无驳回**：

| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | 我把撤掉的那条端到端用例的**红因**写成"就是仓储 null 的静默 no-op"，并断言"不是测试环境的问题"；但在同一套 harness 里 `todo_visual_fixture.dart:75` 用真库覆盖了 `appDatabaseProvider` ⇒ 仓储非 null；保留的两条用例能渲染 A/B 两列本身即反证（列来自 `taskSectionsByListProvider`，仓储为 null 时只会退回 priority 四列） | 成立。我去查的时候只跑到"点完确认列还在"就下了因果结论 | `spec.md` 那段拆成两半：静态读得出的部分（nullable provider + 三处 `?.` ⇒ null 时确实静默）保留；**红因改写成"未定位"**，并写明"撤测试"这件事本身记在账上、端到端用例**待补**，#316 只保留静态成立的那半 |
| 2 | NIT | 同一句错来源（"新建那枚 chip 的 tooltip 是「新建分组」"）还留在代码注释里，spec 改了注释没改 | `kanban_view.dart:573-574` 命中 | 注释一并改对（来源＝appbar IconButton tooltip；chip 只写「分组」） |
| 3 | NIT | 新加的 `## 一条静态读出来…` 节插在 `## 仍缺` 与其条目之间 ⇒ "仍缺"成了空壳，条目被归到缺陷节 | 结构确实如此 | 把缺陷节整体挪到「仍缺」之前 |

教训并入第 53 轮那条规矩：**"我复验过"必须区分"读到"和"查到"**。静态代码路径可以靠读下结论，
"某条测试为什么红"只能靠把它跑到底下结论；没跑出来就写"未定位"，不要借一个成立的事实去解释另一个没查清的现象。

## #315 第 1 轮只读复核（`VERDICT: FAIL`，2 BLOCKING + 4 NIT，全部成立、无驳回）
| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | 台账说日志有 `head=5fa649f` 那行，实际 `/tmp/g54/gates.log` 只有 8 行、缺 gate1-3 | `wc -l`=8、`grep -rl "5fa649f" /tmp` 无命中。成因：`... \| tee /tmp/g54/gates.log 2>/dev/null \|\| mkdir -p /tmp/g54` —— tee 在目录存在前就跑了，前半段只进了 stdout | 重跑一份完整日志（`gates-final.log`，`>` 一次写完 + 头尾溯源行），台账改引它并把成因写下来 |
| 2 | BLOCKING | spec 说 `新建分组` 抄自那枚 chip 的 tooltip | `sed -n '1884,1888p'` ⇒ `ActionChip(key: todo-section-create, label: Text('分组'))` **没有 tooltip**；真来源是 `tasks_by_list_page.dart:298` 的 IconButton tooltip 与 `task_workspace_header.dart:182` 的 `Text('新建分组')` | 改述来源（结论"照抄清单侧用词"不变） |
| 3 | NIT | 三条点击全在第一列，闭包抓错 index 不会红 | 成立 | 加 `改的是被点的那一列，不是第一列`（在 `col-sec-pol` 上点，断言 `id == 'sec-pol'`）；另加页面级 `kanban_section_menu_page_test.dart`：改名框 `initialValue == 'B组'`、确认框 `删除“B组”？` 且 `删除“A组”？` findsNothing ⇒ 两个回调用反必红 |
| 4 | NIT | 读屏用例 `.first` + `findsOneWidget` 退化成 ≥1 | 成立 | 去掉 `.first`，断言唯一 |
| 5 | NIT | 哨兵列 tooltip `管理分组 未分组` 会误导（它不是分组、6 项里 4 项恒灰） | 成立 | 只有 `data.sectionId != null` 的列才叫 `管理分组 <名称>`，「未分组」仍叫 `调整未分组列`，用例双向断言 |
| 6 | NIT | 页面接线零覆盖 + `onSectionCreate: listId == null ? null : …` 是死分支 | 前半成立（`task_section_workspace_test.dart` 无 kanban 关键字）；后半成立（`tasks_by_list_page.dart:162` 保证 listId 为 null 时 sections 必空） | 死分支去掉；页面覆盖按 #3 补 |

**顺带撞出来的一个既有缺陷**：写"确认删除后列真的消失"这条端到端用例时它是红的 —— 回源是
`providers.dart` 的 `taskSectionRepositoryProvider` 在 db/queue 未就绪时返回 null，而三处分组写操作都写 `?.` ⇒
**静默 no-op 且不进 catch**。清单侧一直如此，本 PR 只是多暴露一个入口 ⇒ 立 todo-flutter **#316**，本轮不顺手改；
那条端到端用例撤掉（撤的不是"覆盖"，是"在缺陷未修前把它写成绿的"）。

> ⚠️ 上面这段是**第 1 轮的原始记账**，其中「该用例红 ⇒ 因为 provider 返回 null 走 `?.` no-op」这条**归因已被第 2 轮否掉**：
> 该 harness 用 `TodoVisualFixture` 把 `appDatabaseProvider` 覆盖成了真库（`test/support/todo_visual_fixture.dart:75`），
> 而 `syncChangeQueueProvider` 只依赖同一个 db（`providers.dart:114-118`）⇒ `taskSectionRepositoryProvider`
> 在这个上下文里**非 null**（`providers.dart:174-179`）。反证：同文件保留的两条用例能从真库读出 A组/B组
> （`kanban_section_menu_page_test.dart:94`、`:103`、`:113`）。所以「红因未定位」，不是这条缺陷的证据。
> 处置与复核过程见 `spec.md` 的「一条静态读出来的既有缺陷 + 一条我没查清的撤证」。
> **#316 也已撤销关闭**：`?.` 那个分支读得出来，但按 `app.dart:76-85`（bootstrapped 前只有 loading）+
> `app.dart:19-27`（未登录重定向 `/login`，`TasksByListPage` 唯一调用点 `home_shell.dart:679`）
> + `providers.dart:96-99`/`:114-118`/`:174-179`（session 非 null ⇒ 仓储非 null）这条链，它在真机上**不可达**，
> 是死防御分支而不是"点了确认什么都没发生"的缺陷。完整过程与教训见 `spec.md`（一）。

## Issue #315 那一格（列头「···」→ 重命名/新建分组/删除）已证实
- [x] 三项挂在**列头已有的那枚「···」**上，不新增按钮：分组模式下 `KanbanView.onSectionRename` /
      `onSectionCreate` / `onSectionDelete` 只交出「这一列对应的 `TodoTaskSection`」，
      页面侧复用已有的 `_createTaskSection` / `_renameTaskSection` / `_deleteTaskSection`
      ⇒ **没有新仓储方法、没有新契约**（源页 `:108`/`:115` 的那张脸由此闭合）。
- [x] 「未分组」哨兵列只给 `新建分组`，`重命名`/`删除` 灰显（与第 1 轮复核立下的「折叠项灰显不消失」同口径）。
- [x] 「···」tooltip 按模式分开：分组模式照抄清单侧 `管理分组 <名称>`（`todo-section-menu-*` 的原文），
      固定四列仍是 `调整<列名>列` —— 同一枚按钮在两种模式下管的对象不同，读屏必须能分辨。
- [x] 视图不持有分组状态：点 `删除` 后列还在，等仓储流回来（用例
      `视图不自己改名/删列：点菜单项只交回调，列标题与列集合不变`）。
- [x] 四件套：`320px + 1.3 倍字号下分组管理菜单不溢出` 是**实测**（菜单从 3 项变 6 项，`takeException()` 为空）；
      失败保留已加载数据 = 视图侧无本地写路径；过期响应不覆盖 = 回调交出的是**渲染时那一份** section 对象，
      仓储侧 `rename`/`delete` 走 `_sectionOrThrow`，实体已不在就抛错、由页面提示，不会静默改到别的分组。
- [x] **反向探针**（不是"跑绿就算"）：把 `sectionsManaged: sectionMode` 钉成 `false`
      ⇒ 本轮 5 条用例同时 `[E]` 红（就地三项 / 未分组列 / tooltip / 320px 菜单 / 不自己改列），
      `cp` 还原后 `cmp -s` 判 IDENTICAL；正向对照 `没有分组时列头菜单不含分组管理三项` 在探针下仍绿，
      说明它咬的是"不该出现"而不是恒真。
- [x] 六项门禁跑在**已提交终态** `e3d58a9`，日志 `/tmp/g54/gates-final.log`（一条 `>` 重定向写完，
      不再有"tee 早于 mkdir 把上半段丢掉"的事）：
      头 `### head=e3d58a9  status_before_gates=[]  time=2026-09-24T19:56:14Z`、
      尾 `### status_after_gates=[]` 与 `### pr_files=…`（9 个文件，无 `pubspec.lock`）。
      | 门禁 | 结果 |
      | --- | --- |
      | 1 `git diff --check` / `git diff --check origin/develop...HEAD` | `rc=0` / `rc=0` |
      | 2 `dart format --output=none --set-exit-if-changed <7 个显式文件>` | `Formatted 7 files (0 changed)`、`rc=0`（N=7 == 本轮文件数） |
      | 3 `flutter analyze` | `No issues found! (ran in 1.3s)`、`rc=0` |
      | 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（9 张基线未重录） |
      | 5 全量非 golden | `02:29 +929 ~26: All tests passed!`、`rc=0` |
      | 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |
      ⚠️ 这一栏第一次写的是 `5fa649f` + `/tmp/g54/gates.log`（8 行、缺 head 与 gate1-3）—— 被复核当场抓到"留证不实"。
      数字本身没造假（那一轮确实跑过），但**引用的文件里根本没有那些行**，等价于拿不存在的东西当物证。
      规矩补一条：写"完整日志"之前先 `wc -l` + `head -1` 该日志，把这两个读数一起抄进台账。

## 矩阵 #15 现在到底差什么（别急着重言）
#313 + #315 把「分组开列 / 跨列拖动 / 拖动分组排序 / 分组内新建 / 列头管理分组」五格都补完了，
但**还不能判「有」**：源页团队看板那三面（`:175`「在看板视图右键任务，选择「分配给」」、`:188` 任务评论、
`:198` 任务动态）**从看板入口是否可达**还没按同一口径判过。下一格先判这三面，再谈翻转状态。

## 后半轮第 1 轮只读复核处置（`VERDICT: FAIL`，2 BLOCKING + 2 NIT）
复核手段同第 45 轮：本机 `claude` CLI 的模型别名仍不可用，改由本会话的只读子代理审。
findings **逐条回源复验成立**，无驳回（每条的复验命令与结论见下）：

| # | 级别 | 复核员说的 | 我复验到的 | 处置 |
| --- | --- | --- | --- | --- |
| 1 | BLOCKING | 分组模式没有「归档」列、已完成任务混排在各自分组列，且看板上改不了完成状态，而 spec 六条取舍与两条仍缺都没提 | `git show origin/develop:…kanban_view.dart` 的归档列是 `t.completed \|\| t.priority >= 3`；`_sectionColumns` 从头到尾不看 `completed` | 承认漏登记。`spec.md` 加取舍 3（写清这是分组方式的必然结果 + 明说代价"看板上改不了完成状态"），`kanban_view.dart` 类注释同步，补 2 条用例（列不聚合、拖进分组列不改 completed） |
| 2 | BLOCKING | 两处文档口径不成立：①「固定四列一字未改」——`新建任务` tooltip 其实两条路径都变了；②我把折叠项从灰显改成不渲染，连带改掉了智能清单（`listId == null` 时回调本就是 null）的老菜单形态，且与同菜单仍灰显的「左移/右移」自相矛盾 | `git show origin/develop:…kanban_view.dart` 第 391-392 行是 `value: 'collapse'` + `enabled: onCollapsedChanged != null`、第 404 行是 `tooltip: '新建任务'`；HEAD 一度变成 `if (onCollapsedChanged != null)` 与 `tooltip: '在${data.title}新建任务'` | ②**回滚代码**：折叠项恢复 `enabled:` 灰显；①**改文档**：spec 点名这一处 tooltip 确实在两条路径上都变了，并说明它是向同列头 `调整X列`/`折叠X`/`展开X` 的既有带列名写法对齐。补 3 条用例（折叠 enabled=false 而右移 enabled=true、偏好塞分组 id 不折叠、固定四列 tooltip） |
| 3 | NIT | `/tmp/g53/gates-final.log` 里没有门禁 1/2 的输出，也缺 `head=` / `status_before_gates=[]` 溯源行 | 那份日志确实只有 analyze/golden/full/build 四段 | 换一份完整日志 `/tmp/g53/gates-round2.log`，六段齐全 + 溯源头，数字全部重跑（+919） |
| 4 | NIT | 「溢出 141px」在树上只是散文，没有断言锁得住 | 确实只有 `expect(takeException(), isNull)` | 用形态断言替代数字（见上面门禁 3 段末），并在 tasks 里写明"数字锁不住"的原因 |

## 后半轮第 2 轮只读复核（`VERDICT: PASS`，5 条 NIT 全部处置）
4 条修复经复核回验成立（折叠那段与 develop 逐字节相同、门禁数字独立重跑吻合、
`git diff 7a56a49 HEAD -- lib test` 为空、引文 `:64/:99-:101/:108/:115/:129/:141/:148/:217-:219` 逐字命中）。
NIT 我逐条复验，**全部成立，无驳回**：

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
**全部成立并已全部修**，无拒绝项：

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



## 并主干轮（终态字节 `5d1d550`，2026-09-29）
分支基线落后 develop 一截，本轮**只做并主干**：没有新用例、没有新界面、没有改判定结论。
`git merge origin/develop`（`f361be4`）报 **4 文件 8 hunk**，合并提交 `7216e5a`，之后一笔 `5d1d550` 修 analyze 报的 `duplicate_named_argument`。

| 冲突处 | 取法 | 判据（现跑） |
| --- | --- | --- |
| `lib/features/task/views/kanban_view.dart` | 注释取 develop（含 develop 新加的右键「分配给」），`onAdd`／构造参数／字段与方法两侧都留 | `git diff d56b6a6 5d1d550 -- <该文件>` 里 develop 的 `onAssignCard` 与 `task_assign_action.dart` 的 import 都在 |
| `lib/features/task/task_quick_add_sheet.dart` | 取 develop 的「落库后顺带建提醒」，再把本分支的 `sectionId: widget.sectionId` 手工补回 `repo.create(` | `_save` 的 create 里同时有 `sectionId:` 与 `dueAt: dueAt`，`reminders.create` 那条与 develop 逐字一致 |
| `lib/state/repositories/task_view_action_repository.dart` | **两个方法各自完整重建** | `moveKanbanTaskToSection`／`moveQuadrantTask`／`reorderListTasks` 各 1 次；任取一侧都会合成一个跑不通的方法体（两侧共享同一条 `update(...)..write(TodoTasksCompanion(` 尾巴） |
| `specs/044-kanban-groups/tasks.md` | 取本分支台账 | develop 那四条旧「仍缺」逐条有下文：`列定义未绑定`→上面「后半轮已证实」第 1 条；`拖到未分组落库语义未定`→第 2 条；`四件套不适用`→第 4 条；`看板列头无「···」`**仍挂在「仍缺」第 1 条**，只把含义收窄 |

**被删那枚 `onAdd` 的等价性判据**：develop 写的是 `ordered[index].key == const ValueKey('col-todo') && listId != null ? () => _quickAdd(context, ref, listId!) : null`，与本分支保留那枚的 `!sectionMode` 分支逐字等价 ⇒ 删的是重复实参，不是 develop 的行为。分组模式那侧 develop 没有本分支未覆盖的新语义。

**六道门禁跑在 `5d1d550`**（日志 `/tmp/r136/gates314.log`，首行 `### head=5d1d550 status_before_gates=[]`）：
g1 `git diff --check origin/develop HEAD` rc=0；g2 逐文件 `dart format --output=none --set-exit-if-changed` **7 个 dart 文件、0 changed**（旧写法 `xargs -a` 在 macOS 不存在，会造出 rc=1 的假红，所以这里一个文件一次）；g3 `No issues found!`；g4 `--tags golden` **`+9`**、`find test -name '*.png' | wc -l` = **9**、`git status --porcelain -- test/goldens | wc -l` = **0**；g5 全量 **`+1227 ~26`**；g6 `✓ Built build/web`。`status_after_gates=[]`，`pubspec.lock` 不在 PR 的 9 个文件里（`git diff --name-only origin/develop...HEAD | grep -c pubspec.lock` = 0）。
**两条我自己写坏的度量要说清**：日志里 `png=0` 是我把路径写成 `test/goldens/*.png`（少一层 `todo_workspace/`）造成的**空度量**，不是基线被重录，已在同一条日志末尾用现跑命令补正；`lock_pubdev=0 lock_mirror=0` 在本仓恒 0（`pubspec.lock` 里没有 `url: http` 形态的行），这两条**不算证据**，真正管用的是 `status_after_gates=[]`。

**本轮没有 VERDICT**：#313/#315 那几轮 PASS 审的是并主干之前的字节，对 `5d1d550` 只覆盖「本轮没改的部分」，冲突解决那四处由新派的那一轮判（`/tmp/r136/review-314-r1-prompt.md`）。**未拿到 PASS ⇒ 矩阵 #15 的状态不翻、缺口不销。**

**下一轮入口**：① 回收 `5d1d550` 那轮 VERDICT，PASS 才谈合并与矩阵 #15；② `仍缺` 第 1 条（看板上就地新建／改名／删除分组）与第 2 条（「未分组」列排位是推断）仍在；③ develop 侧新出现的 `KanbanColumn.onAssignCard`（右键「分配给」）与本分支的分组列是两条独立通道，`#15` 的 `:175`/`:188`/`:198` 三面判定要在合并后按新 develop 重取锚点。

# 任务台账：specs/055「设置 → 日期与时间 → 时区」总开关（FL Issue #368）

基准：`zh-cloud-todo-flutter origin/develop@9032005`（分支 `feat/368-timezone-switch`）。
勾选规则：只有**实际跑过且读数对上**的才勾；没判据的写「无判据 + 为什么」。

## 一、实现

- [x] `lib/state/repositories/timezone_preference_repository.dart`（新增，`DATE_TIME`/`timezone` 一行 + `view_preference` 入队）
- [x] `lib/state/providers.dart`：`timezonePreferenceRepositoryProvider`、`timezoneEnabledProvider`
- [x] `lib/features/settings/settings_route.dart`：`_Section('日期与时间')` + `_TimezonePreferenceTile`
- [x] `lib/features/task/task_detail_pane.dart`：提醒编辑器「固定时区」按偏好显隐（`_showReminderEditor` 补 `WidgetRef` 形参）

## 二、按 FR 的判据台账

| 条目 | 判据 | 实跑读数 |
| --- | --- | --- |
| FR-1 有「日期与时间 → 时区」开关 | W1 `find.text('日期与时间')` + `ValueKey('settings-timezone-enabled')` 内的 `Switch` | `+10`（终态实跑见「四·重跑」：门禁 5 = `+908 ~26`，`908 − 10 = 898` 对得上 develop 基线） |
| FR-2 关掉 ⇒ 「固定时区」不出现、IANA 输入框仍在 | `test/features/task/reminder_timezone_gate_test.dart` 两条（开/关各一条，成对） | 同上；**这条先红过一次**（见「三-1」） |
| FR-3 开关不改写任务数据 | R2：切三次后逐字段比对 `timeZone` / `fixedTimezone` | 同上 |
| FR-4 持久化 + 同步 | R1：`get()` 默认开、`todo_view_preferences` 恰 1 行、`todo_sync_changes` 恰 1 条 `entity=viewPreference`、再开仍是 1 行 | 判据可复跑：`flutter test test/features/settings/timezone_preference_test.dart --plain-name R1` ⇒ 绿；「恰 1 行」「恰 1 条」由该用例内两处 `hasLength(1)` 兜住，复算 `git grep -c "hasLength(1)" origin/develop -- test/features/settings/timezone_preference_test.dart` = 4。⚠️ 复核 F-3 记一句红因：把 update 分支改成「再插一行」时，红是 **schema 的 UNIQUE(2067) 抛在仓储里**，`hasLength(1)` 那条断言根本没执行到 ⇒ 这一格真正兜住重复行的是库上的唯一索引，我的断言只是第二道网；并发那道的判据在 R3 |
| FR-5 展示层不受影响 | **无行为测试**，用两条静态判据：`git grep -n "timezoneEnabledProvider" -- lib` ⇒ 3 命中（定义 + 设置页 + 提醒编辑器），`lib/core/time` 内 0 命中；`git status --porcelain lib/core/time \| wc -l` = 0，`task_time_formatter.dart:167` 的「`<IANA> 固定时区`」原样 | 命令已跑（本次会话内），读数如左 |
| FR-6 「固定时间」档 | **本面不做**，另立 FL #369（前置是 service 的逐任务三态模式位） | — |

四件套：

| 件 | 判据 | 状态 |
| --- | --- | --- |
| 1 320px + 1.3 倍字号（本路由自己的 context） | W3：视口宽 320、`TextScaler.linear(1.3)`，先确认 `Switch` 真被渲染，再 `expect(tester.takeException(), isNull)` | 有判据、绿 |
| 2 独立读屏语义 | W2：`getSemantics(f).getSemanticsData().flagsCollection.isToggled` 开时 `Tristate.isTrue`、切换后 `isFalse`（正反两条）；名称由 `find.bySemanticsLabel(RegExp('时区'))` 钉；另判 `onChanged != null` | 有判据、绿。**这一格返工过两次**：先按红测加了 `semanticsLabel`，复核 F-1 证明那是「读错数据源」换来的假结论 ⇒ 文案已撤回，见「三-3」 |
| 3 失败保留已加载数据 | W4（仓储为 null ⇒ 「时区设置暂不可用」）+ W5（写抛错 ⇒ 「时区设置未保存」且开关与内存态都停在原值） | 有判据、绿 |
| 4 过期响应不覆盖新响应 | **R3**（新增）：并发 `setEnabled(false)` / `setEnabled(true)` ⇒ 不抛异常、偏好表恰 1 行、`get()` 回最后一次意图、outbox 2 条 | 有判据、绿。**上一版这里写的是「无判据 / 本面不可达」，两句都是假的**（复核 F-2 + 本仓复算，见「三-4」）；连取证句也站不住、且原句行号已过期 ⇒ 改按方法体现读：`git grep -c "await" origin/develop -- lib/features/settings/settings_route.dart` = 10 命中。`_save` 的两个重载体内各有一处 `await` —— `lib/features/settings/settings_route.dart:437` 与 `lib/features/settings/settings_route.dart:549`；剩下的落在别的方法里，按方法名数得 `_pickWeekStart`、`_signOut`、`_pickShowTags`、`_pickShowFilters` 四个 |

## 三、红测记录（真红过两次，各修一处）

1. **FR-2 红在实现**（`flutter test test/features/task/reminder_timezone_gate_test.dart` → `+1 -1`，
   红在 `findsNothing` 那一条）。行号会随格式化漂 ⇒ 定位改用命令：
   `grep -n findsNothing test/features/task/reminder_timezone_gate_test.dart`（现值 `:43`）。
   `Actual` 是 1 个 `SwitchListTile-[<'task-reminder-fixed-timezone'>]`。
   根因：实现写的是 `ref.read(timezoneEnabledProvider).valueOrNull ?? true` —— `StreamProvider` 首帧是
   `AsyncLoading`，`valueOrNull` 为 null ⇒ 恒退成「开」，"关没关掉"取决于用户在流首帧到达前点了多久。
   修法：`await ref.read(timezoneEnabledProvider.future)`（取"打开这一刻"的持久值），并在 await 之后补 `context.mounted` 才 `showDialog`。
2. **四件套-2 红在判据的假设**（`+3 -1`，红在 `Expected: CheckedState.isTrue / Actual: CheckedState.none`）。
   临时探针（跑完即删，未入库）实测：`SwitchListTile` 挂 key 的节点与其内部 `Switch` 解析到**同一个**
   `SemanticsNode`，该合并节点 `isChecked=none`、`isToggled=none`、`isButton=false`、`isEnabled=true`、
   label=「时区\n开启后可为任务选择「固定时区」」⇒ `Switch` 自带的状态位到不了读屏（merge 只合并 label）。
   修法（当时的）：状态写进 `title` 的 `semanticsLabel`。**这条修法被三-3 撤回** —— 红是真红，结论是假的。
3. **复核 F-1 驳回「到不了读屏」这句，本仓复算接受**（两方独立 + 一条仓内断言：复核自己的探针、
   cursor-agent 交叉验证 `/tmp/xcheck/q1.out`；正反向读数钉在仓内 ——
   `test/features/settings/timezone_preference_test.dart` 里 W2 那两条 `_toggled(tester)` 断言，
   现读 `grep -n "_toggled(tester)," test/features/settings/timezone_preference_test.dart` = 2 命中，
   第 2 轮复核分别把基线改成 `false`、断开假仓储写入流 ⇒ 两条各自红，不存在恒真）：
   我读的是 `SemanticsNode.flagsCollection`（节点**自有**位；子节点被 merge 时 flags 不回写，所以恒 `none`），
   而 `SemanticsNode._addToUpdate` 导出给平台的是 `getSemanticsData()` 那份 —— 同一条数据里
   `Switch` 的 `isToggled` 开 = `Tristate.isTrue`、关 = `isFalse`。
   ⚠️ 原先这一条把正反读数记在本仓 `/tmp/r82/probe-pre-fix-bad0933.log` 名下，**挂错了工件**（第 2 轮复核 3 号缺陷）：
   那份日志第 4 行与第 7 行的 `NODE.label` 都是「时区，已开启」⇒ 探针在"关"那一档根本没扳动开关，
   而且它只打印 label、压根没打印 `isToggled`。结论不变，引证作废。
   ⇒ 自创的 `semanticsLabel` 已删（屏幕与播报都回到嘀嗒的「时区」+ 系统开关态），判据改钉 `getSemanticsData()`。
   **教训：判「某个能力不存在」之前，先确认读的是导出给平台的那份数据；名字读不到 ≠ 能力不存在。**
4. **复核 F-2 驳回「并发不可达」这句**：修前实测（同一份探针）
   `SqliteException(2067): UNIQUE constraint failed: todo_view_preferences.source_type, todo_view_preferences.source_key`
   且 `rows=1 / get()=false` —— 最后一次意图（true）被吞掉。根因是我照抄
   `task_sort_preference_repository` 的形时**漏了外层 `_db.transaction(...)`**；补回事务后 R3 绿。
   同一笔还把上一版那句「4 个 `await` 全部在 `_save` 内」判为假（见「二」四件套-4 格）。

## 四、六道门禁

⚠️ **本节下面这份读数只属于 `b571ef1`，不再充当终态证据**：复核第 1 轮 F-1/F-2 之后动了实现
（撤回 `semanticsLabel`、`setEnabled` 补事务）并新增 R3 ⇒ 门禁要在新的终态字节上整套重跑。
旧日志留着是为了能对照「哪一格变了」。

基准：已提交终态 **`b571ef1`**（`ac51c0b` 是功能那一笔，`b571ef1` 只把门禁 2 判红的三处换行收齐）；
日志 **`/tmp/r82/gates-b571ef1.log`**（1397 行；文件名带 sha ⇒ 不会被下一轮覆写）。六项 **rc 全 0**。

| 门禁 | 读数（从上面那份日志现读，行号是日志内的） |
| --- | --- |
| 1 `git diff --check 9032005..HEAD` | 无输出，`rc=0`（`:4`） |
| 2 `dart format --output=none --set-exit-if-changed`（本轮 6 个文件） | `Formatted 6 files (0 changed)`，`rc=0`（`:7`、`:8`） |
| 3 `flutter analyze` | `rc=0`（`:74`） |
| 4 `flutter test --tags golden` | `00:09 +9: All tests passed!`（`:148`）⇒ **9 张基线一张没重录**，设置页新增一节没进任何一张的视口 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:27 +907 ~26: All tests passed!`（`:1314`） |
| 6 `flutter build web --release`（带 test 域名与租户两个 dart-define） | `✓ Built build/web`（`:1393`），`rc=0` |

计数对账的历史式 `907 − 本轮新增 9 = 898`（`b571ef1` 那轮）——
当年两端各有实跑留痕，但那些文件落在未入库的一次性目录、今已不可取 ⇒ 这类指针从本笔起一律作废，改钉「命令 + 现跑读数」：
在 FL `origin/develop@ded9791` 的一次性工作树跑 `flutter test --exclude-tags "golden || performance" --concurrency=1` ⇒
现读 `+1314 ~26: All tests passed!`、`rc=0`（本笔实跑；命令本身可复跑，日志不入库）。
⚠️ 但别把 skip 数当常量：它只能现跑现读 —— 本笔在 `ded9791` 现读 `~26`，与当年记的 `~26` 相等 ⇒ 这条链上没新增 skip（若哪天不等，就是仓内 skip 变了，不是这里写错）。
提交数改钉死尾 sha 后复算：`git log --oneline 9032005..b571ef1 | wc -l` = 2（与当年记的值一致；
上一版把尾 sha 写成 `HEAD`，那正是「自己作废自己」的计数法 —— 每多一笔台账它就涨一格）。

⚠️ 门禁 2 **第一次是红的**：`ac51c0b` 上 `Formatted 6 files (3 changed)` ⇒ `rc=1`
（第一份日志 `/tmp/r82/gates-ac51c0b.log`，读数留在 `:6-11`，没被覆写）。
处理方式是把三个文件按 formatter 收齐再重跑全套 —— 没有改判据、没有跳过。

跑完门禁后 `git status --porcelain pubspec.lock` 为空（同日志收尾行 `脏项数=0`）⇒
`pubspec.lock` 没被本机镜像扫进这笔。

### 重跑（终态基准 **`876c35e`**，日志 **`/tmp/r82/gates-876c35e.log`**，1400 行）

复核 F-1/F-2 之后动了实现 ⇒ 整套六门禁重跑，**六项 rc 全 0**：

| 门禁 | 读数（行号是这份日志内的） |
| --- | --- |
| 1 `git diff --check 9032005..HEAD` | 无输出，`rc=0`（`:4`） |
| 2 `dart format`（本轮 6 个文件） | `Formatted 6 files (0 changed)`，`rc=0`（`:8`） |
| 3 `flutter analyze` | `rc=0`（`:74`） |
| 4 `flutter test --tags golden` | `00:11 +9: All tests passed!`（`:148`）⇒ 9 张基线仍一张未重录 |
| 5 全量非 golden（`--concurrency=1`） | `02:50 +908 ~26: All tests passed!`（`:1315`） |
| 6 `flutter build web --release` | `✓ Built build/web`（`:1396`），`rc=0`（`:1397`） |

同一式的第二个读数：`908 − 本轮新增 10 = 898`（新增 10 条 = 上一版 9 条 + R3）——
那两处一次性留痕同样已不可取 ⇒ 按「二」节那条命令现跑复算为准，本笔实测 `+1314 ~26`。
门禁跑在已提交终态上：本笔在 `ded9791` 的一次性工作树跑完 `git status --porcelain` 输出为空（`pubspec.lock` 未被本机镜像改写）⇒
**门禁是跑在已提交终态上、且没把本机镜像扫进 `pubspec.lock`**。

台账这几笔（`876c35e` 之后的 md 改动）不动代码字节 ⇒ 上面这份读数对终态仍然有效；
自证命令：`git diff --name-only 876c35e..HEAD`（只应出现 `specs/055-*/{spec,plan,tasks}.md`）。


## 五、编译红（不充当行为证据，只留名字）

- `TextFormField` 没有公开的 `decoration` getter ⇒ 改判渲染出来的 label 文本。
- `dart:ui` 的 `SemanticsFlags` 上没有 `isToggle` / `hasCheckedState`（真名 `isToggled` / `isChecked`），
  `SemanticsNode` 没有 `.node`（是 `.id`）；`CheckedState` 需要 `import 'dart:ui' show CheckedState`。
- `import 'package:drift/drift.dart'` 与 matcher 的 `isNull` / `isNotNull` 撞名 ⇒ `hide isNull, isNotNull`
  （但 `&` 组合条件要整个 drift 导入，不能 `show Value`）。
- 本仓这版 SDK 的 `WidgetTester` **没有** `getSemanticsData(finder)`
  （`Error: The method 'getSemanticsData' isn't defined for the type 'WidgetTester'`）⇒ 写
  `getSemantics(f).getSemanticsData()`。⚠️ cursor-agent 的答案里用的是 `tester.getSemanticsData(finder)`：
  实质一致、名字按本地 SDK 为准（**外部交叉验证也不能照抄，要实测**）。
- `SemanticsNode` 没有 `.node`（是 `.id`），也没有公开的 `actions`。

## 六、踩到并已绕开的测量坑

- `ListView(children: …)` 只构建进视口的行：320×700 下「日期与时间」整节没被构建 ⇒ `find.text` 0 命中，
  看着像"控件没做"其实是"没滚到"。修法：视口高度给到 2400（`_pumpSettings` 里注明了原因）。
- UI 测试**不接** in-memory Drift 的读流：接了收尾必炸 `A Timer is still pending…`；
  改成"收尾 settle 再关库"反而拖到 10 分钟超时。持久化的真库判据留在 R1/R2，UI 侧用 `implements`
  的假仓储（`timezoneEnabledProvider` 仍走真实实现去 `watch()` 它，所以接线本身还是被测的）。
  仓内既有先例是 `TodoVisualFixture` 用 `closeStreamsSynchronously: true` —— 提醒编辑器那两条就是走这条路。

- **「读形不读全」**：抄仓内先例要把那一段整段读完（`setEnabled` 漏掉的正是外层 `_db.transaction`）；
  形对了但并发语义错了，这种洞在单线程测试里不会亮 —— 所以并发判据（R3）本身就是要补的东西。
- **读语义要读导出给平台的那份**：`SemanticsNode` 自有字段 ≠ `SemanticsData`（合并快照，真正下发给
  VoiceOver/TalkBack）。我用前者下了「能力不存在」的结论并据此改了 UI 文案 ⇒ 一次返工 + 一处自创文案。

## 七、遗留与下轮入口

- 矩阵 #12 只去掉「设置里没有『时区』总开关」这条缺口（FL #368 自称的「缺项 ⑥」），
  仍留「任务上没有『固定时间』档」（FL #369 标题写的「缺项 ⑤」）⇒ **状态不翻**（仍「部分」）。
  ⚠️ 复核 F-6 复算后**半对半驳回**：`origin/develop` 的 #12 格确实只有一句
  「`time_zone/fixed_timezone` 字段有；缺跨时区展示闭环」（`git show origin/develop:… | sed -n 73p`，
  该文件里 `grep -c ⑤` = 3），**编号清单只活在未合并的 docs 分支**（同文件 `:79`、`grep -c ⑤` = 21）。
  ⇒ 结论照实写：不是矩阵写错，是 docs 那批 PR 没合的后果；矩阵侧本轮已改写成文字缺口 + Issue 号。
- PR 未合并前，矩阵措辞用「已实现、未进 develop」。
- FL #369 已在 Gitea 现读为 `open`（标题「任务档『固定时间』（墙钟锚定）缺实现：先在 zh-cloud-service
  补契约（矩阵 #12 的缺项 ⑤）」）⇒ 第一道门是 service 契约（逐任务三态模式位），排在下一面。
- **F-4 登记（判为不可达，但把复现方式写清）**：`await ref.read(timezoneEnabledProvider.future)` 期间
  若那条流一直不出事件，用户点「提醒」就是「点了没反应、也不给反馈」。判为不可达的理由链：
  `_editReminder` 在这一步**之前**已经 `await` 过同一条 `appDatabaseProvider` 的 `todoTasks` 查询，
  库慢到会先在那一步卡住；而 drift 的 `watchSingleOrNull()` 一定会发首帧。
  复核用「自己造一条永不出事件的流」能把它点亮（其 PROBE-A）—— 那不是生产路径。
  **这条不删：下次真在生产里遇到就升级为缺陷。**

## 八、第 1 轮只读复核（PR !370，报告 `/tmp/r83rev370/report.md`，审的字节 = 代码 `b571ef1` + 台账 `bad0933`）：`VERDICT: FAIL`

复核员独立复算**成立**的四项（不只记它的错）：范围（9 个文件全属这一面、`pubspec.lock` 三处 blob 相同、
`b571ef1..bad0933` 只动本台账 ⇒ 门禁对终态有效）；门禁台账六个行号指针全部命中、`^rc=` 恰 6 行全 0；
它自己把两份新测试跑出 `+9` 与 `907 − 898` 互洽；9 组变异补丁咬住 8 组（M1 删 `setEnabled` ⇒ `+6 -3`、
M3a/b/c 动 `semanticsLabel` ⇒ 正反分别红在 `:180`/`:167`、M5 无库 ⇒ 红 W4、M6 默认关 ⇒ 红 R1、
M7b 真溢出 ⇒ 红 W3 并打出 `RenderFlex overflowed by 638 pixels`）；
还核了 service 侧（`c432b6f54e`：`fixed_timezone bit(1)` + `time_zone varchar(64)`，40 处 `fixedTimezone` 全是 `Boolean`，
`timeMode`/`fixed_time`/`keepTime` 0 命中）⇒ **「固定时间」需要新契约、不是我不肯做**这句是真话。

| 编号 | 失项 | 本仓复算（自己重跑，不采信转述） | 处置 |
| --- | --- | --- | --- |
| F-1 | 「`SwitchListTile` 的状态位到不了读屏」是**假实测**：我读的是 `SemanticsNode.flagsCollection`（恒 `none`），平台吃的是 `getSemanticsData()`；且这句假事实写进了 `settings_route.dart` 的注释 | 探针复跑：同节点、`node.toggled=none` 而 `data.toggled=isTrue`；cursor-agent 独立给同一结论（`_addToUpdate` 先 `getSemanticsData()` 再 `updateNode(flags: …)`） | 撤回 `semanticsLabel` 与那段注释；判据改钉 `getSemanticsData().flagsCollection.isToggled` 正反两条。spec 五-2、六-4 同步 |
| F-2 | 四件套-4 的「本面不存在并发覆盖」**结论与取证双假**：并发两次 `setEnabled` ⇒ `UNIQUE 2067` + 最后意图丢失；`grep await` 那句里 4 命中有 3 条不在 `_save` 内 | 复跑同一形状：`SqliteException(2067) … source_type, source_key`、`rows=1`、`get()=false`（`/tmp/r82/probe-pre-fix-bad0933.log`） | `setEnabled` 整段补 `_db.transaction`（照仓内先例）+ 新增 R3 四条断言；台账与 spec 五-4 改写成判据不是取舍 |
| F-3 | 台账把 M4 的拦截者记成 `hasLength(1)`，实际红因是 schema 的 UNIQUE 抛在仓储里，断言根本没执行到 | `git show` 逐行对：R1 的 `expect(…, hasLength(1))` 在 insert 抛错之后 | 「二」FR-4 那格不改判据但补一句红因；并发那格由 R3 承担 |
| F-4 | 弹窗前那次 `await` 若流不出首帧 ⇒ 点了没反应也不给反馈 | 不可达论证见「七」最后一条，理由两处：① 同一条 `appDatabaseProvider` 的查询在此之前已 `await`；② drift 的 `watchSingleOrNull()` 必发首帧 | **登记不修**，复现方式与理由链一并写进「七」 |
| F-5 | 四处指针/计数不精确：日志行号指针（原写 `:1155`，真身 `:1154`）、三-1 的「第 45 行」、`wc -l` 未钉尾 sha、spec 二 `:405` 与同文 `:404` 打架 | 日志指针那处随「二」节改钉命令一并撤销（旧引证那份文件已不可取）；`git show 9032005:lib/features/task/task_detail_pane.dart` 里再 `grep -n task-reminder-fixed-timezone` = **404**；`grep -n findsNothing` = `:43`；提交数已钉尾 sha（现读 = 2，见「二」） | 逐处订正；行号易漂的两处改成「用命令定位」 |
| F-6 | 「缺项 ⑤/⑥」矩阵读者无从解析；FL #369 存在性它没法核（会话里无 Gitea 凭据，匿名 404） | **半对半驳回**：`origin/develop` 的 #12 只有「字段有；缺跨时区展示闭环」⇒ 它对 develop 成立；但清单在未合并的 docs 分支 `:79` 里就有（`grep -c ⑤`：develop 3 vs 分支 21）⇒ 不是写错，是 docs 没合。#369 我用 API 现读 `state=open`，标题带「缺项 ⑤」 | 矩阵侧本轮已改写成文字缺口 + Issue 号（docs `27525b4`，!102）；编号来源在 spec 七 写清是哪个 ref |

**本笔动了实现** ⇒ 上面「四」节 `b571ef1` 那套门禁作废，终态另跑一份新日志（见「四」末尾的「重跑」）。

## 九、第 2 轮只读复核（报告 `/tmp/r84rev370/report.md`，审的字节 = `fa94cfa`）：`VERDICT: PASS`

两条真缺陷被复验为**真修好**，不是只变绿：

- F-2（事务）：摘掉 `_db.transaction` 只留内层语句 ⇒ R3 红 `+7 -1`，红因正是 `SqliteException(2067)`，
  抛点 `timezone_preference_repository.dart:61`（异步间隙来自 `:46`）。又在临界区注入 40 ms 等待做**串行性陷阱**：
  带事务 `elapsed≈147 ms`（顺序）、同一陷阱摘事务 `101 ms` 且 `get()=false`（最后意图丢失）；
  另做 40 路并发与 30 轮 `Future.wait` 各一组 ⇒ drift 确实互斥整段临界区。R3 三条断言各自翻错各自红 ⇒ 无牙排除。
- F-1（读屏）：`semanticsLabel` 在 `lib/`、`test/` 命中 **0**（8 处全在 specs 的撤回记录里），
  并用 `git grep … ac51c0b` 做正向对照排除"搜索基是过期 clone"；W2 正反两条各自红（断假仓储写入流 ⇒ 第二条；
  基线改 `false` ⇒ 第一条）⇒ 不是恒真判据。
- 范围与字节：`lib`、`test` 两棵 **tree hash 在 `876c35e` 与 `fa94cfa` 相同**（比"只改 md"更强），
  `pubspec.lock` 四处 blob 同为 `7ef8030b`；门禁 1–5 在副本复跑，`+908 ~26`、`+9`、
  `Formatted 6 files (0 changed)`、`No issues found` 全对上；F-6 的驳回被独立复现。

**本轮新写的**台账缺陷共三条，逐条见下表九-1、九-2、九-3；改法就地见 spec 六-1 与「三-3」：

| 条目 | 复核指的问题 | 本仓复验（命令与读数） | 处置 |
| --- | --- | --- | --- |
| 九-1 | spec 六-1 的「命令见 `tasks.md` 二」是悬空指针 | `grep -n 默认 specs/055-settings-timezone-switch/tasks.md` 只命中 FR-4 那格与 M6 一行，二节没有那条命令 | 命令写进 spec 就地可跑，并注明 `grep` 零命中时退出码 1 属正常 |
| 九-2 | 引了一个不存在的复核编号 F-1′ | `grep -c "F-1′" /tmp/r83rev370/report.md` = 0；默认值那条在正文「四-1」（`:85` 判"站得住但前提不成立"、`:94` 明写不判失项） | 换成真实小节与行号，并留一句"原编号不存在" |
| 九-3 | 三-3 把「关 = isFalse」记到 `/tmp/r82/probe-pre-fix-bad0933.log` 名下 | 那份日志 `:4` 与 `:7` 的 `NODE.label` 都是「时区，已开启」⇒ 探针在"关"那档没扳动，且它只打印 label、没打印 `isToggled` | 正反读数改钉仓内 W2（`grep -c "_toggled(tester)," test/features/settings/timezone_preference_test.dart` = 2），旧引证在「三-3」记为作废 |

`PASS` 只说明字节与台账一致、两处缺陷确已修 ⇒ **不构成合并依据**，合并仍等单独授权。

## 十、并入 develop 之后在合并字节上重跑（2026-09-28，merge 提交 `db39cd9` + 修复提交 `4b0e24f`，日志 `/tmp/r136/g370b/`）

develop 从本分支基线前进到 `af62a8bfa2da`（specs/047「#」建标签、specs/064 日程跨日时间轴、specs/066/067 侧栏落点已进线）⇒ 必须先并主干。冲突 2 处，都是"两边在同一位置各加自己的东西"：
- `lib/state/providers.dart` 的 import 段与时区/周首两组成员混在一个冲突块里 ⇒ 两边全留，且被共享的 `});` 只会闭合最后一个 `StreamProvider`，所以把时区那一组补上自己的 `});` 再拼周首那一组。
- `lib/features/settings/settings_route.dart` 的「日期与时间」卡：develop 侧往 `children` 里加了「星期开始于」行，本分支整张卡只有时区开关 ⇒ 以 develop 的结构为底，把 `_TimezonePreferenceTile()` 追加进去。

**并主干量出一个真缺陷并已修**（修复提交 `4b0e24f`）：时区开关最初插到 `children` **首位**，把已上线的「星期开始于」行推到 y=1306，而 develop 那条《320px + 1.3 倍字号：设置行与档位弹层都不溢出》用例的视口高 1200 ⇒ `tap` 打不到、档位弹层找不到，g5 转红。改法是把时区开关排到它**后面**：已上线那一行的位置不动，两个开关都保留。这不是把测试调宽——红的是被移动的既有控件，修的是布局顺序。

六道门禁重跑在 `4b0e24f`（`/tmp/r136/g370b/`）：
- `g1 rc=0`：`git diff --check $(git merge-base origin/develop HEAD) HEAD`，除标题行外 0 输出。
- `g2 rc=0`：`Formatted 3 files (0 changed) in 0.08 seconds.`
- `g3 rc=0`：`No issues found! (ran in 1.5s)`（`flutter analyze` 全仓）。
- `g4 rc=0`：`goldens_dirty=0 png=9` ⇒ 9 张基线一张都没重录。
- `g5 rc=0`：`+1181 ~26: All tests passed!`（`/tmp/r136/g370b/g5.log` 末行）（比并主干前的 +1140 多，是主干带进来的 specs/047/064/066/067 用例）。
- `g6 rc=0`：`✓ Built build/web`，收尾 `status=0`（工作树干净，`pubspec.lock` 未进任何提交）。
真实合并试算：`git merge-tree --write-tree origin/develop HEAD` ⇒ rc=0、干净树 `c350a6cb5f77`。
台账自扫：`python3 tool/check_spec_selfscan.py specs/055-settings-timezone-switch/tasks.md`（本仓 = 仓库根解析）。

### 十-1、本仓自扫判据的**存量**失项（不掩盖：本轮没把它们清到 0）

`python3 tool/check_spec_selfscan.py specs/055-settings-timezone-switch/tasks.md` 现读 **失项 6 条**，6 条的报出行号全部小于第 212 行 ⇒ 都是第 8/9 轮写下的存量；本轮新加的「十」段自身 0 失项（这段被复扫过，日志 `/tmp/r136/selfscan370.txt`）。
6 条的缺陷类型只有三种：覆盖性主张缺可复跑命令、枚举项数与句首数目不符、指向 `/tmp` 的门禁日志行号已成死锚点。逐条修法是就地补命令或改数，纯 markdown，**不需要重跑六道门禁**。

治理单：**FL Issue #409**（本单不排进功能轮次，与 PR !370 分开收口）。本段只登记不修，故**本轮合并前置中「台账自扫 0 失项」这一条对本文件不成立**——写成不成立而不是略过；六道门禁与只读复核不受影响，因为门禁量的是代码字节（见上一节六格）。

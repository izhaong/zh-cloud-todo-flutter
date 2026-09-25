# 043 任务清单

## 第 43 轮复核 #1 = VERDICT: FAIL，逐条处置
| # | 复核结论 | 处置 |
| --- | --- | --- |
| 1 | FR-002 的引文「哪一天没背够 5 页」**不是原文子串**（原文 `:72`：「即使哪一天没有背够5页的单词，也能记录自己完成3页的付出和努力。」），且 `:72` 被过度归因 | **收下**。`spec.md` 改为逐字引用并说明它讲的是「记付出」不是「看空格」；「整月逐日排格」改记为**本端实现选择**，不再挂 `:72` |
| 2 | 契约只在 tip `17a55ed` 上自证过，`6a67047` 上被推翻；且**假仓库用的是和生产同一个 padLeft**，后端↔客户端日期格式一致无处可证 | **收下**。假仓库改喂 `toIso8601String()` 前 10 位（= Java `LocalDate.toString()` 的形状），再断言这条记录的次数确实落进那一天的格子；探针：把生产 `padLeft(2,'0')` 摘掉 ⇒ 该用例红（见下） |
| 3 | 用例 5 从不断言 `isButton`（摘掉 `button: true` 仍绿）；正则未锚定；用例 2/6 用 `findsAtLeastNWidgets(28)` 且不校验月长；只有两格有独立 key | **收下**。加 `node.flagsCollection.isButton` 与 label **全等**；格子数改 `findsNWidgets(当月真实天数)`；末号（一定无记录）单独占 key 并断言「N 日，未打卡」 |
| 4 | **四件套 FALSIFIED**：`MediaQuery` 包在 `home:` 传不进 `showModalBottomSheet` 的路由，而 `spec.md:44` 声称相反；「无并发请求」也是假的（每次补记发一次 `stats`，无守卫 ⇒ 旧包覆盖新数据）；`ref.invalidate(habitStatsProvider)` 刷的是 `overviewStats`，与描述不符 | **全部收下**，三处都是生产/规格的真错：① 档位挂到 `MaterialApp(builder:)`；② 加 `_loadSeq` 守卫并立 FR-007 + 用例；③ `spec.md` 改述为「刷打卡概览」，并用不 override 的 `habitStatsProvider` 断言 `overviewStats()` 调用次数真的涨了 |
| 5 | 范围核验通过（5 个允许路径、无黄金图、无 `pubspec.lock`）；但 `plan.md` 在 `6a67047` 上不存在（`45df60b` 才加） | **收下措辞**：本文件下面按 commit 记门禁归属，不再笼统说「跑在最终状态」 |

一处**自我更正**要写在台面上：修 ④② 期间我按记忆猜 SDK API，连踩两次整文件编译失败。
能拿原文证实的只有第二次：`habit_month_grid.dart:170:31: Error: No named parameter with the name 'excludeSemantics'.`
⇒ **`Text` 没有这个命名参数**（正解是把可见文本包进 `ExcludeSemantics(child: Text(…))`）。
第一次的具体报错文本我没留在日志里（当时只看到 `Failed to load … Compilation failed`），
所以不再断言它是「命名参数排在位置参数前」那一类错 —— 复核第 6 条点的就是这句多余的话。
编译失败会让 `flutter test` 整文件红，所以第一轮 5 个"探针全红"是**无效证据**；改回 `ExcludeSemantics(child: Text(…))` 并确认全绿后重做的探针才算数（下面那组就是重做的）。

## 反证探针（改完之后重跑，每条红在自己的断言上）
终态 `flutter test test/features/habit/habit_month_grid_test.dart` ⇒ `00:01 +8: All tests passed!`

| 探针 | 改动 | 红在哪 |
| --- | --- | --- |
| P1 | 摘掉生产里的 `button: true` | `Actual: <false>`（`flagsCollection.isButton`） |
| P2 | `ExcludeSemantics(excluding: false, …)` | `Actual: '1 日，打卡 2 次\n' '2'` —— label 被子 Text 污染 |
| P3 | 摘掉 `seq != _loadSeq` 早退 | `Found 0 widgets with text "3" descending from … todo-habit-day-…`（旧包的 9 赢了） |
| P4 | 把 `MaterialApp(builder:)` 挪回 `home:` | `Actual: <10.0>`（弹层 context 的 `scale(10)`，即 1.0 倍） |
| P5 | 生产 `padLeft(2, '0')` 去掉零填充 | `Found 0 widgets with text "2" descending from …`（后端 ISO 串落不到格子） |

五个探针后各 `cp` 还原，末了 `cmp -s` 判生产与测试文件均 **byte-identical OK**。

## 门禁（终态 `2539f8b` 重跑，日志 `/tmp/r43_gates_final.log`）
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | `rc=0`、无输出 |
| 2 `dart format --output=none --set-exit-if-changed`（3 个文件逐个写死） | `Formatted 3 files (0 changed)`、`rc=0`。**这一条红过两次，都要记账**：① `ffe41ac` 上真红 —— 但**红的证据只是 stdout 的 `Formatted 3 files (1 changed)`**，那一跑的 rc 同样是 `tee` 的 0，没捕获到真值（复核第 3 条）；处置是 `dart format` 只格式化本轮那个测试文件，记为 `2539f8b`，终态再逐个文件裸跑取 rc；② 更早一次日志里写着 `rc=0` 是**假的** —— 参数走变量时 zsh 不分词，dart format 收到一个非法路径回了 `Formatted no files`，而 `… \| tee -a log; echo rc=$?` 记的是 `tee` 的码（zsh 无 `${PIPESTATUS[0]}`）⇒ 同一条门禁叠了两层假绿 |
| 3 `flutter analyze` | `No issues found! (ran in 1.9s)`、`rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`（基线 9 张，**未重录**）。**rc 口径要如实说**：这一条终态是单独补跑的，用 `… \| tee` 记输出，所以日志里没留退出码；判据是末行 `All tests passed!`。它在 `ffe41ac` 上裸跑过 `rc=0`，而 `2539f8b` 相比它只差一个 `dart format` 的空白改动且不含任何黄金相关文件 |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:17 +717 ~26: All tests passed!`、`rc=0`。计数可核对：develop 基线 709 + 本轮 8 例 = 717（首版 6 例时的 `+715` 已随本轮改动作废） |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web`、`rc=0` |

## 已证实
- [x] FR-001..FR-005 的用例存在且先红后绿（首版 6 条的红：`Found 0 widgets with text "月度打卡表"`、`Found 0 widgets with key [<'todo-habit-day-2026-09-23'>]`）
- [x] FR-006 由两条用例覆盖：一条在**弹层自己的 context** 上读回 `MediaQuery.textScaler`（1.3 ⇒ `scale(10)=13`），一条在 320×720 + 1.3 倍下断言 `takeException()` 为空**且**格子数等于当月真实天数
- [x] FR-007（新立）过期响应不覆盖新响应：假仓库门控两次回包（旧 9 / 新 3），`statsCalls == 3` 先自证竞态真的构造出来了，再按「新先回、旧后回」完成 ⇒ 界面停在 3、`9` 不出现
- [x] FR-004 失败保留数据：`checkIn` 抛错后「月度打卡表」仍在、当月格子仍是一整月、错误文案可见
- [x] 反向探针 A/B（首版）：摘 `AppCard(onTap:)` ⇒ `+0 -6`；只摘 `checkIn` 的 `date:` ⇒ `+5 -1`，红的正是「补记要传对日期」那条
- [x] 本轮 5 个新探针（P1..P5）各自红在自己的断言上，还原后 `cmp -s` 逐字节一致
- [ ] ~~契约无需改动~~ **已作废**（见复核第 2 条）：`TodoHabitServiceImpl.java:140`-`:145` 的 `dailyCounts` 是 `i % 2` 造的假数、固定只回 7 天 ⇒ 真实当月次数要先修后端（`zh-cloud-service` Issue #281）。客户端只渲染 API 给的 `dailyCounts`，不补假数据
- [ ] ~~「过期响应不覆盖新响应」本面不适用~~ **已作废**（复核第 4 条）：竞态来自连点两格，与翻月无关，已按 FR-007 实现并证明

## 第 43 轮复核 #2 = VERDICT: FAIL（1 条 BLOCKING + 6 条 NIT），逐条处置
| # | 结论 | 处置 |
| --- | --- | --- |
| 1 | **BLOCKING**：`habit_month_grid.dart:8` 的注释把 `:77` 写成「点击查看当月打卡情况」——**不是原文子串**，且悄悄删掉了「向上滑动」，而那正是 spec 取舍里承认的不一致点 | **收下**。改为引用原文「点击习惯进入打卡页面，向上滑动即可查看当月打卡情况」并显式写「本端点一下就出表、不等向上滑动，差异记在 spec 的取舍里」。自证：python 逐行扫源页 ⇒ `'点击查看当月打卡情况'` hits=`[]`，`'点击习惯进入打卡页面，向上滑动即可查看当月打卡情况'` hits=`[77]`（同一条命令里带正对照） |
| 2 | 后端锚点 `:143`-`:145` 在 develop 上不含 `for` 也不含 `setDate`（循环其实是 `:140`-`:145`），文件路径也在 `service/efficiency/habit/` 下，且引号里那段是三行合并**摘录**不是逐字代码 | **收下**，自己 `git show origin/develop:<path>` 复算过：`:140` `for (int i = 6; i >= 0; i--) {`、`:142` `d.setDate(today.minusDays(i).toString());`、`:143` `d.setCount(i % 2 == 0 ? 1 : 0);`。spec/plan/tasks 三处锚点统一改 `:140`-`:145` 并逐行列出、标明路径。`period=MONTH` 只影响 total 的 `:129` 锚点复核员确认在 develop 上是准的，保留 |
| 3 | gate2 记账说「① `ffe41ac` 上真红」也不严谨 —— 那一跑的 rc 同样是 `tee` 的 0，红据只有 stdout 的 `1 changed` | **收下**，措辞改为「红的证据是 stdout，rc 未捕获」。本轮起 gate4/5/6 各跑两遍：一遍留末行输出、一遍把输出丢弃单取 rc |
| 4 | 测试里假仓库的注释写 `gates[n-1]`，代码实际是 `statsCalls - 2` ⇒ 应为 `n-2` | **收下**，注释改 `gates[n-2]`/`queuedCounts[n-2]`，并补一句「n=1 是首屏加载，走默认可见数据」 |
| 5 | 「列表页顶部只有三张统计卡」不准 —— 是**一个** `AppCard`（`habit_page.dart:33`-`:54`）里排三行 `_Stat` | **收下**，spec 与生产注释各改一处（注释不再说「三张卡」） |
| 6 | tasks 里那句「命名参数不能排在位置参数前」无原文支撑（我留住的错误只有 `No named parameter with the name 'excludeSemantics'`） | **收下**，删掉未证实的归因，只留有日志原文的那条，并写明第一次的具体报错文本没留住 |
| 7 | 工作树 `M pubspec.lock`（227 行 `pub.dev`→`pub.flutter-io.cn`）没进 PR，但要求它不能被误提交 | **已知**：本机镜像所致，按 objective 约定不入库；本轮 `git diff --name-only origin/develop...HEAD` 复核过是 6 个文件、不含 lock |
| 8 | 复核环境无网络/Gitea MCP ⇒ `zh-cloud-service` Issue #281 与 gate5/6 只能读我的日志 | 属实，我不要求复核员核这两条；`#281` 由我在本会话用 API 建单（返回 201）持有，gate5/6 的 rc 已按第 3 条的方式重取 |

复核员另外**独立证实**为真的几项（不是它的功劳但我记账）：`isButton` 确实只能靠生产的 `button: true`（SDK `material/ink_well.dart:1401`-`:1405` 只设 `onTap`/`onLongPress`）；`MaterialApp.builder` 的结果确实插在 Navigator **之上**（`widgets/app.dart:1722`-`:1727`），所以档位能进弹层；`mobile-detail` 那 1 张黄金图确实拍得到 push 路由。

## 门禁（第三次跑：终态工作树，日志 `/tmp/r43_gates3.log`）
本轮 7 处改动**全是注释与 markdown**，无行为改动（`git diff --stat` 里生产文件只动了 `///`/`//` 行）。六项仍按要求在终态跑完，且这次 **rc 全部直取**（gate4/5/6 各跑两遍：一遍留输出、一遍 `>/dev/null` 单取退出码）。
| 门禁 | 结果 |
| --- | --- |
| 1 `git diff --check` | `rc=0` |
| 2 `dart format --output=none --set-exit-if-changed`（3 个文件逐个写死） | `Formatted 3 files (0 changed)`、`rc=0` |
| 3 `flutter analyze` | `No issues found! (ran in 2.2s)`、`rc=0` |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（9 张基线未重录） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:13 +717 ~26: All tests passed!`、`rc=0`（= develop 基线 709 + 本轮 8 例） |
| 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |
上一张表（`2539f8b`，日志 `/tmp/r43_gates_final.log`）**已被本表取代**，保留只为对账。

## 复核手段
`claude` CLI 本机不可用（`unrecognized_model`），替代 = 本会话只读子代理审 FR-001..FR-007。
第 1 轮 `VERDICT: FAIL`（5 条，全部采纳）；第 2 轮仍 `VERDICT: FAIL`（1 条 BLOCKING + 6 条 NIT，也全部采纳）。
**两轮都产出了上一轮没有的新结论**，所以第 2 轮之后的这批改法不算「为拿 PASS 循环重跑」。
但按 objective 的同一句话，**我不再自动请求第 3 轮**：要不要再审一遍由人定夺。
若再审，建议只审这三处易错面：① 注释/markdown 里的引文是不是原文子串；② `文件:行号` 锚点在**被引用的那个 ref** 上是否成立；
③ 门禁的 rc 是不是真取到的（zsh 不分词 + `tee` 顶码两个坑）。

## 仍缺（不谎称完成）
- [ ] **⑥ 月度打卡表在真实数据上还没通**：后端 `dailyCounts` 是占位假数（只 7 天、`i % 2`），修好前本弹层显示的「当月次数」不成立 ⇒ 矩阵 #45 的 ⑥ **不因本 PR 合并就判达成**；只有 ⑦ 补记（点日期 → `checkIn(date:)`）是完整闭环。
- [ ] 落点是**弹层**，源页 `:77` 是「点进打卡页面、向上滑动」、`:84` 是「右侧查看」⇒ 与源页不严格一致，需产品确认是否要做成页面/右侧面板。
- [ ] 真机上 1.3 倍字号与 320px 的实际表现未测（本机只有 web 构建可用；`github.com` 超时 ⇒ iOS SPM 编译不可用）。
- [ ] 弹层里格子的点击目标尺寸未实测（只按 320px 均分目测过，没量；也未对照 44px 触控下限评估 —— 源页没给尺寸，自算阈值属发明）。
- [ ] 矩阵 #45 的 ⑥/⑦ 回写：合并后把「已实现待合并 PR !305」换成合并 SHA 并复算行号。


## 合并轮（rebase 到 develop 后重跑）—— 2026-09-24，终态 `794fea4`，合入为 `13892e5d0`

原「点列表行直接弹表」与 develop 的「点行进详情页」抢同一个手势 ⇒ 按源页 `:77` 收回偏离，入口移到详情页「...」。
红测先行：新增的入口用例与既有「恰好含」穷举断言在实现前 `+16 -2` 双红，实现后该文件 `+18 All tests passed!`；
本文件自带的 8 条月度表用例因入口搬家先红 6 条（`openMonthSheet` 仍点行），改共用 helper 走新路径后 `+8 All tests passed!`，
并在 helper 里加「表标题真在」的前置断言，防止后续断言在空树上假绿。

| 门禁 | 终态读数 |
| --- | --- |
| 1 `git diff --check` | `rc=0` |
| 2 `dart format --output=none --set-exit-if-changed`（4 个文件逐个写死） | `Formatted 4 files (0 changed)`、`rc=0`。**中途真红一次**：新增用例未格式化 → `Formatted 1 file (1 changed)` `rc=1`，只对那个文件原地格式化后复跑转绿（本轮自己引入，非存量欠债） |
| 3 `flutter analyze` | `rc=0`（`No issues found!`） |
| 4 `flutter test --tags golden` | `00:04 +9: All tests passed!`、`rc=0`（9 张基线未重录；菜单加项未动任何黄金图） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:44 +885 ~26: All tests passed!`、`rc=0`。计数可核：develop 基线 876 + 本 PR 自带 8 例 + 本轮新增入口用例 1 例 = 885 |
| 6 `flutter build web --release --dart-define=…` | `✓ Built build/web`、`rc=0` |

门禁跑在**已提交**的终态上（`status=[]` 记在日志首行），跑完 `pubspec.lock` 仍与 develop 一致（本轮没有把本机镜像带进去）。
合并后 develop 的 tree 与本树同一枚（`a9aae454095e`）⇒ 上表读数对合并后的 develop 直接成立，无需重跑。

复核：本轮未派只读复核子代理（会话轮次预算已尽），改动限于「入口换宿主 + 用例跟随」，
其中我改动了 `!291` 已验收的详情页菜单 ⇒ **合前/合后应补一次只读复核**，重点核「月度打卡表」这一文案是否真是源页用词、
以及菜单加项是否影响 `settings`/`detail` 两处既有黄金断言。此项记为**未达成**，不写成已通过。

## 第 72 轮（2026-09-25）：Issue #348 —— 未来日不得被念成「未打卡」，也不得被补记

起因是 service PR !283 的只读复核（S7）指出本文件旧「取舍」里那句**「客户端自己把还没到的格子留空」与实现不符**：
格子从来不空，一直是日期数字。顺源回读两端代码才挖出真缺陷（!305 已合并 `13892e5d0`，判据按 `origin/develop@9032005` 的最终字节重取）：

| 主张 | 实测（develop 最终字节） |
| ---- | ---- |
| 语义只有两档 | `habit_month_grid.dart:110-113` `_cellLabel` 只分 `count > 0` / 「未打卡」⇒ 26 号被读屏念成「26 日，未打卡」 |
| 未来日可点且真发请求 | 同文件 `:159` `onTap: () => _backfill(day)` 无任何日期判断 |
| 补到未来的记录进不了统计 | BE `TodoHabitServiceImpl.java:105` `checkIn` 不校验未来时间（直接 `insert`），而 `:125` 的窗口写死 `to = LocalDateTime.now()` ⇒ 记录落库但 `dailyCounts`/`total` 永远取不到它。**用户点了、存了、看不见** |

**改动**：新增 `habitIsFutureDay(day, today)`（两边都削到当天零点再比）；`_cellLabel` 拆成三档；
`_backfill` 对未来日**不发请求**并写 `_notice`（`这个日期还没到，不能补记`，`todo-habit-month-notice` 槽位，
不借错误条），**下一次点按格子时**清场（两槽独立、在飞的刷新失败不顶掉提示 —— 复核 D2 撤掉我原来那句过头的「下一次操作前清场，不残留」，见本文件末「复核第二轮处置」）。判据与取舍的翻转已写进 `spec.md`（含一条诚实边界：**嘀嗒源页没有一句明文规定未来日不可点**，
本条是按统计窗口与「补记」语义做的取舍，服务端不改）。

**红测 → 绿**：`+8 -4` → `+13`。新用例不是白加的：整月 30 格逐格穷举标签（判据在测试里自己算），
且第一次实现把「今天 23:59」判成了未来日 —— 正是那条字面日期用例把它咬红的。

| 门禁（跑在已提交的 `b83b4dd` 上，日志 `/tmp/r72/`） | 读数 |
| --- | --- |
| 1 `git diff --check` | `rc=0` |
| 2 `dart format --output=none --set-exit-if-changed`（2 个文件点名） | `Formatted 2 files (0 changed)`、`rc=0`。中途真红一次：新增用例未格式化 ⇒ 只对那个文件原地格式化后复跑转绿（未跑全仓） |
| 3 `flutter analyze` | `No issues found!` |
| 4 `flutter test --tags golden` | `+9: All tests passed!`（9 张基线 0 改动、未重录） |
| 5 `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:38 +903 ~26: All tests passed!` |
| 6 `flutter build web --release --dart-define=TODO_API_BASE_URL=https://todo-test.zh04.com --dart-define=TODO_TENANT_ID=1` | `✓ Built build/web` |
| `pubspec.lock` | 全程未被改（`git status` 只列出本轮点名的文件）⇒ 没把本机镜像带进 PR |

**反向探针 8 条全部为红**（每条只抽掉一个行为，日志 `/tmp/r72_PROBES.log`，还原后 `cmp` 一致且复跑 `+13` 全绿）：
`PA` 摘掉「还没到」那一档 / `PB` 摘掉未来日守卫 / `PC` 只拦不提示（静默早退）/ `PD` 只归一化一侧（今天 23:59 判成未来）/
`PE` 判据放宽成「今天也算没到」/ `PF` 提示不清场 / `PG` 提示借用错误条槽位 / `PH` 提示只成语义不渲染。

**计数口径（别误读）**：本轮只数了本文件 `8 → 13` 条用例，**没有**重跑 develop 的全量基线 ⇒
「+903 里多出的就是这 5 条」这句话本轮没证，需要下一轮或复核员去量。

**复核**：本轮结论未过只读复核 ⇒ 「合前拿到 `VERDICT`」这一格是**欠的**，不得当作已通过。

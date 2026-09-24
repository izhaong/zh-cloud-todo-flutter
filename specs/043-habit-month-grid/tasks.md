# 043 任务清单

## 第 43 轮复核 #1 = VERDICT: FAIL，逐条处置
| # | 复核结论 | 处置 |
| --- | --- | --- |
| 1 | FR-002 的引文「哪一天没背够 5 页」**不是原文子串**（原文 `:72`：「即使哪一天没有背够5页的单词，也能记录自己完成3页的付出和努力。」），且 `:72` 被过度归因 | **收下**。`spec.md` 改为逐字引用并说明它讲的是「记付出」不是「看空格」；「整月逐日排格」改记为**本端实现选择**，不再挂 `:72` |
| 2 | 契约只在 tip `17a55ed` 上自证过，`6a67047` 上被推翻；且**假仓库用的是和生产同一个 padLeft**，后端↔客户端日期格式一致无处可证 | **收下**。假仓库改喂 `toIso8601String()` 前 10 位（= Java `LocalDate.toString()` 的形状），再断言这条记录的次数确实落进那一天的格子；探针：把生产 `padLeft(2,'0')` 摘掉 ⇒ 该用例红（见下） |
| 3 | 用例 5 从不断言 `isButton`（摘掉 `button: true` 仍绿）；正则未锚定；用例 2/6 用 `findsAtLeastNWidgets(28)` 且不校验月长；只有两格有独立 key | **收下**。加 `node.flagsCollection.isButton` 与 label **全等**；格子数改 `findsNWidgets(当月真实天数)`；末号（一定无记录）单独占 key 并断言「N 日，未打卡」 |
| 4 | **四件套 FALSIFIED**：`MediaQuery` 包在 `home:` 传不进 `showModalBottomSheet` 的路由，而 `spec.md:44` 声称相反；「无并发请求」也是假的（每次补记发一次 `stats`，无守卫 ⇒ 旧包覆盖新数据）；`ref.invalidate(habitStatsProvider)` 刷的是 `overviewStats`，与描述不符 | **全部收下**，三处都是生产/规格的真错：① 档位挂到 `MaterialApp(builder:)`；② 加 `_loadSeq` 守卫并立 FR-007 + 用例；③ `spec.md` 改述为「刷打卡概览」，并用不 override 的 `habitStatsProvider` 断言 `overviewStats()` 调用次数真的涨了 |
| 5 | 范围核验通过（5 个允许路径、无黄金图、无 `pubspec.lock`）；但 `plan.md` 在 `6a67047` 上不存在（`45df60b` 才加） | **收下措辞**：本文件下面按 commit 记门禁归属，不再笼统说「跑在最终状态」 |

一处**自我更正**要写在台面上：修 ④② 期间我先按记忆写了 `Text(x, excludeSemantics: true)` —— `Text` 没有这个命名参数，且命名参数不能排在位置参数前，两次都是**编译失败**（`Failed to load … No named parameter`）。
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
| 2 `dart format --output=none --set-exit-if-changed`（3 个文件逐个写死） | `Formatted 3 files (0 changed)`、`rc=0`。**这一条红过两次，都要记账**：① `ffe41ac` 上真红（`Formatted 3 files (1 changed)`）⇒ 用 `dart format` 只格式化本轮那个测试文件，记为 `2539f8b`；② 更早一次日志里写着 `rc=0` 是**假的** —— 参数走变量时 zsh 不分词，dart format 收到一个非法路径回了 `Formatted no files`，而 `… \| tee -a log; echo rc=$?` 记的是 `tee` 的码（zsh 无 `${PIPESTATUS[0]}`）⇒ 同一条门禁叠了两层假绿 |
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
- [ ] ~~契约无需改动~~ **已作废**（见复核第 2 条）：`TodoHabitServiceImpl.java:143`-`:145` 的 `dailyCounts` 是 `i % 2` 造的假数、固定只回 7 天 ⇒ 真实当月次数要先修后端（`zh-cloud-service` Issue #281）。客户端只渲染 API 给的 `dailyCounts`，不补假数据
- [ ] ~~「过期响应不覆盖新响应」本面不适用~~ **已作废**（复核第 4 条）：竞态来自连点两格，与翻月无关，已按 FR-007 实现并证明

## 复核手段
`claude` CLI 本机不可用（`unrecognized_model`），替代 = 本会话只读子代理审 FR-001..FR-007。
第 1 轮 `VERDICT: FAIL`（5 条，全部采纳，无一条写理由驳回）；本轮改动完成后请求第 2 轮。
按 objective「不得为拿 PASS 循环重跑」：第 2 轮若仍 FAIL 且无新结论，停下来请示，不再自查第 3 遍。

## 仍缺（不谎称完成）
- [ ] **⑥ 月度打卡表在真实数据上还没通**：后端 `dailyCounts` 是占位假数（只 7 天、`i % 2`），修好前本弹层显示的「当月次数」不成立 ⇒ 矩阵 #45 的 ⑥ **不因本 PR 合并就判达成**；只有 ⑦ 补记（点日期 → `checkIn(date:)`）是完整闭环。
- [ ] 落点是**弹层**，源页 `:77` 是「点进打卡页面、向上滑动」、`:84` 是「右侧查看」⇒ 与源页不严格一致，需产品确认是否要做成页面/右侧面板。
- [ ] 真机上 1.3 倍字号与 320px 的实际表现未测（本机只有 web 构建可用；`github.com` 超时 ⇒ iOS SPM 编译不可用）。
- [ ] 弹层里格子的点击目标尺寸未实测（只按 320px 均分目测过，没量；也未对照 44px 触控下限评估 —— 源页没给尺寸，自算阈值属发明）。
- [ ] 矩阵 #45 的 ⑥/⑦ 回写：合并后把「已实现待合并 PR !305」换成合并 SHA 并复算行号。

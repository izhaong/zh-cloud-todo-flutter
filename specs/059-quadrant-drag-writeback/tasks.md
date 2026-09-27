# 059 四象限拖动换象限并回写 — 台账

- 轮次：第 111 轮（2026-09-27）
- 关联：Gitea Issue #378（`git -C /tmp/wt-fl-378 rev-parse --abbrev-ref HEAD` ⇒ `feat/378-quadrant-drag-writeback`）
- 矩阵行：#36《如何编辑四象限规则》第 ⑤ 面「拖动换象限并回写」
- 上一批（第 110 轮 PR !382）状态：`open` ⇒ 本轮不引用它的任何 SHA 作为"已合并"证据

## 一、落地的三面

| # | 面 | 落点 |
| --- | --- | --- |
| 1 | 回写式纯函数 | `quadrantDropPatch` / `QuadrantDropPatch` / `_oneMonthLater`（`lib/features/task/views/eisenhower_view.dart`） |
| 2 | 拖拽层 | `EisenhowerView` 转 `ConsumerStatefulWidget`；`_QuadrantTile` 外包 `DragTarget<QuadrantDragMove>`、卡片包 `Semantics` + `LongPressDraggable` |
| 3 | 写库与同步 | `TaskViewActionRepository.moveQuadrantTask`（`lib/state/repositories/task_view_action_repository.dart`，同事务登记 outbox） |

宿主 `tasks_by_list_page.dart` 未进 diff：提交前 `git status --short` 恰好 4 行
（`git status --short | wc -l` ⇒ 4，两个 lib 文件、一个测试文件、`specs/059-quadrant-drag-writeback/`）
⇒ 「不动宿主」这条守住了。

## 二、六道门禁（全部跑在最终字节上，格式化之后）

| 门禁 | 读数 | 锚点 |
| --- | --- | --- |
| `git diff --check` | rc=0 | `/tmp/r111b/g1-check.log:2` |
| `dart format --output=none --set-exit-if-changed <本轮 3 个文件>` | rc=0 | `/tmp/r111b/g2-format.log:3` |
| `flutter analyze` | `No issues found!` | `/tmp/r111b/g3-analyze.log:64` |
| `flutter test --tags golden` | `00:04 +9: All tests passed!`（9 张基线未重录） | `/tmp/r111b/g4-golden.log:12` |
| `flutter test --exclude-tags 'golden \|\| performance' --concurrency=1` | `02:22 +913 ~26: All tests passed!` | `/tmp/r111b/g5-full.log:1108` |
| `flutter build web --release --dart-define=…` | `✓ Built build/web` rc=0 | `/tmp/r111b/g6-build.log:80` |

门禁 2 的说明：本轮 3 个文件先以 rc=1 报"会被改动"，`git show origin/develop:<两个 lib 文件>` 落盘后
`dart format --output=none --set-exit-if-changed` 回 rc=0 ⇒ 不合规的只有我新写的部分，
原地格式化没有顺手改任何存量代码（`git diff` 行数 360→368，只多在我这几段）。

## 三、反向探针：把实现改坏，看判据是否真的会红

脚本 `/tmp/r111b/probes.py`（本机临时、不入库）。每条探针跑完立刻还原，
前后各跑一次绿基线对照。汇总：`PROBE-BAD=0`，见 `/tmp/r111b/probes.log:15`。

| 探针 | 改坏的东西 | 应红的用例 | 实际 |
| --- | --- | --- | --- |
| P1 | 回写式改按"显示的是哪套"选（看板未加载就退回本机两轴） | 降级态那条 | 红 1 条，正是它（`/tmp/r111b/probes.log:5`） |
| P2 | 去掉同一任务的写链排队 | 连续两次拖动 | 红 1 条（`/tmp/r111b/probes.log:9`） |
| P3 | 组合1 也偷写 `dueAt` | 纯函数那条 + 组合1 拖到 Q2 + 降级态 | 红 3 条（`/tmp/r111b/probes.log:13`） |

P1 的名单**故意不含**「组合1 拖到 Q2」：那条看板已加载，显示与规则同源，改坏后仍然绿是应有行为，
把它列进"应红"就是把判据写松（第 6 列写的是范围，不是"越多越好"）。

## 四、交叉验证（`cursor-agent --trust`，日志 `/tmp/r111/crosscheck-378.out`，6399 字节，末行 `CROSSCHECK: DONE`）

| 主张 | 它的判定 | 处置 |
| --- | --- | --- |
| 自定义规则不给拖 | 对：源页 `:48`–`:58` 无任何拖动脉络，任何回写式都是我们编的 | 采纳，写进 spec §三 4 |
| 「本机分档 ≡ 嘀嗒组合2」 | **驳回**：同为两轴但判定式不等价（本机"重要"含中优先级、"紧急"是滚动 24h） | 已把 spec §三 2 改成"写回值必须被同一分类器判回目标象限"的闭环说法 |
| 回写式该由"生效规则"还是"当前显示"决定 | 指出降级态这个交叉坑：组合1 规则 + 看板未加载时会连带写出 `dueAt` | **真缺陷**，已改为 `effectiveRuleType = activeRule?.type`，并加降级态用例（P1 证明这条用例确实咬得住） |
| `priorityOnly` 的目标优先级取规则键序 | 对，且 `keys.length > 4` 的并档分支当前不可达 | 采纳，纯函数用例按 `['P3','P2','P1','P0']` 钉 |
| `DateTime(y, m+1, 31)` | 会进位到 3/3，不是夹到月末 | 加 `_oneMonthLater` 兜底 + 1/31 边界用例 |
| feedback 要不要补 `dragAnchorBuilder` | 不必：看板先例就是小反馈层 + 默认锚点，全仓 `dragAnchorBuilder` 0 命中 | 采纳：反馈层只放限宽 240 的标题卡 |

## 五、本轮自己抓到、并修掉的错（不写"顺手改好了"，逐条给现象）

1. **夹具缺 `todoLists` 行 ⇒ 4 条测试因错误前提而红、另 1 条因同一错误而假绿。**
   现象：拖动后仓储记到了调用，库里 `priority` 仍是 0，界面弹了失败提示。
   真因：`moveQuadrantTask` 经 `_requireWritableTask`，清单不存在 ⇒ 整笔事务抛错。
   最坏的一点是「写失败：卡片留在原象限并给可见提示」那条**当时是绿的**——它测的正是失败提示，
   而所有写都因夹具失败 ⇒ 判据失效却报喜。修法：`_memoryDbWithTask` 先插清单行
   （同 `test/task_view_action_repository_test.dart` 的夹具写法），再让"写失败"用例显式 `failNext = true`。
2. **正向对照会被 `ProviderScope` 静默废掉。** 同一测试里第二次 `pumpWidget` 换了
   `quadrantRulesProvider` 的 override，但容器只在创建那一次读 `overrides` ⇒
   「组合2 下能拖」那半边其实还在跑自定义规则，`findsWidgets` 就永远红——
   而它反过来把 W3 的"custom 不能拖"喂成假绿。修法：`_pump` 增加 `scopeKey`，两次 pump 换 key；
   正向对照收紧成 `findsOneWidget`（一张卡只该有一个可拖层）。
3. **`find.bySemanticsLabel('拖动调整象限')` 恒 0 命中。** 传 `String` 是**全等**匹配
   （`flutter_test` 的 `_bySemanticsProperty`：`pattern is RegExp ? hasMatch : ==`），
   而卡片节点被 `ListTile` 合并成「拖动调整象限\n任务 task-1」⇒ 必须传 `RegExp`。
   诊断读数：同一次 pump 下 `byLabel(String)=0 byLabel(RegExp)=2`。
4. **降级态那条用例原本"拖回原象限"，测的是另一件事。** 任务 priority 0 + 今天截止，
   本机分档就在 Q3，我却往 Q3 拖 ⇒ `onWillAcceptWithDetails` 直接拒 ⇒ `calls` 为空。
   改成往 Q2 拖，才真的咬住"组合1 不写 dueAt"。
5. **W6 的计数一度按错误的时序断言。** 假件是在排队后的方法体里记 `calls`，
   所以"第二次拖动完成"时 `calls.length` 仍是 1 才是对的；
   原写法 `== 2` 把"排队生效"当成了缺陷。改为：先断言仍为 1（= 没抢跑），
   放行闸门后再断言 2，并比对两次的 `dueAt` 分别落在 7 月 / 6 月。
6. **写链落库不能只靠 `pumpAndSettle`。** 拖动写是 fire-and-forget，帧停稳定 ≠ 写完成；
   加 `_settleWrites`（数帧轮询 `finished` 与 `calls` 的差，落不完就当场失败）而非"多泵两下试试"。

## 六、仍缺（不藏）

- **可达性缺口**：本面只有"长按拖动"一条路径。嘀嗒源页本节也只写拖动，
  键盘式跨象限、右键换档都没写 ⇒ 不做是忠实，但无障碍路径因此为零（拖动对手臂不便者不友好），
  这条留给下一个 Issue，不在本轮偷偷补。
- **自定义规则**不回写（spec §三 4）。
- **降级态显示偏差**：看板未加载时卡片所在格子由本机两轴算，而组合1 只写优先级 ⇒
  拖完可能不落回拖入的那格。取"不越权改截止时间"优先，已写进 spec §三 2。
- 矩阵 #36 原行的证据列引了 `zh-cloud-client`（已废弃端）⇒ 本轮把该行重判时**必须**去掉这条证据，
  见第 111 轮的 docs 提交（追加在 docs PR !102 的 `docs/parity-replay-combined` 分支上）。

## 七、只读复核（VERDICT）

- 状态：**未达成**。派单在 PR 开出来之后，审的是 `git diff origin/develop..HEAD` 的最终 ref；
  结论回来前，本节与矩阵行的"复核"格都算欠账。

## 八、下轮入口

1. 本轮 PR 的 VERDICT 回来后回写 §七，并把矩阵 #36 的证据列换成已合并 SHA（未合并前只写"已实现、未合并"）。
2. 年视图「点击日期 → 周视图并高亮」是矩阵 #28 剩的那一格（第 110 轮登记，判据 `:64`），
   与四象限无关 ⇒ 开 specs/060，不要塞进 059。
3. 队列里 FL 已有 21 条 open PR（`GET /repos/izhaong/zh-cloud-todo-flutter/pulls?state=open&limit=50` ⇒ 21 条），
   含本轮 ⇒ 合并动作仍等用户明说"合并"。

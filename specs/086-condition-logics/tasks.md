# 任务清单：跨筛选条件的「且 / 或」（`conditionLogics`）

基准提交：分支 `feat/524-condition-logics`，起点 `origin/develop@0e4221c1e0b4`（FL 现读 tip）。
下列行号以该起点之上的本分支工作树为基准（改动前的对照一律标 `origin/develop`）。
服务端契约与算法不属本轮改动，基准 zh-cloud-service `origin/develop@7bd493dd1265`。

## 红测先行（三刀各自先看不绿）

- [x] 求值面 `test/features/filter/task_filter_condition_logics_test.dart`（`grep -c "^  test(" test/features/filter/task_filter_condition_logics_test.dart` = 8）：
      首跑红在编译/加载层 —— `/tmp/w10_red1.log` 末段 `Failing tests:` 下只有一行
      `…/task_filter_condition_logics_test.dart: loading …`，即「`conditionLogics` 这个入参还不存在」，
      不是断言不成立。补完 `TaskFilter.conditionLogics` + `applyTaskFilter` 的子句构造后
      `/tmp/w10_green1.log` 尾行 `00:00 +8: All tests passed!`。
- [x] 存套面 `test/features/filter/saved_filter_condition_logics_test.dart`（`grep -c "^  test(" test/features/filter/saved_filter_condition_logics_test.dart` = 14）：
      实现前同样红在加载层（`/tmp/w10_red2.log` 末段 `…/saved_filter_condition_logics_test.dart: loading …`）。
      第一版实现在 `/tmp/w10_green2.log` 只到 `00:00 +11 -2`（两条红在我自己的断言写法上，见下节）。
      最终绿在 `/tmp/w10_green3.log` 尾行 `00:05 +83: All tests passed!`（跑的是整个 `test/features/filter/`）。
- [x] 界面面 `test/features/filter/advanced_filter_condition_logic_test.dart`（`grep -c "^  testWidgets(" test/features/filter/advanced_filter_condition_logic_test.dart` = 4）：
      实现前 3 条红、1 条绿，`/tmp/w10_red3.log` 尾段 `Failing tests:` 点名「两条已启用条件才出现开关…」
      「切到「或」真的改预览命中数…」「应用后重开对话框仍是那一档…」；
      那条先绿的是 `不足两条已启用条件时不给跨条件开关：一条条件切「且/或」没有可观察差异`
      ——小节不存在时它本来成立，所以它不算本轮的证据。
      实现后 `00:05 +83: All tests passed!`（`/tmp/w10_green3.log`）。

## 反向探针（九处各自摘一环，全部要红）

判据都是「摘掉实现里的一环 ⇒ 用例必须变红；还原后 `cmp -s` 证明字节回来」。
逐处读数在 `/tmp/w10_probes_final.log` 与 `/tmp/w10_probe1b.sh` 的运行输出里。

- [x] 求值面：`isConditionOr` 改成永假 ⇒ 红（等于新模式根本没接线）。
- [x] 求值面：把「且」追加进**所有**已有子句改成只追加进最后一个 ⇒ 恰那一条
      `「and」追加进所有已有子句，不是只跟紧挨着的前一条两两判断` 变红（析取范式 vs 两两判断的差别只有这一处能量出来）。
- [x] 求值面：`clauses.any(clause.every)` 换成 `clauses.every(clause.any)`（子句间/子句内的与或互换）⇒ 红 3 条。
- [x] 契约面：`toJson` 去掉「非空才出键」⇒ 红（老过滤器重新落库时 JSON 形状会变）。
- [x] 契约面：`fromJson` 的 known 集里去掉 `conditionLogics` ⇒ 红（读侧又整份判「本机暂不支持套用」）。
- [x] 映射面：放置校验里去掉「不能挂在第一条已启用条件」⇒ 红。
- [x] 映射面：读侧不验未知键 ⇒ 红。
- [x] 界面面：第一条已启用条件也给开关 ⇒ 红（那是服务端 `validateLogicPlacement` 会整份拒绝的形状）。
- [x] 界面面：开关的 `onSelected` 改成空操作 ⇒ 红 2 条（只有 chip 自己亮，档位进不了筛选态）。

## 中途改掉的四处自己的错

- [x] 第一刀探针的其中一条锚点写的是 `for (final clause in clauses) clause.add(piece.test);`，
      而本分支后来为 analyze 的 info 级 lint 给它补了大括号 ⇒ `assert count==1` 拿到 0，**变异根本没发生**，
      脚本却把它报成「GREEN(探针失败——断言不咬)」。这条读数作废，
      重跑的是 `/tmp/w10_probe1b.sh`（锚点取自还原前的真实字节，运行前用 `grep -n "clause.add(piece.test)"` 量过行号 2337）。
      教训与既有记录同族：「计划跑探针」≠「跑过探针」，锚点会被自己的格式化打掉。
- [x] analyze 首轮 rc=1（`/tmp/w10_gate.log:77` 的 `ANALYZE_RC=1`）：info 级 lint 也会挂 rc，
      命中是 `Statements in a for should be enclosed in a block … tasks_by_list_page.dart:2334:37`
      （`grep -c "info •" /tmp/w10_gate.log` = 1）；补大括号单独成一次提交
      （`git log --oneline` 里可见 `style(filter): 子句构造里的 for 补大括号`），之后 `/tmp/w10_analyze2.log` rc=0。
- [x] 存套面断言 `expect(jsonOf(...), '{"…"}')` 拿 Map 跟字符串比，永远不成立 ⇒ 改成先 `jsonEncode` 再比串
      （契约项 4「老过滤器重新落库时 JSON 逐字节不变」只有比串才量得出）。
- [x] 预览用例的关键词 `周报` 在 fixture 里一个任务都不命中，切「或」前后都是 0 条 ⇒ 断言恒真。
      换成 `跨端`，预览读数才成立 0→2→0。
      这两条就是 `/tmp/w10_green2.log` 尾段的 `00:00 +11 -2`。

## 085 台账里被本轮作废的一条

- [x] `test/features/filter/saved_filter_tag_logic_test.dart` 原有一条「跨条件的 `conditionLogics`
      仍然算不支持」——它钉的是 085 那轮的现状（字段还不认）。本轮认了这个字段，
      该用例已就地改成反向主张「读回来的跨条件词不丢：位置是否参与求值由服务端那条 `i == 0` 规则决定，
      不在读侧提前判死」，没有留下两条互相否证的用例（复算
      `grep -c "仍然算不支持" test/features/filter/saved_filter_tag_logic_test.dart` = 0）。

## 实现

- [x] 条件顺序表与展示名：`lib/features/filter/filter_bar.dart:16`（`conditionOrder`，与
      `TodoFilterConditionsDO.CONDITION_ORDER` 同序同命名）、`:26`（`conditionKeyLabel`）、
      `:40`（`activeConditionKeys`：面板行、求值 pieces、放置校验三处共用这一个函数）。
- [x] 筛选态字段：`lib/features/filter/filter_bar.dart:96`（`Map<String, String> conditionLogics`，
      构造缺省 `const {}`）、`:158`（`isConditionOr`：值归小写等于 `or` 才算「或」，与服务端
      `equalsIgnoreCase` 同口径）。
- [x] 求值：`lib/features/task/tasks_by_list_page.dart:2246`（`applyTaskFilter` 收成有序 pieces）、
      `:2327`（子句表）、`:2336-2337`（「且」追加进每个已有子句）、`:2347`（子句内 AND、子句间 OR）。
      日期合成一条条件：`:2197`（`_dateConditionMatches` 把 `dueRange` 与 `dueAtFrom`/`dueAtTo` 并成一条 `dateRange`）。
      页面作用域那三条（`selectedListId`、`folderId`、`assigneeUserId`）留在 `hardGates`
      （`:2345` 调用处）不进 pieces ⇒ 它们不在 `conditionOrder` 里，本来就不该能挂词。
- [x] 面板：`lib/features/filter/filter_bar.dart:931`（`_ConditionLogicSection`）、`:946`
      （整节 key `task-filter-condition-logic`）、`:955`（每条件一个 `…-logic-$key` 组）、
      `:966`（每档自带读屏节点 `…-logic-$key-{and|or}`）、`:580`（插入位置：高级条件之后、预览之前）。
      草稿三处同轮带上档位：`:477`（预览草稿）、`:679`（「应用高级筛选」回传）、`:780`（`_AdvancedFilter` 字段）。
- [x] 契约对象：`lib/state/repositories/filter_repository.dart:17`（构造）、`:35`（字段）、
      `:49-50`（`toJson` 非空才出键、且排在已有键之后）、`:61`（known 集）、
      `:68-81`（形状校验：不是「对象 + 两项都是字符串」就退回 `unsupportedKeys`）、`:92`。
- [x] 双向映射：`lib/features/filter/saved_filter_mapping.dart:28-45`（写侧按 `activeConditionKeys`
      验放置，不合法位置点名进 `skipped`，只有 `or` 出键）、`:59`（空表则整个键不出）、
      `:88-104`（读侧键值都验，猜就返回 `null` 交调用方标「本机暂不支持套用」）。

## 门禁实跑读数

- [x] `flutter analyze` rc=0：`/tmp/w10_gate2.log` 第 74 行 `ANALYZE_RC=0`（跑在最后一笔提交之后）。
- [x] `flutter test`（整个 `test/`）通过：同一日志第 1836 行 `TEST_RC=0`，尾行
      `01:21 +1535 ~26: All tests passed!`。对账：上一轮（085 收口）的同一道门禁尾行是
      `01:22 +1509 ~26: All tests passed!`（`/tmp/w9_gate.log:1808`），
      通过数差 `1535 - 1509` = 本轮新增的 8+14+4，跳过数 26 没动 ⇒ 新增用例之外没有碰别的测试。
- [x] 台账自扫：`python3 tool/check_spec_selfscan.py specs/086-condition-logics/tasks.md` 失项 0。
- [x] 反向对照证这把尺会红：同一命令对临时注入死锚点的副本报 `失项 1 条`，
      还原后 `cmp -s` 通过、再跑回到 `失项 0 条`。

## 复核

**未经独立复核**：claude `-p` 的 VERDICT 通道仍回 0 字节。替代判据 = 上面两道门禁 + 九处反向探针
+ 三刀红测先行，全部留日志。**未做**：真后端（test 环境）端到端跑一遍带逻辑词的过滤器；
本轮只证客户端与服务端**同一算法**，用例里的期望值是照 `TodoFilterServiceImpl.java:300-325` 手算的。

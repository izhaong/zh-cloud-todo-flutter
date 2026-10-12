# 规格：跨筛选条件的「且 / 或」（矩阵 #22 面 ⑥）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#524（从 #334 拆出的面 ⑥；面 ⑦「同一标签条件内部」
  已由 `specs/085-tag-logic-filter/` 落到 develop）。
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径与行号以 zh-cloud-docs `origin/develop` 为准；
  复算 `git -C zh-cloud-docs show origin/develop:'todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md' | sed -n '61p;71p'`）：
  - `:71`「你还可以使用“且”逻辑、“或”逻辑来关联前后两个筛选条件。并且，在同一个筛选条件（仅标签支持）
    内，也可以选择使用“且”逻辑、“或”逻辑。」—— 前半句是本轮，后半句是 085。
  - `:61`「高级筛选通过逻辑词：“或”、“且”以及清单、日期、优先级、标签等筛选条件可以进行多语句查询。」

## 服务端契约与算法都已在 develop（本轮零 DDL、零服务端改动）

基准 zh-cloud-service `origin/develop@7bd493dd1265`。复算：
`git -C zh-cloud-service show 7bd493dd126562b7cec0a8d7dacbe365fc75fe18:yudao-module-todo/src/main/java/cn/iocoder/yudao/module/todo/service/filter/TodoFilterServiceImpl.java | sed -n '300,325p;614,635p;644,660p'`

- `TodoFilterConditionsDO.java:51` `private Map<String, String> conditionLogics;`，
  `:58-59` `CONDITION_ORDER = listIds, tagIds, priorities, statuses, dateRange, keyword`。
- 求值 `TodoFilterServiceImpl.java:300-325`：按 `CONDITION_ORDER` 收集**已启用**条件成 pieces，
  构造**析取范式** —— 挂 `or` 的开一个新子句，挂 `and`（含缺失）的把这条**追加进所有已有子句**；
  子句内 AND、子句间 OR。`isOrLogic` 忽略大小写，只认 `or`。
- 校验一 `:614-635` `validateLogicWords`：`conditionLogics` 必须是对象、键必须在 `CONDITION_ORDER` 里、
  值必须是 `and`/`or`，否则抛 `TODO_FILTER_INVALID_CONDITIONS`。
- 校验二 `:644-660` `validateLogicPlacement`：词只能挂在**已启用**的条件上，且不能挂在**第一条已启用**
  条件上；注释还写明「未启用条件的连接词也不许静默丢掉」。

## 缺口（改动前，基准 `origin/develop@0e4221c1e0b4`）

- 求值：`applyTaskFilter`（`lib/features/task/tasks_by_list_page.dart`）是**逐条 `return false` 的隐式全 AND 链**，
  没有子句概念 ⇒ 挂什么词都改变不了结果。
- 契约对象：`TodoFilterConditions`（`lib/state/repositories/filter_repository.dart`）没有这个字段，
  `fromJson` 的 known 集也没有 ⇒ 别的端存来的 `conditionLogics` 整份进 `unsupportedKeys`，
  UI 标「本机暂不支持套用」（085 那轮还专门写了用例钉住这条现状）。
- 面板：跨条件没有任何入口（085 只做条件内部的标签档位）。
- 复算改动前的缺（本分支上这些符号都已存在，所以要对着 develop 跑）：
  `git -C zh-cloud-todo-flutter grep -c conditionLogics origin/develop -- lib` ⇒ **0 命中**
  （正对照：`... grep -c tagLogic origin/develop -- lib` 得 3 个文件 ⇒ 同一条尺量得出"有"）。

## 契约

1. **条件顺序只认 `conditionOrder`**（与 `TodoFilterConditionsDO.CONDITION_ORDER` 逐字同序、同命名）。
   服务端注释自己给了理由：「前后」由这张表判定，否则连接词会挂到另一条条件上 ⇒
   面板条件行、求值 pieces、放置校验三处共用同一份 `activeConditionKeys()`，不分叉。
2. **词挂在条件上，不是挂在"两条之间"**：`Map<String, String>`，键是条件名，值 `and`/`or`，
   语义是「这条条件相对前面累计结果」的连接方式。第一条的词不参与判断（服务端 `i == 0` 也如此）。
3. **析取范式不是两两判断**：挂 `and` 的条件要追加进**所有**已有子句。
   错例：实现成「只跟紧挨着的前一条比」会把 `{priorities, statuses(or), keyword(and)}`
   算成 `(prio) OR (comp AND kw)`，而服务端算出 `(prio AND kw) OR (comp AND kw)` ——
   用例 `「and」追加进所有已有子句，不是只跟紧挨着的前一条两两判断` 钉的就是这个差别。
4. **缺省不写键**：`and` 与「没有这个键」在服务端等价（`isOrLogic` 只认 `or`）⇒
   `toJson` 只在表里有 `or` 时出 `conditionLogics`，且排在已有键之后 ⇒
   老过滤器重新落库时 `conditions` JSON 逐字节不变（用例直接比字符串）。
5. **面板只画合法位置**：已启用条件 <2 条时整节不出现；出现时第一条不给开关。
   理由就是校验二 —— 摆一个按下去会被服务端整份拒绝的开关，等于给用户一个假按钮。
6. **不合法位置的词不许静默丢掉**：`savedFilterOf` 把它列进 `skipped`（点名到具体条件名），
   对话框据 `skipped` 非空拒绝保存 —— 沿用文件夹 / 负责人那一维的既有通道，不新造机制。
7. **读侧两条都验、猜就不套**：键不在 `conditionOrder` 或值不在词表 ⇒ `taskFilterFromSaved` 返回 `null`；
   形状不是「对象 + 两项都是字符串」则退回 `unsupportedKeys`（读成空表等于丢掉一条真实存在的条件）。
   挂在第一条上的词**照原样带回来**不判死：是否参与求值由服务端那条 `i == 0` 规则决定，本端同规则。
8. **日期是一条条件**：`dueRange` 与 `dueAtFrom`/`dueAtTo` 在契约里同属 `dateRange` 一个对象 ⇒
   求值里必须合成一条，拆成两条会多出两个能挂词的位置，与 `conditionOrder` 对不上。

## 已知边界（不算已验证）

- 若 `dueRange` 用的是契约装不下的档位（`overdue`/`future`/`last7days`/`next7days`），
  `activeConditionKeys` 会把 `dateRange` 算作已启用，而契约里那份 `dateRange` 其实为 null ⇒
  位置判定偏保守（多算一条活跃）。这一形状本来就被 `skipped`（「到期范围…」）挡在保存之前，
  不会产出被服务端拒绝的 JSON；本轮不额外加闸门，留在这里备查。
- 逻辑词只覆盖契约那六条。清单（`listIds`）在本地筛选态里是单选 `listId`，
  智能清单切换另有入口 ⇒ 这一条能挂词但当前面板不会给出（它是第一条时不给；排在前面的清单条件
  由页面作用域决定，见 `activeConditionKeys` 第一行判定）。

## 验收

- 单元（求值）：`test/features/filter/task_filter_condition_logics_test.dart`（8 条 `test(`）。
- 单元（存套）：`test/features/filter/saved_filter_condition_logics_test.dart`（14 条 `test(`）。
- 界面：`test/features/filter/advanced_filter_condition_logic_test.dart`（4 条 `testWidgets(`）。
- 门禁：`flutter analyze` rc=0；全量 `flutter test` 通过（见 `tasks.md` 的实跑读数）。
- 复核：**未经独立复核**（claude `-p` 的 VERDICT 通道 0 字节）。替代判据 = 两道门禁 +
  七处反向探针（三刀各自摘一环），全部留日志；不假装复核过。

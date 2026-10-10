# 规格：标签条件内部的「且 / 或」两档（矩阵 #22 面 ⑦）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#334（布尔组合）。该单是两面，本轮只做面 ⑦
  「同一个标签条件内部选且/或」；面 ⑥「条件之间用逻辑词串联」另立 FL #524，
  不拿本轮冒充它。
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径与行号以 zh-cloud-docs `origin/develop@f53674736ace` 为准；
  核对命令：`git -C zh-cloud-docs show f53674736ace313dbdd140eea53089e207fc3d17:'todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/09-如何管理海量任务/05-过滤器：随心所欲筛选你想看的任务.md' | sed -n '61p;71p'`）：
  - `:71`「你还可以使用“且”逻辑、“或”逻辑来关联前后两个筛选条件。并且，在同一个筛选条件（仅标签支持）
    内，也可以选择使用“且”逻辑、“或”逻辑。」—— 后半句是本轮，前半句是 FL #524。
  - `:61`「高级筛选通过逻辑词：“或”、“且”以及清单、日期、优先级、标签等筛选条件可以进行多语句查询。」

## 服务端契约早已存在（本轮不需要新契约，也不需要 DDL）

基准 zh-cloud-service `origin/develop@7bd493dd1265`（复算：
`git -C zh-cloud-service show 7bd493dd126562b7cec0a8d7dacbe365fc75fe18:yudao-module-todo/src/main/java/cn/iocoder/yudao/module/todo/dal/dataobject/filter/TodoFilterConditionsDO.java | sed -n '43p;51p;61p;62p'`）：

- `TodoFilterConditionsDO.java:43` `private String tagLogic;` —— 条件对象里有这个字段。
- `TodoFilterConditionsDO.java:61-62` `LOGIC_AND = "and"` / `LOGIC_OR = "or"` —— 词表就这两个值。
- `TodoFilterServiceImpl.java:65-67` 的 `FILTER_CONDITION_FIELDS` 白名单含 `"tagLogic"` ⇒ 服务端认这个键。
- `TodoFilterServiceImpl.java:359-361` 求值：`LOGIC_OR.equalsIgnoreCase(tagLogic == null ? LOGIC_AND : tagLogic)`
  ⇒ **缺省即「且」**，且大小写不敏感。客户端不许自创第三种缺省。
- `TodoFilterServiceImpl.java:614-616` 校验：非法逻辑词直接抛
  `TODO_FILTER_INVALID_CONDITIONS`，注释写明「静默改判等于客户端以为『或』、服务端按『且』各算一套」。
- 条件整体存 `todo_filter.conditions`（JSON 文本列），新增一个对象键 ⇒ 零建表、零 ALTER。

## 缺口（改动前，基准 `origin/develop@dede0d21fab9`）

复算 `git -C zh-cloud-todo-flutter grep -c "tagLogic" origin/develop -- lib` ⇒ **0 命中**
（正对照：同一命令把串换成 `tagIds:` 在 `lib/features` 下有命中 ⇒ 标签条件本身有构造点，逻辑词一个都没有）。
两端都缺：

- 求值侧写死「且」：`origin/develop` 的 `lib/features/task/tasks_by_list_page.dart:2215`
  是 `if (!owned.containsAll(filter.tagIds)) return false;` —— 没有档位可传。
- 面板侧没有任何逻辑词入口（`test/features/filter/` 下按「且/或」文案查找 0 命中，见本仓
  `advanced_filter_tag_logic_test.dart` 的 RED 记录）。
- 存套侧 `TodoFilterConditions` 无 `tagLogic` 字段，`fromJson` 的 known 集也没有它 ⇒ 别的端存来的
  `{"tagLogic":"or"}` 会整份落进 `unsupportedKeys`，该过滤器在 UI 上标「本机暂不支持套用」。

## 契约

1. **词表与服务端同源，缺省「且」**：`TaskFilter.tagLogic` 是 `String`（`and` / `or`，构造缺省 `and`），
   不是 `bool`。理由：`bool` 表达不了「键在但值不在词表里」这一档，而那正是服务端会明确拒绝的输入
   （`TodoFilterServiceImpl.java:614-616`）。大小写按服务端 `equalsIgnoreCase` 同口径先归小写再判。
2. **「且」不写键**：`TodoFilterConditions.toJson` 通篇是「非默认才出键」的条件键，
   `tagLogic` 沿用同一形状 ⇒ 本轮改动前已存在的过滤器，其 `conditions` JSON 一个字节都不变，
   读侧也不必分「缺键」与「显式 and」两条分支（两者等价，都由 `fromJson` 给 `null`，
   再由 `taskFilterFromSaved` 落到 `and`）。
3. **读侧要认键**：`tagLogic` 必须进 `fromJson` 的 known 集。漏了这一条，别的端存的「或」过滤器
   会整份被判「不支持套用」——那是把已支持的维度读成不支持，比不支持更糟。
4. **档位只在 ≥2 个标签时参与一切**：`TaskFilter.tagsMatchAny` 要求 `tagIds.length > 1`。
   单标签下 `containsAll` 与 `any` 命中集本就相同，而面板上开关也只在 ≥2 个标签时出现 ⇒
   留着 `or` 就是一份「存得下、看不见、改不动」的条件，所以既不按「或」求值也不写键。
5. **未知逻辑词不猜**：`taskFilterFromSaved` 对既非 `and` 也非 `or` 的取值返回 `null`
   （调用方标「本机暂不支持套用」），与 `statuses` 只认 `done`/`todo` 是同一条规矩。
6. **跨条件的逻辑词不在本轮**：`conditionLogics` 继续留在 known 集之外 ⇒ 整份判不支持。
   它属于 FL #524（面 ⑥），本轮不顺手求值，避免「写了键又不消费」那种一半形状。
7. **预览与列表同源**：开关改的是同一份 `TaskFilter`，预览用的还是同一个 `applyTaskFilter`
   ⇒ 切档时「命中 N 项」与套出列表看到的数不会分家。

## 验收

- 单元（求值）：`test/features/filter/task_filter_tag_logic_or_test.dart`（6 条 `test(`）
  ——「或」档只含其一也算命中、「且」档要求全部、大小写不敏感、未知值按缺省、索引未就位不在这里放行。
- 单元（存套）：`test/features/filter/saved_filter_tag_logic_test.dart`（8 条 `test(`）
  ——只有「或」写键、缺省与显式 `and` 都不写键、`OR` 归一、`fromJson` 认键、
  `conditionLogics` 仍算不支持、套回不丢档、未知词整份拒套、单标签不算「或」也不写键。
- 界面：`test/features/filter/advanced_filter_tag_logic_test.dart`（3 条 `testWidgets(`）
  ——开关随标签数出现/收回、切档真的改预览命中数（1→2→1）、套用后重开对话框读得回档位、
  两档各有读屏名。
- 门禁：`flutter analyze` rc=0；全量 `flutter test` 通过（`01:22 +1509 ~26: All tests passed!`，
  跳过项是既有 golden，未重录）。
- 复核：本轮**未经独立复核**（claude `-p` VERDICT 通道连续 0 字节，见 FL #334 留言）。
  替代判据是四处反向探针（见 `tasks.md`「反向探针」）+ 上述两道门禁；不假装复核过。

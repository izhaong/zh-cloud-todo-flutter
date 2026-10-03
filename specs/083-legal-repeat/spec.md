# 规格：重复任务「法定工作日 / 法定节假日」两档接线（矩阵 #24 面 ⑥）

- 来源 Issue：izhaong/zh-cloud-todo-flutter#324
- 前置契约：izhaong/zh-cloud-service #319 已合并，服务端 develop `641aa0768ba27213b49209f3927a8b49914548b4`
  （枚举 `LEGAL_WORKDAY("legal-workday")` / `LEGAL_HOLIDAY("legal-holiday")`、命中判定读字典表 `todo_calendar_holiday`）
- 判据源（嘀嗒帮助中心镜像，逐字照抄，路径以 zh-cloud-docs `origin/develop` 为准）：
  `todo/99_参考资料/dida365-help-center/02-功能指南/01-任务/10-设置重复任务.md`
  - `:65`「- 法定工作日」 `:67`「为工作中的任务设置「法定工作日」重复，任务将避开周末和法定节假日，在法定工作日重复，确保你的工作安排永远精准。」
  - `:78`「- 法定节假日」 `:80`「为休息日专用任务设置「法定节假日」重复，任务将遵循国家放假安排，在法定节假日重复，完美匹配你的放假节奏。」
  - 文档把这两档分别挂在「工作日」与「节假日」两个分组里 ⇒ 选择器里的顺序照它排（工作日 → 法定工作日 → 每周末 → 法定节假日）。

## 缺口（改动前，基准 `origin/develop@603038133d90`）

- 两档根本进不来：`git grep -c "LEGAL_WORKDAY" origin/develop -- lib` ⇒ 0 命中
  （正对照：同一命令把串换成 `WEEKDAY` 得 2 个文件 ⇒ 判据不是恒假）。
- 仓库侧白名单只有 7 档（`git show origin/develop:lib/state/repositories/repeat_rule_repository.dart` 的
  `const frequencies = {…}` = `DAILY/WEEKLY/MONTHLY/YEARLY/WEEKDAY/WEEKEND/CUSTOM`），
  传 `LEGAL_WORKDAY` 会直接 `ArgumentError('不支持的重复频率')`。
- FL **没有也不该有**节假日数据源，occurrence 全部由服务端物化
  （`lib/state/repositories/repeat_rule_repository.dart:161-165` 的注释：UI 不直接调 occurrence REST API）
  ⇒ 本轮客户端只负责「选得到、存得下、读得回中文、同步得出去」，**不算下一次是哪天**。

## 契约

1. 三处同轮改，缺一处就是「菜单里有、点了没反应」的假档：
   - 白名单：`lib/state/repositories/repeat_rule_repository.dart:246`、`:248`；
   - 选择器档位：`lib/features/task/task_detail_pane.dart:2099`、`:2101`；
   - 详情面文案表 `_repeatRuleLabel`：`lib/features/task/task_detail_pane.dart:2434`、`:2436`
     （漏了这一处时文案会退化成把枚举名 `LEGAL_HOLIDAY` 直接印给用户 ⇒ 用例 `find.text('LEGAL_HOLIDAY')` 断言 `findsNothing`）。
2. **这两档故意不派生星期集**：`repeat_rule_repository.dart:304` 处只有注释、没有 `if (frequency == 'LEGAL_WORKDAY') return [1,2,3,4,5]`
   这样的代码。理由写在 Issue #324「别做的事」里：把「法定工作日」近似成「周一至周五」，
   调休放假日会被算成上班日，而且这条假事会随 outbox 同步到服务端变成持久数据。
   调用点本来就只给 `CUSTOM` 传 `weekdays`（`task_detail_pane.dart:1955`、`:1991`），所以 `byDay` 自然是 `null`；
   用例把这件事钉住（仓储侧断 `byDay` 为 `null`，UI 侧同样断一次）。
3. **wire 值映射（本轮真正的坑）**：本地 `todo_repeat_rules.freq` 存大写常量，服务端 `frequency` 是小写连字符。
   老档位全是单个词，`toLowerCase()` 恰好等价；`LEGAL_WORKDAY` 是第一个带分隔符的档位 ⇒
   照老写法出库发的是 `legal_workday`，服务端 `TodoSyncServiceImpl.validateRepeatRulePayload` 用
   `TodoRepeatFrequencyEnum.findByFrequency` 认不出来，表现为「本地存成功、同步一直失败」。
   反向也一样：入站 `.toUpperCase()` 会把 `legal-workday` 存成 `LEGAL-WORKDAY`（带连字符的第三种写法），
   档位既匹配不上选择器也查不到文案。
   ⇒ 新增 `lib/core/sync/repeat_frequency_wire.dart`，出库 `repeat_rule_repository.dart:341`、
   入站 `sync_coordinator.dart:1793`、chip key `task_detail_pane.dart:2107` 三处都过这一层，
   单一事实源。复算（三个消费点各一处，没有第二处自己搓大小写）：
   `grep -rc "repeatFrequencyToWire\|repeatFrequencyFromWire" lib/state/repositories/repeat_rule_repository.dart lib/core/sync/sync_coordinator.dart lib/features/task/task_detail_pane.dart`
   ⇒ 三行都是 `:1`（helper 自己是定义处，计数 2）。
   映射本身由 `test/core/sync/repeat_frequency_wire_test.dart` 钉住（含「往返恒等」那条：
   任何一档 local→wire→local 不许长出第三种写法）。
4. chip key 用 wire 形态（`task-repeat-frequency-legal-workday`）而不是 `option.$1.toLowerCase()`：
   自动化与测试引用的 key 与服务端取值同名，避免「key 里是下划线、协议里是连字符」这种第二个歧义源。
5. 四件套（新 UI 逐条量，见 tasks.md 的格子）：320px + 1.3 倍字号下两档 chip 仍可达且不撑破可视宽；
   读屏能念出「法定工作日 / 法定节假日」；保存失败沿用既有 `ArgumentError → SnackBar` 通路（本轮没新增写路径，
   也没有新增"失败后仍要留着的数据"）；过期响应不覆盖——档位写库与出库在同一个 Drift 事务里，本轮没动这条。

## 范围外

- 农历重复 ⑦（FL #325）与艾宾浩斯记忆法 ⑧（FL #326）各自成轮。
- 矩阵 #24 面 ⑥ 的翻面：本轮 FL 合并后按「service `641aa0768ba2` + FL 合并 SHA」改判（见 tasks.md 下一轮入口）。
- 服务端把「降级原因」放进接口响应（izhaong/zh-cloud-service#322）——本轮不依赖它：
  FL 不算 occurrence，所以缺下一年数据时用户看到的是"服务端没生成任务"，而不是错值。

# 063 · 规格：快速添加识别到时间时，同时创建提醒（矩阵 #83 的「提醒」那半）

FL Issue **#388**。判据源：`todo/99_参考资料/dida365-help-center/03-特色功能/05-智能识别.md`。

## 判据源（逐字）

原文 `:5`：

> 你可以在“快速添加”中直接输入日期文本，滴答清单会自动识别并为您创建日期和提醒。

原文 `:13`（本轮已实现的那条，见 specs/062）：

> 当你在清单中输入的是模糊日期时，滴答清单会统一识别成最近有效的日期和时间。

原文是**两半**：日期 + 提醒。specs/062 只补了日期那半。

## 现状（基准 `origin/develop`，现跑）

- 日期那半已接：`lib/features/task/task_quick_add_sheet.dart` 里 `_maybeResolveDate()` 调
  `NlpDateParser().parse`，`_save()` 保存时把 `_nlpResolvedDueAt` 写进 `TaskRepository.create(dueAt:)`。
- 提醒那半**没接**：复算 `git grep -in "reminderRepositoryProvider" -- lib/features/task/task_quick_add_sheet.dart`
  ⇒ 无输出（该弹窗一次都不引用提醒仓储）。
- 本地能力是齐的，不需要动后端：`ReminderRepository.create(taskId:, fireAt:, anchorType: 'ABSOLUTE', …)`
  在同一 Drift 事务里写 `todo_reminders` 并登记同步 outbox（`lib/state/repositories/reminder_repository.dart`）。
  provider 也已存在：`reminderRepositoryProvider`（`lib/state/providers.dart`）。

## 本面要做的

在快速添加弹窗的保存路径上：**识别命中**（`NlpDateParser` 返回非 `null`）⇒ 建完任务后，
用**识别到的那个时间本身**创建一条 `ABSOLUTE` 提醒（不预设"提前多少分钟"）。

### 为什么不预设提前量

原文「提前提醒 / 延后提醒」两节**只有图片、无可复现文字规则**（复算：
`grep -c "!\[" /tmp/wt-docs/todo/99_参考资料/dida365-help-center/03-特色功能/05-智能识别.md` 与
`grep -c "分钟" 同文件` 两个读数一起看），没有任何一句给出默认偏移数字 ⇒
自造一个"提前 30 分钟"就是自创规则。提醒时刻等于识别到的时间，是原文 `:5` 的字面下限。

## 验收标准（Given / When / Then）

1. **原文两半都落地**：Given 已登录且清单可选，When 在快速添加输入「明天9点」并保存，
   Then 任务 `dueAt` = 次日 09:00，且 `todo_reminders` 恰新增一行、`remindAt` 等于同一个时刻。
2. **没识别出时间就不建提醒**：When 输入「买牛奶」并保存，Then 任务建成、`todo_reminders` 零新增
   （不无中生有地造一条提醒）。
3. **提醒建不成不能说谎**：Given 提醒写入抛错，When 保存，Then 任务仍然保留（不回滚、不假装没建），
   弹窗**不关**、在弹窗自己的可见区显示原因，且再点一次「保存」只补提醒、不会把任务建第二遍。
4. **未登录的早退不变**：未登录点保存仍先在弹窗内显示「请先登录」，不发起任何写入
   （这条是既有行为，本面不得让它退化成 `?.` 静默跳过——提醒仓储为 `null` 时同样要给可见提示）。
5. **不改识别本身**：`NlpDateParser` 的行为（含 specs/062 的裸钟点与「半」的拒识）一字不动；
   本面只加"命中之后"的接线。

## Non-Goals

- 不做「提前提醒 / 延后提醒」的偏移量与多提醒：原文那两节无可复现规则（另立单）。
- 不做服务端 NLP 的 `reminderTime`（第 27 轮范围裁定 ② 已把服务端 NLP 裁出范围）。
- 不动逐行解析的另两处调用点（`home_shell.dart` 与 `tasks_by_list_page.dart` 里的 `dueAtResolver`
  是**显示/编辑**用的解析回调，不是创建路径；复算 `git grep -n "NlpDateParser().parse" -- lib` 的三处里
  只有本弹窗写库）。
- 不新增界面：沿用本弹窗已有的可见反馈通道（`_report`）。四件套里的「320px / 1.3 倍字号」
  在**本路由**上仍要实测一次（保存按钮与提示行是同一条），另两件（失败保留数据、过期响应不覆盖新响应）
  由验收第 3、4 条承担。

# 073 批量快速添加：识别到时间的每一行都落提醒（FL #410）

## 一、判据源（逐字）
《03-特色功能/05-智能识别.md》`:5`「你可以在“快速添加”中直接输入日期文本，滴答清单会自动识别并为您创建日期和提醒。」
同一页只有 4 个小节：日期和时间、重复、提前提醒、延后提醒。`:13` 的模糊日期口径（下午 4 点输入「9点提醒我」→ 今晚 9 点）属**日期**那半，已由 specs/062/063 覆盖；本规格只做**提醒**那半的批量缺口。

## 二、缺口是怎么量出来的
- 单条：`lib/features/task/task_quick_add_sheet.dart` 的 `_save` 在任务落库后调 `reminders.create(taskId: ..., fireAt: dueAt)`，判据在 `test/features/task/quick_add_nlp_reminder_test.dart`。
- 批量：`lib/state/repositories/task_repository.dart` 的 `createBatch` 只写 `dueAt`，全树 `git grep -n -e reminders.create origin/develop -- lib` 的命中里没有批量路径 ⇒ 同一句话的两半只做了一半。
- 复算：`git grep -n 'attachResolvedReminders' HEAD -- lib` ⇒ 本目录落地后应为「定义 1 + 调用 2」。

## 三、口径与取舍
1. **落点在调用侧**，不给 `TaskRepository` 注入提醒仓储：`git grep -c 'TaskRepository(' HEAD -- lib` 现读 3（含构造声明本身 ⇒ 真构造 2 处），`git grep -n 'TaskRepository(' HEAD -- test` 命中近百行 ⇒ 改构造函数的波及面远大于两处调用点各加一次接线。两处共用一个顶层函数 `attachResolvedReminders`，重复只有一处签名。
2. **失败不回滚、不静默**：提醒写不成时任务保留，并把话给用户——沿用 `TaskQuickAddSheet` 的先例（`任务已建，但提醒没建成…`）。部分失败要同时报成功数与失败数。
3. 四件套：本单不新增界面（只在既有 snackbar 上并一句），①320px/1.3 倍字号 与 ②独立读屏语义 由既有 `quick_add_batch_reminders_test.dart` 之外的既有壳层用例覆盖，本目录不新判；③失败保留已加载数据由「部分失败」那条用例钉住；④过期响应不覆盖新响应 **不适用** —— 这条路径是本地写，无请求代际，壳上的 generation 计数器都不覆盖它。

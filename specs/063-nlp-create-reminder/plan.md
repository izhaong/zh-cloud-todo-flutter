# 063 · 实施计划

## 落点：只改 `_save()` 一处

`TaskQuickAddSheetState._save()` 现在的形状是：读默认值 → `repo.create(... dueAt: _nlpResolvedDueAt)` → `pop`。
改成：**接住 `create` 的返回值**（它就是 `Future<TodoTask>`，id 已可用），命中识别时补一条提醒写入。
不新建 provider、不抽 service —— `reminderRepositoryProvider` 与 `ReminderRepository.create` 都已存在。

## 失败语义为什么这么设计

任务建成之后提醒才失败，属于**部分成功**：
- 回滚任务 = 把已经落库的东西藏起来，用户以为没保存 ⇒ 不可；
- 关掉弹窗 = 静默失败 ⇒ 正是本仓 #289/#292 两轮开掉的那类缺陷；
- 留在弹窗但允许重复点「保存」再建一次任务 ⇒ 数据重复，比静默更坏。

⇒ 留在弹窗、显示原因，并把"任务已建"记进状态：第二次点保存只走补提醒那一步。
这条状态用 `_savedTaskId` 表达；`_nlpResolvedDueAt` 为空时不进入这段逻辑。

## 测试形状（先红后绿）

用 `TodoVisualFixture`（真 Drift 内存库 + 真 `SyncChangeQueue`），而不是 mock 仓储：
判据要落在**库里有没有那一行提醒**与 outbox 条数上，mock 会把"接了线"和"接线接对了"混成一回事。

- 正例：输入「明天9点」保存 ⇒ 断言 `todoTasks.dueAt` 与 `todoReminders.remindAt` 都等于次日 09:00，
  且提醒行数恰 1。
- 反例：输入「买牛奶」保存 ⇒ 提醒行数 0。
- 失败例：用覆盖 provider 的 `ReminderRepository` 子类让 `create` 抛错 ⇒ 任务仍在、弹窗未关、
  提示可见；再点一次保存，任务行数不增。

「明天9点」的期望值从**真实时钟**算（`DateTime.now()` 的次日 09:00），不依赖 `fixture.fixedNow`：
`NlpDateParser` 在本弹窗用的是无参构造（真时钟），把期望绑到 fixture 的时间会在凌晨/晚间桶里假绿。

## 门禁顺序

红测 → 实现 → `dart format` 显式文件 → 六道门禁跑在最终字节 → 台账自扫 → 只读复核 → push / PR。

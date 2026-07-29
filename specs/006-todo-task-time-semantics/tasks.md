# Tasks: Todo 提醒、重复与时间语义

## Phase 1: 契约与数据模型

- [ ] T001 在 `test/task_time_semantics_repository_test.dart` 写跨午夜、全天、固定时区和非法结束时间的失败测试。
- [ ] T002 在 `lib/core/db/app_database.dart` 与 `lib/state/repositories/task_repository.dart` 实现时间字段事务更新和 task outbox；运行 T001 至通过。
- [ ] T003 在 `test/task_time_semantics_repository_test.dart` 写单提醒、多提醒、结束提醒、持续提醒，以及派发 ID 与提醒规则 ID 分离的稍后/完成/忽略/开始专注失败测试。已局部验证缺失 parent task 时必须原子拒绝，且不写 reminder/outbox；`reminder_inbox_test.dart` 已覆盖开始专注写入 `start_focus` outbox 并进入关联任务专注页，其余提醒与派发验收仍未完成，保持未勾选。
- [ ] T004 新建 `lib/state/repositories/reminder_repository.dart` 与 `lib/state/repositories/reminder_dispatch_action_repository.dart`，使提醒规则和派发动作分别先写 Drift 再 enqueue；运行 T003 至通过。
- [ ] T005 在 `test/task_time_semantics_repository_test.dart` 写六类频率、跳过、补做和无效规则的失败测试。
- [ ] T006 新建 `lib/state/repositories/repeat_rule_repository.dart`，实现规则与 occurrence 动作的原子写入；运行 T005 至通过。

## Phase 2: 同步与界面

- [ ] T007 在 `test/sync_coordinator_time_semantics_test.dart` 写 task、reminder、repeatRule、repeatSkip 的 serverId 依赖、拉取顺序与重复 push 失败测试。
- [ ] T008 修改 `lib/core/sync/sync_coordinator.dart` 使 T007 通过，并断言失败项保持可重试 outbox 状态。
- [ ] T009 在 `test/features/task/task_time_semantics_test.dart` 写详情的时间、提醒和重复编辑回显失败测试。
- [ ] T010 修改 `lib/features/task/task_detail_pane.dart` 与 `lib/features/reminder/reminder_inbox_page.dart` 接入 Repository/use-case，使 T009 通过且不直接调用 API；App 运行期间的即时通知轮询同样只能经 `ReminderInboxRepository`，并以派发 ID 去重。提醒收件箱的“开始专注”已通过 `ReminderDispatchActionRepository` 入队并进入关联任务番茄专注页，但 T009 全量详情编辑回显尚未完全结项。

## Phase 3: 证据与交接

- [ ] T011 运行 plan.md 的低资源验证命令，将实际输出写入 Docs #49；未完成的设备和测试环境旅程保持 `partial`。
- [ ] T012 与 Service #181 对齐请求、响应、错误码、时区格式和 mutation 幂等键，并在 Docs #49 链接双方 Draft PR。

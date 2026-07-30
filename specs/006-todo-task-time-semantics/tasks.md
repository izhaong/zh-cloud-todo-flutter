# Tasks: Todo 提醒、重复与时间语义

## Phase 1: 契约与数据模型

- [ ] T001 在 `test/task_time_semantics_repository_test.dart` 写跨午夜、全天、固定时区和非法结束时间的失败测试。
- [ ] T002 在 `lib/core/db/app_database.dart` 与 `lib/state/repositories/task_repository.dart` 实现时间字段事务更新和 task outbox；运行 T001 至通过。
- [x] T003 在 `test/task_time_semantics_repository_test.dart` 写单提醒、多提醒、结束提醒、持续提醒，以及派发 ID 与提醒规则 ID 分离的稍后/完成/忽略/开始专注失败测试。已验证缺失 parent task 时原子拒绝且不写 reminder/outbox，四种派发动作按各自 dispatch ID 写入独立 outbox，非法 ID/稍后分钟数不入队；`reminder_inbox_test.dart` 覆盖稍后、完成、批量忽略、开始专注与重试状态，其中开始专注进入关联任务专注页。
- [x] T004 新建 `lib/state/repositories/reminder_repository.dart` 与 `lib/state/repositories/reminder_dispatch_action_repository.dart`，使提醒规则和派发动作分别先写 Drift 再 enqueue；`task_time_semantics_repository_test.dart` 与 `reminder_inbox_test.dart` 定向回归通过。
- [ ] T005 在 `test/task_time_semantics_repository_test.dart` 写六类频率、三类重复模式、自选日期排序去重/非法边界、跳过、补做和无效规则的失败测试。
- [ ] T006 扩展 `lib/state/repositories/repeat_rule_repository.dart`，实现 selectedDates、规则与 occurrence 动作的原子写入；运行 T005 至通过。

## Phase 2: 同步与界面

- [ ] T007 在 `test/sync_coordinator_time_semantics_test.dart` 写 task、reminder、repeatRule（含 selectedDates）、repeatSkip 的 serverId 依赖、拉取顺序与重复 push 失败测试。
- [ ] T008 修改 `lib/core/sync/sync_coordinator.dart` 使 T007 通过，并断言失败项保持可重试 outbox 状态。
- [ ] T009 在 `test/features/task/task_time_semantics_test.dart` 写详情的时间、提醒和重复编辑回显失败测试。已覆盖按次数结束与按日期结束，其中日期结束规范化为截止日 `23:59:59` 的包含式上界；下一步补自选日期的新增、删除、排序去重与保存旅程。提醒已覆盖独立的 `DUE/dueAt` 截止入口、`END/endAt` 结束入口、绝对时间修改，以及已有规则的 `DUE` 派生、提前量、持续间隔、时区保留、规则 UUID 不变与 outbox 载荷。其余 B2 设备/测试环境旅程尚未结项，保持未勾选。
- [ ] T010 修改 `lib/features/task/task_detail_pane.dart` 与 `lib/features/reminder/reminder_inbox_page.dart` 接入 Repository/use-case，使 T009 通过且不直接调用 API；App 运行期间的即时通知轮询同样只能经 `ReminderInboxRepository`，并以派发 ID 去重。详情中的重复结束条件已通过 `RepeatRuleRepository` 写入 Drift/outbox，已有提醒编辑已通过 `ReminderRepository.update` 保持同一规则 UUID 并重算相对触发时间，截止提醒已从错误的 `END` 对齐为后端 `DUE` 契约，且补回了真正绑定时间段 `endAt` 的 `END` 入口；提醒收件箱的四种派发动作均经 `ReminderDispatchActionRepository` 入队，开始专注进入关联任务番茄专注页，最新本地动作状态覆盖同一 dispatch ID 的远端旧待处理项并禁止重复提交。其余外部验收仍未结项，保持未勾选。

## Phase 3: 证据与交接

- [ ] T011 运行 plan.md 的低资源验证命令，将实际输出写入 Docs #49；未完成的设备和测试环境旅程保持 `partial`。
- [ ] T012 与 Service #181 对齐请求、响应、错误码、时区格式和 mutation 幂等键，并在 Docs #49 链接双方 Draft PR。

## 补充执行证据

- 2026-07-30：日历改期固定时区语义完成红绿闭环。失败测试证明旧实现按设备本地日期落格，并在拖拽时保留设备时分而非任务 IANA 时区墙钟；修复后 `CalendarView` 复用统一时间转换，固定时区任务按配置时区落格，跨夏令时拖拽保留墙钟并转换为新的 UTC 瞬时，全天任务保持纯日期，非法历史时区安全降级为设备本地语义。后续 Widget 红绿测试又冻结日程模式的时间与时段必须显示任务墙钟，并按显示墙钟排序，不能直接显示或排序原始 UTC 瞬时。时间线补充失败测试证明原实现同样会按 UTC 瞬时落错日期桶并显示、排序错误；现在分桶、日期时间标签与组内排序统一使用任务固定时区墙钟，同时仍保持全天任务的纯日期语义。定向日历、时间线与详情时间语义测试通过；真实跨设备时区切换与固定端 GUI 仍未执行，T009–T012 保持未勾选。
- 2026-07-30：固定时区语义继续覆盖任务主表面。红灯分别证明主列表分组、任务行日期徽标、侧栏今天/明天/未来 7 天统计与筛选、看板截止日期以及高级日期过滤/排序会直接使用 UTC 瞬时；统一 `taskWallClockDateTime` 后，上述入口按任务 IANA 墙钟一致呈现，全天任务仍不做时区位移。同期修正“未来 7 天”只包含第 7 天零点、漏掉该日其余时刻的边界。四象限的“未来 24 小时”保持真实瞬时比较，不改为墙钟日期。真实跨设备时区切换与固定端 GUI 仍未执行，T009–T012 保持未勾选。
- 2026-07-30：时间线“顺延一天”补充跨 DST 红绿测试。旧实现固定增加 24 小时，使 `America/Los_Angeles` 09:00 在夏令时结束后变为 08:00；现在开始、结束与截止分别按任务展示日期顺延并转换回 UTC，墙钟 09:00/10:00 保持不变，实际瞬时间隔可为 23 或 25 小时。浮动任务夹具同步改为本地墙钟值，延长一小时仍按真实持续时间增加。真实固定端拖放旅程仍未执行，T009–T012 保持未勾选。

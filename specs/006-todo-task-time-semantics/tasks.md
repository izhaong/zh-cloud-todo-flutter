# Tasks: Todo 提醒、重复与时间语义

## Phase 1: 契约与数据模型

- [x] T001 在 `test/task_time_semantics_repository_test.dart` 写跨午夜、全天、固定时区和非法结束时间的失败测试。已覆盖创建/更新非法区间、跨午夜时段、全天日期范围、固定 IANA 时区、清空时间段及完成/重开时间载荷。
- [x] T002 在 `lib/core/db/app_database.dart` 与 `lib/state/repositories/task_repository.dart` 实现时间字段事务更新和 task outbox；运行 T001 至通过。创建和更新均验证 Drift/outbox 一致，模拟 enqueue 失败时任务插入或修改完整回滚。
- [x] T003 在 `test/task_time_semantics_repository_test.dart` 写单提醒、多提醒、结束提醒、持续提醒，以及派发 ID 与提醒规则 ID 分离的稍后/完成/忽略/开始专注失败测试。已验证缺失 parent task 时原子拒绝且不写 reminder/outbox，四种派发动作按各自 dispatch ID 写入独立 outbox，非法 ID/稍后分钟数不入队；`reminder_inbox_test.dart` 覆盖稍后、完成、批量忽略、开始专注与重试状态，其中开始专注进入关联任务专注页。
- [x] T004 新建 `lib/state/repositories/reminder_repository.dart` 与 `lib/state/repositories/reminder_dispatch_action_repository.dart`，使提醒规则和派发动作分别先写 Drift 再 enqueue；`task_time_semantics_repository_test.dart` 与 `reminder_inbox_test.dart` 定向回归通过。
- [x] T005 在 `test/task_time_semantics_repository_test.dart` 写六类频率、三类重复模式、自选日期排序去重/非法边界、跳过、补做和无效规则的失败测试。现已覆盖六类频率、`ON_DUE`/`ON_COMPLETE`/`ON_SELECTED_DATES`、selectedDates 排序去重与矛盾边界、字段非法矩阵、跳过和补做。
- [x] T006 扩展 `lib/state/repositories/repeat_rule_repository.dart`，实现 selectedDates、规则与 occurrence 动作的原子写入；运行 T005 至通过。规则保存、skip 与 catchup 均新增 enqueue 失败回滚断言，确认不会留下半写 Drift 状态或孤立 outbox。

## Phase 2: 同步与界面

- [x] T007 在 `test/sync_coordinator_time_semantics_test.dart` 写 task、reminder、repeatRule（含 selectedDates）、repeatSkip 的 serverId 依赖、拉取顺序与重复 push 失败测试。现已覆盖同批临时 task/rule ID 依赖、乱序 pull 先规则后跳过、网络失败后稳定 mutation/批幂等键重试，以及成功后的重复 push 空操作。
- [x] T008 修改 `lib/core/sync/sync_coordinator.dart` 使 T007 通过，并断言失败项保持可重试 outbox 状态。现有协调器实现通过完整集成用例：首轮连接失败后四类 outbox 均为 `retryable` 且 attemptCount 为 1，重试成功后分别回写 serverId 并全部转为 `synced`。
- [ ] T009 在 `test/features/task/task_time_semantics_test.dart` 写详情的时间、提醒和重复编辑回显失败测试。已覆盖定时固定时区墙钟回显/保存与全天纯日期选择（全天不打开时间选择器）；按次数结束与按日期结束已覆盖，其中日期结束规范化为截止日 `23:59:59` 的包含式上界；自选日期已覆盖新增、删除、排序去重、再次保存，以及切回到期模式时清空有限日期集合。提醒已覆盖独立的 `DUE/dueAt` 截止入口、`END/endAt` 结束入口、绝对时间修改，以及已有规则的 `DUE` 派生、提前量、持续间隔、时区保留、规则 UUID 不变与 outbox 载荷。其余 B2 设备/测试环境旅程尚未结项，保持未勾选。
- [ ] T010 修改 `lib/features/task/task_detail_pane.dart` 与 `lib/features/reminder/reminder_inbox_page.dart` 接入 Repository/use-case，使 T009 通过且不直接调用 API；App 运行期间的即时通知轮询同样只能经 `ReminderInboxRepository`，并以派发 ID 去重。详情中的重复结束条件已通过 `RepeatRuleRepository` 写入 Drift/outbox，已有提醒编辑已通过 `ReminderRepository.update` 保持同一规则 UUID 并重算相对触发时间，截止提醒已从错误的 `END` 对齐为后端 `DUE` 契约，且补回了真正绑定时间段 `endAt` 的 `END` 入口；提醒收件箱的四种派发动作均经 `ReminderDispatchActionRepository` 入队，开始专注进入关联任务番茄专注页，最新本地动作状态覆盖同一 dispatch ID 的远端旧待处理项并禁止重复提交。其余外部验收仍未结项，保持未勾选。

## Phase 3: 证据与交接

- [ ] T011 运行 plan.md 的低资源验证命令，将实际输出写入 Docs #49；未完成的设备和测试环境旅程保持 `partial`。
- [ ] T012 与 Service #181 对齐请求、响应、错误码、时区格式和 mutation 幂等键，并在 Docs #49 链接双方 Draft PR。

## 补充执行证据

- 2026-07-30：日历改期固定时区语义完成红绿闭环。失败测试证明旧实现按设备本地日期落格，并在拖拽时保留设备时分而非任务 IANA 时区墙钟；修复后 `CalendarView` 复用统一时间转换，固定时区任务按配置时区落格，跨夏令时拖拽保留墙钟并转换为新的 UTC 瞬时，全天任务保持纯日期，非法历史时区安全降级为设备本地语义。后续 Widget 红绿测试又冻结日程模式的时间与时段必须显示任务墙钟，并按显示墙钟排序，不能直接显示或排序原始 UTC 瞬时。时间线补充失败测试证明原实现同样会按 UTC 瞬时落错日期桶并显示、排序错误；现在分桶、日期时间标签与组内排序统一使用任务固定时区墙钟，同时仍保持全天任务的纯日期语义。定向日历、时间线与详情时间语义测试通过；真实跨设备时区切换与固定端 GUI 仍未执行，T009–T012 保持未勾选。
- 2026-07-30：固定时区语义继续覆盖任务主表面。红灯分别证明主列表分组、任务行日期徽标、侧栏今天/明天/未来 7 天统计与筛选、看板截止日期以及高级日期过滤/排序会直接使用 UTC 瞬时；统一 `taskWallClockDateTime` 后，上述入口按任务 IANA 墙钟一致呈现，全天任务仍不做时区位移。同期修正“未来 7 天”只包含第 7 天零点、漏掉该日其余时刻的边界。四象限的“未来 24 小时”保持真实瞬时比较，不改为墙钟日期。真实跨设备时区切换与固定端 GUI 仍未执行，T009–T012 保持未勾选。
- 2026-07-30：时间线“顺延一天”补充跨 DST 红绿测试。旧实现固定增加 24 小时，使 `America/Los_Angeles` 09:00 在夏令时结束后变为 08:00；现在开始、结束与截止分别按任务展示日期顺延并转换回 UTC，墙钟 09:00/10:00 保持不变，实际瞬时间隔可为 23 或 25 小时。浮动任务夹具同步改为本地墙钟值，延长一小时仍按真实持续时间增加。真实固定端拖放旅程仍未执行，T009–T012 保持未勾选。
- 2026-07-30：详情日期/时间选择器固定时区编辑完成红绿闭环。失败测试证明旧实现会把原始 UTC `16:30` 直接交给选择器，而不是显示 `America/Los_Angeles` 墙钟 `09:30`；现在选择器先按任务 IANA 时区生成初始墙钟，用户确认后再通过时区数据库和当日 DST 偏移转换为 UTC 瞬时。全天任务跳过时间选择并保持纯日期；非法历史时区继续安全降级为设备本地语义。定向详情、日历、工作视图和时间语义仓储测试通过；真实跨设备时区切换与固定端 GUI 仍未执行，T009–T012 保持未勾选。
- 2026-07-30：详情自选日期重复编辑旅程补齐。现有新增两日和切回到期模式基础上，新增用例从乱序且重复的输入验证按日期排序去重回显，删除一个日期、重复选择已有日期不产生副本，再新增日期并保存；Drift 与 outbox 最终均为排序后的 `["2026-07-20","2026-07-25"]`。自选日期 Chip 同时提供明确的删除图标 key 与中文 tooltip，方便自动化和辅助语义定位。真实固定端删除热区与跨设备同步仍未执行，T009–T012 保持未勾选。
- 2026-07-30：时间语义依赖批次与失败恢复闭环。新增集成用例把一个未同步 task、reminder、自选日期 repeatRule 和 repeatSkip 放入同批，断言后三者引用同一个临时 task ID、skip 引用同一个临时 rule ID，且 selectedDates 保持排序去重。首轮网络失败后四条 outbox 均保持可重试，第二轮沿用原 mutation、临时实体 ID 与批幂等键成功回写 `201/301/401/501`，第三轮 push 不再发送；既有乱序 pull 用例继续保证 repeatRule 先于 repeatSkip 应用。T007–T008 已完成。
- 2026-07-30：Phase 1 Repository 契约收口。复核既有任务时间测试后确认跨午夜、全天、固定时区、非法区间以及 task/outbox 原子回滚已完整覆盖；重复规则新增三种模式与通用非法字段矩阵，并分别模拟 rule、skip、catchup 在 outbox enqueue 失败时回滚，未留下半写规则、跳过记录或 occurrence action。定向 Repository 测试 28 项通过，T001/T002/T005/T006 已完成。
- 2026-07-30：详情全天固定时区日期编辑补充真实选择器旅程。用例打开截止日期选择器、选择 `2026-07-15` 后确认不会再出现 `TimePickerDialog`，保存到 Drift 与 task outbox 的都是设备本地纯日期午夜，同时保持 `allDay=true` 与 fixedTimezone 元数据。同期静态审计 `task_detail_pane.dart` 和 `reminder_inbox_page.dart`：任务、提醒、重复及提醒动作写入均经对应 Repository，直接 Drift 访问仅用于本地只读流和 serverId 到本地任务的导航解析。真实设备日期控件与测试环境同步仍未执行，T009–T012 保持未勾选。

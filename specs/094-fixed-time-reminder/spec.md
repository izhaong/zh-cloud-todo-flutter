# 094 「固定时间」档提醒按设备当地墙钟触发（FL #371）

## 判据源

嘀嗒《02-功能指南/01-任务/07-固定时间与固定时区.md》：
- `:64`「这样一来，不论你是在洛杉矶出差，还是在巴塞罗那旅游，滴答清单都会在
  当地时间上午7点提醒你早起运动。」——「固定时间」档的提醒触发瞬间要按
  **设备当地墙钟**重解释，不是锚点区钉死的绝对时刻。
- 对照 `:56`（固定时区档）：任务自动换算成"北京时间 18 点"提醒——
  那一档才钉绝对时刻，本单不碰。

## 契约

- `reminderTriggerDateTime(remindAt, mode, timeZone, {deviceZone, now})`
  （lib/core/time/task_time_formatter.dart）：仅 `fixedTime` 且锚点区有效时换算；
  浮动/固定时区/无锚点/锚点无效原样返回 `remindAt`（不差于旧行为）。
- 换算 = 锚点区读出的墙钟字段 → 设备当前时区的同一钟点。生产路径设备时区走
  Dart 运行时当地解释（`DateTime.toLocal()`，OS tz、含 DST），固定点两趟收敛
  （`T = fields − offset(T)`，now 与 T 之间最多一道 DST 台阶）；全程 UTC 表示，
  避开 naive-local 字段的 DST 陷阱。`deviceZone` 仅测试注入钉确定值
  （`timezone.local` 在无初始化时默认 UTC，不可靠）。
- `ReminderNotificationPoller`：每条 pending 先取任务（`taskByServerId`）拿
  timeMode/timeZone，再算 trigger；**去重、到期判定、payload 毫秒、系统排期
  fireAt、dispatchState 全部键在换算后的 trigger 上**——设备换区或锚点变化 ⇒
  触发瞬间变化 ⇒ 下一轮 poll 自动重排（旧排期被 stale 判据取消/重排）；
  服务端 `remindAt` 只作身份来源。
- 任务查不到（本地未同步）⇒ 浮动档 ⇒ trigger = remindAt。
- 一次性迁移效应：存量 time_mode=2 的提醒升级后触发瞬间 ≠ remindAt ⇒
  首轮 poll 重排一次，属修正不属回归。

## 测试台账

test/core/task_time_mode_test.dart「提醒触发瞬间（FL #371）」组，6 条：
1. 设备洛杉矶：锚点上海 07-15 07:00 → 触发为洛杉矶当地 07-15 07:00
   （UTC 14:00；deviceZone 注入）
2. 设备上海 = 锚点上海：trigger == remindAt（恒等路径）
3. 冬令时 DST：1 月洛杉矶 PST，锚点上海 07:00 → UTC 15:00（夏冬两季
   offset 不同，走同一字段重解释而非固定偏移）
4. 生产路径（不注入 deviceZone，注入 now=07-20）：`trigger.toLocal()` 墙钟
   == 07:00 07-15（返回值是 UTC 表示，本地钟点必须经 toLocal 读）
5. 浮动 / 固定时区档：原样返回 remindAt
6. 锚点 null / 无效串：原样返回 remindAt

test/reminder_notification_poller_test.dart，2 条：
7. 固定时间档按设备当地钟点持久调度，同一触发只排一次（第二轮不重排）
8. 锚点区变化后（上海→纽约）触发瞬间重排：scheduled 长度 +1 且两次 fireAt
   不同瞬间（dedup 键在 trigger 上 ⇒ 自动重排）

## 变异探针

- 变异：`reminderTriggerDateTime` 函数体首行插入 `return remindAt;`
  （整体摘掉换算）。结果：红 3 条——1（洛杉矶钟点断言）、7/8（poller 触发
  瞬间断言），全落在固定时间正向行为上；2–6 走恒等/回退路径变异下仍绿，
  符合预期。用 `cp` 备份还原（不用 `git checkout --`，防误伤未提交改动）。
- 首选变异（`anchor == null || anchor != null`）只产出编译红，不可归因，
  已弃用并改用上述语义变异。

## 门禁

- `dart format` 4 个改动文件：0 changed（2 个测试文件折行调整）
- `flutter analyze`：No issues found!
- 全量 `flutter test`：All tests passed（26 条本单相关文件先行验证 +22→+26）

## 范围外

- 提醒 payload 服务端契约（B 面）：remindAt 仍由服务端下发，客户端只做
  显示解释；服务端按设备时区下发属 service #312 领域。
- 「固定时区」档提醒不换算（:56 语义：钉绝对时刻）。
- `timezone.local` 不可靠不修：设置页时区开关只是显示可见性开关
  （specs/055），与本单无耦合。

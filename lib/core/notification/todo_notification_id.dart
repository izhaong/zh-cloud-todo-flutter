/// OS 通知 id 的**类型命名空间**（FL #358）。
///
/// 病灶：客户端原来直接拿服务端 `dispatch.id` 当 `local_notifications` 的 `id`。
/// 一旦「@ 提及」这类通知也进同一条流，两条流的 id **会在同一个命名空间里相撞** ——
/// 后到的那条会覆盖/顶掉前一条，用户看到的是"一条通知变成了另一条"。
///
/// 做法：把 32 位 id 空间按类型切成两个区间，**跨类型永不相等**。
/// （用 `<< 20` 而不是给 id 加前缀字符串：`local_notifications` 的 id 必须是 int。）
library;

/// 提醒：`[0x1000_0000, 0x1FFF_FFFF]`。
const int reminderNotificationIdBase = 0x10000000;

/// 提及：`[0x2000_0000, 0x2FFF_FFFF]`。
const int mentionNotificationIdBase = 0x20000000;

/// 服务端 id 允许的最大值（20 位），超过就取模 —— 宁可两条通知共用一个 id，
/// 也不能因为一条异常 id 让 `local_notifications` 抛错（那会让整轮调度失败）。
const int _maxServerId = 0xFFFFF;

/// 提醒通知的 OS id。
int reminderOsNotificationId(int serverDispatchId) =>
    reminderNotificationIdBase | (serverDispatchId & _maxServerId);

/// 提及通知的 OS id。**与提醒区间不重叠** —— 这就是加命名空间的全部意义。
int mentionOsNotificationId(int serverNotificationId) =>
    mentionNotificationIdBase | (serverNotificationId & _maxServerId);

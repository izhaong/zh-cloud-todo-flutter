import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/notification/todo_notification_id.dart';

/// FL #358：OS 通知 id 的**类型命名空间**。
///
/// 病灶：客户端原来直接拿服务端 `dispatch.id` 当 `local_notifications` 的 id。
/// 「@ 提及」一旦并入同一条流，两条流的 id 会在**同一个命名空间**里相撞 ⇒
/// 后到的那条会顶掉前一条（用户看到"一条通知变成另一条"）。
void main() {
  test('提醒与提及的 id 跨类型永不相等', () {
    for (var id = 1; id <= 5000; id += 7) {
      expect(
        reminderOsNotificationId(id),
        isNot(mentionOsNotificationId(id)),
        reason: '服务端编号 $id 在两类里必须映射到不同 OS id，否则系统通知中心会互相顶掉',
      );
    }
  });

  test('同一类型内：不同服务端 id 仍然不同（不因命名空间而塌缩）', () {
    expect(reminderOsNotificationId(1), isNot(reminderOsNotificationId(2)));
    expect(mentionOsNotificationId(1), isNot(mentionOsNotificationId(2)));
  });

  test('同一类型内：同一 id 稳定（重排后仍是同一条通知）', () {
    expect(reminderOsNotificationId(42), reminderOsNotificationId(42));
  });

  test('异常大的服务端 id 不抛错（宁可塌缩，也不能让整轮调度失败）', () {
    expect(() => reminderOsNotificationId(1 << 40), returnsNormally);
    expect(() => mentionOsNotificationId(1 << 40), returnsNormally);
  });

  /// 提及**不进提醒调度链** —— 两者是**两个不同的端点与两个不同的类型**。
  ///
  /// `ReminderNotificationPoller` 是提醒专用（按 `timeMode` 重解释触发时刻、
  /// 把未来项交 OS 持久调度、文案写死「到期提醒」）。
  /// 这条判据钉的是结构事实：**两条流不共用同一个入口** ——
  /// 它是"提及不会被 OS 提前调度、也不会被写成到期提醒"的前提。
  test('提醒收件箱与通知收件箱是两套类型（不是同一个模型）', () {
    final reminder = ReminderInboxItem(
      id: 1,
      taskId: 2,
      taskTitle: 'x',
      remindAt: DateTime(2026, 10, 17),
    );
    const notification = TodoNotificationItem(id: 1, type: 'MENTION');
    expect(reminder, isNot(isA<TodoNotificationItem>()));
    expect(notification, isNot(isA<ReminderInboxItem>()));
    expect(notification.isMention, isTrue);
    expect(
      const TodoNotificationItem(id: 1, type: 'REMINDER').isMention,
      isFalse,
    );
  });

  /// 列表页对提及的处理是**跳转 + 标已读**，绝不调用 `LocalNotificationService`。
  ///
  /// 这是"提及只展示"的**落地判据**：判据源是那一页的实现里
  /// `LocalNotificationService` 的**零调用**（提醒专用链路在 poller，不在页面）。
  test('通知列表页不引用 OS 调度器（提及只展示）', () {
    // 判据用**源码级**断言：页面文件里不出现 LocalNotificationService。
    // （widget 级断言要 mock 整条导航栈，成本不成比例；结构事实用结构判据钉。）
    // ignore: avoid_dynamic_calls
    final pageSource = File(
      'lib/features/collaboration/notification_list_page.dart',
    ).readAsStringSync();
    expect(
      pageSource.contains('LocalNotificationService'),
      isFalse,
      reason: '通知列表页一旦引用 OS 调度器，提及就会被"到点弹出"——那是提醒专用链路',
    );
    expect(pageSource.contains('schedule('), isFalse, reason: '同上：调度动作属于提醒链路');
  });
}

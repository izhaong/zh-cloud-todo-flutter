import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/notification/local_notification_service.dart';
import 'package:zh_cloud_todo_flutter/core/notification/reminder_notification_poller.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_inbox_repository.dart';

void main() {
  test(
    'poll shows each pending due dispatch once through the inbox repository',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 29, 12);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-local',
              serverId: const Value(101),
              name: '收集箱',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-local',
              serverId: const Value(201),
              listId: 'list-local',
              title: '本地任务标题',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final notifications = _RecordingNotificationService();
      final poller = ReminderNotificationPoller(
        repository: _FakeReminderInboxRepository([
          ReminderInboxItem(
            id: 301,
            taskId: 201,
            taskTitle: '服务端旧标题',
            remindAt: now.subtract(const Duration(minutes: 1)),
          ),
          ReminderInboxItem(
            id: 302,
            taskId: 202,
            taskTitle: '未来提醒',
            remindAt: now.add(const Duration(minutes: 1)),
          ),
          ReminderInboxItem(
            id: 303,
            taskId: 203,
            taskTitle: '已忽略提醒',
            remindAt: now.subtract(const Duration(minutes: 1)),
            status: 'DISMISSED',
          ),
        ]),
        database: db,
        notifications: notifications,
        now: () => now,
      );

      expect(await poller.poll(), 1);
      expect(await poller.poll(), 0);
      expect(notifications.shown, [
        (id: 301, title: '本地任务标题', body: '到期提醒', payload: 'reminder:301'),
      ]);
    },
  );
}

class _FakeReminderInboxRepository extends ReminderInboxRepository {
  _FakeReminderInboxRepository(this.items)
    : super(ReminderActionApi(ApiClient()));

  final List<ReminderInboxItem> items;

  @override
  Future<List<ReminderInboxItem>> list() async => items;
}

class _RecordingNotificationService extends LocalNotificationService {
  final shown = <({int id, String title, String? body, String? payload})>[];

  @override
  Future<void> show({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}

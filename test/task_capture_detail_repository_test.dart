import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'offline checklist creation persists locally and enqueues a mutation',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));

      final task = await repository.create(listId: 'inbox', title: '撰写周报');
      final item = await repository.createChecklistItem(
        taskId: task.id,
        title: '整理数据',
      );

      expect(item.taskId, task.id);
      expect(item.title, '整理数据');
      final stored = await db.select(db.todoChecklistItems).get();
      expect(stored, hasLength(1));
      final outbox = await db.select(db.todoSyncChanges).get();
      final checklistChange = outbox.singleWhere(
        (change) => change.entity == 'task' && change.entityLocalId == item.id,
      );
      final payload =
          jsonDecode(checklistChange.payloadJson) as Map<String, dynamic>;
      expect(payload['isChecklistItem'], isTrue);
      expect(payload['parentTaskId'], task.id);
      expect(payload['listId'], task.listId);
    },
  );
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

void main() {
  test('时间线移动在同一离线写链路更新任务并入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 15, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-inbox',
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            listId: 'list-inbox',
            title: '调整时间',
            startAt: Value(DateTime.utc(2026, 7, 16, 9)),
            endAt: Value(DateTime.utc(2026, 7, 16, 10)),
            dueAt: Value(DateTime.utc(2026, 7, 16, 10)),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.moveTimelineTask(
      'task-1',
      startAt: DateTime.utc(2026, 7, 17, 13),
      endAt: DateTime.utc(2026, 7, 17, 14, 30),
      dueAt: DateTime.utc(2026, 7, 17, 14, 30),
    );

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.startAt?.toUtc(), DateTime.utc(2026, 7, 17, 13));
    expect(task.endAt?.toUtc(), DateTime.utc(2026, 7, 17, 14, 30));
    expect(task.dueAt?.toUtc(), DateTime.utc(2026, 7, 17, 14, 30));
    expect(queued, hasLength(1));
    expect(queued.single.entity, SyncEntities.task);
    expect(queued.single.op, SyncOps.upsert);
    expect(queued.single.entityLocalId, 'task-1');
  });
}

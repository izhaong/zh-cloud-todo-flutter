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

  test('看板跨列写入明确状态字段并入队', () async {
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
            title: '跨列任务',
            priority: const Value(0),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.moveKanbanTask('task-1', priority: 3, completed: true);

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).getSingle();
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.priority, 3);
    expect(task.completed, isTrue);
    expect(queued, hasLength(1));
    expect(queued.single.entity, SyncEntities.task);
    expect(queued.single.op, SyncOps.upsert);
  });

  test('列表重排按任务 UUID 持久化顺序并逐项入队', () async {
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
    for (final task in [('task-1', 0), ('task-2', 1)]) {
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: task.$1,
              listId: 'list-inbox',
              title: task.$1,
              sortOrder: Value(task.$2),
              updatedAt: now,
              createdAt: now,
            ),
          );
    }
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.reorderListTasks(['task-2', 'task-1']);

    final tasks = await (db.select(
      db.todoTasks,
    )..orderBy([(row) => OrderingTerm(expression: row.sortOrder)])).get();
    final queued = await db.select(db.todoSyncChanges).get();
    expect(tasks.map((task) => task.id), ['task-2', 'task-1']);
    expect(queued, hasLength(2));
    expect(
      queued.every((change) => change.entity == SyncEntities.task),
      isTrue,
    );
  });
}

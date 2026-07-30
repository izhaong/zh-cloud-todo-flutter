import 'dart:convert';

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

  test('只读清单拒绝时间线移动且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db, writable: false);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveTimelineTask(
        'task-1',
        startAt: DateTime.utc(2026, 7, 17, 13),
        endAt: DateTime.utc(2026, 7, 17, 14),
        dueAt: DateTime.utc(2026, 7, 17, 14),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '当前清单为只读，无法修改任务',
        ),
      ),
    );

    final task = await _taskById(db, 'task-1');
    expect(task.startAt?.toUtc(), DateTime.utc(2026, 7, 16, 9));
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('只读清单拒绝看板移动且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db, writable: false);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveKanbanTask('task-1', priority: 3, completed: true),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '当前清单为只读，无法修改任务',
        ),
      ),
    );

    final task = await _taskById(db, 'task-1');
    expect(task.priority, 0);
    expect(task.completed, isFalse);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('只读清单拒绝列表重排且不部分写入或创建 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db, writable: false);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.reorderListTasks(['task-2', 'task-1']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '当前清单为只读，无法修改任务',
        ),
      ),
    );

    expect((await _taskById(db, 'task-1')).sortOrder, 0);
    expect((await _taskById(db, 'task-2')).sortOrder, 1);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('列表重排拒绝跨清单任务且保持事务无副作用', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    final now = DateTime.utc(2026, 7, 15, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-other',
            name: '其他清单',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await (db.update(db.todoTasks)..where((row) => row.id.equals('task-2')))
        .write(const TodoTasksCompanion(listId: Value('list-other')));
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.reorderListTasks(['task-2', 'task-1']),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '必须属于同一清单',
        ),
      ),
    );

    expect((await _taskById(db, 'task-1')).sortOrder, 0);
    expect((await _taskById(db, 'task-2')).sortOrder, 1);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('任务与日历视图偏好可从 Drift 恢复且分别同步', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:inbox'),
      equals(null),
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:work'),
      equals(null),
    );
    expect(await repository.getCalendarViewMode(), equals(null));

    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:inbox',
      viewType: 'kanban',
    );
    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:work',
      viewType: 'timeline',
    );
    await repository.saveCalendarViewMode('agenda');

    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:inbox'),
      'kanban',
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:work'),
      'timeline',
    );
    expect(await repository.getCalendarViewMode(), 'agenda');
    final preferences = await db.select(db.todoViewPreferences).get();
    final queued = await db.select(db.todoSyncChanges).get();
    expect(preferences, hasLength(3));
    expect(queued, hasLength(3));
    expect(preferences.map((row) => row.sourceType).toSet(), {
      'task_view',
      'calendar_view',
    });
    final payloads = queued
        .map((change) => jsonDecode(change.payloadJson) as Map<String, dynamic>)
        .toList(growable: false);
    expect(
      payloads
          .where((payload) => payload['sourceType'] == 'task_view')
          .map((payload) => payload['sourceKey'])
          .toSet(),
      {'list:inbox', 'list:work'},
    );
  });

  test('旧任务视图偏好只回退收集箱且读取不产生写操作', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 30, 9);
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'legacy-view',
            sourceType: 'task_view',
            sourceKey: 'tasks_by_list',
            valueJson: '{"viewType":"kanban"}',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:inbox'),
      'kanban',
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:work'),
      equals(null),
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'smart:all'),
      equals(null),
    );
    expect(await db.select(db.todoViewPreferences).get(), hasLength(1));
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);

    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:inbox',
      viewType: 'timeline',
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:inbox'),
      'timeline',
    );
  });
}

Future<void> _seedViewActionList(AppDatabase db, {bool writable = true}) async {
  final now = DateTime.utc(2026, 7, 15, 9);
  await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          id: 'list-inbox',
          name: '收集箱',
          accessRole: Value(writable ? 'owner' : 'viewer'),
          writable: Value(writable),
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
            priority: const Value(0),
            sortOrder: Value(task.$2),
            startAt: Value(DateTime.utc(2026, 7, 16, 9)),
            endAt: Value(DateTime.utc(2026, 7, 16, 10)),
            dueAt: Value(DateTime.utc(2026, 7, 16, 10)),
            updatedAt: now,
            createdAt: now,
          ),
        );
  }
}

Future<TodoTask> _taskById(AppDatabase db, String taskId) {
  return (db.select(
    db.todoTasks,
  )..where((row) => row.id.equals(taskId))).getSingle();
}

import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

void main() {
  test('未排期任务拖入时间格会原子写入时段、全天语义与 outbox', () async {
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
            id: 'task-unscheduled',
            listId: 'list-inbox',
            title: '尚未安排',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    final startAt = DateTime(2026, 7, 16);
    final endAt = DateTime(2026, 7, 17);

    await repository.scheduleTimelineTask(
      'task-unscheduled',
      startAt: startAt,
      endAt: endAt,
      dueAt: endAt,
      allDay: true,
    );

    final task = await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals('task-unscheduled'))).getSingle();
    final changes = await db.select(db.todoSyncChanges).get();
    expect(task.startAt, startAt);
    expect(task.endAt, endAt);
    expect(task.dueAt, endAt);
    expect(task.allDay, isTrue);
    expect(changes, hasLength(1));
    expect(
      jsonDecode(changes.single.payloadJson),
      containsPair('allDay', true),
    );
  });

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

  test('日历拖拽改期只更新截止时间并在同一事务入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.moveCalendarTask(
      'task-1',
      dueAt: DateTime.utc(2026, 7, 20, 10),
    );

    final task = await _taskById(db, 'task-1');
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.startAt?.toUtc(), DateTime.utc(2026, 7, 16, 9));
    expect(task.endAt?.toUtc(), DateTime.utc(2026, 7, 16, 10));
    expect(task.dueAt?.toUtc(), DateTime.utc(2026, 7, 20, 10));
    expect(queued, hasLength(1));
    expect(queued.single.entity, SyncEntities.task);
    expect(queued.single.op, SyncOps.upsert);
    expect(queued.single.entityLocalId, 'task-1');
  });

  test('推荐任务添加到今天保留固定时区墙钟时刻并原子入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).write(
      TodoTasksCompanion(
        dueAt: Value(DateTime.utc(2026, 3, 7, 17, 30)),
        startAt: const Value.absent(),
        endAt: const Value.absent(),
        allDay: const Value(false),
        fixedTimezone: const Value(true),
        timeMode: const Value(1),
        timeZone: const Value('America/Los_Angeles'),
      ),
    );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.addToToday('task-1', today: DateTime(2026, 3, 8));

    final task = await _taskById(db, 'task-1');
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.dueAt?.toUtc(), DateTime.utc(2026, 3, 8, 16, 30));
    expect(task.allDay, isFalse);
    expect(task.fixedTimezone, isTrue);
    expect(task.timeZone, 'America/Los_Angeles');
    expect(queued, hasLength(1));
    expect(queued.single.entity, SyncEntities.task);
  });

  test('无日期推荐任务添加到今天设为全天且重复调用不重复入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    await (db.update(
      db.todoTasks,
    )..where((row) => row.id.equals('task-1'))).write(
      const TodoTasksCompanion(
        dueAt: Value(null),
        startAt: Value(null),
        endAt: Value(null),
        allDay: Value(false),
      ),
    );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    final today = DateTime(2026, 8, 2);

    await repository.addToToday('task-1', today: today);
    await repository.addToToday('task-1', today: today);

    final task = await _taskById(db, 'task-1');
    final queued = await db.select(db.todoSyncChanges).get();
    expect(task.dueAt, today);
    expect(task.allDay, isTrue);
    expect(task.startAt, isNull);
    expect(task.endAt, isNull);
    expect(queued, hasLength(1));
  });

  test('只读清单拒绝添加到今天且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db, writable: false);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));
    final before = await _taskById(db, 'task-1');

    await expectLater(
      repository.addToToday('task-1', today: DateTime(2026, 8, 2)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '当前清单为只读，无法修改任务',
        ),
      ),
    );

    final after = await _taskById(db, 'task-1');
    expect(after.dueAt, before.dueAt);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
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

  test('时间线拒绝非正时间段且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveTimelineTask(
        'task-1',
        startAt: DateTime.utc(2026, 7, 17, 14),
        endAt: DateTime.utc(2026, 7, 17, 14),
        dueAt: DateTime.utc(2026, 7, 17, 14),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '必须晚于开始时间',
        ),
      ),
    );

    final task = await _taskById(db, 'task-1');
    expect(task.startAt?.toUtc(), DateTime.utc(2026, 7, 16, 9));
    expect(task.endAt?.toUtc(), DateTime.utc(2026, 7, 16, 10));
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('看板拒绝越界优先级且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveKanbanTask('task-1', priority: 4, completed: true),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '必须介于 0 和 3',
        ),
      ),
    );

    final task = await _taskById(db, 'task-1');
    expect(task.priority, 0);
    expect(task.completed, isFalse);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
  });

  test('列表重排拒绝重复任务且不修改排序或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.reorderListTasks(['task-1', 'task-1']),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          '不能包含重复任务',
        ),
      ),
    );

    expect((await _taskById(db, 'task-1')).sortOrder, 0);
    expect((await _taskById(db, 'task-2')).sortOrder, 1);
    expect(await db.select(db.todoSyncChanges).get(), isEmpty);
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

  test('只读清单拒绝日历拖拽改期且不修改任务或 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedViewActionList(db, writable: false);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await expectLater(
      repository.moveCalendarTask(
        'task-1',
        dueAt: DateTime.utc(2026, 7, 20, 10),
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
    expect(task.dueAt?.toUtc(), DateTime.utc(2026, 7, 16, 10));
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
    expect((await repository.getCalendarDisplay()).showCompletedTasks, isNull);

    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:inbox',
      viewType: 'kanban',
    );
    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:work',
      viewType: 'timeline',
    );
    await repository.saveCalendarDisplay(
      viewMode: 'agenda',
      showCompletedTasks: true,
    );

    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:inbox'),
      'kanban',
    );
    expect(
      await repository.getTaskWorkspaceViewMode(sourceKey: 'list:work'),
      'timeline',
    );
    final display = await repository.getCalendarDisplay();
    expect(display.viewType, 'agenda');
    expect(display.showCompletedTasks, isTrue);
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

  test('时间线缩放与折叠偏好按来源隔离且不覆盖视图模式', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:inbox',
      viewType: 'timeline',
    );
    await repository.saveTaskTimelinePreference(
      sourceKey: 'list:inbox',
      zoom: 1.25,
      scale: 'month',
      collapsedGroupIds: const {'overdue', 'later'},
    );
    await repository.saveTaskTimelinePreference(
      sourceKey: 'list:work',
      zoom: 0.75,
      scale: 'day',
      collapsedGroupIds: const {'today'},
    );

    final inbox = await repository.getTaskWorkspacePreference(
      sourceKey: 'list:inbox',
    );
    final work = await repository.getTaskWorkspacePreference(
      sourceKey: 'list:work',
    );
    expect(inbox.viewType, 'timeline');
    expect(inbox.timelineZoom, 1.25);
    expect(inbox.timelineScale, 'month');
    expect(inbox.collapsedTimelineGroupIds, {'overdue', 'later'});
    expect(work.viewType, 'list');
    expect(work.timelineZoom, 0.75);
    expect(work.timelineScale, 'day');
    expect(work.collapsedTimelineGroupIds, {'today'});

    final changes = await db.select(db.todoSyncChanges).get();
    final latestInbox = changes
        .map((change) => jsonDecode(change.payloadJson) as Map<String, dynamic>)
        .where((payload) => payload['sourceKey'] == 'list:inbox')
        .last;
    expect(latestInbox['viewType'], 'timeline');
    expect(
      jsonDecode(latestInbox['valueJson'] as String),
      containsPair('timelineZoom', 1.25),
    );
    expect(
      jsonDecode(latestInbox['valueJson'] as String),
      containsPair('timelineScale', 'month'),
    );
  });

  test('服务端包装的时间线偏好可恢复并在部分更新时保留未知字段', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 30, 9);
    await db
        .into(db.todoViewPreferences)
        .insert(
          TodoViewPreferencesCompanion.insert(
            id: 'server-view',
            serverId: const Value(301),
            sourceType: 'task_view',
            sourceKey: 'list:inbox',
            valueJson: jsonEncode({
              'sourceType': 'task_view',
              'sourceKey': 'list:inbox',
              'viewType': 'timeline',
              'valueJson': jsonEncode({
                'viewType': 'timeline',
                'timelineZoom': 1.5,
                'collapsedTimelineGroupIds': ['tomorrow'],
                'futureField': 'keep-me',
              }),
            }),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

    final restored = await repository.getTaskWorkspacePreference(
      sourceKey: 'list:inbox',
    );
    expect(restored.viewType, 'timeline');
    expect(restored.timelineZoom, 1.5);
    expect(restored.collapsedTimelineGroupIds, {'tomorrow'});

    await repository.saveTaskWorkspaceViewMode(
      sourceKey: 'list:inbox',
      viewType: 'kanban',
    );
    final change = await db.select(db.todoSyncChanges).getSingle();
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    final value = jsonDecode(payload['valueJson'] as String);
    expect(value['viewType'], 'kanban');
    expect(value['timelineZoom'], 1.5);
    expect(value['collapsedTimelineGroupIds'], ['tomorrow']);
    expect(value['futureField'], 'keep-me');
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

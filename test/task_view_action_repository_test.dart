import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_formatter.dart';
import 'package:zh_cloud_todo_flutter/core/time/task_time_mode.dart';
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
        timeMode: const Value(2),
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
    expect((await repository.getCalendarDisplay()).showHeatmap, isNull);

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
      showHeatmap: true,
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

  group('智能清单落点共用的 scheduleTaskToDay', () {
    test('把截止日挪到指定日、保留展示墙钟时刻；时段留在原日（与日历拖拽改期同口径）', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedViewActionList(db);
      await (db.update(
        db.todoTasks,
      )..where((row) => row.id.equals('task-1'))).write(
        TodoTasksCompanion(
          dueAt: Value(DateTime.utc(2026, 3, 7, 17, 30)),
          allDay: const Value(false),
          fixedTimezone: const Value(true),
          timeMode: const Value(2),
          timeZone: const Value('America/Los_Angeles'),
        ),
      );
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

      await repository.scheduleTaskToDay(
        'task-1',
        targetDay: DateTime(2026, 10, 20),
      );

      final task = await _taskById(db, 'task-1');
      final queued = await db.select(db.todoSyncChanges).get();
      expect(
        task.dueAt?.toUtc(),
        DateTime.utc(2026, 10, 20, 16, 30),
        reason: '洛杉矶墙上 09:30 要跟着换日走（十月是 PDT，与三月的 PST 差一小时）',
      );
      expect(task.allDay, isFalse);
      expect(task.timeZone, 'America/Los_Angeles');
      expect(
        task.startAt?.toUtc(),
        DateTime.utc(2026, 7, 16, 9),
        reason:
            '本端「改日期」一律只挪截止时间，时段留在原日 —— 与 moveCalendarTask、addToToday 同一条约定，'
            '不是这条落点漏了（登记为已知偏差见 specs/111，跨三处的修法另开单）',
      );
      expect(task.endAt?.toUtc(), DateTime.utc(2026, 7, 16, 10));
      expect(queued, hasLength(1));
      expect(queued.single.entity, SyncEntities.task);
    });

    test('无日期任务落成目标日全天并只入队一次', () async {
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
      final targetDay = DateTime(2027, 1, 5);

      await repository.scheduleTaskToDay('task-1', targetDay: targetDay);

      final task = await _taskById(db, 'task-1');
      expect(task.dueAt, targetDay);
      expect(task.allDay, isTrue, reason: '无日期 = 只补日期，不替用户编一个时刻');
      expect(await db.select(db.todoSyncChanges).get(), hasLength(1));
    });

    test('截止日已在目标日 ⇒ 一行都不写、一条 outbox 都不发', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedViewActionList(db);
      final dueAt = DateTime(2026, 12, 1, 10, 15);
      await (db.update(
        db.todoTasks,
      )..where((row) => row.id.equals('task-1'))).write(
        TodoTasksCompanion(dueAt: Value(dueAt), allDay: const Value(false)),
      );
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

      await repository.scheduleTaskToDay(
        'task-1',
        targetDay: DateTime(2026, 12, 1),
      );

      final task = await _taskById(db, 'task-1');
      expect(task.dueAt, dueAt, reason: '同一天但时刻不同也不能被抹成 00:00 —— 那是改时刻，不是改日');
      expect(
        await db.select(db.todoSyncChanges).get(),
        isEmpty,
        reason: '没变化还入队 = 白发一次同步变更',
      );
    });

    test('只读清单拒绝落点并原样抛出', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedViewActionList(db, writable: false);
      final before = await _taskById(db, 'task-1');
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

      await expectLater(
        repository.scheduleTaskToDay(
          'task-1',
          targetDay: DateTime(2026, 12, 1),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '当前清单为只读，无法修改任务',
          ),
        ),
      );
      expect(await _taskById(db, 'task-1'), before);
      expect(await db.select(db.todoSyncChanges).get(), isEmpty);
    });

    test('浮动与固定时间：挪完之后「谓词读的那个日子」就是落点日，时刻不动', () async {
      // 收窄后的不变量（specs/111 需求 1）：只有这两档成立。
      // 断言走 taskWallClockDateTime —— 与 _dateConditionMatches 同一个读数口径，
      // 不是「我以为写进去了」，而是「列表那一格真会这么判」。
      for (final entry in <({int mode, String? zone})>[
        (mode: 0, zone: null),
        (mode: 2, zone: 'America/Los_Angeles'),
      ]) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedViewActionList(db);
        await (db.update(
          db.todoTasks,
        )..where((row) => row.id.equals('task-1'))).write(
          TodoTasksCompanion(
            dueAt: Value(
              entry.mode == 0
                  ? DateTime(2026, 10, 1, 9, 30)
                  : DateTime.utc(2026, 10, 1, 16, 30),
            ),
            allDay: const Value(false),
            fixedTimezone: Value(entry.mode != 0),
            timeMode: Value(entry.mode),
            timeZone: Value(entry.zone),
          ),
        );
        final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

        await repository.scheduleTaskToDay(
          'task-1',
          targetDay: DateTime(2026, 10, 13),
        );

        final task = await _taskById(db, 'task-1');
        final display = taskWallClockDateTime(
          task.dueAt!,
          allDay: task.allDay,
          mode: TaskTimeMode.fromWire(task.timeMode),
          timeZone: task.timeZone,
        );
        expect(
          [display.year, display.month, display.day],
          [2026, 10, 13],
          reason: 'timeMode ${entry.mode} 挪日之后，读的那一侧必须落在 10-13',
        );
        expect(
          [display.hour, display.minute],
          [9, 30],
          reason: 'timeMode ${entry.mode}：只换日，钟点留着',
        );
      }
    });

    test('固定时区档挪的是锚点区日历日：这条现状要钉住（跨午日的后果见 FL #587）', () async {
      // 一次性探针实测读数（2026-10-12，设备 Asia/Shanghai）：
      //   stored=2026-10-13 16:30:00.000Z  display=2026-10-14 00:30:00.000
      //   ⇒ 展示日比落点日多一天，任务不会出现在刚拖上去的「今天」里。
      // 这不是本轮造的口径：taskDateTimeForDisplayDay 的注释写明「固定时区的钟点取锚点区
      // （北京 11:00 挪到今天仍是北京 11:00）」，依据是嘀嗒《01-任务/07-固定时间与固定时区.md》:48。
      // 本条只锁「写进去的是锚点日 + 锚点钟点」，A/B 两个修法由 #587 那一轮裁。
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedViewActionList(db);
      await (db.update(
        db.todoTasks,
      )..where((row) => row.id.equals('task-1'))).write(
        TodoTasksCompanion(
          dueAt: Value(DateTime.utc(2026, 10, 1, 16, 30)),
          allDay: const Value(false),
          fixedTimezone: const Value(true),
          timeMode: const Value(1),
          timeZone: const Value('America/Los_Angeles'),
        ),
      );
      final repository = TaskViewActionRepository(db, SyncChangeQueue(db));

      await repository.scheduleTaskToDay(
        'task-1',
        targetDay: DateTime(2026, 10, 13),
      );

      final task = await _taskById(db, 'task-1');
      expect(
        task.dueAt?.toUtc(),
        DateTime.utc(2026, 10, 13, 16, 30),
        reason:
            '锚点区 10-13 09:30（十月是 PDT）——写成设备当地的 10-13 09:30 就是改了另一档语义，'
            '要改也得连 calendarDueAtForDay 与时间线挪动一起改（FL #587）',
      );
      expect(task.timeZone, 'America/Los_Angeles');
      expect(task.allDay, isFalse);
      expect(await db.select(db.todoSyncChanges).get(), hasLength(1));
    });
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

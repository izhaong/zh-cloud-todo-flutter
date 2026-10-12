import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_dispatch_action_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('pull preserves a task fixed timezone', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 15, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-1',
            serverId: const Value(101),
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'changes': [
                    {
                      'entityType': 'task',
                      'entityId': 201,
                      'operation': 'upsert',
                      'payload': {
                        'listId': 101,
                        'title': '跨时区会议',
                        'startAt': '2026-07-15T16:30:00.000Z',
                        'endAt': '2026-07-15T18:00:00.000Z',
                        'dueAt': '2026-07-15T18:00:00.000Z',
                        'allDay': false,
                        'timeZone': 'America/Los_Angeles',
                        'fixedTimezone': true,
                      },
                    },
                  ],
                  'tombstones': const [],
                  'hasMore': false,
                },
              },
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
      todoApi: client,
    );

    expect(await coordinator.pull(), 1);
    final task = await db.taskByServerId(201);
    expect(task?.timeZone, 'America/Los_Angeles');
    expect(task?.fixedTimezone, isTrue);
  });

  test(
    'pull preserves ON_COMPLETE task completion and repeat linkage',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 15, 9);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-1',
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
              id: 'parent-task',
              serverId: const Value(201),
              listId: 'list-1',
              title: '重复模板',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'entityType': 'task',
                        'entityId': 201,
                        'operation': 'upsert',
                        'payload': {
                          'listId': 101,
                          'title': '重复模板',
                          'status': 'DONE',
                          'completedAt': '2026-07-15T09:00:00.000Z',
                        },
                      },
                      {
                        'entityType': 'repeat_rule',
                        'entityId': 301,
                        'operation': 'upsert',
                        'payload': {
                          'taskId': 201,
                          'frequency': 'daily',
                          'intervalValue': 1,
                          'startAt': '2026-07-15T09:00:00.000Z',
                          'enabled': true,
                          'repeatMode': 'ON_COMPLETE',
                        },
                      },
                      {
                        'entityType': 'task',
                        'entityId': 202,
                        'operation': 'upsert',
                        'payload': {
                          'listId': 101,
                          'title': '重复模板',
                          'status': 'TODO',
                          'repeatParentTaskId': 201,
                          'repeatRuleId': 301,
                          'repeatOccurrenceAt': '2026-07-16T09:00:00.000Z',
                        },
                      },
                    ],
                    'tombstones': const [],
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.pull(), 3);
      final parent = await db.taskByServerId(201);
      final generated = await db.taskByServerId(202);
      final pulledRule = await (db.select(
        db.todoRepeatRules,
      )..where((rule) => rule.serverId.equals(301))).getSingle();
      expect(parent?.completed, isTrue);
      expect(parent?.completedAt?.toUtc(), DateTime.utc(2026, 7, 15, 9));
      expect(generated?.repeatParentTaskId, 'parent-task');
      expect(generated?.repeatRuleId, pulledRule.id);
      expect(
        generated?.repeatOccurrenceAt?.toUtc(),
        DateTime.utc(2026, 7, 16, 9),
      );
    },
  );

  test('pull preserves normalized selected-date repeat rules', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 7, 13, 9, 30);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            serverId: const Value(201),
            listId: 'list-1',
            title: '自选日期模板',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'changes': [
                    {
                      'entityType': 'repeat_rule',
                      'entityId': 301,
                      'operation': 'upsert',
                      'payload': {
                        'taskId': 201,
                        'frequency': 'custom',
                        'intervalValue': 1,
                        'startAt': '2026-07-13T09:30:00',
                        'repeatMode': 'ON_SELECTED_DATES',
                        'selectedDates': [
                          '2026-07-20',
                          '2026-07-15',
                          '2026-07-20',
                        ],
                        'timeZone': 'Asia/Shanghai',
                      },
                    },
                  ],
                  'tombstones': const [],
                  'hasMore': false,
                },
              },
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
      todoApi: client,
    );

    expect(await coordinator.pull(), 1);
    final rule = await db.select(db.todoRepeatRules).getSingle();
    expect(rule.repeatMode, 'ON_SELECTED_DATES');
    expect(rule.byDay, isNull);
    expect(rule.selectedDatesJson, '["2026-07-15","2026-07-20"]');
  });

  test('pushes completion with the ON_COMPLETE service contract', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 15, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-1',
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
            id: 'task-1',
            serverId: const Value(201),
            listId: 'list-1',
            title: '完成后生成下一次',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await TaskRepository(db, SyncChangeQueue(db)).toggleComplete('task-1');

    Map<String, dynamic>? sentTask;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final changes = ((options.data as Map)['changes'] as List)
              .cast<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList();
          sentTask = changes.single;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'ok': true,
                  'accepted': [
                    {
                      'entityType': 'task',
                      'entityId': 201,
                      'operation': 'upsert',
                      'clientMutationId': sentTask!['clientMutationId'],
                    },
                  ],
                  'conflicts': const [],
                },
              },
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
      todoApi: client,
    );

    expect(await coordinator.push(), 1);
    final payload = sentTask!['payload'] as Map<String, dynamic>;
    expect(sentTask!['entityType'], 'task');
    expect(payload['status'], 'DONE');
    expect(payload['completedAt'], isA<int>());
  });

  test('pushes a repeat skip with the same temporary rule ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 7, 15, 9);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'task-1',
            serverId: const Value(101),
            listId: 'list-1',
            title: '模板任务',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));
    final rule = await repeats.save(
      taskId: 'task-1',
      frequency: 'CUSTOM',
      weekdays: const [1, 3, 5],
      startAt: now,
    );
    await repeats.skip(
      repeatRuleId: rule.id,
      taskId: 'task-1',
      occurrenceAt: now.add(const Duration(days: 2)),
    );

    List<Map<String, dynamic>> sentChanges = const [];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          sentChanges = ((options.data as Map)['changes'] as List)
              .cast<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList();
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'code': 0,
                'data': {
                  'ok': true,
                  'accepted': [
                    for (final change in sentChanges)
                      {
                        'entityType': change['entityType'],
                        'entityId': change['entityType'] == 'repeat_rule'
                            ? 701
                            : 702,
                        'operation': change['operation'],
                        'clientMutationId': change['clientMutationId'],
                      },
                  ],
                  'conflicts': const [],
                },
              },
            ),
          );
        },
      ),
    );
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
      todoApi: client,
    );

    expect(await coordinator.push(), 2);
    final ruleChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'repeat_rule',
    );
    final skipChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'repeat_skip',
    );
    expect(ruleChange['entityId'], isNegative);
    expect(skipChange['payload']?['repeatRuleId'], ruleChange['entityId']);
    expect((await db.select(db.todoRepeatRules).getSingle()).serverId, 701);
    expect((await db.select(db.todoRepeatSkips).getSingle()).serverId, 702);
  });

  test(
    'retries task reminder selected dates and skip with stable dependencies',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 15, 9);
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-1',
              serverId: const Value(101),
              name: '收集箱',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final queue = SyncChangeQueue(db);
      final task = await TaskRepository(
        db,
        queue,
      ).create(listId: 'list-1', title: '离线时间语义任务');
      await ReminderRepository(db, queue).create(taskId: task.id, fireAt: now);
      final repeats = RepeatRuleRepository(db, queue);
      final rule = await repeats.save(
        taskId: task.id,
        frequency: 'CUSTOM',
        startAt: now,
        repeatMode: 'ON_SELECTED_DATES',
        selectedDates: [
          DateTime.utc(2026, 7, 20),
          DateTime.utc(2026, 7, 18),
          DateTime.utc(2026, 7, 20),
        ],
      );
      await repeats.skip(
        repeatRuleId: rule.id,
        taskId: task.id,
        occurrenceAt: DateTime.utc(2026, 7, 18, 9),
      );

      var requests = 0;
      List<Map<String, dynamic>> sentChanges = const [];
      final sentBatches = <List<Map<String, dynamic>>>[];
      final sentBatchKeys = <String?>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            final changes = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .map((entry) => entry.cast<String, dynamic>())
                .toList();
            sentBatches.add(changes);
            sentBatchKeys.add(
              (options.data as Map)['idempotency_key'] as String?,
            );
            if (requests == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            sentChanges = changes;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': [
                      for (final change in sentChanges)
                        {
                          'entityType': change['entityType'],
                          'entityId': switch (change['entityType']) {
                            'task' => 201,
                            'reminder' => 301,
                            'repeat_rule' => 401,
                            'repeat_skip' => 501,
                            _ => throw StateError(
                              'Unexpected entity ${change['entityType']}',
                            ),
                          },
                          'operation': change['operation'],
                          'clientMutationId': change['clientMutationId'],
                        },
                    ],
                    'conflicts': const [],
                  },
                },
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.push(), 0);
      expect(requests, 1);
      final retryableChanges = await db.select(db.todoSyncChanges).get();
      expect(retryableChanges.map((change) => change.status).toSet(), {
        'retryable',
      });
      expect(retryableChanges.map((change) => change.attemptCount).toSet(), {
        1,
      });
      await db
          .update(db.todoSyncChanges)
          .write(
            TodoSyncChangesCompanion(
              nextAttemptAt: Value(
                DateTime.now().subtract(const Duration(seconds: 1)),
              ),
            ),
          );

      expect(await coordinator.push(), 4);
      expect(requests, 2);
      expect(
        sentBatches[1].map((change) => change['clientMutationId']).toList(),
        sentBatches[0].map((change) => change['clientMutationId']).toList(),
      );
      expect(
        sentBatches[1].map((change) => change['entityId']).toList(),
        sentBatches[0].map((change) => change['entityId']).toList(),
      );
      expect(
        sentBatches[1].map((change) => change['payload']).toList(),
        sentBatches[0].map((change) => change['payload']).toList(),
      );
      expect(sentBatchKeys[1], sentBatchKeys[0]);
      final taskChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'task',
      );
      final reminderChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'reminder',
      );
      final ruleChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'repeat_rule',
      );
      final skipChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'repeat_skip',
      );
      expect(taskChange['entityId'], isNegative);
      expect(reminderChange['payload']?['taskId'], taskChange['entityId']);
      expect(ruleChange['payload']?['taskId'], taskChange['entityId']);
      expect(skipChange['payload']?['taskId'], taskChange['entityId']);
      expect(skipChange['payload']?['repeatRuleId'], ruleChange['entityId']);
      expect(ruleChange['payload']?['selectedDates'], [
        '2026-07-18',
        '2026-07-20',
      ]);
      expect(
        sentChanges.indexOf(taskChange),
        lessThan(sentChanges.indexOf(ruleChange)),
      );
      expect(
        sentChanges.indexOf(taskChange),
        lessThan(sentChanges.indexOf(reminderChange)),
      );
      expect(
        sentChanges.indexOf(ruleChange),
        lessThan(sentChanges.indexOf(skipChange)),
      );
      expect((await db.taskByServerId(201))?.id, task.id);
      expect((await db.select(db.todoReminders).getSingle()).serverId, 301);
      expect((await db.select(db.todoRepeatRules).getSingle()).serverId, 401);
      expect((await db.select(db.todoRepeatSkips).getSingle()).serverId, 501);

      expect(await coordinator.push(), 0);
      expect(requests, 2);
      expect(
        (await db.select(db.todoSyncChanges).get())
            .map((change) => change.status)
            .toSet(),
        {'synced'},
      );
    },
  );

  test(
    'pushes a repeat catchup action after resolving task and rule IDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 7, 15, 9);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-1',
              serverId: const Value(101),
              listId: 'list-1',
              title: '模板任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));
      final rule = await repeats.save(
        taskId: 'task-1',
        frequency: 'DAILY',
        startAt: now,
      );
      await (db.update(db.todoRepeatRules)
            ..where((row) => row.id.equals(rule.id)))
          .write(const TodoRepeatRulesCompanion(serverId: Value(701)));
      await (db.update(db.todoSyncChanges)
            ..where((row) => row.entity.equals('repeat_rule')))
          .write(const TodoSyncChangesCompanion(status: Value('synced')));
      await repeats.skip(
        repeatRuleId: rule.id,
        taskId: 'task-1',
        occurrenceAt: now,
      );
      final localSkip = await db.select(db.todoRepeatSkips).getSingle();
      await (db.update(db.todoRepeatSkips)
            ..where((row) => row.id.equals(localSkip.id)))
          .write(const TodoRepeatSkipsCompanion(serverId: Value(702)));
      await (db.update(db.todoSyncChanges)
            ..where((row) => row.entity.equals('repeat_skip')))
          .write(const TodoSyncChangesCompanion(status: Value('synced')));
      await repeats.catchup(
        repeatRuleId: rule.id,
        taskId: 'task-1',
        occurrenceAt: now,
      );

      List<Map<String, dynamic>> sentChanges = const [];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentChanges = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .map((entry) => entry.cast<String, dynamic>())
                .toList();
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': [
                      for (final change in sentChanges)
                        {
                          'entityType': change['entityType'],
                          'entityId': 800,
                          'operation': change['operation'],
                          'clientMutationId': change['clientMutationId'],
                        },
                    ],
                    'conflicts': const [],
                  },
                },
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.push(), 1);
      final catchupChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'repeat_occurrence_action',
      );
      expect(catchupChange['payload']?['taskId'], 101);
      expect(catchupChange['payload']?['repeatRuleId'], 701);
      expect(catchupChange['payload']?['action'], 'CATCHUP');
    },
  );

  test(
    'pulls repeat rules before their skips when the response is unordered',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 7, 15, 9);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-1',
              serverId: const Value(101),
              listId: 'list-1',
              title: '模板任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': [
                      {
                        'entityType': 'repeat_skip',
                        'entityId': 702,
                        'operation': 'upsert',
                        'payload': {
                          'taskId': 101,
                          'repeatRuleId': 701,
                          'occurrenceAt': now
                              .add(const Duration(days: 2))
                              .toIso8601String(),
                        },
                      },
                      {
                        'entityType': 'repeat_rule',
                        'entityId': 701,
                        'operation': 'upsert',
                        'payload': {
                          'taskId': 101,
                          'frequency': 'custom',
                          'intervalValue': 1,
                          'weekdays': '1,3,5',
                          'startAt': now.toIso8601String(),
                        },
                      },
                    ],
                    'tombstones': const [],
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.pull(), 2);
      expect(await db.select(db.todoRepeatRules).get(), hasLength(1));
      expect(await db.select(db.todoRepeatSkips).get(), hasLength(1));
    },
  );

  test(
    'retries a transient reminder dispatch action with its original mutation',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final actions = ReminderDispatchActionRepository(SyncChangeQueue(db));
      await actions.snooze(reminderDispatchId: 400, minutes: 10);

      var pushes = 0;
      final sentMutationIds = <String?>[];
      final sentBatchKeys = <String?>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            pushes++;
            final changes = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .map((entry) => entry.cast<String, dynamic>())
                .toList();
            final mutationId = changes.single['clientMutationId'] as String?;
            sentMutationIds.add(mutationId);
            sentBatchKeys.add(
              (options.data as Map)['idempotency_key'] as String?,
            );
            if (pushes == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': [
                      {
                        'entityType': 'reminder_dispatch_action',
                        'entityId': 400,
                        'operation': 'upsert',
                        'clientMutationId': mutationId,
                      },
                    ],
                    'conflicts': const [],
                  },
                },
              ),
            );
          },
        ),
      );
      final client = ApiClient(dio: dio);
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'test', deviceId: 'device-1'),
        todoApi: client,
      );

      expect(await coordinator.push(), 0);
      var change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.status, 'retryable');
      expect(change.attemptCount, 1);

      expect(await coordinator.push(), 0);
      await db
          .update(db.todoSyncChanges)
          .write(
            TodoSyncChangesCompanion(
              nextAttemptAt: Value(
                DateTime.now().subtract(const Duration(seconds: 1)),
              ),
            ),
          );
      expect(await coordinator.push(), 1);
      change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.status, 'synced');
      expect(pushes, 2);
      expect(sentMutationIds, hasLength(2));
      expect(sentMutationIds[1], sentMutationIds[0]);
      expect(sentBatchKeys, hasLength(2));
      expect(sentBatchKeys[1], sentBatchKeys[0]);
    },
  );
}

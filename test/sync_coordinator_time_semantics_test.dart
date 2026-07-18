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
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';

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

      expect(await coordinator.push(), 1);
      change = await db.select(db.todoSyncChanges).getSingle();
      expect(change.status, 'synced');
      expect(pushes, 2);
      expect(sentMutationIds, hasLength(2));
      expect(sentMutationIds[1], sentMutationIds[0]);
    },
  );
}

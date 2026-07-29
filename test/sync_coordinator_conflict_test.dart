import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/reminder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/repeat_rule_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'revision conflict restores server task, revision, and marks only its outbox change failed',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 18, 14);
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
              title: '本地旧标题',
              priority: const Value(1),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db.writeRevision('task', 201, 7);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      await repository.update('task-local', title: '离线编辑标题');

      final pushedBatches = <List<Map<String, dynamic>>>[];
      var pushCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>();
              pushedBatches.add(changes);
              pushCount++;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': pushCount == 2,
                      'accepted': pushCount == 2
                          ? [
                              {
                                'clientMutationId':
                                    changes.single['clientMutationId'],
                                'entityType': 'task',
                                'entityId': 201,
                                'operation': 'upsert',
                                'revision': 9,
                              },
                            ]
                          : const <Map<String, dynamic>>[],
                      'conflicts': pushCount == 1
                          ? [
                              {
                                'clientMutationId':
                                    changes.single['clientMutationId'],
                                'entityType': 'task',
                                'entityId': 201,
                                'reason': 'REVISION_CONFLICT',
                                'serverRevision': 8,
                                'serverValue': {
                                  'listId': 101,
                                  'title': '服务端最新标题',
                                  'status': 'TODO',
                                  'priority': 3,
                                  'allDay': false,
                                  'fixedTimezone': true,
                                  'timeZone': 'Asia/Shanghai',
                                },
                              },
                            ]
                          : const <Map<String, dynamic>>[],
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
        api: SyncApi(client, clientId: 'test-client', deviceId: 'device-a'),
        todoApi: client,
      );

      expect(await coordinator.push(), 0);
      expect(pushedBatches, hasLength(1));
      expect(pushedBatches.single.single['entityType'], 'task');
      expect(pushedBatches.single.single['entityId'], 201);
      expect(pushedBatches.single.single['baseRevision'], 7);

      final restored = await db.taskByServerId(201);
      expect(restored?.id, 'task-local');
      expect(restored?.title, '服务端最新标题');
      expect(restored?.priority, 3);
      expect(restored?.timeZone, 'Asia/Shanghai');
      expect(restored?.fixedTimezone, isTrue);
      expect(
        await db.readRevision('task', 201),
        8,
        reason: '下一次本地编辑必须以冲突响应中的服务端版本为 baseRevision，避免重复冲突',
      );

      final conflicted = await (db.select(
        db.todoSyncChanges,
      )..where((change) => change.status.equals('failed'))).getSingle();
      expect(
        conflicted.clientMutationId,
        pushedBatches.single.single['clientMutationId'],
      );

      await repository.update('task-local', title: '采用服务端版本后的再次编辑');
      expect(await coordinator.push(), 1);
      expect(pushedBatches, hasLength(2));
      expect(pushedBatches.last.single['baseRevision'], 8);
      expect(await db.readRevision('task', 201), 9);
      final retried = await (db.select(
        db.todoSyncChanges,
      )..where((change) => change.status.equals('synced'))).getSingle();
      expect(
        retried.clientMutationId,
        pushedBatches.last.single['clientMutationId'],
      );
      expect(conflicted.status, 'failed');
    },
  );

  test(
    'reminder and repeat conflicts restore server values before new edits replay',
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
              title: '冲突恢复任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoReminders)
          .insert(
            TodoRemindersCompanion.insert(
              id: 'reminder-local',
              serverId: const Value(301),
              taskId: 'task-local',
              remindAt: now,
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoRepeatRules)
          .insert(
            TodoRepeatRulesCompanion.insert(
              id: 'repeat-local',
              serverId: const Value(401),
              taskId: 'task-local',
              freq: 'DAILY',
              startAt: Value(now),
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db.writeRevision('reminder', 301, 7);
      await db.writeRevision('repeat_rule', 401, 11);

      final reminders = ReminderRepository(db, SyncChangeQueue(db));
      final repeats = RepeatRuleRepository(db, SyncChangeQueue(db));
      await reminders.update(
        id: 'reminder-local',
        fireAt: now.add(const Duration(minutes: 10)),
        anchorType: 'ABSOLUTE',
        persistent: true,
        intervalMinutes: 10,
        fixedTimezone: false,
      );
      await repeats.save(
        taskId: 'task-local',
        frequency: 'DAILY',
        startAt: now,
        countLimit: 2,
      );

      final pushedBatches = <List<Map<String, dynamic>>>[];
      var pushCount = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>();
              pushedBatches.add(changes);
              pushCount++;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': pushCount == 2,
                      'accepted': pushCount == 2
                          ? [
                              for (final change in changes)
                                {
                                  'clientMutationId':
                                      change['clientMutationId'],
                                  'entityType': change['entityType'],
                                  'entityId': change['entityType'] == 'reminder'
                                      ? 301
                                      : 401,
                                  'operation': 'upsert',
                                  'revision': change['entityType'] == 'reminder'
                                      ? 9
                                      : 13,
                                },
                            ]
                          : const <Map<String, dynamic>>[],
                      'conflicts': pushCount == 1
                          ? [
                              for (final change in changes)
                                {
                                  'clientMutationId':
                                      change['clientMutationId'],
                                  'entityType': change['entityType'],
                                  'entityId': change['entityType'] == 'reminder'
                                      ? 301
                                      : 401,
                                  'reason': 'REVISION_CONFLICT',
                                  'serverRevision':
                                      change['entityType'] == 'reminder'
                                      ? 8
                                      : 12,
                                  'serverValue':
                                      change['entityType'] == 'reminder'
                                      ? {
                                          'taskId': 201,
                                          'fireAt': now
                                              .add(const Duration(hours: 1))
                                              .toIso8601String(),
                                          'anchorType': 'ON_DUE',
                                          'offsetMinutes': -15,
                                          'status': 'PENDING',
                                          'persistent': true,
                                          'intervalMinutes': 30,
                                          'timeZone': 'Asia/Shanghai',
                                          'fixedTimezone': true,
                                        }
                                      : {
                                          'taskId': 201,
                                          'frequency': 'WEEKLY',
                                          'intervalValue': 2,
                                          'weekdays': '1,3',
                                          'startAt': now.toIso8601String(),
                                          'untilAt': now
                                              .add(const Duration(days: 30))
                                              .toIso8601String(),
                                          'countLimit': 4,
                                          'enabled': true,
                                          'repeatMode': 'ON_DUE',
                                          'timeZone': 'Asia/Shanghai',
                                        },
                                },
                            ]
                          : const <Map<String, dynamic>>[],
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
        api: SyncApi(client, clientId: 'test-client', deviceId: 'device-b'),
        todoApi: client,
      );

      expect(await coordinator.push(), 0);
      final restoredReminder = await (db.select(
        db.todoReminders,
      )..where((row) => row.serverId.equals(301))).getSingle();
      final restoredRepeat = await (db.select(
        db.todoRepeatRules,
      )..where((row) => row.serverId.equals(401))).getSingle();
      expect(restoredReminder.id, 'reminder-local');
      expect(restoredReminder.anchorType, 'ON_DUE');
      expect(restoredReminder.intervalMinutes, 30);
      expect(restoredReminder.fixedTimezone, isTrue);
      expect(restoredRepeat.id, 'repeat-local');
      expect(restoredRepeat.freq, 'WEEKLY');
      expect(restoredRepeat.interval, 2);
      expect(restoredRepeat.byDay, '1,3');
      expect(restoredRepeat.countLimit, 4);
      expect(await db.readRevision('reminder', 301), 8);
      expect(await db.readRevision('repeat_rule', 401), 12);
      expect(
        await (db.select(
          db.todoSyncChanges,
        )..where((change) => change.status.equals('failed'))).get(),
        hasLength(2),
      );

      await reminders.update(
        id: 'reminder-local',
        fireAt: now.add(const Duration(hours: 2)),
        anchorType: 'ON_DUE',
        offsetMinutes: -30,
        persistent: true,
        intervalMinutes: 30,
        timeZone: 'Asia/Shanghai',
        fixedTimezone: true,
      );
      await repeats.save(
        taskId: 'task-local',
        frequency: 'WEEKLY',
        intervalValue: 2,
        weekdays: const [1, 3],
        startAt: now,
        untilAt: now.add(const Duration(days: 30)),
        countLimit: 3,
        timeZone: 'Asia/Shanghai',
      );

      expect(await coordinator.push(), 2);
      expect(pushedBatches, hasLength(2));
      final replayBaseRevisions = {
        for (final change in pushedBatches.last)
          change['entityType']: change['baseRevision'],
      };
      expect(replayBaseRevisions['reminder'], 8);
      expect(replayBaseRevisions['repeat_rule'], 12);
      expect(await db.readRevision('reminder', 301), 9);
      expect(await db.readRevision('repeat_rule', 401), 13);
    },
  );
}

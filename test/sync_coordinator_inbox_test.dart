import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test(
    'offline inbox task pushes its inbox list before the task in one batch',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TaskRepository(db, SyncChangeQueue(db));
      await repository.create(listId: 'inbox', title: '同步收集箱任务');

      List<Map<String, dynamic>>? pushedChanges;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>();
              pushedChanges = changes;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        for (final change in changes)
                          {
                            'entityType': change['entityType'],
                            'entityId': change['entityType'] == 'list'
                                ? 10
                                : 11,
                            'operation': 'upsert',
                            'clientMutationId': change['clientMutationId'],
                          },
                      ],
                      'conflicts': <Map<String, dynamic>>[],
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
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.push();

      expect(pushedChanges, isNotNull);
      expect(pushedChanges!.map((change) => change['entityType']), [
        'list',
        'task',
      ]);
      expect(
        pushedChanges![1]['payload']['listId'],
        pushedChanges![0]['entityId'],
      );
      final inbox = await db.listByLocalId('inbox');
      expect(inbox?.serverId, 10);
    },
  );

  test(
    'legacy failed inbox task is recovered with an inbox list change',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 13);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'legacy-inbox-task',
              listId: 'inbox',
              title: '恢复旧收集箱任务',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoSyncChanges)
          .insert(
            TodoSyncChangesCompanion.insert(
              clientMutationId: 'legacy-inbox-mutation',
              entity: 'task',
              op: 'upsert',
              entityLocalId: const Value('legacy-inbox-task'),
              payloadJson:
                  '{"id":"legacy-inbox-task","listId":"inbox","title":"恢复旧收集箱任务"}',
              status: const Value('failed'),
              createdAt: now,
            ),
          );

      List<Map<String, dynamic>>? pushedChanges;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map<String, dynamic>>();
              pushedChanges = changes;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        for (final change in changes)
                          {
                            'entityType': change['entityType'],
                            'entityId': change['entityType'] == 'list'
                                ? 10
                                : 11,
                            'operation': 'upsert',
                            'clientMutationId': change['clientMutationId'],
                          },
                      ],
                      'conflicts': <Map<String, dynamic>>[],
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
        api: SyncApi(client, clientId: 'test-client', deviceId: 'test-device'),
        todoApi: client,
      );

      await coordinator.push();

      expect(pushedChanges!.map((change) => change['entityType']), [
        'list',
        'task',
      ]);
      expect(
        pushedChanges![1]['payload']['listId'],
        pushedChanges![0]['entityId'],
      );
      final changes = await db.select(db.todoSyncChanges).get();
      expect(changes.every((change) => change.status == 'synced'), isTrue);
    },
  );

  test('moving an existing task to inbox creates the collection list first', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 13);
    await db
        .into(db.todoTasks)
        .insert(
          TodoTasksCompanion.insert(
            id: 'existing-task',
            listId: 'ordinary-list',
            title: '移动到收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final repository = TaskRepository(db, SyncChangeQueue(db));

    await repository.update('existing-task', listId: 'inbox');

    final changes = await (db.select(db.todoSyncChanges)
          ..orderBy([(change) => OrderingTerm(expression: change.id)]))
        .get();
    expect(changes.map((change) => change.entity), ['list', 'task']);
    expect(await db.listByLocalId('inbox'), isNotNull);
  });
}

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
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
}

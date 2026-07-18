import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';

void main() {
  test(
    'pull orders a task before its server-authoritative activity without outgoing activity changes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final server = _ActivityPullServer();
      final client = server.client();
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'activity-test', deviceId: 'device-b'),
        todoApi: client,
      );
      final watchEvent =
          (db.select(db.todoActivities)
                ..where((row) => row.taskServerId.equals(101)))
              .watch()
              .firstWhere((records) => records.length == 1);

      expect(await coordinator.pull(), 2);
      final activities = await watchEvent.timeout(const Duration(seconds: 1));

      expect(activities.single.serverId, 900);
      expect(activities.single.taskServerId, 101);
      expect(activities.single.action, 'task_updated');
      expect(activities.single.actorUserName, 'Alice');

      expect(await coordinator.pull(), 2);
      expect(await db.select(db.todoActivities).get(), hasLength(1));
      expect(SyncEntities.syncable, isNot(contains('activity')));
      expect(await coordinator.push(), 0);
      expect(server.pushes, isZero);
    },
  );
}

class _ActivityPullServer {
  var pushes = 0;

  ApiClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/sync/pull')) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    // Deliberately put the dependent activity first: Flutter
                    // must order the task before applying the read-only cache.
                    'changes': [
                      {
                        'entityType': 'activity',
                        'entityId': 900,
                        'operation': 'upsert',
                        'revision': 2,
                        'payload': {
                          'taskId': 101,
                          'action': 'task_updated',
                          'actorUserName': 'Alice',
                          'occurredAt': '2026-07-16T09:30:00Z',
                        },
                      },
                      {
                        'entityType': SyncEntities.task,
                        'entityId': 101,
                        'operation': 'upsert',
                        'revision': 1,
                        'payload': {'title': '服务端任务', 'status': 'TODO'},
                      },
                    ],
                    'tombstones': const <Map<String, dynamic>>[],
                    'nextCursor': 'activity-1',
                    'hasMore': false,
                  },
                },
              ),
            );
            return;
          }
          if (options.path.endsWith('/sync/push')) {
            pushes++;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': const <Map<String, dynamic>>[],
                    'conflicts': const <Map<String, dynamic>>[],
                  },
                },
              ),
            );
            return;
          }
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'unexpected request: ${options.path}',
            ),
          );
        },
      ),
    );
    return ApiClient(dio: dio);
  }
}

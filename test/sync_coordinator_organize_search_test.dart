import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

void main() {
  test(
    'push resolves task-tag task and tag dependencies to server IDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 16, 9);
      await db
          .into(db.todoTasks)
          .insert(
            TodoTasksCompanion.insert(
              id: 'task-local',
              serverId: const Value(101),
              listId: 'inbox',
              title: '整理项目标签',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await db
          .into(db.todoTags)
          .insert(
            TodoTagsCompanion.insert(
              id: 'tag-local',
              serverId: const Value(201),
              name: '项目',
              updatedAt: now,
              createdAt: now,
            ),
          );
      await TagRepository(
        db,
        SyncChangeQueue(db),
      ).setTaskTags('task-local', ['tag-local']);

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
                          'entityId': change['entityId'],
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
      final change = sentChanges.single;
      expect(change['entityType'], 'task_tag');
      expect(change['payload']?['taskId'], 101);
      expect(change['payload']?['tagIds'], [201]);
    },
  );
}

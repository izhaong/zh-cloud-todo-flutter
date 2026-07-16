import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

void main() {
  test('看板完成列出站映射为服务端 done 状态', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 16, 9);
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
            title: '完成看板任务',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await TaskViewActionRepository(
      db,
      SyncChangeQueue(db),
    ).moveKanbanTask('task-local', priority: 3, completed: true);

    List<Map<String, dynamic>> sentChanges = const [];
    final dio = Dio()
      ..interceptors.add(
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
    expect(change['entityType'], 'task');
    expect(change['payload']?['priority'], 3);
    expect(change['payload']?['status'], 'done');
  });
}

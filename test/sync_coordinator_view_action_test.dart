import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/board_preference_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
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

  test('拉取看板偏好会映射服务端清单并落入本地表', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = Dio()
      ..interceptors.add(
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
                        'entityType': 'list',
                        'entityId': 101,
                        'operation': 'upsert',
                        'revision': 1,
                        'payload': {'name': '项目', 'sortOrder': 0},
                      },
                      {
                        'entityType': 'board_preference',
                        'entityId': 401,
                        'operation': 'upsert',
                        'revision': 2,
                        'payload': {
                          'listId': 101,
                          'groupDimension': 'CUSTOM',
                          'columnsJson': '["TODO","DONE"]',
                        },
                      },
                    ],
                    'tombstones': const [],
                    'nextCursor': '2',
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
    final list = await db.listByServerId(101);
    final preference = await db.select(db.todoBoardPreferences).getSingle();
    expect(preference.serverId, 401);
    expect(preference.listId, list!.id);
    expect(preference.groupDimension, 'CUSTOM');
    expect(preference.columnsJson, '["TODO","DONE"]');
  });

  test('新建清单与看板偏好共批上推时复用清单临时 ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    final list = await ListRepository(db, queue).create(name: '离线项目');
    await BoardPreferenceRepository(
      db,
      queue,
    ).save(listId: list.id, groupDimension: 'PRIORITY');

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
                          'entityId': change['entityType'] == 'list'
                              ? 101
                              : 401,
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
    final listChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'list',
    );
    final preferenceChange = sentChanges.singleWhere(
      (change) => change['entityType'] == 'board_preference',
    );
    expect(listChange['entityId'], isNegative);
    expect(preferenceChange['payload']?['listId'], listChange['entityId']);

    expect((await (_listById(db, list.id))).serverId, 101);
    expect(
      (await db.select(db.todoBoardPreferences).getSingle()).serverId,
      401,
    );
    await BoardPreferenceRepository(
      db,
      queue,
    ).save(listId: list.id, groupDimension: 'CUSTOM');
    final secondMutation = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.status.equals('queued'))).getSingle();
    expect(secondMutation.payloadJson, contains('"listId":101'));
  });

  test('看板偏好冲突以服务端值覆盖本地并保留失败 outbox', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 16, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoBoardPreferences)
        .insert(
          TodoBoardPreferencesCompanion.insert(
            id: 'preference-local',
            serverId: const Value(401),
            listId: 'list-local',
            groupDimension: 'LOCAL',
            columnsJson: const Value('["LOCAL"]'),
            updatedAt: now,
            createdAt: now,
          ),
        );
    final queue = SyncChangeQueue(db);
    await queue.enqueue(
      entity: 'board_preference',
      op: 'upsert',
      localId: 'preference-local',
      serverId: 401,
      payload: {
        'listId': 101,
        'groupDimension': 'LOCAL',
        'columnsJson': '["LOCAL"]',
      },
    );

    var pushCount = 0;
    List<Map<String, dynamic>> resentChanges = const [];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final change =
                ((options.data as Map)['changes'] as List).single as Map;
            pushCount++;
            if (pushCount > 1) {
              resentChanges = [change.cast<String, dynamic>()];
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': 'board_preference',
                          'entityId': 401,
                          'operation': 'upsert',
                          'clientMutationId': change['clientMutationId'],
                        },
                      ],
                      'conflicts': const [],
                    },
                  },
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
                    'accepted': const [],
                    'conflicts': [
                      {
                        'entityType': 'board_preference',
                        'entityId': 401,
                        'operation': 'upsert',
                        'clientMutationId': change['clientMutationId'],
                        'serverRevision': 7,
                        'serverValue': {
                          'listId': 101,
                          'groupDimension': 'SERVER',
                          'columnsJson': '["TODO","DONE"]',
                        },
                      },
                    ],
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
    final preference = await db.select(db.todoBoardPreferences).getSingle();
    final mutation = await db.select(db.todoSyncChanges).getSingle();
    expect(preference.groupDimension, 'SERVER');
    expect(preference.columnsJson, '["TODO","DONE"]');
    expect(mutation.status, 'failed');
    expect(await db.readRevision('board_preference', 401), 7);

    await BoardPreferenceRepository(
      db,
      queue,
    ).save(listId: 'list-local', groupDimension: 'RETRY');
    expect(await coordinator.push(), 1);
    expect(resentChanges.single['baseRevision'], 7);
  });
}

Future<TodoList> _listById(AppDatabase db, String id) {
  return (db.select(
    db.todoLists,
  )..where((row) => row.id.equals(id))).getSingle();
}

import 'dart:convert';

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
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

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

  test('pushes child reparent before deleting its former parent tag', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tags = TagRepository(db, SyncChangeQueue(db));
    final parent = await tags.create(name: '项目');
    final child = await tags.create(name: '客户端', parentId: parent.id);
    await (db.update(db.todoTags)..where((tag) => tag.id.equals(parent.id)))
        .write(const TodoTagsCompanion(serverId: Value(101)));
    await (db.update(db.todoTags)..where((tag) => tag.id.equals(child.id)))
        .write(const TodoTagsCompanion(serverId: Value(102)));
    await (db.update(
      db.todoSyncChanges,
    )).write(const TodoSyncChangesCompanion(status: Value('synced')));
    await tags.delete(parent.id);

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

    expect(await coordinator.push(), 2);
    expect(sentChanges, hasLength(2));
    expect(sentChanges[0]['entityType'], 'tag');
    expect(sentChanges[0]['operation'], 'upsert');
    expect(sentChanges[0]['entityId'], 102);
    expect(sentChanges[0]['payload']['parentId'], isNull);
    expect(sentChanges[1]['entityType'], 'tag');
    expect(sentChanges[1]['operation'], 'delete');
    expect(sentChanges[1]['entityId'], 101);
  });

  test(
    'sort preference pushes from A and B restores it from the sync feed',
    () async {
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final sortPreferencesA = TaskSortPreferenceRepository(
        dbA,
        SyncChangeQueue(dbA),
      );
      await sortPreferencesA.save('list-a', TaskSort.dueDate);

      Map<String, dynamic>? pushedChange;
      final dioA = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map>()
                  .map((entry) => entry.cast<String, dynamic>())
                  .toList();
              pushedChange = changes.single;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': 'view_preference',
                          'entityId': 88,
                          'operation': 'upsert',
                          'clientMutationId': pushedChange!['clientMutationId'],
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
      final clientA = ApiClient(dio: dioA);
      final coordinatorA = SyncCoordinator(
        db: dbA,
        api: SyncApi(clientA, clientId: 'device-a', deviceId: 'device-a'),
        todoApi: clientA,
      );

      expect(await coordinatorA.push(), 1);
      expect(pushedChange!['entityType'], 'view_preference');
      expect(pushedChange!['payload'], {
        'sourceType': 'TASK_SORT',
        'sourceKey': 'list-a',
        'viewType': 'LIST',
        'valueJson': jsonEncode({'sort': 'dueDate'}),
      });
      final preferenceA = await dbA.select(dbA.todoViewPreferences).getSingle();
      expect(preferenceA.serverId, 88);
      await dbA.close();

      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(dbB.close);
      final dioB = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final isFolderList = options.path.endsWith('/folder/list');
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: isFolderList
                      ? {'code': 0, 'data': const []}
                      : {
                          'code': 0,
                          'data': {
                            'changes': [
                              {
                                'entityType': 'view_preference',
                                'entityId': 88,
                                'operation': 'upsert',
                                'revision': 1,
                                'payload': pushedChange!['payload'],
                              },
                            ],
                            'tombstones': const [],
                            'nextCursor': 'view-preference-88',
                            'hasMore': false,
                          },
                        },
                ),
              );
            },
          ),
        );
      final clientB = ApiClient(dio: dioB);
      final coordinatorB = SyncCoordinator(
        db: dbB,
        api: SyncApi(clientB, clientId: 'device-b', deviceId: 'device-b'),
        todoApi: clientB,
      );

      expect(await coordinatorB.pull(), 1);
      expect(
        await TaskSortPreferenceRepository(
          dbB,
          SyncChangeQueue(dbB),
        ).get('list-a'),
        TaskSort.dueDate,
      );
      final preferenceB = await dbB.select(dbB.todoViewPreferences).getSingle();
      expect(preferenceB.serverId, 88);
    },
  );

  test('pull restores a child tag with its local parent UUID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final isFolderList = options.path.endsWith('/folder/list');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: isFolderList
                    ? {'code': 0, 'data': const []}
                    : {
                        'code': 0,
                        'data': {
                          'changes': [
                            {
                              'entityType': 'tag',
                              'entityId': 12,
                              'operation': 'upsert',
                              'revision': 1,
                              'payload': {'name': '客户端', 'parentId': 11},
                            },
                            {
                              'entityType': 'tag',
                              'entityId': 11,
                              'operation': 'upsert',
                              'revision': 1,
                              'payload': {'name': '项目', 'parentId': null},
                            },
                          ],
                          'tombstones': const [],
                          'nextCursor': 'nested-tags',
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
      api: SyncApi(client, clientId: 'device-b', deviceId: 'device-b'),
      todoApi: client,
    );

    expect(await coordinator.pull(), 2);
    final tags = await db.select(db.todoTags).get();
    final parent = tags.singleWhere((tag) => tag.serverId == 11);
    final child = tags.singleWhere((tag) => tag.serverId == 12);
    expect(child.parentId, parent.id);
  });

  test('push resolves a child tag parent UUID to its server ID', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 19);
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'parent-local',
            serverId: const Value(101),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: 'child-local',
            parentId: const Value('parent-local'),
            name: '客户端',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await SyncChangeQueue(db).enqueue(
      entity: 'tag',
      op: 'upsert',
      localId: 'child-local',
      payload: {'name': '客户端', 'parentId': 'parent-local'},
    );

    Map<String, dynamic>? pushedChange;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            pushedChange = ((options.data as Map)['changes'] as List)
                .cast<Map>()
                .single
                .cast<String, dynamic>();
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'ok': true,
                    'accepted': [
                      {
                        'entityType': 'tag',
                        'entityId': 102,
                        'operation': 'upsert',
                        'clientMutationId': pushedChange!['clientMutationId'],
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
      api: SyncApi(client, clientId: 'device-a', deviceId: 'device-a'),
      todoApi: client,
    );

    expect(await coordinator.push(), 1);
    expect(pushedChange!['payload']['parentId'], 101);
  });
}

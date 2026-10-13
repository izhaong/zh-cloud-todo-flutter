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
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
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

  test(
    'same batch task-tag reuses unsynced task and tag temporary IDs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final list = await ListRepository(db, queue).create(name: '项目');
      final task = await TaskRepository(
        db,
        queue,
      ).create(listId: list.id, title: '整理项目标签');
      final tag = await TagRepository(db, queue).create(name: '工作');
      await TagRepository(db, queue).setTaskTags(task.id, [tag.id]);

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
                Response<Map<String, dynamic>>(
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
                              'list' => 101,
                              'tag' => 201,
                              'task' => 301,
                              _ => 401,
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
        api: SyncApi(client, clientId: 'device-a', deviceId: 'device-a'),
        todoApi: client,
      );

      expect(await coordinator.push(), 4);
      final taskChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'task',
      );
      final tagChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'tag',
      );
      final taskTagChange = sentChanges.singleWhere(
        (change) => change['entityType'] == 'task_tag',
      );
      expect(taskTagChange['payload']['taskId'], taskChange['entityId']);
      expect(taskTagChange['payload']['tagIds'], [tagChange['entityId']]);
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
      // FL #619：两端各自的清单本地 id 是 uuid，同一条服务端清单在 A 叫 list-a、
      // 在 B 叫 list-b-on-b。旧断言把两端的 sourceKey 写成同一个字符串，
      // 于是"每清单排序跨端"这件事它其实测不到（键从来对不上）。
      final seededAt = DateTime.utc(2026, 7, 30, 9);
      await dbA
          .into(dbA.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-a',
              serverId: const Value(7),
              name: '项目',
              updatedAt: seededAt,
              createdAt: seededAt,
            ),
          );
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
        'sourceKey': 'list-server:7',
        'viewType': 'LIST',
        // 上行形状：本轮多带一个 direction 键。B 端是从这同一条 feed 恢复的，
        // 所以这条断言同时也是"方向会跟着同步到另一台设备"的判据。
        'valueJson': jsonEncode({
          'sort': 'dueDate',
          'direction': 'newestFirst',
        }),
      });
      final preferenceA = await dbA.select(dbA.todoViewPreferences).getSingle();
      expect(preferenceA.serverId, 88);
      await dbA.close();

      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(dbB.close);
      await dbB
          .into(dbB.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-b-on-b',
              serverId: const Value(7),
              name: '项目',
              updatedAt: seededAt,
              createdAt: seededAt,
            ),
          );
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
      // B 端从同一条 feed 恢复：档位与**方向**都要跟着过来，
      // 否则第二台设备会静默退回降序。
      final restoredB = await TaskSortPreferenceRepository(
        dbB,
        SyncChangeQueue(dbB),
      ).get('list-b-on-b');
      expect(restoredB.sort, TaskSort.dueDate);
      expect(restoredB.direction, TaskSortDirection.newestFirst);
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

  test('pull preserves task assignee for offline filtering', () async {
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
                              'entityType': 'list',
                              'entityId': 11,
                              'operation': 'upsert',
                              'revision': 1,
                              'payload': {'name': '协作清单'},
                            },
                            {
                              'entityType': 'task',
                              'entityId': 21,
                              'operation': 'upsert',
                              'revision': 1,
                              'payload': {
                                'listId': 11,
                                'title': '负责人筛选任务',
                                'status': 'TODO',
                                'assigneeUserId': 101,
                                'assigneeUserName': '小周',
                              },
                            },
                          ],
                          'tombstones': const [],
                          'nextCursor': 'assignee-task',
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
    final task = await db.select(db.todoTasks).getSingle();
    expect(task.assigneeUserId, 101);
    expect(task.assigneeUserName, '小周');
    final filtered = await TaskQueryRepository(
      db,
    ).filter(const TaskQueryFilter(assigneeUserId: 101));
    expect(filtered.map((item) => item.id), [task.id]);
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

  test(
    'pushes an unsynced parent folder before a child queued first',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 30, 9);
      await db.batch((batch) {
        batch.insert(
          db.todoFolders,
          TodoFoldersCompanion.insert(
            id: 'parent-local',
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          db.todoFolders,
          TodoFoldersCompanion.insert(
            id: 'child-local',
            parentId: const Value('parent-local'),
            name: '客户端',
            updatedAt: now,
            createdAt: now,
          ),
        );
      });
      final queue = SyncChangeQueue(db);
      final child = await (db.select(
        db.todoFolders,
      )..where((row) => row.id.equals('child-local'))).getSingle();
      final parent = await (db.select(
        db.todoFolders,
      )..where((row) => row.id.equals('parent-local'))).getSingle();
      await queue.enqueue(
        entity: 'folder',
        op: 'upsert',
        localId: child.id,
        payload: child.toJson(),
      );
      await queue.enqueue(
        entity: 'folder',
        op: 'upsert',
        localId: parent.id,
        payload: parent.toJson(),
      );

      final createdPayloads = <Map<String, dynamic>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final payload = Map<String, dynamic>.from(options.data as Map);
              createdPayloads.add(payload);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': payload['name'] == '项目' ? 101 : 102,
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

      expect(await coordinator.push(), 2);
      expect(createdPayloads, [
        {'name': '项目', 'parentId': null},
        {'name': '客户端', 'parentId': 101},
      ]);
      expect(
        (await db.select(db.todoSyncChanges).get())
            .map((change) => change.status)
            .toSet(),
        {'synced'},
      );
    },
  );

  test(
    'same push creates an offline folder before its associated list',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      final folder = await FolderRepository(db, queue).create('离线项目');
      final list = await ListRepository(
        db,
        queue,
      ).create(name: '离线清单', folderLocalId: folder.id);

      Map<String, dynamic>? pushedList;
      final requestOrder = <String>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/folder/create')) {
                requestOrder.add('folder');
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': 88},
                  ),
                );
                return;
              }
              requestOrder.add('sync');
              final changes = ((options.data as Map)['changes'] as List)
                  .cast<Map>()
                  .map((entry) => entry.cast<String, dynamic>())
                  .toList();
              pushedList = changes.singleWhere(
                (change) => change['entityType'] == 'list',
              );
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'ok': true,
                      'accepted': [
                        {
                          'entityType': 'list',
                          'entityId': 101,
                          'operation': 'upsert',
                          'clientMutationId': pushedList!['clientMutationId'],
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

      expect(await coordinator.push(), 2);
      expect(requestOrder, ['folder', 'sync']);
      expect(pushedList!['payload']['folderId'], 88);
      expect(pushedList!['payload'], isNot(contains('folderLocalId')));
      final syncedList = await db.listByLocalId(list.id);
      expect(syncedList?.folderLocalId, folder.id);
      expect(syncedList?.folderId, 88);
      expect(syncedList?.serverId, 101);
    },
  );
}

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

void main() {
  test(
    'pull hydrates REST-only folders into an empty Drift database',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/folder/list')) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {
                      'code': 0,
                      'data': [
                        {
                          'id': 72,
                          'parentId': 71,
                          'name': 'B3 子文件夹',
                          'sortOrder': 5,
                        },
                        {'id': 71, 'name': 'B3 恢复文件夹', 'sortOrder': 4},
                      ],
                    },
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'changes': [
                        {
                          'changeId': 1,
                          'entityType': 'list',
                          'entityId': 101,
                          'operation': 'upsert',
                          'revision': 1,
                          'tombstone': false,
                          'payload': {
                            'id': 101,
                            'name': '子项目清单',
                            'folderId': 72,
                            'sortOrder': 0,
                          },
                        },
                      ],
                      'tombstones': [],
                      'nextCursor': 'todo-core:1',
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
        api: SyncApi(client, clientId: 'folder-pull', deviceId: 'folder-pull'),
        todoApi: client,
      );

      await coordinator.pull();

      final folders = await db.select(db.todoFolders).get();
      expect(folders, hasLength(2));
      final parent = folders.singleWhere((folder) => folder.serverId == 71);
      final child = folders.singleWhere((folder) => folder.serverId == 72);
      expect(parent.name, 'B3 恢复文件夹');
      expect(parent.sortOrder, 4);
      expect(child.parentId, parent.id);
      final list = await db.listByServerId(101);
      expect(list?.folderId, 72);
      expect(list?.folderLocalId, child.id);
    },
  );

  test(
    'pull removes a synced folder no longer returned by REST list',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.todoFolders)
          .insert(
            TodoFoldersCompanion.insert(
              id: 'deleted-on-server',
              serverId: const Value(72),
              name: '已删除文件夹',
              updatedAt: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
      final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/folder/list')) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': []},
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'changes': [],
                      'tombstones': [],
                      'nextCursor': 'todo-core:0',
                      'hasMore': false,
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = ApiClient(dio: dio);
      await SyncCoordinator(
        db: db,
        api: SyncApi(
          client,
          clientId: 'folder-delete',
          deviceId: 'folder-delete',
        ),
        todoApi: client,
      ).pull();

      expect(await db.select(db.todoFolders).get(), isEmpty);
    },
  );

  test(
    'pull clears a list folder when the sync payload explicitly contains null',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: 'list-in-folder',
              serverId: const Value(101),
              name: '待办',
              folderLocalId: const Value('folder-local'),
              folderId: const Value(88),
              updatedAt: now,
              createdAt: now,
            ),
          );
      final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/folder/list')) {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {'code': 0, 'data': []},
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'data': {
                      'changes': [
                        {
                          'changeId': 1,
                          'entityType': 'list',
                          'entityId': 101,
                          'operation': 'upsert',
                          'revision': 2,
                          'tombstone': false,
                          'payload': {
                            'id': 101,
                            'name': '待办',
                            'folderId': null,
                            'sortOrder': 0,
                          },
                        },
                      ],
                      'tombstones': [],
                      'nextCursor': 'todo-core:1',
                      'hasMore': false,
                    },
                  },
                ),
              );
            },
          ),
        );
      final client = ApiClient(dio: dio);
      await SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'list-clear', deviceId: 'list-clear'),
        todoApi: client,
      ).pull();

      final list = await db.listByServerId(101);
      expect(list?.folderId, isNull);
      expect(list?.folderLocalId, isNull);
    },
  );
}

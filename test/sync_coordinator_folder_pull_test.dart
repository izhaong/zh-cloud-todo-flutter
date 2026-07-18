import 'package:dio/dio.dart';
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
      final coordinator = SyncCoordinator(
        db: db,
        api: SyncApi(client, clientId: 'folder-pull', deviceId: 'folder-pull'),
        todoApi: client,
      );

      await coordinator.pull();

      final folders = await db.select(db.todoFolders).get();
      expect(folders, hasLength(1));
      expect(folders.single.serverId, 71);
      expect(folders.single.name, 'B3 恢复文件夹');
      expect(folders.single.sortOrder, 4);
    },
  );
}

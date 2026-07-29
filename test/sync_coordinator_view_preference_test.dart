import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

void main() {
  test(
    'pull keeps malformed legacy view preferences distinct by server ID',
    () async {
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
                                'entityType': 'view_preference',
                                'entityId': 7,
                                'operation': 'upsert',
                                'revision': 1,
                                'payload': {'id': 7},
                              },
                              {
                                'entityType': 'view_preference',
                                'entityId': 8,
                                'operation': 'upsert',
                                'revision': 2,
                                'payload': {'id': 8},
                              },
                            ],
                            'tombstones': const [],
                            'nextCursor': 'legacy-view-preferences',
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
      final preferences = await db.select(db.todoViewPreferences).get();
      expect(preferences.map((row) => row.serverId).toSet(), {7, 8});
      expect(preferences.map((row) => row.sourceType).toSet(), {
        'LEGACY_SERVER',
      });
      expect(preferences.map((row) => row.sourceKey).toSet(), {'7', '8'});
    },
  );
}

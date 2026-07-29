import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B3_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test(
    'B3 live A/B restores an offline folder move after a file-database restart',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final sessionA = await _login();
      final sessionB = await _login();
      final directory = await Directory.systemTemp.createTemp('todo-b3-folder-');
      final databaseFile = File('${directory.path}/todo.sqlite');
      var dbA = AppDatabase.forTesting(NativeDatabase(databaseFile));
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      int? folderServerId;
      int? listServerId;
      try {
        final queue = SyncChangeQueue(dbA);
        final folder = await FolderRepository(
          dbA,
          queue,
        ).create('B3 restart folder $suffix');
        final lists = ListRepository(dbA, queue);
        final list = await lists.create(name: 'B3 restart list $suffix');
        await _coordinator(dbA, apiA, 'b3-restart-a-$suffix').push();
        expect(await _pendingOrFailedCount(dbA), 0);
        folderServerId =
            await (dbA.select(dbA.todoFolders)
                  ..where((row) => row.id.equals(folder.id)))
                .getSingle()
                .then((row) => row.serverId);
        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        final folderId = folderServerId;
        final listId = listServerId;
        expect(folderId, isPositive);
        expect(listId, isPositive);
        if (folderId == null || listId == null) {
          fail('folder/list push did not return server IDs');
        }

        await FolderApi(
          apiA,
        ).moveLists(listServerIds: [listId], folderServerId: folderId);
        await _coordinator(dbA, apiA, 'b3-restart-a-$suffix').pull();
        await ListRepository(dbA, SyncChangeQueue(dbA)).moveToFolder(
          list.id,
          null,
        );
        expect(await _pendingOrFailedCount(dbA), 1);

        await dbA.close();
        dbA = AppDatabase.forTesting(NativeDatabase(databaseFile));
        final restarted = await dbA.listByLocalId(list.id);
        expect(restarted?.folderId, isNull);
        expect(await _pendingOrFailedCount(dbA), 1);

        await _coordinator(dbA, apiA, 'b3-restart-a-$suffix').push();
        expect(await _pendingOrFailedCount(dbA), 0);
        await _coordinator(dbB, apiB, 'b3-restart-b-$suffix').pull();
        final restoredB = await (dbB.select(
          dbB.todoLists,
        )..where((row) => row.serverId.equals(listId))).getSingleOrNull();
        expect(restoredB?.folderId, isNull);
      } finally {
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId);
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/folder/delete',
          folderServerId,
        );
        await dbA.close();
        await dbB.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !_enabled,
  );
}

Future<TodoAuthSession> _login() => AuthGatewayImpl(
  _client(''),
  tenantId: _tenantId,
).passwordLogin(mobile: _mobile, password: _password);

ApiClient _client(String token) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: _baseUrl)),
  tokenProvider: () => token,
  tenantIdProvider: () => _tenantId,
);

SyncCoordinator _coordinator(
  AppDatabase db,
  ApiClient client,
  String deviceId,
) => SyncCoordinator(
  db: db,
  api: SyncApi(client, clientId: deviceId, deviceId: deviceId),
  todoApi: client,
);

Future<int> _pendingOrFailedCount(AppDatabase db) async {
  final changes = await db.select(db.todoSyncChanges).get();
  return changes
      .where((change) => change.status == 'queued' || change.status == 'failed')
      .length;
}

Future<void> _deleteIfPresent(ApiClient api, String path, int? id) async {
  if (id == null) return;
  try {
    await api.raw.delete<void>(path, queryParameters: {'id': id});
  } on DioException catch (error) {
    if (error.response?.statusCode != 404) rethrow;
  }
}

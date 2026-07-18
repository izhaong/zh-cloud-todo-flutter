import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/auth/auth_gateway.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/folder_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B3_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test('B3 live A/B restores REST-only folder into clean Drift', () async {
    expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
    expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final sessionA = await _login();
    final sessionB = await _login();
    final dbA = AppDatabase.forTesting(NativeDatabase.memory());
    final dbB = AppDatabase.forTesting(NativeDatabase.memory());
    final apiA = _client(sessionA.accessToken);
    final apiB = _client(sessionB.accessToken);
    await _deletePriorB3Folders(apiA);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    int? folderServerId;
    var deletedOnServer = false;
    try {
      final folder = await FolderRepository(
        dbA,
        SyncChangeQueue(dbA),
      ).create('B3 folder $suffix');
      await _coordinator(dbA, apiA, 'b3-folder-a-$suffix').push();
      expect(await _pendingOrFailedCount(dbA), 0);
      folderServerId =
          await (dbA.select(dbA.todoFolders)
                ..where((row) => row.id.equals(folder.id)))
              .getSingle()
              .then((row) => row.serverId);
      final serverId = folderServerId;
      expect(serverId, isPositive);
      if (serverId == null) fail('folder push did not return a server ID');

      final listed = await apiA.get<Map<String, dynamic>>('/folder/list');
      final serverFolders = listed.data?['data'] as List? ?? const [];
      expect(
        serverFolders.whereType<Map>().map(
          (folder) => (folder['id'] as num?)?.toInt(),
        ),
        contains(serverId),
        reason: 'REST folder/list must expose the just-created folder',
      );

      await _coordinator(dbB, apiB, 'b3-folder-b-$suffix').pull();
      final restored = await (dbB.select(
        dbB.todoFolders,
      )..where((row) => row.serverId.equals(serverId))).getSingleOrNull();
      if (restored == null) {
        fail('clean Drift must contain folder $serverId after pull');
      }
      expect(restored.name, 'B3 folder $suffix');

      await FolderRepository(
        dbA,
        SyncChangeQueue(dbA),
      ).rename(folder.id, 'B3 folder renamed $suffix');
      await _coordinator(dbA, apiA, 'b3-folder-a-$suffix').push();
      expect(await _pendingOrFailedCount(dbA), 0);
      await _coordinator(dbB, apiB, 'b3-folder-b-$suffix').pull();
      final renamed = await (dbB.select(
        dbB.todoFolders,
      )..where((row) => row.serverId.equals(serverId))).getSingleOrNull();
      expect(renamed?.name, 'B3 folder renamed $suffix');

      await FolderRepository(dbA, SyncChangeQueue(dbA)).delete(folder.id);
      await _coordinator(dbA, apiA, 'b3-folder-a-$suffix').push();
      expect(await _pendingOrFailedCount(dbA), 0);
      deletedOnServer = true;
      await _coordinator(dbB, apiB, 'b3-folder-b-$suffix').pull();
      expect(
        await (dbB.select(
          dbB.todoFolders,
        )..where((row) => row.serverId.equals(serverId))).getSingleOrNull(),
        isNull,
      );
    } finally {
      if (folderServerId != null && !deletedOnServer) {
        try {
          final response = await apiA.raw.delete<Map<String, dynamic>>(
            '/app-api/todo/folder/delete',
            queryParameters: {'id': folderServerId},
          );
          expect(response.data?['code'], 0);
        } on DioException catch (error) {
          if (error.response?.statusCode != 404) rethrow;
        }
      }
      await dbA.close();
      await dbB.close();
    }
  }, skip: !_enabled);
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

Future<void> _deletePriorB3Folders(ApiClient api) async {
  final response = await api.get<Map<String, dynamic>>('/folder/list');
  final folders = response.data?['data'] as List? ?? const [];
  for (final folder in folders.whereType<Map>()) {
    final id = (folder['id'] as num?)?.toInt();
    final name = folder['name']?.toString() ?? '';
    if (id == null || !name.startsWith('B3 folder ')) continue;
    final deleted = await api.raw.delete<Map<String, dynamic>>(
      '/app-api/todo/folder/delete',
      queryParameters: {'id': id},
    );
    expect(deleted.data?['code'], 0, reason: 'must delete prior B3 folder $id');
  }
}

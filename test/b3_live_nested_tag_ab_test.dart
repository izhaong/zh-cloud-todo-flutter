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
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

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
    'B3 live A/B restores a nested tag through push and clean Drift pull',
    () async {
      expect(_mobile, isNotEmpty);
      expect(_password, isNotEmpty);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      int? parentServerId;
      int? childServerId;
      try {
        final tags = TagRepository(dbA, SyncChangeQueue(dbA));
        final parent = await tags.create(name: 'B3 parent tag $suffix');
        final child = await tags.create(
          name: 'B3 child tag $suffix',
          parentId: parent.id,
        );
        await _coordinator(dbA, apiA, 'b3-tag-a-$suffix').push();
        parentServerId = await _serverId(dbA, parent.id);
        childServerId = await _serverId(dbA, child.id);
        expect(parentServerId, isPositive);
        expect(childServerId, isPositive);

        await _coordinator(dbB, apiB, 'b3-tag-b-$suffix').pull();
        final parentB = await _tagByServerId(dbB, parentServerId!);
        final childB = await _tagByServerId(dbB, childServerId!);
        expect(childB.parentId, parentB.id);
      } finally {
        await _delete(apiA, childServerId);
        await _delete(apiA, parentServerId);
        await dbA.close();
        await dbB.close();
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

Future<int?> _serverId(AppDatabase db, String id) => (db.select(
  db.todoTags,
)..where((tag) => tag.id.equals(id))).getSingle().then((tag) => tag.serverId);

Future<TodoTag> _tagByServerId(AppDatabase db, int id) => (db.select(
  db.todoTags,
)..where((tag) => tag.serverId.equals(id))).getSingle();

Future<void> _delete(ApiClient client, int? id) async {
  if (id == null) return;
  try {
    await client.raw.delete<Map<String, dynamic>>(
      '/app-api/todo/tag/delete?id=$id',
    );
  } on DioException catch (error) {
    if (error.response?.statusCode != 404) rethrow;
  }
}

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
    'B3 live A/B reparents a child before deleting its former parent tag',
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
      int? childServerId;
      try {
        final tagsA = TagRepository(dbA, SyncChangeQueue(dbA));
        final parentA = await tagsA.create(name: 'B3 delete parent $suffix');
        final childA = await tagsA.create(
          name: 'B3 delete child $suffix',
          parentId: parentA.id,
        );
        final coordinatorA = _coordinator(dbA, apiA, 'b3-tag-delete-a-$suffix');
        final coordinatorB = _coordinator(dbB, apiB, 'b3-tag-delete-b-$suffix');
        await coordinatorA.push();
        final parentServerId = await _serverId(dbA, parentA.id);
        childServerId = await _serverId(dbA, childA.id);
        expect(parentServerId, isPositive);
        expect(childServerId, isPositive);

        await coordinatorB.pull();
        expect(await _tagByServerId(dbB, parentServerId!), isNotNull);
        final childBeforeDelete = await _tagByServerId(dbB, childServerId!);
        expect(childBeforeDelete, isNotNull);
        expect(childBeforeDelete!.parentId, isNotNull);

        await tagsA.delete(parentA.id);
        await coordinatorA.push();
        await coordinatorB.pull();

        expect(await _tagByServerId(dbB, parentServerId), isNull);
        final childAfterDelete = await _tagByServerId(dbB, childServerId);
        expect(childAfterDelete, isNotNull);
        expect(childAfterDelete!.parentId, isNull);
      } finally {
        await _delete(apiA, childServerId);
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

Future<TodoTag?> _tagByServerId(AppDatabase db, int id) => (db.select(
  db.todoTags,
)..where((tag) => tag.serverId.equals(id))).getSingleOrNull();

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

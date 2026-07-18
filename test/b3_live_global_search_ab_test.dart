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
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

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
    'B3 live A/B: pushed aggregate is searchable through Service and a clean Drift pull',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final keyword = 'B3检索$suffix';
      int? listServerId;
      int? taskServerId;
      int? tagServerId;

      try {
        final queueA = SyncChangeQueue(dbA);
        final list = await ListRepository(
          dbA,
          queueA,
        ).create(name: '$keyword 清单');
        final tag = await TagRepository(
          dbA,
          queueA,
        ).create(name: '$keyword 标签');
        final task = await TaskRepository(dbA, queueA).create(
          listId: list.id,
          title: '$keyword 任务',
          description: 'B3 A/B Drift searchable fixture',
        );
        final coordinatorA = _coordinator(dbA, apiA, 'b3-search-a-$suffix');
        await coordinatorA.push();
        expect(await _pendingOrFailedCount(dbA), 0);

        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        taskServerId =
            await (dbA.select(dbA.todoTasks)
                  ..where((row) => row.id.equals(task.id)))
                .getSingle()
                .then((row) => row.serverId);
        tagServerId =
            await (dbA.select(dbA.todoTags)
                  ..where((row) => row.id.equals(tag.id)))
                .getSingle()
                .then((row) => row.serverId);
        expect(listServerId, isPositive);
        expect(taskServerId, isPositive);
        expect(tagServerId, isPositive);

        final remote = await TodoRestApi(
          apiA,
        ).globalSearch.search(keyword: keyword, pageSize: 20);
        expect(remote.items.map((item) => item.type), ['task', 'list', 'tag']);
        expect(remote.items.map((item) => item.id), [
          taskServerId,
          listServerId,
          tagServerId,
        ]);

        final coordinatorB = _coordinator(dbB, apiB, 'b3-search-b-$suffix');
        await coordinatorB.pull();
        final local = await TaskQueryRepository(dbB).search(keyword);
        expect(local.map((item) => item.type), ['task', 'list', 'tag']);
        expect(local.map((item) => item.title), [
          '$keyword 任务',
          '$keyword 清单',
          '$keyword 标签',
        ]);
      } finally {
        await _deleteIfPresent(apiA, '/app-api/todo/task/delete', taskServerId);
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId);
        await _deleteIfPresent(apiA, '/app-api/todo/tag/delete', tagServerId);
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

Future<int> _pendingOrFailedCount(AppDatabase db) async {
  final changes = await db.select(db.todoSyncChanges).get();
  return changes
      .where((change) => change.status == 'queued' || change.status == 'failed')
      .length;
}

Future<void> _deleteIfPresent(
  ApiClient client,
  String path,
  int? serverId,
) async {
  if (serverId == null) return;
  try {
    await client.raw.delete<Map<String, dynamic>>('$path?id=$serverId');
  } on DioException catch (error) {
    if (error.response?.statusCode != 404) rethrow;
  }
}

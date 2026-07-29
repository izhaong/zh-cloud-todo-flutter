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
    'B3 live A/B applies an idempotent server batch update then pulls it into clean Drift',
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
      int? listServerId;
      int? firstTaskServerId;
      int? secondTaskServerId;

      try {
        final queue = SyncChangeQueue(dbA);
        final list = await ListRepository(
          dbA,
          queue,
        ).create(name: 'B3 batch $suffix');
        final tasks = TaskRepository(dbA, queue);
        final first = await tasks.create(
          listId: list.id,
          title: 'B3 batch first $suffix',
        );
        final second = await tasks.create(
          listId: list.id,
          title: 'B3 batch second $suffix',
        );
        await _coordinator(dbA, apiA, 'b3-batch-a-$suffix').push();
        expect(await _pendingOrFailedCount(dbA), 0);

        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        firstTaskServerId = await _taskServerId(dbA, first.id);
        secondTaskServerId = await _taskServerId(dbA, second.id);
        expect(listServerId, isPositive);
        expect(firstTaskServerId, isPositive);
        expect(secondTaskServerId, isPositive);

        final request = TodoTaskBatchUpdateRequest(
          taskIds: [firstTaskServerId!, secondTaskServerId!],
          priority: 3,
          isPinned: true,
          deviceId: 'b3-batch-a-$suffix',
          clientMutationId: 'b3-batch-mutation-$suffix',
        );
        final firstResult = await TodoRestApi(apiA).taskBatch.update(request);
        final retryResult = await TodoRestApi(apiA).taskBatch.update(request);
        expect(firstResult.map((item) => item.status), ['success', 'success']);
        expect(retryResult.map((item) => item.status), ['success', 'success']);

        await _coordinator(dbB, apiB, 'b3-batch-b-$suffix').pull();
        final firstB = await _taskByServerId(dbB, firstTaskServerId);
        final secondB = await _taskByServerId(dbB, secondTaskServerId);
        expect(firstB.priority, 3);
        expect(secondB.priority, 3);
        expect(firstB.isPinned, isTrue);
        expect(secondB.isPinned, isTrue);
      } finally {
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/task/delete',
          secondTaskServerId,
        );
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/task/delete',
          firstTaskServerId,
        );
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId);
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

Future<int?> _taskServerId(AppDatabase db, String taskId) async =>
    (await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals(taskId))).getSingle()).serverId;

Future<TodoTask> _taskByServerId(AppDatabase db, int serverId) => (db.select(
  db.todoTasks,
)..where((row) => row.serverId.equals(serverId))).getSingle();

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

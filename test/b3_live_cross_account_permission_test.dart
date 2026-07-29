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
const _primaryMobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _secondaryMobile = String.fromEnvironment('TODO_B3_SECONDARY_MOBILE');
const _smsCode = String.fromEnvironment(
  'TODO_B3_TEST_SMS_CODE',
  defaultValue: '9999',
);

void main() {
  test(
    'B3 live cross-account search and batch update never expose or mutate another users task',
    () async {
      expect(_primaryMobile, isNotEmpty);
      expect(_secondaryMobile, isNotEmpty);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final primaryAuth = AuthGatewayImpl(_client(''), tenantId: _tenantId);
      final sessionA = await _smsLogin(primaryAuth, _primaryMobile);
      final secondaryAuth = AuthGatewayImpl(_client(''), tenantId: _tenantId);
      final sessionB = await _smsLogin(secondaryAuth, _secondaryMobile);
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final keyword = 'B3跨账户$suffix';
      int? listServerId;
      int? taskServerId;

      try {
        final queue = SyncChangeQueue(dbA);
        final list = await ListRepository(
          dbA,
          queue,
        ).create(name: '$keyword 清单');
        final task = await TaskRepository(
          dbA,
          queue,
        ).create(listId: list.id, title: '$keyword 任务');
        final coordinator = _coordinator(dbA, apiA, 'b3-owner-a-$suffix');
        expect(await coordinator.push(), 2);
        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        taskServerId =
            await (dbA.select(dbA.todoTasks)
                  ..where((row) => row.id.equals(task.id)))
                .getSingle()
                .then((row) => row.serverId);
        expect(listServerId, isPositive);
        expect(taskServerId, isPositive);

        final hidden = await TodoRestApi(
          apiB,
        ).globalSearch.search(keyword: keyword, pageSize: 20);
        expect(hidden.items, isEmpty);

        final denied = await TodoRestApi(apiB).taskBatch.update(
          TodoTaskBatchUpdateRequest(
            taskIds: [taskServerId!],
            priority: 3,
            deviceId: 'b3-other-user-$suffix',
            clientMutationId: 'b3-other-user-mutation-$suffix',
          ),
        );
        expect(denied, hasLength(1));
        expect(denied.single.taskId, taskServerId);
        expect(denied.single.status, 'failed');
        expect(denied.single.errorCode, isNotEmpty);

        await coordinator.pull();
        final ownerTask = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.serverId.equals(taskServerId!))).getSingle();
        expect(ownerTask.priority, 0);
      } finally {
        await _deleteIfPresent(apiA, '/app-api/todo/task/delete', taskServerId);
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId);
        await dbA.close();
      }
    },
    skip: !_enabled,
  );
}

Future<TodoAuthSession> _smsLogin(
  AuthGatewayImpl gateway,
  String mobile,
) async {
  await gateway.sendSmsCode(mobile: mobile, scene: 1);
  return gateway.smsLogin(mobile: mobile, code: _smsCode);
}

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

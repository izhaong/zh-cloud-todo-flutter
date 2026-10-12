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
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_query_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_sort_preference_repository.dart';

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
    'B3 live A/B restores a task sort preference through clean Drift pull',
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
      final listKey = 'b3-sort-$suffix';
      final coordinatorA = _coordinator(dbA, apiA, 'b3-sort-a-$suffix');
      final coordinatorB = _coordinator(dbB, apiB, 'b3-sort-b-$suffix');
      final queueA = SyncChangeQueue(dbA);
      int? serverId;
      String? localId;
      try {
        final preferencesA = TaskSortPreferenceRepository(dbA, queueA);
        await preferencesA.save(listKey, TaskSort.dueDate);
        localId = (await _sortPreference(dbA, listKey)).id;

        expect(await coordinatorA.push(), 1);
        serverId = (await _sortPreference(dbA, listKey)).serverId;
        expect(serverId, isPositive);

        await coordinatorB.pull();
        final preferencesB = TaskSortPreferenceRepository(
          dbB,
          SyncChangeQueue(dbB),
        );
        expect((await preferencesB.get(listKey)).sort, TaskSort.dueDate);
        expect((await _sortPreference(dbB, listKey)).serverId, serverId);
      } finally {
        if (serverId != null && localId != null) {
          await queueA.enqueue(
            entity: SyncEntities.viewPreference,
            op: SyncOps.delete,
            localId: localId,
            serverId: serverId,
            payload: {'id': serverId},
          );
          await coordinatorA.push();
        }
        await dbA.close();
        await dbB.close();
      }
    },
    skip: !_enabled,
  );
}

Future<TodoViewPreference> _sortPreference(AppDatabase db, String listKey) {
  final query = db.select(db.todoViewPreferences)
    ..where((row) => row.sourceType.equals('TASK_SORT'))
    ..where((row) => row.sourceKey.equals(listKey));
  return query.getSingle();
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

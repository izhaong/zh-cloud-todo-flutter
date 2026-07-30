import 'dart:convert';

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
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';
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
    'B3 live A/B applies synced filter remotely and restores it in clean Drift',
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
      final keyword = 'B3组合过滤$suffix';
      final coordinatorA = _coordinator(dbA, apiA, 'b3-filter-a-$suffix');
      final coordinatorB = _coordinator(dbB, apiB, 'b3-filter-b-$suffix');
      final queueA = SyncChangeQueue(dbA);
      int? listServerId;
      int? firstTaskServerId;
      int? secondTaskServerId;
      int? excludedTaskServerId;
      int? filterServerId;
      String? filterLocalId;

      try {
        final list = await ListRepository(
          dbA,
          queueA,
        ).create(name: '$keyword 清单');
        final first = await TaskRepository(
          dbA,
          queueA,
        ).create(listId: list.id, title: '$keyword A', priority: 3);
        final second = await TaskRepository(
          dbA,
          queueA,
        ).create(listId: list.id, title: '$keyword Z', priority: 3);
        final excluded = await TaskRepository(
          dbA,
          queueA,
        ).create(listId: list.id, title: '$keyword 低优先级', priority: 1);
        expect(await coordinatorA.push(), 4);

        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        firstTaskServerId = await _taskServerId(dbA, first.id);
        secondTaskServerId = await _taskServerId(dbA, second.id);
        excludedTaskServerId = await _taskServerId(dbA, excluded.id);
        expect(listServerId, isPositive);
        expect(firstTaskServerId, isPositive);
        expect(secondTaskServerId, isPositive);

        const sortOrdersJson = '[{"field":"title","direction":"ASC"}]';
        final filter = await FilterRepository(dbA, queueA).save(
          name: '$keyword 高优先级',
          conditions: TodoFilterConditions(
            listIds: [list.id],
            priorities: const [3],
            keyword: keyword,
          ),
          sortOrders: const [
            TodoFilterSortOrder(field: 'title', direction: 'ASC'),
          ],
        );
        filterLocalId = filter.id;
        expect(await coordinatorA.push(), 1);
        filterServerId = await _filterServerId(dbA, filterLocalId);
        expect(filterServerId, isPositive);

        final remote = await TodoRestApi(
          apiA,
        ).filter.apply(filterId: filterServerId!, pageSize: 20);
        expect(remote.total, 2);
        expect(remote.items.map((item) => item.id), [
          firstTaskServerId,
          secondTaskServerId,
        ]);
        expect(remote.items.map((item) => item.title), [
          '$keyword A',
          '$keyword Z',
        ]);

        await coordinatorB.pull();
        final restored = await (dbB.select(
          dbB.todoFilters,
        )..where((row) => row.serverId.equals(filterServerId!))).getSingle();
        final restoredList = await dbB.listByServerId(listServerId!);
        expect(restored.name, '$keyword 高优先级');
        expect(jsonDecode(restored.conditionJson), {
          'listIds': [restoredList!.id],
          'priorities': [3],
          'keyword': keyword,
        });
        expect(restored.sortOrdersJson, sortOrdersJson);
      } finally {
        if (filterServerId != null && filterLocalId != null) {
          await queueA.enqueue(
            entity: SyncEntities.filter,
            op: SyncOps.delete,
            localId: filterLocalId,
            serverId: filterServerId,
            payload: {'id': filterServerId},
          );
          await coordinatorA.push();
        }
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/task/delete',
          firstTaskServerId,
        );
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/task/delete',
          secondTaskServerId,
        );
        await _deleteIfPresent(
          apiA,
          '/app-api/todo/task/delete',
          excludedTaskServerId,
        );
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId);
        await dbA.close();
        await dbB.close();
      }
    },
    skip: !_enabled,
  );
}

Future<int?> _taskServerId(AppDatabase db, String localId) =>
    (db.select(db.todoTasks)..where((row) => row.id.equals(localId)))
        .getSingle()
        .then((row) => row.serverId);

Future<int?> _filterServerId(AppDatabase db, String? localId) {
  if (localId == null) return Future.value(null);
  return (db.select(db.todoFilters)..where((row) => row.id.equals(localId)))
      .getSingle()
      .then((row) => row.serverId);
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

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
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B4_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test(
    'B4 live A/B restores list kanban timeline and scoped view mutations',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final coordinatorA = _coordinator(dbA, apiA, 'b4-view-a-$suffix');
      final coordinatorB = _coordinator(dbB, apiB, 'b4-view-b-$suffix');
      final queueA = SyncChangeQueue(dbA);
      int? listServerId;
      int? firstTaskServerId;
      int? secondTaskServerId;
      String? preferenceLocalId;
      int? preferenceServerId;

      try {
        final list = await ListRepository(
          dbA,
          queueA,
        ).create(name: 'B4 view $suffix');
        final tasks = TaskRepository(dbA, queueA);
        final first = await tasks.create(
          listId: list.id,
          title: 'B4 kanban $suffix',
        );
        final second = await tasks.create(
          listId: list.id,
          title: 'B4 timeline $suffix',
        );
        expect(await coordinatorA.push(), 3);

        listServerId = (await dbA.listByLocalId(list.id))?.serverId;
        firstTaskServerId = await _taskServerId(dbA, first.id);
        secondTaskServerId = await _taskServerId(dbA, second.id);
        expect(listServerId, isPositive);
        expect(firstTaskServerId, isPositive);
        expect(secondTaskServerId, isPositive);

        final actions = TaskViewActionRepository(dbA, queueA);
        await actions.moveKanbanTask(first.id, priority: 3, completed: false);
        expect(await coordinatorA.push(), 1);

        await actions.reorderListTasks([second.id, first.id]);
        expect(await coordinatorA.push(), 2);

        final startAt = DateTime.utc(2026, 8, 3, 9);
        final endAt = DateTime.utc(2026, 8, 3, 10, 30);
        await actions.moveTimelineTask(
          second.id,
          startAt: startAt,
          endAt: endAt,
          dueAt: endAt,
        );
        expect(await coordinatorA.push(), 1);

        final sourceKey = 'list:${list.id}';
        await actions.saveTaskWorkspaceViewMode(
          sourceKey: sourceKey,
          viewType: 'timeline',
        );
        expect(await coordinatorA.push(), 1);
        await actions.saveTaskTimelinePreference(
          sourceKey: sourceKey,
          zoom: 1.25,
          scale: 'month',
          collapsedGroupIds: const {'priority:3'},
        );
        expect(await coordinatorA.push(), 1);

        final preference = await _viewPreference(dbA, sourceKey);
        preferenceLocalId = preference.id;
        preferenceServerId = preference.serverId;
        expect(preferenceServerId, isPositive);
        expect(await coordinatorA.push(), 0);

        await coordinatorB.pull();
        final firstB = await _taskByServerId(dbB, firstTaskServerId!);
        final secondB = await _taskByServerId(dbB, secondTaskServerId!);
        expect(firstB.priority, 3);
        expect(firstB.completed, isFalse);
        expect(firstB.sortOrder, 1);
        expect(secondB.sortOrder, 0);
        expect(secondB.startAt?.toUtc(), startAt);
        expect(secondB.endAt?.toUtc(), endAt);
        expect(secondB.dueAt?.toUtc(), endAt);

        final listB = await dbB.listByServerId(listServerId!);
        expect(listB, isNotNull);
        final restored = await TaskViewActionRepository(
          dbB,
          SyncChangeQueue(dbB),
        ).getTaskWorkspacePreference(sourceKey: 'list:${listB!.id}');
        expect(restored.viewType, 'timeline');
        expect(restored.timelineZoom, 1.25);
        expect(restored.timelineScale, 'month');
        expect(restored.collapsedTimelineGroupIds, {'priority:3'});
      } finally {
        Object? firstCleanupError;
        StackTrace? firstCleanupStack;

        Future<void> attemptCleanup(Future<void> Function() action) async {
          try {
            await action();
          } catch (error, stack) {
            firstCleanupError ??= error;
            firstCleanupStack ??= stack;
          }
        }

        await attemptCleanup(() async {
          if (preferenceLocalId == null || preferenceServerId == null) return;
          await queueA.enqueue(
            entity: SyncEntities.viewPreference,
            op: SyncOps.delete,
            localId: preferenceLocalId,
            serverId: preferenceServerId,
            payload: {'id': preferenceServerId},
          );
          await coordinatorA.push();
        });
        await attemptCleanup(
          () => _deleteIfPresent(
            apiA,
            '/app-api/todo/task/delete',
            secondTaskServerId,
          ),
        );
        await attemptCleanup(
          () => _deleteIfPresent(
            apiA,
            '/app-api/todo/task/delete',
            firstTaskServerId,
          ),
        );
        await attemptCleanup(
          () =>
              _deleteIfPresent(apiA, '/app-api/todo/list/delete', listServerId),
        );
        await attemptCleanup(dbA.close);
        await attemptCleanup(dbB.close);

        if (firstCleanupError != null) {
          Error.throwWithStackTrace(firstCleanupError!, firstCleanupStack!);
        }
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

Future<int?> _taskServerId(AppDatabase db, String taskId) async =>
    (await (db.select(
      db.todoTasks,
    )..where((row) => row.id.equals(taskId))).getSingle()).serverId;

Future<TodoTask> _taskByServerId(AppDatabase db, int serverId) => (db.select(
  db.todoTasks,
)..where((row) => row.serverId.equals(serverId))).getSingle();

Future<TodoViewPreference> _viewPreference(AppDatabase db, String sourceKey) =>
    (db.select(db.todoViewPreferences)
          ..where((row) => row.sourceType.equals('task_view'))
          ..where((row) => row.sourceKey.equals(sourceKey)))
        .getSingle();

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

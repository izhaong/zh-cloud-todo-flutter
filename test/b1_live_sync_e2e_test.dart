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
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

const _enabled = bool.fromEnvironment('TODO_B1_LIVE');
const _baseUrl = String.fromEnvironment(
  'TODO_API_BASE_URL',
  defaultValue: 'https://todo-test.zh04.com',
);
const _tenantId = String.fromEnvironment('TODO_TENANT_ID', defaultValue: '1');
const _mobile = String.fromEnvironment('TODO_B1_E2E_MOBILE');
const _password = String.fromEnvironment('TODO_B1_E2E_PASSWORD');

void main() {
  test(
    'B1 live sync maps a clean Drift aggregate and propagates tombstones',
    () async {
      expect(_mobile, isNotEmpty, reason: 'TODO_B1_E2E_MOBILE is required');
      expect(_password, isNotEmpty, reason: 'TODO_B1_E2E_PASSWORD is required');
      // 两个独立 NativeDatabase.memory 实例刻意模拟两个设备。
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      final sessionA = await _login();
      final sessionB = await _login();
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final apiA = _client(sessionA.accessToken);
      final apiB = _client(sessionB.accessToken);
      final coordinatorA = _coordinator(dbA, apiA, 'b1-live-device-a');
      final coordinatorB = _coordinator(dbB, apiB, 'b1-live-device-b');
      final listsA = ListRepository(dbA, SyncChangeQueue(dbA));
      final tasksA = TaskRepository(dbA, SyncChangeQueue(dbA));
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final list = await listsA.create(name: 'B1 live sync $suffix');
      final task = await tasksA.create(
        listId: list.id,
        title: 'B1 live sync task $suffix',
        description: '## Markdown\n\n来自设备 A 的正文。',
        priority: 2,
      );
      final checklist = await tasksA.createChecklistItem(
        taskId: task.id,
        title: '在设备 B 回显检查事项',
      );

      try {
        await coordinatorA.push();

        final syncedListA = await dbA.listByLocalId(list.id);
        final syncedTaskByLocalId = await (dbA.select(
          dbA.todoTasks,
        )..where((row) => row.id.equals(task.id))).getSingle();
        final syncedChecklistA = await (dbA.select(
          dbA.todoChecklistItems,
        )..where((row) => row.id.equals(checklist.id))).getSingle();
        expect(syncedListA?.serverId, isPositive);
        expect(syncedTaskByLocalId.serverId, isPositive);
        expect(syncedChecklistA.serverId, isPositive);
        expect(await _pendingOrFailedCount(dbA), 0);

        await coordinatorB.pull();

        final taskB = await dbB.taskByServerId(syncedTaskByLocalId.serverId!);
        expect(taskB, isNotNull);
        expect(taskB!.id, isNot(task.id));
        expect(taskB.description, '## Markdown\n\n来自设备 A 的正文。');
        final listB = await dbB.listByServerId(syncedListA!.serverId!);
        expect(listB, isNotNull);
        expect(listB!.id, isNot(list.id));
        final checklistB =
            await (dbB.select(dbB.todoChecklistItems)..where(
                  (row) => row.serverId.equals(syncedChecklistA.serverId!),
                ))
                .getSingle();
        expect(checklistB.taskId, taskB.id);
        expect(checklistB.title, '在设备 B 回显检查事项');

        await tasksA.deleteChecklistItem(checklist.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(
          await (dbB.select(dbB.todoChecklistItems)..where(
                (row) => row.serverId.equals(syncedChecklistA.serverId!),
              ))
              .getSingleOrNull(),
          isNull,
        );

        await tasksA.delete(task.id);
        await coordinatorA.push();
        await coordinatorB.pull();
        expect(await dbB.taskByServerId(syncedTaskByLocalId.serverId!), isNull);
      } finally {
        await _deleteIfPresent(apiA, '/app-api/todo/task/delete', task.id, dbA);
        await _deleteIfPresent(apiA, '/app-api/todo/list/delete', list.id, dbA);
        await dbA.close();
        await dbB.close();
      }
    },
    skip: _enabled ? false : 'set --dart-define=TODO_B1_LIVE=true to run',
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
  String localId,
  AppDatabase db,
) async {
  final serverId = path.contains('/task/')
      ? (await (db.select(
          db.todoTasks,
        )..where((row) => row.id.equals(localId))).getSingleOrNull())?.serverId
      : (await db.listByLocalId(localId))?.serverId;
  if (serverId == null) return;
  await client.raw.delete<Map<String, dynamic>>('$path?id=$serverId');
}

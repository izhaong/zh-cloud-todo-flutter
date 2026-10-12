import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_retry_policy.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('失败退避按指数增长并设定上限', () {
    expect(syncRetryDelay(1), const Duration(seconds: 5));
    expect(syncRetryDelay(2), const Duration(seconds: 10));
    expect(syncRetryDelay(3), const Duration(seconds: 20));
    expect(syncRetryDelay(99), const Duration(hours: 1));
  });

  test('手动重试会立刻把失败项重新入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.todoSyncChanges)
        .insert(
          TodoSyncChangesCompanion.insert(
            clientMutationId: 'mutation-1',
            entity: 'task',
            op: 'upsert',
            payloadJson: '{}',
            createdAt: DateTime.utc(2026, 7, 16),
            status: const Value('failed'),
            attemptCount: const Value(3),
            nextAttemptAt: Value(DateTime.utc(2026, 7, 16, 10)),
            failureReason: const Value('revision_conflict'),
          ),
        );

    await SyncChangeQueue(db).retryNow(id);

    final change = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(change.status, 'queued');
    expect(change.attemptCount, 3);
    expect(change.nextAttemptAt, isNull);
    expect(change.failureReason, isNull);
  });

  test('连接失败后以原幂等键和 mutation 重试且成功后不重复发送', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 16);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-1',
            serverId: const Value(101),
            name: '可靠性清单',
            updatedAt: now,
            createdAt: now,
          ),
        );
    final task = await TaskRepository(
      db,
      SyncChangeQueue(db),
    ).create(listId: 'list-1', title: '可靠重试任务');
    final api = _TransientThenAcceptingSyncApi();
    final coordinator = SyncCoordinator(db: db, api: api, todoApi: ApiClient());

    expect(await coordinator.push(), 0);
    var change = await db.select(db.todoSyncChanges).getSingle();
    expect(change.status, 'retryable');
    expect(change.attemptCount, 1);

    await db
        .update(db.todoSyncChanges)
        .write(
          TodoSyncChangesCompanion(
            nextAttemptAt: Value(
              DateTime.now().subtract(const Duration(seconds: 1)),
            ),
          ),
        );
    expect(await coordinator.push(), 1);
    change = await db.select(db.todoSyncChanges).getSingle();
    expect(change.status, 'synced');
    expect((await db.taskByServerId(7))?.id, task.id);
    expect(api.idempotencyKeys, hasLength(2));
    expect(api.idempotencyKeys.first, api.idempotencyKeys.last);
    expect(api.mutationIds, hasLength(2));
    expect(api.mutationIds.first, api.mutationIds.last);

    expect(await coordinator.push(), 0);
    expect(api.attempts, 2);
  });

  test('版本冲突保留服务端拒绝原因供恢复界面展示', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db
        .into(db.todoSyncChanges)
        .insert(
          TodoSyncChangesCompanion.insert(
            clientMutationId: 'mutation-conflict',
            entity: 'task',
            op: 'upsert',
            entityServerId: const Value(7),
            payloadJson: '{}',
            createdAt: DateTime.utc(2026, 7, 16),
          ),
        );

    await SyncCoordinator(
      db: db,
      api: _ConflictSyncApi(),
      todoApi: ApiClient(),
    ).push();

    final change = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(change.status, 'failed');
    expect(change.failureReason, 'revision_conflict');
  });
}

class _TransientThenAcceptingSyncApi extends SyncApi {
  _TransientThenAcceptingSyncApi()
    : super(ApiClient(), clientId: 'test', deviceId: 'test');

  int attempts = 0;
  final idempotencyKeys = <String>[];
  final mutationIds = <String?>[];

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async {
    attempts++;
    idempotencyKeys.add(idempotencyKey);
    mutationIds.add(changes.single.clientMutationId);
    if (attempts == 1) throw StateError('offline');
    return SyncPushResult(
      ok: true,
      accepted: [
        SyncChangeDto(
          entityType: 'task',
          entityId: 7,
          operation: 'upsert',
          clientMutationId: changes.single.clientMutationId,
        ),
      ],
      conflicts: const [],
      nextCursor: null,
    );
  }
}

class _ConflictSyncApi extends SyncApi {
  _ConflictSyncApi() : super(ApiClient(), clientId: 'test', deviceId: 'test');

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async => SyncPushResult(
    ok: true,
    accepted: const [],
    conflicts: [
      SyncConflictDto(
        clientMutationId: changes.single.clientMutationId,
        reason: 'revision_conflict',
      ),
    ],
    nextCursor: null,
  );
}

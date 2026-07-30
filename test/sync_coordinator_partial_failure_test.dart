import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/filter_repository.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_view_action_repository.dart';

void main() {
  test(
    'deferred filter does not replace the sent view preference idempotency key',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertUnsyncedList(db);
      await _enqueueDependentFilterAndViewPreference(db);
      final changes = await db.select(db.todoSyncChanges).get();
      final filterChange = changes.singleWhere(
        (change) => change.entity == SyncEntities.filter,
      );
      final viewChange = changes.singleWhere(
        (change) => change.entity == SyncEntities.viewPreference,
      );
      final api = _AcceptingSyncApi();

      expect(
        await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).push(),
        1,
      );

      expect(api.idempotencyKeys, [viewChange.clientMutationId]);
      expect(api.entityBatches, [
        [SyncEntities.viewPreference],
      ]);
      final stored = await db.select(db.todoSyncChanges).get();
      expect(
        stored.singleWhere((change) => change.id == filterChange.id).status,
        'queued',
      );
      expect(
        stored.singleWhere((change) => change.id == viewChange.id).status,
        'synced',
      );
    },
  );

  test(
    'network failure marks only sent changes retryable and keeps deferred filter queued',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertUnsyncedList(db);
      await _enqueueDependentFilterAndViewPreference(db);
      final api = _FailingSyncApi();

      expect(
        await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).push(),
        0,
      );

      final stored = await db.select(db.todoSyncChanges).get();
      final filter = stored.singleWhere(
        (change) => change.entity == SyncEntities.filter,
      );
      final view = stored.singleWhere(
        (change) => change.entity == SyncEntities.viewPreference,
      );
      expect(filter.status, 'queued');
      expect(filter.attemptCount, 0);
      expect(filter.nextAttemptAt, isNull);
      expect(view.status, 'retryable');
      expect(view.attemptCount, 1);
      expect(view.nextAttemptAt, isNotNull);
      expect(api.idempotencyKeys, [view.clientMutationId]);
    },
  );

  test(
    'malformed filter fails alone while a valid view preference still syncs',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await _insertUnsyncedList(db);
      await _enqueueDependentFilterAndViewPreference(db);
      final filterChange = (await db.select(db.todoSyncChanges).get())
          .singleWhere((change) => change.entity == SyncEntities.filter);
      await (db.update(
        db.todoSyncChanges,
      )..where((change) => change.id.equals(filterChange.id))).write(
        const TodoSyncChangesCompanion(
          payloadJson: Value(
            '{"name":"损坏过滤器","conditionsJson":"{\\"listIds\\":\\"not-a-list\\"}"}',
          ),
        ),
      );
      final api = _AcceptingSyncApi();

      expect(
        await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).push(),
        1,
      );

      expect(api.entityBatches, [
        [SyncEntities.viewPreference],
      ]);
      final stored = await db.select(db.todoSyncChanges).get();
      final failed = stored.singleWhere(
        (change) => change.entity == SyncEntities.filter,
      );
      final synced = stored.singleWhere(
        (change) => change.entity == SyncEntities.viewPreference,
      );
      expect(failed.status, 'failed');
      expect(failed.failureReason, 'LOCAL_PAYLOAD_INVALID');
      expect(failed.attemptCount, 1);
      expect(synced.status, 'synced');
    },
  );

  test(
    'filter with a missing local relation fails without sending its UUID',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = SyncChangeQueue(db);
      await FilterRepository(db, queue).save(
        name: '缺失清单过滤器',
        conditions: const TodoFilterConditions(listIds: ['missing-list']),
      );
      await TaskViewActionRepository(
        db,
        queue,
      ).saveTaskWorkspaceViewMode(sourceKey: 'smart:all', viewType: 'kanban');
      final api = _AcceptingSyncApi();

      expect(
        await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).push(),
        1,
      );

      expect(api.entityBatches, [
        [SyncEntities.viewPreference],
      ]);
      final stored = await db.select(db.todoSyncChanges).get();
      final failed = stored.singleWhere(
        (change) => change.entity == SyncEntities.filter,
      );
      expect(failed.status, 'failed');
      expect(failed.failureReason, 'LOCAL_PAYLOAD_INVALID');
      expect(
        stored
            .singleWhere(
              (change) => change.entity == SyncEntities.viewPreference,
            )
            .status,
        'synced',
      );
    },
  );
}

Future<void> _insertUnsyncedList(AppDatabase db) {
  final now = DateTime.utc(2026, 7, 30, 12);
  return db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          id: 'local-list',
          name: '未同步清单',
          updatedAt: now,
          createdAt: now,
        ),
      );
}

Future<void> _enqueueDependentFilterAndViewPreference(AppDatabase db) async {
  final queue = SyncChangeQueue(db);
  await FilterRepository(db, queue).save(
    name: '依赖清单的过滤器',
    conditions: const TodoFilterConditions(listIds: ['local-list']),
  );
  await TaskViewActionRepository(
    db,
    queue,
  ).saveTaskWorkspaceViewMode(sourceKey: 'smart:all', viewType: 'kanban');
}

class _AcceptingSyncApi extends SyncApi {
  _AcceptingSyncApi()
    : super(ApiClient(), clientId: 'partial', deviceId: 'partial');

  final idempotencyKeys = <String>[];
  final entityBatches = <List<String>>[];

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    entityBatches.add(
      changes.map((change) => change.entityType).toList(growable: false),
    );
    return SyncPushResult(
      ok: true,
      accepted: [
        for (final change in changes)
          SyncChangeDto(
            entityType: change.entityType,
            entityId: change.entityType == SyncEntities.viewPreference
                ? 401
                : 301,
            operation: change.operation,
            clientMutationId: change.clientMutationId,
          ),
      ],
      conflicts: const [],
      nextCursor: null,
    );
  }
}

class _FailingSyncApi extends SyncApi {
  _FailingSyncApi()
    : super(ApiClient(), clientId: 'partial', deviceId: 'partial');

  final idempotencyKeys = <String>[];

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) {
    idempotencyKeys.add(idempotencyKey);
    throw StateError('offline');
  }
}

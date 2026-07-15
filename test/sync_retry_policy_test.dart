import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_retry_policy.dart';

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
          ),
        );

    await SyncChangeQueue(db).retryNow(id);

    final change = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.id.equals(id))).getSingle();
    expect(change.status, 'queued');
    expect(change.attemptCount, 3);
    expect(change.nextAttemptAt, isNull);
  });
}

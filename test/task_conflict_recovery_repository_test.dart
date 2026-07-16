import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/task_repository.dart';

void main() {
  test('将冲突任务快照恢复为一次可同步的本地副本', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = TaskRepository(db, SyncChangeQueue(db));
    final source = await repository.create(
      listId: 'inbox',
      title: '本地修改的任务',
      description: '离线正文',
      priority: 3,
      dueAt: DateTime.utc(2026, 7, 20),
      isPinned: true,
    );
    final conflictId = await db
        .into(db.todoSyncChanges)
        .insert(
          TodoSyncChangesCompanion.insert(
            clientMutationId: 'conflict-task-snapshot',
            entity: SyncEntities.task,
            op: SyncOps.upsert,
            entityLocalId: Value(source.id),
            entityServerId: const Value(7),
            payloadJson: jsonEncode(source.toJson()),
            createdAt: DateTime.utc(2026, 7, 16),
            status: const Value('failed'),
            failureReason: const Value('revision_conflict'),
          ),
        );
    final conflict = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.id.equals(conflictId))).getSingle();

    final restored = await repository.createConflictCopies([conflict]);

    expect(restored, 1);
    final copy = await (db.select(
      db.todoTasks,
    )..where((row) => row.title.equals('本地修改的任务（本地副本）'))).getSingle();
    expect(copy.id, isNot(source.id));
    expect(copy.serverId, isNull);
    expect(copy.description, '离线正文');
    expect(copy.priority, 3);
    expect(copy.dueAt?.toUtc(), DateTime.utc(2026, 7, 20));
    expect(copy.isPinned, isTrue);
    final copyChange = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.entityLocalId.equals(copy.id))).getSingle();
    expect(copyChange.status, 'queued');
    final resolved = await (db.select(
      db.todoSyncChanges,
    )..where((row) => row.id.equals(conflictId))).getSingle();
    expect(resolved.status, 'resolved');
    expect(resolved.failureReason, 'revision_conflict');

    expect(await repository.createConflictCopies([resolved]), 0);
  });
}

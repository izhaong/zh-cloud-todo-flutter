import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

void main() {
  test(
    'moving a list to a folder updates Drift and writes a list outbox change',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 7, 19);
      await db.batch((batch) {
        batch.insert(
          db.todoFolders,
          TodoFoldersCompanion.insert(
            id: 'folder-local',
            serverId: const Value(88),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          db.todoLists,
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '待办',
            updatedAt: now,
            createdAt: now,
          ),
        );
      });

      final moved = await ListRepository(
        db,
        SyncChangeQueue(db),
      ).moveToFolder('list-local', 88);

      expect(moved.folderId, 88);
      final changes = await db.select(db.todoSyncChanges).get();
      expect(changes, hasLength(1));
      expect(changes.single.entity, SyncEntities.list);
      expect(changes.single.entityServerId, 101);
      expect(jsonDecode(changes.single.payloadJson)['folderId'], 88);
    },
  );
}

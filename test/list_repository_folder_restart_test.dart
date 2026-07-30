import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

void main() {
  test(
    'offline folder move survives a file-database restart with its outbox',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'todo-folder-move-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/todo.sqlite');
      final now = DateTime.utc(2026, 7, 19);
      final first = AppDatabase.forTesting(NativeDatabase(file));
      await first.batch((batch) {
        batch.insert(
          first.todoFolders,
          TodoFoldersCompanion.insert(
            id: 'folder-local',
            serverId: const Value(88),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
        batch.insert(
          first.todoLists,
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '离线清单',
            updatedAt: now,
            createdAt: now,
          ),
        );
      });
      await ListRepository(
        first,
        SyncChangeQueue(first),
      ).moveToFolder('list-local', 'folder-local');
      await first.close();

      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);
      final list = await reopened.listByLocalId('list-local');
      final changes = await reopened.select(reopened.todoSyncChanges).get();

      expect(list?.folderId, 88);
      expect(list?.folderLocalId, 'folder-local');
      expect(changes, hasLength(1));
      expect(changes.single.entity, SyncEntities.list);
      expect(changes.single.entityServerId, 101);
      expect(jsonDecode(changes.single.payloadJson)['folderId'], 88);
      expect(
        jsonDecode(changes.single.payloadJson)['folderLocalId'],
        'folder-local',
      );
    },
  );
}

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/board_preference_repository.dart';

void main() {
  test('保存看板偏好在同一离线写链路落库并入队', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 16, 9);
    await db.into(db.todoLists).insert(
      TodoListsCompanion.insert(
        id: 'list-local',
        serverId: const Value(101),
        name: '项目',
        updatedAt: now,
        createdAt: now,
      ),
    );
    await BoardPreferenceRepository(db, SyncChangeQueue(db)).save(
      listId: 'list-local',
      groupDimension: 'CUSTOM',
      columnsJson: '["TODO","DONE"]',
    );
    final preference = await db.select(db.todoBoardPreferences).getSingle();
    final queued = await db.select(db.todoSyncChanges).getSingle();
    expect(preference.listId, 'list-local');
    expect(preference.groupDimension, 'CUSTOM');
    expect(preference.columnsJson, '["TODO","DONE"]');
    expect(queued.entity, SyncEntities.boardPreference);
    expect(queued.entityLocalId, preference.id);
    expect(jsonDecode(queued.payloadJson), {
      'listId': 101,
      'groupDimension': 'CUSTOM',
      'columnsJson': '["TODO","DONE"]',
    });
  });
}

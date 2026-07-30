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
    await db
        .into(db.todoLists)
        .insert(
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

  test('恢复当前清单失败偏好会重新入队并保留旧记录', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 16, 9);
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'list-local',
            serverId: const Value(101),
            name: '项目',
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoBoardPreferences)
        .insert(
          TodoBoardPreferencesCompanion.insert(
            id: 'preference-local',
            serverId: const Value(401),
            listId: 'list-local',
            groupDimension: 'SERVER',
            columnsJson: const Value('["SERVER"]'),
            updatedAt: now,
            createdAt: now,
          ),
        );
    await db
        .into(db.todoSyncChanges)
        .insert(
          TodoSyncChangesCompanion.insert(
            clientMutationId: 'failed-board-preference',
            entity: SyncEntities.boardPreference,
            op: SyncOps.upsert,
            entityLocalId: const Value('preference-local'),
            entityServerId: const Value(401),
            payloadJson: jsonEncode({
              'listId': 101,
              'groupDimension': 'LOCAL',
              'columnsJson': '["LOCAL"]',
            }),
            createdAt: now,
            status: const Value('failed'),
          ),
        );

    final repository = BoardPreferenceRepository(db, SyncChangeQueue(db));
    expect(await repository.hasRecoverableFailed(listId: 'list-local'), isTrue);
    expect(await repository.recoverLatestFailed(listId: 'list-local'), isTrue);
    expect(
      await repository.hasRecoverableFailed(listId: 'list-local'),
      isFalse,
    );

    final preference = await db.select(db.todoBoardPreferences).getSingle();
    final changes = await db.select(db.todoSyncChanges).get();
    final old = changes.singleWhere(
      (change) => change.clientMutationId == 'failed-board-preference',
    );
    final retry = changes.singleWhere((change) => change.status == 'queued');
    expect(preference.groupDimension, 'LOCAL');
    expect(old.status, 'resolved');
    expect(jsonDecode(retry.payloadJson), {
      'listId': 101,
      'groupDimension': 'LOCAL',
      'columnsJson': '["LOCAL"]',
    });
  });

  test('看板列顺序与折叠状态按清单保存并可恢复', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 30, 9);
    for (final id in ['list-a', 'list-b']) {
      await db
          .into(db.todoLists)
          .insert(
            TodoListsCompanion.insert(
              id: id,
              name: id,
              updatedAt: now,
              createdAt: now,
            ),
          );
    }
    final repository = BoardPreferenceRepository(db, SyncChangeQueue(db));

    await repository.saveLayout(
      listId: 'list-a',
      orderedColumnIds: const ['urgent', 'doing', 'todo', 'archive'],
      collapsedColumnIds: const {'archive', 'todo'},
    );

    final a = await repository.get('list-a');
    final b = await repository.get('list-b');
    expect(a.orderedColumnIds, ['urgent', 'doing', 'todo', 'archive']);
    expect(a.collapsedColumnIds, {'archive', 'todo'});
    expect(b.orderedColumnIds, BoardViewPreference.defaultColumnIds);
    expect(b.collapsedColumnIds, isEmpty);
    final change = await db.select(db.todoSyncChanges).getSingle();
    final payload = jsonDecode(change.payloadJson) as Map<String, dynamic>;
    expect(payload['groupDimension'], 'PRIORITY');
    expect(jsonDecode(payload['columnsJson'] as String), {
      'order': ['urgent', 'doing', 'todo', 'archive'],
      'collapsed': ['archive', 'todo'],
    });
  });
}

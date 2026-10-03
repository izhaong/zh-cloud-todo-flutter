import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

/// specs/081 / FL Issue #341：清单「置顶」（嘀嗒《02-用清单管理任务》
/// 「在侧边栏左滑某个清单，会出现「置顶」、「编辑」和「删除」3个选项。」）。
void main() {
  Future<(AppDatabase, ListRepository)> openRepo() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return (db, ListRepository(db, SyncChangeQueue(db)));
  }

  Future<Set<String>> snapshotOf(AppDatabase db) async {
    final rows = await db.select(db.todoSyncChanges).get();
    return rows.map((r) => r.clientMutationId).toSet();
  }

  Future<List<TodoSyncChange>> addedListChanges(
    AppDatabase db,
    Set<String> before,
  ) async {
    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.list))).get();
    return rows.where((r) => !before.contains(r.clientMutationId)).toList();
  }

  test('新建清单默认未置顶；置顶写进本地列', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    expect(a.isPinned, false, reason: '列默认值必须是未置顶');

    await repo.setPinned(a.id, true);
    final rows = await db.select(db.todoLists).get();
    expect(rows.single.isPinned, true, reason: '置顶要落到本地列');
  });

  test('置顶登记一条 list/upsert，payload 带 isPinned（服务端同名字段）', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    final before = await snapshotOf(db);

    await repo.setPinned(a.id, true);

    final added = await addedListChanges(db, before);
    expect(added, hasLength(1), reason: '本步只应新增一条 outbox');
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['isPinned'], true, reason: '出库 payload 必须带置顶位');
    expect(payload['name'], '工作', reason: 'payload 仍是整行 upsert');
  });

  test('取消置顶同样落列并出库', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    await repo.setPinned(a.id, true);
    final before = await snapshotOf(db);

    await repo.setPinned(a.id, false);

    final rows = await db.select(db.todoLists).get();
    expect(rows.single.isPinned, false);
    final added = await addedListChanges(db, before);
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['isPinned'], false, reason: '取消置顶也要同步出去');
  });

  test('getAll 把置顶清单排在最前，未置顶仍按 sortOrder', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '甲', sortOrder: 0);
    await repo.create(name: '乙', sortOrder: 1);
    final c = await repo.create(name: '丙', sortOrder: 2);

    await repo.setPinned(c.id, true);

    final lists = await repo.getAll();
    expect(lists.map((e) => e.name).toList(), [
      '丙',
      '甲',
      '乙',
    ], reason: '置顶优先，其余保持 sortOrder');
    expect(lists.map((e) => e.id), containsAll([a.id, c.id]));
  });

  test('库表升到 v25：todo_lists 建表带 is_pinned 列', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 25, reason: '置顶位需要一次迁移');
    final cols = await db.customSelect('PRAGMA table_info(todo_lists)').get();
    final names = cols.map((r) => r.data['name'] as String).toSet();
    expect(names, contains('is_pinned'), reason: '建表必须带置顶列');
  });
}

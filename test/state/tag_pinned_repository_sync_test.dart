import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/tag_repository.dart';

/// specs/082 / FL Issue #329 面 ⑥ 的「置顶」半面：标签置顶（嘀嗒《04-用标签管理任务》
/// `:79`「在侧边栏左滑某个标签，会出现「置顶」、「编辑」和「删除」3个选项。」）。
void main() {
  Future<(AppDatabase, TagRepository)> openRepo() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return (db, TagRepository(db, SyncChangeQueue(db)));
  }

  Future<Set<String>> snapshotOf(AppDatabase db) async {
    final rows = await db.select(db.todoSyncChanges).get();
    return rows.map((r) => r.clientMutationId).toSet();
  }

  Future<List<TodoSyncChange>> addedTagChanges(
    AppDatabase db,
    Set<String> before,
  ) async {
    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.tag))).get();
    return rows.where((r) => !before.contains(r.clientMutationId)).toList();
  }

  /// 直接插行，固定 createdAt —— 排序用例不能依赖时钟精度（三次 `create()` 可能落在同一微秒）。
  Future<TodoTag> seedTag(
    AppDatabase db,
    String id,
    String name,
    DateTime createdAt, {
    int? serverId,
    bool isPinned = false,
  }) async {
    await db
        .into(db.todoTags)
        .insert(
          TodoTagsCompanion.insert(
            id: id,
            serverId: Value(serverId),
            name: name,
            updatedAt: createdAt,
            createdAt: createdAt,
            isPinned: Value(isPinned),
          ),
        );
    return (db.select(db.todoTags)..where((t) => t.id.equals(id))).getSingle();
  }

  test('新建标签默认未置顶；置顶写进本地列', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '重要');
    expect(a.isPinned, false, reason: '列默认值必须是未置顶');

    await repo.setPinned(a.id, true);

    final rows = await db.select(db.todoTags).get();
    expect(rows.single.isPinned, true, reason: '置顶要落到本地列');
  });

  test('置顶登记一条 tag/upsert，payload 带 isPinned（服务端同名字段）', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '重要');
    final before = await snapshotOf(db);

    await repo.setPinned(a.id, true);

    final added = await addedTagChanges(db, before);
    expect(added, hasLength(1), reason: '本步只应新增一条 outbox');
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['isPinned'], true, reason: '出库 payload 必须带置顶位');
    expect(payload['name'], '重要', reason: 'payload 仍是整行 upsert');
  });

  test('取消置顶同样落列并出库', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '重要');
    await repo.setPinned(a.id, true);
    final before = await snapshotOf(db);

    await repo.setPinned(a.id, false);

    final rows = await db.select(db.todoTags).get();
    expect(rows.single.isPinned, false);
    final added = await addedTagChanges(db, before);
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['isPinned'], false, reason: '取消置顶也要同步出去');
  });

  test('getAll 把置顶标签排在最前，未置顶仍按 createdAt 升序', () async {
    final (db, repo) = await openRepo();
    final base = DateTime(2026, 3, 1);
    await seedTag(db, 't-a', '甲', base);
    await seedTag(db, 't-b', '乙', base.add(const Duration(minutes: 1)));
    await seedTag(db, 't-c', '丙', base.add(const Duration(minutes: 2)));

    await repo.setPinned('t-c', true);

    final tags = await repo.getAll();
    expect(tags.map((t) => t.name).toList(), [
      '丙',
      '甲',
      '乙',
    ], reason: '置顶优先，其余维持改造前的 created_at 升序');
  });

  test('watchAll 与 getAll 同一顺序（读屏与列表不能两套口径）', () async {
    final (db, repo) = await openRepo();
    final base = DateTime(2026, 3, 1);
    await seedTag(db, 't-a', '甲', base);
    await seedTag(db, 't-b', '乙', base.add(const Duration(minutes: 1)));
    await repo.setPinned('t-b', true);

    final streamed = await repo.watchAll().first;
    final listed = await repo.getAll();
    expect(
      streamed.map((t) => t.id).toList(),
      listed.map((t) => t.id).toList(),
    );
    expect(streamed.first.id, 't-b', reason: '置顶那条在两个读法里都排最前');
  });

  test('pull 带回 isPinned 就落列；没带就保留本地置顶位', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seedTag(db, 't-in', '入库标签', DateTime(2026, 3, 1), serverId: 301);
    await seedTag(
      db,
      't-keep',
      '保留置顶',
      DateTime(2026, 3, 2),
      serverId: 302,
      isPinned: true,
    );
    final changes = [
      {
        'changeId': 1,
        'entityType': 'tag',
        'entityId': 301,
        'operation': 'upsert',
        'revision': 1,
        'tombstone': false,
        'payload': {'id': 301, 'name': '入库标签', 'isPinned': true},
      },
      {
        'changeId': 2,
        'entityType': 'tag',
        'entityId': 302,
        'operation': 'upsert',
        'revision': 1,
        'tombstone': false,
        'payload': {'id': 302, 'name': '保留置顶'},
      },
    ];
    final dio = Dio(BaseOptions(baseUrl: 'https://todo.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'code': 0,
                  'data': {
                    'changes': changes,
                    'tombstones': [],
                    'nextCursor': 'todo-core:2',
                    'hasMore': false,
                  },
                },
              ),
            );
          },
        ),
      );
    final client = ApiClient(dio: dio);
    final coordinator = SyncCoordinator(
      db: db,
      api: SyncApi(client, clientId: 'tag-pin', deviceId: 'tag-pin'),
      todoApi: client,
    );

    await coordinator.pull();

    final rows = await db.select(db.todoTags).get();
    final arrived = rows.firstWhere((t) => t.serverId == 301);
    final kept = rows.firstWhere((t) => t.serverId == 302);
    expect(arrived.isPinned, true, reason: '服务端下发的置顶位要落到本地列');
    expect(kept.isPinned, true, reason: 'payload 没带 isPinned 时不得静默取消本地置顶');
  });

  test('库表升到 v26：todo_tags 建表带 is_pinned 列', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      db.schemaVersion,
      30,
      reason: '标签置顶位需要一次迁移，拖拽位次又推了一格，推荐契约列再推一格，清单颜色列再推一格，清单图标/背景/显隐四列再推一格',
    );
    final cols = await db.customSelect('PRAGMA table_info(todo_tags)').get();
    final names = cols.map((r) => r.data['name'] as String).toSet();
    expect(names, contains('is_pinned'), reason: '建表必须带置顶列');
  });
}

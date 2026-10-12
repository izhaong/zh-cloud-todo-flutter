import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

/// specs/102 / FL Issue #339：清单「颜色」属性的仓储写路径。
///
/// 嘀嗒《02-用清单管理任务.md》:73「你可以设置清单的「名称」、「颜色」…」。
/// 服务端契约已就绪（`todo_list.color`、增量出站 `payload.put("color", …)`），
/// 客户端补的是 create / setColor 两条写路径，payload 走整行 `toJson()`。
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

  test('create 接 color 落列，outbox payload 带同名键；不传默认 null', () async {
    final (db, repo) = await openRepo();
    final before = await snapshotOf(db);

    final colored = await repo.create(name: '骑行', color: '#00C853');
    expect(colored.color, '#00C853', reason: '色要落到本地列');

    final plain = await repo.create(name: '读书');
    expect(plain.color, isNull, reason: '不选色就是无色，别塞空串冒充');

    final added = await addedListChanges(db, before);
    expect(added, hasLength(2), reason: '两次新建各一条 outbox');
    final payloadByName = {
      for (final change in added)
        (jsonDecode(change.payloadJson) as Map<String, dynamic>)['name']
                as String:
            jsonDecode(change.payloadJson) as Map<String, dynamic>,
    };
    expect(
      payloadByName['骑行']!['color'],
      '#00C853',
      reason: '新建那一条的 outbox payload 必须带 color',
    );
    expect(
      payloadByName['读书']!.containsKey('color'),
      isTrue,
      reason: '整行 upsert 的 toJson 自动含 color 键（null 值也是它）',
    );
  });

  test("setColor 更新列并出一条 list/upsert，payload['color'] 跟着变", () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    final before = await snapshotOf(db);

    await repo.setColor(a.id, '#F44336');

    final row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.color, '#F44336');
    final added = await addedListChanges(db, before);
    expect(added, hasLength(1), reason: '改色只该有一条 outbox');
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['color'], '#F44336', reason: '出库必须带新色');
    expect(payload['name'], '工作', reason: 'payload 仍是整行 upsert');
  });

  test('setColor(null) 清色：列回 null、payload 带显式 null 键', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作', color: '#4772FA');
    expect(a.color, '#4772FA', reason: '前提：先有色可清');
    final before = await snapshotOf(db);

    await repo.setColor(a.id, null);

    final row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.color, isNull);
    final added = await addedListChanges(db, before);
    final payload =
        jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload.containsKey('color'), isTrue, reason: '键必须在，值是 null');
    expect(payload['color'], isNull, reason: '清色也要同步出去，另一端才知道该回退默认色');
  });
}

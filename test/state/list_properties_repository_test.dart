import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

/// specs/105 / FL #339、#340：清单「Emoji 图标 / 背景 / 在智能清单中显示」
/// 的仓储写路径。
///
/// 嘀嗒《02-用清单管理任务.md》：:86-:87 图标两种方式、:103-:111 背景四样式、
/// :118「已完成/已放弃/垃圾桶」不支持背景（本端智能清单同样拒绝）。
/// 出库 payload 走整行 `toJson()`，四键（icon/backgroundType/backgroundValue/
/// showInSmartList）随 camelCase getter 自动带上。
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

  test('create 四属性落列，outbox payload 带同名键；不传走默认值', () async {
    final (db, repo) = await openRepo();
    final before = await snapshotOf(db);

    final full = await repo.create(
      name: '骑行',
      icon: '🚴',
      backgroundType: 'color',
      backgroundValue: '#00C853',
      showInSmartList: false,
    );
    expect(full.icon, '🚴');
    expect(full.backgroundType, 'color');
    expect(full.backgroundValue, '#00C853');
    expect(full.showInSmartList, isFalse, reason: '关掉智能清单显示要落列');

    final plain = await repo.create(name: '读书');
    expect(plain.icon, isNull);
    expect(plain.backgroundType, 'theme', reason: '默认跟随应用主题');
    expect(plain.backgroundValue, isNull);
    expect(plain.showInSmartList, isTrue);

    final added = await addedListChanges(db, before);
    expect(added, hasLength(2));
    final payloadByName = {
      for (final change in added)
        (jsonDecode(change.payloadJson) as Map<String, dynamic>)['name']
                as String:
            jsonDecode(change.payloadJson) as Map<String, dynamic>,
    };
    expect(payloadByName['骑行']!['icon'], '🚴');
    expect(payloadByName['骑行']!['backgroundType'], 'color');
    expect(payloadByName['骑行']!['backgroundValue'], '#00C853');
    expect(payloadByName['骑行']!['showInSmartList'], isFalse);
    expect(payloadByName['读书']!['icon'], isNull);
    expect(payloadByName['读书']!['backgroundType'], 'theme');
    expect(payloadByName['读书']!['showInSmartList'], isTrue);
  });

  test('setIcon 更新列并出一条 list/upsert；setIcon(null) 清图标', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    final before = await snapshotOf(db);

    await repo.setIcon(a.id, '💼');
    var row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.icon, '💼');
    var added = await addedListChanges(db, before);
    expect(added, hasLength(1));
    var payload = jsonDecode(added.single.payloadJson) as Map<String, dynamic>;
    expect(payload['icon'], '💼');

    await repo.setIcon(a.id, null);
    row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.icon, isNull);
    added = await addedListChanges(db, before);
    expect(added, hasLength(2));
    payload = jsonDecode(added.last.payloadJson) as Map<String, dynamic>;
    expect(payload.containsKey('icon'), isTrue, reason: '清除也要显式同步出去');
    expect(payload['icon'], isNull);
  });

  test('setBackground 色背景落列出库；theme 强制 value 回 null', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    final before = await snapshotOf(db);

    await repo.setBackground(a.id, 'gradient', '#FF9A9E,#FAD0C4');
    var row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.backgroundType, 'gradient');
    expect(row.backgroundValue, '#FF9A9E,#FAD0C4');

    await repo.setBackground(a.id, 'theme', '应该被忽略');
    row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.backgroundType, 'theme');
    expect(row.backgroundValue, isNull, reason: 'theme 档不该留残留值');

    final added = await addedListChanges(db, before);
    expect(added, hasLength(2));
    final last = jsonDecode(added.last.payloadJson) as Map<String, dynamic>;
    expect(last['backgroundType'], 'theme');
    expect(last['backgroundValue'], isNull);
  });

  test('setBackground 空串 type 归一化为 theme', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    await repo.setBackground(a.id, '', null);
    final row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.backgroundType, 'theme');
  });

  test('setBackground 拒绝 inbox 与智能清单（嘀嗒 :118 三例外）', () async {
    final (db, repo) = await openRepo();

    // 先播种 inbox 行：守卫判的是「这行存在且是 inbox」，否则先撞"清单不存在"。
    final now = DateTime.now();
    await db
        .into(db.todoLists)
        .insert(
          TodoListsCompanion.insert(
            id: 'inbox',
            name: '收集箱',
            updatedAt: now,
            createdAt: now,
          ),
        );

    await expectLater(
      repo.setBackground('inbox', 'color', '#FF0000'),
      throwsArgumentError,
      reason: '嘀嗒「垃圾桶」不支持背景，本端 inbox 同样拒绝',
    );

    final smart = await repo.create(name: 'smart:today');
    await expectLater(
      repo.setBackground(smart.id, 'image', 'https://example.com/bg.png'),
      throwsArgumentError,
    );

    final row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(smart.id))).getSingle();
    expect(row.backgroundType, 'theme', reason: '被拒后不该有任何写入');
  });

  test('setShowInSmartList(false/true) 双向往返，出库带布尔', () async {
    final (db, repo) = await openRepo();
    final a = await repo.create(name: '工作');
    final before = await snapshotOf(db);

    await repo.setShowInSmartList(a.id, false);
    var row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.showInSmartList, isFalse);

    await repo.setShowInSmartList(a.id, true);
    row = await (db.select(
      db.todoLists,
    )..where((t) => t.id.equals(a.id))).getSingle();
    expect(row.showInSmartList, isTrue);

    final added = await addedListChanges(db, before);
    expect(added, hasLength(2));
    expect(
      (jsonDecode(added.first.payloadJson) as Map)['showInSmartList'],
      isFalse,
    );
    expect(
      (jsonDecode(added.last.payloadJson) as Map)['showInSmartList'],
      isTrue,
    );
  });
}

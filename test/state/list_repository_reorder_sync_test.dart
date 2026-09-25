import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_change_queue.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_entities.dart';
import 'package:zh_cloud_todo_flutter/state/repositories/list_repository.dart';

/// specs/054 / FL Issue #341：清单拖拽排序要能同步出去。
///
///  develop 上的病灶（逐条实测，见 spec.md 二）：`ListRepository.reorder`
/// （`list_repository.dart:163`）写完 `sortOrder` 就返回，**一条 outbox 都不登记**，
/// 而同文件 `create:85 / rename:103 / moveToFolder:141 / delete:181 / saveSmart:212`
/// 每个写方法都登记 ⇒ 换设备 pull 回来顺序是旧的，界面上却"刚刚拖好了"。
/// 本套用例钉的是**跨端成立**，不是"本地排个序"。
void main() {
  Future<(AppDatabase, ListRepository)> _open() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return (db, ListRepository(db, SyncChangeQueue(db)));
  }

  /// 表里现在的 `id → sortOrder`。
  Future<Map<String, int>> _order(AppDatabase db) async {
    final rows = await db.select(db.todoLists).get();
    return {for (final r in rows) r.id: r.sortOrder};
  }

  /// 只看本步新增的 outbox 行（`create()` 自己每条都会登记一行，
  /// 不先做快照就等不到"reorder 登记了几条"这个数）。
  Future<List<TodoSyncChange>> _added(
    AppDatabase db,
    Set<String> before,
  ) async {
    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.list))).get();
    return rows.where((r) => !before.contains(r.clientMutationId)).toList();
  }

  Future<Set<String>> _snapshot(AppDatabase db) async {
    final rows = await db.select(db.todoSyncChanges).get();
    return rows.map((r) => r.clientMutationId).toSet();
  }

  test('拖完顺序：每个位次都登记一条 list/upsert，payload 的 sortOrder 就是位次', () async {
    final (db, repo) = await _open();
    final a = await repo.create(name: '工作');
    final b = await repo.create(name: '生活');
    final c = await repo.create(name: '学习');
    final before = await _snapshot(db);

    await repo.reorder([c.id, a.id, b.id]);

    expect(await _order(db), {c.id: 0, a.id: 1, b.id: 2}, reason: '本地位次');
    final added = await _added(db, before);
    expect(added, hasLength(3), reason: '三条都改了位次 ⇒ 三条都要登记，另一台才收敛得到');
    expect(added.map((r) => r.op).toSet(), {SyncOps.upsert});
    final byPayload = <int, String>{
      for (final r in added)
        (jsonDecode(r.payloadJson) as Map<String, dynamic>)['sortOrder']!
                as int:
            jsonDecode(r.payloadJson)['id']! as String,
    };
    expect(byPayload, {0: c.id, 1: a.id, 2: b.id}, reason: '登记出去的位次必须与库里一致');
    expect(added.map((r) => r.entityLocalId).toSet(), {
      c.id,
      a.id,
      b.id,
    }, reason: '每行都带上自己那条清单的 localId');
  });

  test('登记 payload 取自读回的那一行，不是传入参数拼的', () async {
    final (db, repo) = await _open();
    final a = await repo.create(name: '旧名');
    final b = await repo.create(name: 'B');
    // 建完再改名：outbox 里"这条清单最新的样子"是改后的名字。
    await repo.rename(a.id, '新名');
    final before = await _snapshot(db);

    await repo.reorder([b.id, a.id]);

    final added = await _added(db, before);
    final forA = added.where((r) => r.entityLocalId == a.id).toList();
    expect(forA, hasLength(1), reason: 'a 也要登记一行');
    expect(
      (jsonDecode(forA.single.payloadJson) as Map<String, dynamic>)['name'],
      '新名',
      reason: '拼出来的 payload 会带成 reorder 当时的旧快照或漏字段；读回行才保证与库一致',
    );
  });

  test('第 2 条登记失败 ⇒ 整批位次回到失败前，outbox 也不留半条', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final creating = ListRepository(db, SyncChangeQueue(db));
    final a = await creating.create(name: 'A');
    final b = await creating.create(name: 'B');
    final c = await creating.create(name: 'C');
    final before = await _snapshot(db);
    final orderBefore = await _order(db);

    // 失败注入打在**依赖层**（queue），仓储与它的事务仍跑真身：
    // 若哪天把 enqueue 挪出事务，这条当场红。
    final repo = ListRepository(db, _ThrowingQueue(db, failOnCall: 2));
    await expectLater(
      repo.reorder([c.id, a.id, b.id]),
      throwsA(isA<StateError>()),
    );

    expect(await _order(db), orderBefore, reason: '半途失败不许留下"前几条已改、后一条没改"的半截顺序');
    expect(
      await _added(db, before),
      isEmpty,
      reason: '整批回滚 ⇒ outbox 也不该留下已回滚位次对应的登记行',
    );
  });

  test('传入的 id 有一条已不存在 ⇒ 跳过它，位次不留空洞', () async {
    final (db, repo) = await _open();
    final a = await repo.create(name: 'A');
    final b = await repo.create(name: 'B');
    final before = await _snapshot(db);

    await repo.reorder([b.id, '已被别的面删掉的清单', a.id]);

    expect(await _order(db), {b.id: 0, a.id: 1}, reason: '留下的两条按实际位次连续排');
    expect(
      await _added(db, before),
      hasLength(2),
      reason: '不存在的 id 不登记（否则同步出去一条指向空 localId 的 upsert）',
    );
  });

  test('空列表 reorder 不出事、也不登记', () async {
    final (db, repo) = await _open();
    final before = await _snapshot(db);
    await repo.reorder(const []);
    expect(await _added(db, before), isEmpty);
    expect(await db.select(db.todoLists).get(), isEmpty, reason: '别凭空造出行来');
  });
}

/// 只在第 [failOnCall] 次 `enqueue` 抛错的队列；其余照常写表（保留真事务语义）。
class _ThrowingQueue extends SyncChangeQueue {
  _ThrowingQueue(super.db, {required this.failOnCall});

  final int failOnCall;
  int _calls = 0;

  @override
  Future<void> enqueue({
    required String entity,
    required String op,
    String? localId,
    int? serverId,
    String? clientMutationId,
    required Map<String, dynamic> payload,
  }) async {
    _calls++;
    if (_calls == failOnCall) {
      throw StateError('模拟 outbox 写入失败');
    }
    await super.enqueue(
      entity: entity,
      op: op,
      localId: localId,
      serverId: serverId,
      clientMutationId: clientMutationId,
      payload: payload,
    );
  }
}

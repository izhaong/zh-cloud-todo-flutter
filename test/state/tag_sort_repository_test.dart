import 'dart:convert';

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

/// specs/088 / FL Issue #329 面「长按拖拽自定义排序」的仓储半：
/// 嘀嗒《04-用标签管理任务》`:118`「通过在侧边栏「长按标签」即可进行拖拽，
/// 可以对清单进行自由排序」。
///
/// ⚠️ 语义与 `ListRepository.reorder`（specs/054）**同形不同向**：服务端标签
/// 排序是 `is_pinned DESC, sort_order DESC, id DESC`（`TodoTagMapper`），
/// sort_order **值大在前** ⇒ 本仓传入顺序的第一位拿组内**最大**值；
/// 清单那边是 0 = 第一位。两处不许互相抄。
void main() {
  Future<(AppDatabase, TagRepository, SyncChangeQueue)> openRepo() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = SyncChangeQueue(db);
    return (db, TagRepository(db, queue), queue);
  }

  /// 表里现在的 `id → sortOrder`。
  Future<Map<String, int>> orderOf(AppDatabase db) async {
    final rows = await db.select(db.todoTags).get();
    return {for (final r in rows) r.id: r.sortOrder};
  }

  Future<Set<String>> snapshotOf(AppDatabase db) async {
    final rows = await db.select(db.todoSyncChanges).get();
    return rows.map((r) => r.clientMutationId).toSet();
  }

  Future<List<TodoSyncChange>> addedAfter(
    AppDatabase db,
    Set<String> before,
  ) async {
    final rows = await (db.select(
      db.todoSyncChanges,
    )..where((t) => t.entity.equals(SyncEntities.tag))).get();
    return rows.where((r) => !before.contains(r.clientMutationId)).toList();
  }

  test('reorder 后第一位拿组内最大值，getAll 按新序排', () async {
    final (db, repo, _) = await openRepo();
    // 现 watchAll 序（isPinned DESC, createdAt ASC）：专注(30天前) > 评审 > 跟进
    final a = await repo.create(name: '专注');
    final b = await repo.create(name: '评审');
    final c = await repo.create(name: '跟进');

    await repo.reorder([c.id, a.id, b.id]);

    expect(await orderOf(db), {
      c.id: 2,
      a.id: 1,
      b.id: 0,
    }, reason: '服务端 sort_order DESC：值大在前 ⇒ 传入顺序第一位拿最大值');
    expect((await repo.getAll()).map((t) => t.id).toList(), [
      c.id,
      a.id,
      b.id,
    ], reason: '界面顺序必须真的跟着变');
  });

  test('reorder 登记组内每一行（与 ListRepository.reorder 同口径）', () async {
    final (db, repo, _) = await openRepo();
    final a = await repo.create(name: '专注');
    final b = await repo.create(name: '评审');
    final c = await repo.create(name: '跟进');
    final before = await snapshotOf(db);

    // 现序就是 a,b,c：三行位次 2/1/0，c 绝对值未变也要登记 ——
    // 它前面的行都变了，少登记一行另一端就收敛不出同样的相对序。
    await repo.reorder([a.id, b.id, c.id]);

    final added = await addedAfter(db, before);
    expect(
      added.map((r) => r.entityLocalId).toSet(),
      {a.id, b.id, c.id},
      reason: '组内每行都登记，payload 才能整体表达新序',
    );
    final byPayload = <int, String>{
      for (final r in added)
        (jsonDecode(r.payloadJson) as Map<String, dynamic>)['sortOrder']!
                as int:
            jsonDecode(r.payloadJson)['id']! as String,
    };
    expect(byPayload, {2: a.id, 1: b.id, 0: c.id}, reason: 'payload 位次与库里一致');
  });

  test('登记 payload 取自读回的那一行，不是传入参数拼的', () async {
    final (db, repo, _) = await openRepo();
    final a = await repo.create(name: '旧名');
    final b = await repo.create(name: 'B');
    await repo.update(a.id, name: '新名', parentId: null);
    final before = await snapshotOf(db);

    await repo.reorder([b.id, a.id]);

    final added = await addedAfter(db, before);
    final forA = added.where((r) => r.entityLocalId == a.id).toList();
    expect(forA, hasLength(1));
    expect(
      (jsonDecode(forA.single.payloadJson) as Map<String, dynamic>)['name'],
      '新名',
      reason: '拼参数会带成 reorder 当时的旧快照；读回行才与库一致',
    );
  });

  test('第 2 条登记失败 ⇒ 整批位次回到失败前，outbox 不留半条', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final creating = TagRepository(db, SyncChangeQueue(db));
    final a = await creating.create(name: 'A');
    final b = await creating.create(name: 'B');
    final c = await creating.create(name: 'C');
    final before = await snapshotOf(db);
    final orderBefore = await orderOf(db);

    final repo = TagRepository(db, _ThrowingQueue(db, failOnCall: 2));
    await expectLater(
      repo.reorder([c.id, a.id, b.id]),
      throwsA(isA<StateError>()),
    );

    expect(await orderOf(db), orderBefore, reason: '半途失败不许留半截顺序');
    expect(await addedAfter(db, before), isEmpty);
  });

  test('传入的 id 有一个已不存在 ⇒ 跳过它，留下的按实际位次连续排', () async {
    final (db, repo, _) = await openRepo();
    final a = await repo.create(name: 'A');
    final b = await repo.create(name: 'B');
    final before = await snapshotOf(db);

    await repo.reorder([b.id, '已被别的面删掉的标签', a.id]);

    expect(await orderOf(db), {b.id: 1, a.id: 0}, reason: '位次按幸存行连续分配，不留空洞');
    expect(await addedAfter(db, before), hasLength(2));
  });

  test('空列表 reorder 不出事、也不登记', () async {
    final (db, repo, _) = await openRepo();
    final before = await snapshotOf(db);
    await repo.reorder(const []);
    expect(await addedAfter(db, before), isEmpty);
    expect(await db.select(db.todoTags).get(), isEmpty);
  });

  test('入站 upsert 带 sortOrder 就落库', () async {
    final (db, _, queue) = await openRepo();
    final api = _TagPullApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.tag,
              entityId: 201,
              operation: SyncOps.upsert,
              payload: {'name': '工作', 'sortOrder': 5},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: false,
        ),
      ],
    );
    await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).pull();

    final tag = await db.tagByServerId(201);
    expect(tag, isNotNull);
    expect(tag!.sortOrder, 5, reason: '另一端排好的位次要原样落地');
  });

  test('入站 upsert 缺 sortOrder 就保留本地值（不替用户归零）', () async {
    final (db, repo, _) = await openRepo();
    final tag = await repo.create(name: '工作');
    // 本地把这条标签排到了位次 7（serverId 需要手工补上才能命中入站行）。
    await (db.update(db.todoTags)..where((t) => t.id.equals(tag.id))).write(
      TodoTagsCompanion(serverId: const Value(201), sortOrder: const Value(7)),
    );
    final api = _TagPullApi(
      pulls: [
        SyncPullResult(
          changes: [
            SyncChangeDto(
              entityType: SyncEntities.tag,
              entityId: 201,
              operation: SyncOps.upsert,
              payload: {'name': '工作'},
            ),
          ],
          tombstones: const [],
          nextCursor: 'c1',
          hasMore: false,
        ),
      ],
    );
    await SyncCoordinator(db: db, api: api, todoApi: ApiClient()).pull();

    final after = await db.tagByServerId(201);
    expect(after!.sortOrder, 7, reason: 'payload 没带位次 ⇒ 保留本地已排的位次');
  });
}

/// 只在 [failOnCall] 次 `enqueue` 抛错的队列；其余照常写表（保留真事务语义）。
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

class _TagPullApi extends SyncApi {
  _TagPullApi({List<SyncPullResult>? pulls})
    : _pulls = [...?pulls],
      super(ApiClient(), clientId: 'tag-sort-test', deviceId: 'tag-sort-test');

  final List<SyncPullResult> _pulls;

  @override
  Future<SyncPushResult> push({
    required String idempotencyKey,
    required List<SyncChangeDto> changes,
  }) async {
    return SyncPushResult(
      ok: true,
      accepted: const [],
      conflicts: const [],
      nextCursor: null,
    );
  }

  @override
  Future<SyncPullResult> pull({
    String? cursor,
    int limit = 200,
    List<String>? entityTypes,
  }) async {
    if (_pulls.isEmpty) {
      return SyncPullResult(
        changes: const [],
        tombstones: const [],
        nextCursor: cursor,
        hasMore: false,
      );
    }
    return _pulls.removeAt(0);
  }
}

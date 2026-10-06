import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/api_client.dart';
import 'package:zh_cloud_todo_flutter/core/api/sync_api.dart';
import 'package:zh_cloud_todo_flutter/core/db/app_database.dart';
import 'package:zh_cloud_todo_flutter/core/sync/sync_coordinator.dart';

/// 只回放分页骨架的第一页，不掺任何实体变更：判据量的是「游标有没有被推进并持久化」，
/// 不是某一类实体的落地。
class _PagingSyncApi extends SyncApi {
  _PagingSyncApi()
    : super(ApiClient(), clientId: 'test-client', deviceId: 'test-device');

  final List<String?> seenCursors = <String?>[];
  int _pages = 0;

  @override
  Future<SyncPullResult> pull({
    String? cursor,
    int limit = 200,
    List<String>? entityTypes,
  }) async {
    seenCursors.add(cursor);
    _pages++;
    if (_pages == 1) {
      return SyncPullResult(
        changes: const [],
        tombstones: const [],
        nextCursor: 'todo-core:237',
        hasMore: true,
      );
    }
    return SyncPullResult(
      changes: const [],
      tombstones: const [],
      nextCursor: 'todo-core:237',
      hasMore: false,
    );
  }
}

void main() {
  test('一轮 pull 之后游标落库，下一轮必须带着它继续', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _PagingSyncApi();
    final coordinator = SyncCoordinator(
      db: db,
      api: api,
      todoApi: ApiClient(),
    );

    await coordinator.pull();
    expect(api.seenCursors, [null], reason: '首轮从空游标开始是对的');

    final stored = await db.readSyncCursor();
    expect(
      stored?.cursor,
      'todo-core:237',
      reason: '服务端给了 nextCursor 且本轮没有待重试的分组，游标必须写回',
    );

    await coordinator.pull();
    expect(
      api.seenCursors,
      [null, 'todo-core:237'],
      reason: '第二轮不能再从 changeId 起点重放同一页',
    );
  });
}

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../api/todo_client.dart';

/// M11-B1 同步引擎骨架
///
/// - pull：从后端拉取清单/任务/文件夹/标签，merge 到本地
/// - push：把本地 TodoSyncChanges 表里的 mutation 上推到后端
/// - 冲突：暂以 last-write-wins（LWW by updatedAt）
///   真正 conflict 解决留给 B3 增量

class SyncEngine {
  SyncEngine({required this.db, required this.api});

  final AppDatabase db;
  final TodoApiClient api;

  Future<int> pullLists() async {
    final resp = await api.get<List<dynamic>>('/list/my');
    final remote = (resp.data ?? []).cast<Map<String, dynamic>>();
    // 简化：直接 upsert；M11-B2 补 delta cursor
    for (final item in remote) {
      final id = item['id'] as int;
      await db.into(db.todoLists).insertOnConflictUpdate(
            TodoListsCompanion.insert(
              serverId: Value(id),
              name: item['name'] as String,
              sortOrder: Value((item['sortOrder'] as int?) ?? 0),
              updatedAt: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );
    }
    return remote.length;
  }

  Future<int> pushPending() async {
    final pending = await (db.select(db.todoSyncChanges)
          ..where((t) => t.status.equals('queued')))
        .get();
    var pushed = 0;
    for (final change in pending) {
      try {
        // 占位：实际根据 entity/op 路由到具体端点（M11-B3 补）
        await db.update(db.todoSyncChanges).replace(
          change.copyWith(
            status: 'synced',
            attemptCount: change.attemptCount + 1,
          ),
        );
        pushed++;
      } catch (_) {
        await db.update(db.todoSyncChanges).replace(
          change.copyWith(
            status: 'failed',
            attemptCount: change.attemptCount + 1,
          ),
        );
      }
    }
    return pushed;
  }
}
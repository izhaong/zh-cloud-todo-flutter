import 'package:drift/drift.dart';

import '../../core/api/todo_api.dart';
import '../../core/db/app_database.dart';

/// 任务动态只读缓存：网络刷新落 Drift，UI 一律订阅本地流。
class ActivityRepository {
  ActivityRepository(this._db, this._api);

  final AppDatabase _db;
  final ActivityApi _api;

  Stream<List<TodoActivity>> watchTask(int taskServerId) {
    return (_db.select(_db.todoActivities)
          ..where((row) => row.taskServerId.equals(taskServerId))
          ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)]))
        .watch();
  }

  Future<void> refreshTask(int taskServerId) async {
    final records = await _api.listTask(taskServerId);
    await _db.transaction(() async {
      for (final record in records) {
        if (record.id <= 0) continue;
        await _db
            .into(_db.todoActivities)
            .insertOnConflictUpdate(
              TodoActivitiesCompanion.insert(
                serverId: Value(record.id),
                taskServerId: record.taskId,
                actorUserId: Value(record.actorUserId),
                actorUserName: Value(record.actorUserName),
                action: record.action,
                detail: Value(record.detail),
                occurredAt: record.occurredAt,
              ),
            );
      }
    });
  }
}

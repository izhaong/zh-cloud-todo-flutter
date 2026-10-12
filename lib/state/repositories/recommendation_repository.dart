import 'package:drift/drift.dart';

import '../../core/api/todo_api.dart';
import '../../core/db/app_database.dart';

/// 推荐读取模型的本地缓存。
///
/// 推荐由服务端按可见清单计算，本仓库只在成功响应后整体替换 Drift 缓存；
/// 读取失败不会清空既有缓存，也不会产生 outbox 写操作。
class RecommendationRepository {
  RecommendationRepository(this._db, this._api);

  final AppDatabase _db;
  final RecommendationApi _api;

  Stream<List<TodoRecommendation>> watchAll() {
    return (_db.select(_db.todoRecommendations)..orderBy([
          (row) => OrderingTerm(expression: row.score, mode: OrderingMode.desc),
          (row) => OrderingTerm(expression: row.taskServerId),
        ]))
        .watch();
  }

  Future<void> refresh({int limit = 10}) async {
    final remote = await _api.list(limit: limit);
    final refreshedAt = DateTime.now();
    await _db.transaction(() async {
      await _db.delete(_db.todoRecommendations).go();
      await _db.batch((batch) {
        batch.insertAll(
          _db.todoRecommendations,
          remote
              .map(
                (item) => TodoRecommendationsCompanion.insert(
                  taskServerId: Value(item.taskServerId),
                  title: item.title,
                  dueAt: Value(item.dueAt),
                  reasonCode: item.reasonCode,
                  reason: item.reason,
                  score: item.score,
                  createdAt: Value(item.createdAt),
                  rescheduleCount: Value(item.rescheduleCount),
                  unfinishedDays: Value(item.unfinishedDays),
                  refreshedAt: refreshedAt,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<void> removeTask(int taskServerId) async {
    await (_db.delete(
      _db.todoRecommendations,
    )..where((row) => row.taskServerId.equals(taskServerId))).go();
  }
}

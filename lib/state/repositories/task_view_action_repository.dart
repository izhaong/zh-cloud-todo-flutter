import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// B4 任务视图共享写操作。
///
/// 列表、看板和时间线只能经此类（或后续同类 use-case）写入任务聚合，
/// 以便本地任务更新与 outbox mutation 使用同一个 Drift transaction。
class TaskViewActionRepository {
  TaskViewActionRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

  Future<void> moveTimelineTask(
    String taskId, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  }) async {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', '必须晚于开始时间');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          startAt: Value(startAt),
          endAt: Value(endAt),
          dueAt: Value(dueAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final task = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: task.id,
        serverId: task.serverId,
        payload: task.toJson(),
      );
    });
  }

  Future<void> moveKanbanTask(
    String taskId, {
    required int priority,
    required bool completed,
  }) async {
    if (priority < 0 || priority > 3) {
      throw ArgumentError.value(priority, 'priority', '必须介于 0 和 3');
    }

    await _db.transaction(() async {
      await (_db.update(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).write(
        TodoTasksCompanion(
          priority: Value(priority),
          completed: Value(completed),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final task = await (_db.select(
        _db.todoTasks,
      )..where((row) => row.id.equals(taskId))).getSingle();
      await _queue.enqueue(
        entity: SyncEntities.task,
        op: SyncOps.upsert,
        localId: task.id,
        serverId: task.serverId,
        payload: task.toJson(),
      );
    });
  }

  Future<void> reorderListTasks(List<String> taskIds) async {
    if (taskIds.toSet().length != taskIds.length) {
      throw ArgumentError.value(taskIds, 'taskIds', '不能包含重复任务');
    }

    await _db.transaction(() async {
      for (final entry in taskIds.indexed) {
        final taskId = entry.$2;
        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).write(
          TodoTasksCompanion(
            sortOrder: Value(entry.$1),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final task = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).getSingle();
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: task.id,
          serverId: task.serverId,
          payload: task.toJson(),
        );
      }
    });
  }
}

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';

/// B3 任务批量编辑的逐项结果。
///
/// 批量操作不是一个全有或全无的黑箱：每个选中项都要返回可见、可重试的
/// 结果。每个成功项在独立 Drift transaction 中落库并写入 outbox，因此某一
/// 项失败不会回滚已经成功的其它任务，也不会留下只更新任务未入队的半状态。
enum TaskBatchEditStatus { success, skipped, failed }

class TaskBatchEditResult {
  const TaskBatchEditResult({
    required this.taskId,
    required this.status,
    this.reason,
  });

  final String taskId;
  final TaskBatchEditStatus status;
  final String? reason;
}

class TaskBatchEditCommand {
  const TaskBatchEditCommand({
    required this.taskIds,
    this.listId,
    this.dueAt,
    this.priority,
    this.completed,
    this.isPinned,
  });

  final List<String> taskIds;
  final String? listId;
  final DateTime? dueAt;
  final int? priority;
  final bool? completed;
  final bool? isPinned;

  bool get hasChanges =>
      listId != null ||
      dueAt != null ||
      priority != null ||
      completed != null ||
      isPinned != null;
}

class TaskBatchEditRepository {
  TaskBatchEditRepository(this._db, this._queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;

  Future<List<TaskBatchEditResult>> apply(TaskBatchEditCommand command) async {
    if (!command.hasChanges) {
      throw ArgumentError.value(command, 'command', '至少提供一个批量修改字段');
    }
    if (command.priority != null &&
        (command.priority! < 0 || command.priority! > 3)) {
      throw ArgumentError.value(command.priority, 'priority', '必须介于 0 和 3');
    }

    final seenIds = <String>{};
    final results = <TaskBatchEditResult>[];
    for (final taskId in command.taskIds) {
      if (!seenIds.add(taskId)) {
        results.add(
          TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.skipped,
            reason: '重复任务',
          ),
        );
        continue;
      }
      final result = await _applyOne(taskId, command);
      results.add(result);
    }
    return results;
  }

  Future<TaskBatchEditResult> _applyOne(
    String taskId,
    TaskBatchEditCommand command,
  ) async {
    try {
      return await _db.transaction(() async {
        final task = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).getSingleOrNull();
        if (task == null) {
          return TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.failed,
            reason: '任务不存在',
          );
        }

        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).write(
          TodoTasksCompanion(
            listId: command.listId == null
                ? const Value.absent()
                : Value(command.listId!),
            dueAt: command.dueAt == null
                ? const Value.absent()
                : Value(command.dueAt!),
            priority: command.priority == null
                ? const Value.absent()
                : Value(command.priority!),
            completed: command.completed == null
                ? const Value.absent()
                : Value(command.completed!),
            isPinned: command.isPinned == null
                ? const Value.absent()
                : Value(command.isPinned!),
            updatedAt: Value(DateTime.now()),
          ),
        );
        final updated = await (_db.select(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).getSingle();
        await _queue.enqueue(
          entity: SyncEntities.task,
          op: SyncOps.upsert,
          localId: updated.id,
          serverId: updated.serverId,
          payload: updated.toJson(),
        );
        return TaskBatchEditResult(
          taskId: taskId,
          status: TaskBatchEditStatus.success,
        );
      });
    } catch (_) {
      return TaskBatchEditResult(
        taskId: taskId,
        status: TaskBatchEditStatus.failed,
        reason: '本地写入失败',
      );
    }
  }
}

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/sync_change_queue.dart';
import '../../core/sync/sync_entities.dart';
import '../../features/task/task_view_mutation_feedback.dart';
import 'task_repository.dart';

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
    this.clearDueAt = false,
    this.tagIds,
    this.priority,
    this.completed,
    this.isPinned,
  });

  final List<String> taskIds;
  final String? listId;
  final DateTime? dueAt;
  final bool clearDueAt;
  final List<String>? tagIds;
  final int? priority;
  final bool? completed;
  final bool? isPinned;

  bool get hasChanges =>
      listId != null ||
      dueAt != null ||
      clearDueAt ||
      tagIds != null ||
      priority != null ||
      completed != null ||
      isPinned != null;
}

class TaskBatchEditRepository {
  TaskBatchEditRepository(AppDatabase db, SyncChangeQueue queue)
    : _db = db,
      _queue = queue,
      _tasks = TaskRepository(db, queue);

  final AppDatabase _db;
  final SyncChangeQueue _queue;
  final TaskRepository _tasks;

  /// 将每个任务关联到同一个主任务，并逐项保留成功、跳过与失败结果。
  ///
  /// 层级、循环、同清单与只读规则由 [TaskRepository.reparent] 统一维护；
  /// 每个任务使用独立 transaction，避免一个失败项回滚其它成功项。
  Future<List<TaskBatchEditResult>> linkToParent({
    required List<String> taskIds,
    required String parentTaskId,
  }) async {
    final seenIds = <String>{};
    final results = <TaskBatchEditResult>[];
    for (final taskId in taskIds) {
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
      try {
        await _tasks.reparent(taskId, parentTaskId);
        results.add(
          TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.success,
          ),
        );
      } on ArgumentError catch (error) {
        results.add(
          TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.failed,
            reason: error.message?.toString() ?? '关联主任务失败',
          ),
        );
      } on StateError catch (error) {
        results.add(
          TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.failed,
            reason: error.message,
          ),
        );
      } catch (_) {
        results.add(
          TaskBatchEditResult(
            taskId: taskId,
            status: TaskBatchEditStatus.failed,
            reason: '关联主任务失败',
          ),
        );
      }
    }
    return results;
  }

  Future<List<TaskBatchEditResult>> apply(TaskBatchEditCommand command) async {
    if (!command.hasChanges) {
      throw ArgumentError.value(command, 'command', '至少提供一个批量修改字段');
    }
    if (command.priority != null &&
        (command.priority! < 0 || command.priority! > 3)) {
      throw ArgumentError.value(command.priority, 'priority', '必须介于 0 和 3');
    }
    if (command.clearDueAt && command.dueAt != null) {
      throw ArgumentError.value(command, 'command', '不能同时设置和清空截止时间');
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

        if (command.listId != null) {
          final list = await (_db.select(
            _db.todoLists,
          )..where((row) => row.id.equals(command.listId!))).getSingleOrNull();
          if (list == null) {
            return TaskBatchEditResult(
              taskId: taskId,
              status: TaskBatchEditStatus.failed,
              reason: '清单不存在',
            );
          }
          // FL #603：子任务不许单独换清单，与左滑那条同一口径。
          // 批量里选中一条子任务就把它单独挪走，会当场造出「父子不同清单」的违规状态
          // （`moveToList` 在别处也是这么拒的）。**先拒并说明**，别让它走到写库那一步。
          if (task.parentTaskId != null) {
            return TaskBatchEditResult(
              taskId: taskId,
              status: TaskBatchEditStatus.failed,
              reason: '子任务请随主任务一起移动',
            );
          }
          // 目标清单必须**可写**：只读清单（订阅来的）不该被批量写进去。
          // 原来这里只校验"清单存在"，于是往只读清单搬会静默成功。
          if (!list.writable) {
            return TaskBatchEditResult(
              taskId: taskId,
              status: TaskBatchEditStatus.failed,
              reason: taskViewReadOnlyMessage,
            );
          }
        }

        final tagIds = command.tagIds?.toSet().toList(growable: false);
        if (tagIds != null) {
          final tags = await (_db.select(
            _db.todoTags,
          )..where((row) => row.id.isIn(tagIds))).get();
          if (tags.length != tagIds.length) {
            return TaskBatchEditResult(
              taskId: taskId,
              status: TaskBatchEditStatus.failed,
              reason: '标签不存在',
            );
          }
        }

        await (_db.update(
          _db.todoTasks,
        )..where((row) => row.id.equals(taskId))).write(
          TodoTasksCompanion(
            listId: command.listId == null
                ? const Value.absent()
                : Value(command.listId!),
            // FL #603：换清单时**必须一起清掉 `sectionId`** —— 分组属于原清单。
            // 原来这里只写 `listId`、不清分组，于是批量换清单会留下一行
            // 「listId 在新清单、sectionId 还是旧清单的」违规数据。
            sectionId: command.listId == null
                ? const Value.absent()
                : const Value<String?>(null),
            dueAt: command.clearDueAt
                ? const Value<DateTime?>(null)
                : command.dueAt == null
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
        if (tagIds != null) {
          await (_db.delete(
            _db.todoTaskTags,
          )..where((row) => row.taskId.equals(taskId))).go();
          for (final tagId in tagIds) {
            await _db
                .into(_db.todoTaskTags)
                .insert(
                  TodoTaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
                );
          }
          await _queue.enqueue(
            entity: SyncEntities.taskTag,
            op: SyncOps.upsert,
            localId: updated.id,
            serverId: updated.serverId,
            payload: {'taskId': updated.id, 'tagIds': tagIds},
          );
        }
        return TaskBatchEditResult(
          taskId: taskId,
          status: TaskBatchEditStatus.success,
        );
      });
    } on StateError catch (error) {
      // 落点类拒绝（目标清单只读、子任务不许单独换清单）要**原样上报**：
      // 兜底成「本地写入失败」是一句没有下一步的句子，用户不知道该怎么办。
      return TaskBatchEditResult(
        taskId: taskId,
        status: TaskBatchEditStatus.failed,
        reason: error.message,
      );
    } catch (_) {
      return TaskBatchEditResult(
        taskId: taskId,
        status: TaskBatchEditStatus.failed,
        reason: '本地写入失败',
      );
    }
  }
}

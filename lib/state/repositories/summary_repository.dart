import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// 摘要预览所需的一行任务事实：清单归属、完成信息与进度来源。
class SummaryTaskRow {
  const SummaryTaskRow({
    required this.taskId,
    required this.title,
    required this.listId,
    required this.listName,
    required this.completed,
    required this.createdAt,
    required this.sortOrder,
    this.completedAt,
    this.dueAt,
    this.checklistDone = 0,
    this.checklistTotal = 0,
    this.subtaskDone = 0,
    this.subtaskTotal = 0,
  });

  final String taskId;
  final String title;
  final String listId;
  final String listName;
  final bool completed;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final DateTime createdAt;
  final int sortOrder;
  final int checklistDone;
  final int checklistTotal;
  final int subtaskDone;
  final int subtaskTotal;
}

/// 摘要取数只读；嘀嗒的摘要载体是笔记正文，因此不落库、不入 outbox。
abstract interface class SummaryRepository {
  Future<List<SummaryTaskRow>> loadInRange({
    required DateTime from,
    required DateTime to,
  });
}

class DriftSummaryRepository implements SummaryRepository {
  DriftSummaryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<SummaryTaskRow>> loadInRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final taskQuery = _db.select(_db.todoTasks);
    taskQuery.where((task) {
      final completedInRange =
          task.completed.equals(true) &
          task.completedAt.isBiggerOrEqualValue(from) &
          task.completedAt.isSmallerThanValue(to);
      final undoneByDue =
          task.dueAt.isBiggerOrEqualValue(from) &
          task.dueAt.isSmallerThanValue(to);
      final undoneByCreation =
          task.dueAt.isNull() &
          task.createdAt.isBiggerOrEqualValue(from) &
          task.createdAt.isSmallerThanValue(to);
      return task.cancelled.equals(false) &
          task.parentTaskId.isNull() &
          (completedInRange |
              (task.completed.equals(false) &
                  (undoneByDue | undoneByCreation)));
    });
    // 无 orderBy 时 SQLite 的返回顺序不稳定，会让清单候选项抖动。
    taskQuery.orderBy([
      (task) => OrderingTerm(expression: task.createdAt),
      (task) => OrderingTerm(expression: task.id),
    ]);
    final tasks = await taskQuery.get();
    if (tasks.isEmpty) return const [];

    final taskIds = tasks.map((task) => task.id).toSet();
    final lists = await _db.select(_db.todoLists).get();
    final listNames = {for (final list in lists) list.id: list.name};

    final checklistItems = await (_db.select(
      _db.todoChecklistItems,
    )..where((item) => item.taskId.isIn(taskIds))).get();
    final checklistDone = <String, int>{};
    final checklistTotal = <String, int>{};
    for (final item in checklistItems) {
      checklistTotal[item.taskId] = (checklistTotal[item.taskId] ?? 0) + 1;
      if (item.completed) {
        checklistDone[item.taskId] = (checklistDone[item.taskId] ?? 0) + 1;
      }
    }

    final children = await (_db.select(
      _db.todoTasks,
    )..where((task) => task.parentTaskId.isIn(taskIds))).get();
    final subtaskDone = <String, int>{};
    final subtaskTotal = <String, int>{};
    for (final child in children) {
      final parentId = child.parentTaskId!;
      subtaskTotal[parentId] = (subtaskTotal[parentId] ?? 0) + 1;
      if (child.completed && !child.cancelled) {
        subtaskDone[parentId] = (subtaskDone[parentId] ?? 0) + 1;
      }
    }

    return [
      for (final task in tasks)
        SummaryTaskRow(
          taskId: task.id,
          title: task.title,
          listId: task.listId,
          listName: listNames[task.listId] ?? '未知清单',
          completed: task.completed,
          completedAt: task.completedAt,
          dueAt: task.dueAt,
          createdAt: task.createdAt,
          sortOrder: task.sortOrder,
          checklistDone: checklistDone[task.id] ?? 0,
          checklistTotal: checklistTotal[task.id] ?? 0,
          subtaskDone: subtaskDone[task.id] ?? 0,
          subtaskTotal: subtaskTotal[task.id] ?? 0,
        ),
    ];
  }
}

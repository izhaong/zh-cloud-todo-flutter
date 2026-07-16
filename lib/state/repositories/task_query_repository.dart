import '../../core/db/app_database.dart';

enum TaskSearchResultType { task, list, tag }

class TaskSearchResult {
  const TaskSearchResult({
    required this.type,
    required this.id,
    required this.title,
  });

  final TaskSearchResultType type;
  final String id;
  final String title;

  String get identity => '${type.name}:$id';
}

class TaskQueryFilter {
  const TaskQueryFilter({
    this.listId,
    this.priority,
    this.completed,
    this.tagIds = const [],
    this.keyword,
    this.dueAtFrom,
    this.dueAtTo,
  });

  final String? listId;
  final int? priority;
  final bool? completed;
  final List<String> tagIds;
  final String? keyword;
  final DateTime? dueAtFrom;
  final DateTime? dueAtTo;
}

class TaskQueryRepository {
  TaskQueryRepository(this._db);

  final AppDatabase _db;

  Future<List<TaskSearchResult>> search(String keyword) async {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final tasks = await _db.select(_db.todoTasks).get();
    final lists = await _db.select(_db.todoLists).get();
    final tags = await _db.select(_db.todoTags).get();
    final results = <TaskSearchResult>[
      ...tasks
          .where(
            (task) =>
                task.title.toLowerCase().contains(normalized) ||
                (task.description?.toLowerCase().contains(normalized) ?? false),
          )
          .map(
            (task) => TaskSearchResult(
              type: TaskSearchResultType.task,
              id: task.id,
              title: task.title,
            ),
          ),
      ...lists
          .where((list) => list.name.toLowerCase().contains(normalized))
          .map(
            (list) => TaskSearchResult(
              type: TaskSearchResultType.list,
              id: list.id,
              title: list.name,
            ),
          ),
      ...tags
          .where((tag) => tag.name.toLowerCase().contains(normalized))
          .map(
            (tag) => TaskSearchResult(
              type: TaskSearchResultType.tag,
              id: tag.id,
              title: tag.name,
            ),
          ),
    ];
    results.sort((left, right) {
      final byType = left.type.index.compareTo(right.type.index);
      if (byType != 0) return byType;
      final byTitle = left.title.compareTo(right.title);
      return byTitle != 0 ? byTitle : left.id.compareTo(right.id);
    });
    return results;
  }

  Future<List<TodoTask>> filter(TaskQueryFilter filter) async {
    if (filter.dueAtFrom != null &&
        filter.dueAtTo != null &&
        filter.dueAtFrom!.isAfter(filter.dueAtTo!)) {
      throw ArgumentError.value(filter, 'filter', '截止日期起点不能晚于终点');
    }
    final tasks = await _db.select(_db.todoTasks).get();
    final taskTags = await _db.select(_db.todoTaskTags).get();
    final tagIdsByTask = <String, Set<String>>{};
    for (final taskTag in taskTags) {
      tagIdsByTask.putIfAbsent(taskTag.taskId, () => {}).add(taskTag.tagId);
    }
    final normalizedKeyword = filter.keyword?.trim().toLowerCase();
    final results = tasks.where((task) {
      if (filter.listId != null && task.listId != filter.listId) return false;
      if (filter.priority != null && task.priority != filter.priority) {
        return false;
      }
      if (filter.completed != null && task.completed != filter.completed) {
        return false;
      }
      if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
        final matchesTitle = task.title.toLowerCase().contains(normalizedKeyword);
        final matchesDescription =
            task.description?.toLowerCase().contains(normalizedKeyword) ?? false;
        if (!matchesTitle && !matchesDescription) return false;
      }
      final dueAt = task.dueAt;
      if (filter.dueAtFrom != null &&
          (dueAt == null || dueAt.isBefore(filter.dueAtFrom!))) {
        return false;
      }
      if (filter.dueAtTo != null &&
          (dueAt == null || dueAt.isAfter(filter.dueAtTo!))) {
        return false;
      }
      return filter.tagIds.every(
        (tagId) => tagIdsByTask[task.id]?.contains(tagId) ?? false,
      );
    }).toList();
    results.sort((left, right) {
      if (left.isPinned != right.isPinned) {
        return left.isPinned ? -1 : 1;
      }
      final bySortOrder = left.sortOrder.compareTo(right.sortOrder);
      return bySortOrder != 0 ? bySortOrder : left.id.compareTo(right.id);
    });
    return results;
  }
}

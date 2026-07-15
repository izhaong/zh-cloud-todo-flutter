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
  });

  final String? listId;
  final int? priority;
  final bool? completed;
  final List<String> tagIds;
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
    final tasks = await _db.select(_db.todoTasks).get();
    final taskTags = await _db.select(_db.todoTaskTags).get();
    final tagIdsByTask = <String, Set<String>>{};
    for (final taskTag in taskTags) {
      tagIdsByTask.putIfAbsent(taskTag.taskId, () => {}).add(taskTag.tagId);
    }
    final results = tasks.where((task) {
      if (filter.listId != null && task.listId != filter.listId) return false;
      if (filter.priority != null && task.priority != filter.priority) {
        return false;
      }
      if (filter.completed != null && task.completed != filter.completed) {
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

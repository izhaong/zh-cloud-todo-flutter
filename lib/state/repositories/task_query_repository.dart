import '../../core/db/app_database.dart';
import '../../core/time/task_time_formatter.dart';

DateTime? _taskDueWallClock(TodoTask task) {
  final due = task.dueAt;
  if (due == null) return null;
  return taskWallClockDateTime(
    due,
    allDay: task.allDay,
    fixedTimezone: task.fixedTimezone,
    timeZone: task.timeZone,
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 用户在任务工作区中选择的主排序字段。
///
/// 所有排序仍固定以置顶、手工顺序与任务 UUID 作为额外键，确保
/// Drift 查询与 Widget 渲染在同值场景也拥有相同的确定性顺序。
enum TaskSort { smart, priorityDesc, dueDate, title, createdAt, updatedAt }

/// 时间轴方向的档位。
///
/// 嘀嗒《03-用分组和排序管理任务》只在「按创建时间排序」(:169-176) 与
/// 「按修改时间排序」(:186，方向条目在 :192-193) 两节下列出「从旧到新 / 从新到旧」，
/// 其余档位没有方向 ⇒ [compareTodoTasks] 只在这两档读取本参数。
/// [newestFirst] 排第一是因为它是默认值，也是本参数出现之前唯一的行为。
enum TaskSortDirection { newestFirst, oldestFirst }

int compareTodoTasks(
  TodoTask left,
  TodoTask right,
  TaskSort sort, {
  TaskSortDirection direction = TaskSortDirection.newestFirst,
}) {
  if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;

  final reversed = direction == TaskSortDirection.oldestFirst ? -1 : 1;
  final bySelectedField = switch (sort) {
    TaskSort.smart => 0,
    TaskSort.priorityDesc => right.priority.compareTo(left.priority),
    TaskSort.dueDate => (_taskDueWallClock(left) ?? DateTime(9999)).compareTo(
      _taskDueWallClock(right) ?? DateTime(9999),
    ),
    TaskSort.title => left.title.toLowerCase().compareTo(
      right.title.toLowerCase(),
    ),
    TaskSort.createdAt => reversed * right.createdAt.compareTo(left.createdAt),
    TaskSort.updatedAt => reversed * right.updatedAt.compareTo(left.updatedAt),
  };
  if (bySelectedField != 0) return bySelectedField;

  final byManualOrder = left.sortOrder.compareTo(right.sortOrder);
  return byManualOrder != 0 ? byManualOrder : left.id.compareTo(right.id);
}

enum TaskSearchResultType { task, list, tag }

/// 搜索页当前展示的实体范围。
///
/// `all` 保留既有“任务优先、清单、标签”的稳定顺序；其余范围只保留对应实体。
enum TaskSearchScope { all, task, list, tag }

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

/// 离线搜索的可复现分页请求。
///
/// 任务筛选只适用于 [TaskSearchScope.task]，由调用方在选择其它范围时保留但不应用，
/// 从而在切回任务范围后仍能恢复用户当前筛选。
class TaskSearchPageRequest {
  const TaskSearchPageRequest({
    required this.keyword,
    this.scope = TaskSearchScope.all,
    this.filter = const TaskQueryFilter(),
    this.offset = 0,
    this.limit = 50,
  });

  final String keyword;
  final TaskSearchScope scope;
  final TaskQueryFilter filter;
  final int offset;
  final int limit;
}

/// 一页本地搜索结果；[total] 是应用范围和任务筛选后的总数。
class TaskSearchPageResult {
  const TaskSearchPageResult({required this.results, required this.total});

  final List<TaskSearchResult> results;
  final int total;
}

class TaskQueryFilter {
  const TaskQueryFilter({
    this.listId,
    this.priority,
    this.completed,
    this.assigneeUserId,
    this.tagIds = const [],
    this.keyword,
    this.dueAtFrom,
    this.dueAtTo,
    this.sort = TaskSort.smart,
    this.sortDirection = TaskSortDirection.newestFirst,
  });

  final String? listId;
  final int? priority;
  final bool? completed;
  final int? assigneeUserId;
  final List<String> tagIds;
  final String? keyword;
  final DateTime? dueAtFrom;
  final DateTime? dueAtTo;
  final TaskSort sort;
  final TaskSortDirection sortDirection;
}

class TaskQueryRepository {
  TaskQueryRepository(this._db);

  final AppDatabase _db;

  Future<List<TaskSearchResult>> search(String keyword) async {
    final entries = await _db.searchIndex(keyword);
    return entries
        .map(
          (entry) => TaskSearchResult(
            type: switch (entry.entityType) {
              'task' => TaskSearchResultType.task,
              'list' => TaskSearchResultType.list,
              'tag' => TaskSearchResultType.tag,
              _ => throw StateError('未知搜索索引实体：${entry.entityType}'),
            },
            id: entry.entityId,
            title: entry.title,
          ),
        )
        .toList(growable: false);
  }

  /// 在本地 FTS 结果上应用实体范围和任务组合筛选后，返回稳定分页。
  ///
  /// FTS 已按任务、清单、标签、标题和实体 ID 排序；任务范围额外只保留既有
  /// [filter] 结果中的本地 UUID。先完成交集再切页，避免筛选后的第二页出现空洞。
  Future<TaskSearchPageResult> searchPage(TaskSearchPageRequest request) async {
    if (request.offset < 0) {
      throw ArgumentError.value(request.offset, 'offset', '搜索偏移量不能小于零');
    }
    if (request.limit < 1 || request.limit > 50) {
      throw ArgumentError.value(request.limit, 'limit', '搜索页长必须在 1 到 50 之间');
    }

    final allEntries = await search(request.keyword);
    final scopedEntries = allEntries.where(
      (entry) => switch (request.scope) {
        TaskSearchScope.all => true,
        TaskSearchScope.task => entry.type == TaskSearchResultType.task,
        TaskSearchScope.list => entry.type == TaskSearchResultType.list,
        TaskSearchScope.tag => entry.type == TaskSearchResultType.tag,
      },
    );
    final filteredEntries = request.scope == TaskSearchScope.task
        ? await _filterTaskSearchEntries(scopedEntries, request.filter)
        : scopedEntries.toList(growable: false);
    final total = filteredEntries.length;
    final pageStart = request.offset.clamp(0, total);
    final pageEnd = (pageStart + request.limit).clamp(pageStart, total);
    return TaskSearchPageResult(
      results: filteredEntries.sublist(pageStart, pageEnd),
      total: total,
    );
  }

  Future<List<TaskSearchResult>> _filterTaskSearchEntries(
    Iterable<TaskSearchResult> entries,
    TaskQueryFilter filter,
  ) async {
    final taskIds = (await this.filter(filter)).map((task) => task.id).toSet();
    return entries
        .where((entry) => taskIds.contains(entry.id))
        .toList(growable: false);
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
      if (filter.assigneeUserId != null &&
          task.assigneeUserId != filter.assigneeUserId) {
        return false;
      }
      if (normalizedKeyword != null && normalizedKeyword.isNotEmpty) {
        final matchesTitle = task.title.toLowerCase().contains(
          normalizedKeyword,
        );
        final matchesDescription =
            task.description?.toLowerCase().contains(normalizedKeyword) ??
            false;
        if (!matchesTitle && !matchesDescription) return false;
      }
      final dueAt = _taskDueWallClock(task);
      final dueDay = dueAt == null ? null : _dateOnly(dueAt);
      if (filter.dueAtFrom != null &&
          (dueDay == null || dueDay.isBefore(_dateOnly(filter.dueAtFrom!)))) {
        return false;
      }
      if (filter.dueAtTo != null &&
          (dueDay == null || dueDay.isAfter(_dateOnly(filter.dueAtTo!)))) {
        return false;
      }
      return filter.tagIds.every(
        (tagId) => tagIdsByTask[task.id]?.contains(tagId) ?? false,
      );
    }).toList();
    results.sort(
      (left, right) => compareTodoTasks(
        left,
        right,
        filter.sort,
        direction: filter.sortDirection,
      ),
    );
    return results;
  }
}

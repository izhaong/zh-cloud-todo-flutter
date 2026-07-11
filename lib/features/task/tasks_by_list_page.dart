import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../../state/repositories/task_repository.dart';
import '../filter/filter_bar.dart';
import '../shell/quick_add_bar.dart';
import 'view_mode.dart';
import 'views/calendar_view.dart';
import 'views/eisenhower_view.dart';
import 'views/kanban_view.dart';
import 'views/timeline_view.dart';
import 'widgets/task_group_header.dart';
import 'widgets/task_row_host.dart';
import 'widgets/task_workspace_header.dart';

/// Task workspace body driven by the parent sidebar selection.
class TasksByListPage extends ConsumerStatefulWidget {
  const TasksByListPage({
    super.key,
    this.title = '任务',
    this.initialListId,
    this.initialDueRange,
    this.initialCompleted,
    this.lockedListId = false,
    this.hideAppBar = false,
    this.selectedTaskId,
    this.onTaskSelected,
    this.onSelectionInvalidated,
    this.onQuickAdd,
  });

  final String title;
  final String? initialListId;
  final String? initialDueRange;
  final bool? initialCompleted;
  final bool lockedListId;
  final bool hideAppBar;
  final String? selectedTaskId;
  final ValueChanged<String>? onTaskSelected;
  final ValueChanged<String>? onSelectionInvalidated;
  final QuickAddSubmitCallback? onQuickAdd;

  @override
  ConsumerState<TasksByListPage> createState() => _TasksByListPageState();
}

/// Synthetic local list used by tasks that have not been filed elsewhere.
const String kInboxListId = 'inbox';

class _TasksByListPageState extends ConsumerState<TasksByListPage> {
  String? _selectedListId;
  TaskFilter _filter = TaskFilter();
  TaskViewMode _mode = TaskViewMode.list;
  TaskSort _sort = TaskSort.smart;
  TaskRepository? _streamRepository;
  String? _streamListId;
  Stream<List<TodoTask>>? _tasksStream;
  int _visibilityRevision = 0;
  Set<String> _latestVisibleTaskIds = const {};
  String? _trackedSelectedTaskId;
  bool? _selectedTaskLastCompleted;
  String? _completionInvalidationTaskId;
  String? _reportedInvalidSelectionId;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId;
    _filter = TaskFilter(
      dueRange: widget.initialDueRange,
      completed: widget.initialCompleted,
    );
  }

  @override
  void didUpdateWidget(covariant TasksByListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lockedListId &&
        widget.initialListId != oldWidget.initialListId) {
      setState(() => _selectedListId = widget.initialListId);
    }
    if (widget.initialDueRange != oldWidget.initialDueRange ||
        widget.initialCompleted != oldWidget.initialCompleted) {
      setState(() {
        _filter = TaskFilter(
          dueRange: widget.initialDueRange,
          completed: widget.initialCompleted,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final taskRepo = ref.watch(taskRepositoryProvider);
    final now = ref.watch(currentDateTimeProvider)();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final desktopMode = viewportWidth >= TodoLayoutTokens.compactMinWidth;
    final showQuickAdd = viewportWidth >= TodoLayoutTokens.tabletMinWidth;
    final mobileMode = viewportWidth < TodoLayoutTokens.tabletMinWidth;

    if (taskRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasksStream = _resolveTasksStream(taskRepo);

    final body = StreamBuilder<List<TodoTask>>(
      stream: tasksStream,
      builder: (context, snapshot) {
        final raw = snapshot.data ?? const <TodoTask>[];
        final items = _applyFilter(raw, _filter, _selectedListId, now);
        if (snapshot.hasData) {
          _reportInvalidSelection(items);
        }

        final modeBody = snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : _buildModeBody(items, desktopMode: desktopMode, now: now);
        final workspace = Column(
          children: [
            if (widget.hideAppBar)
              TaskWorkspaceHeader(
                title: widget.title,
                taskCount: items.length,
                mode: _mode,
                sort: _sort,
                filterActive: !_filter.isEmpty,
                onModeChanged: _changeMode,
                onSortChanged: (sort) => setState(() => _sort = sort),
                onFilterPressed: _openFilterPanel,
              ),
            if (showQuickAdd) QuickAddBar(onSubmit: _submitQuickAdd),
            Expanded(
              child: mobileMode
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 72),
                      child: modeBody,
                    )
                  : modeBody,
            ),
          ],
        );
        if (!mobileMode) return workspace;
        return Stack(
          children: [
            workspace,
            Positioned(
              right: 16,
              bottom: 16,
              child: MobileQuickAddButton(onSubmit: _submitQuickAdd),
            ),
          ],
        );
      },
    );
    if (widget.hideAppBar) {
      return ColoredBox(color: colors.surface, child: body);
    }
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(widget.title), centerTitle: false),
      body: body,
    );
  }

  Widget _buildModeBody(
    List<TodoTask> items, {
    required bool desktopMode,
    required DateTime now,
  }) {
    switch (_mode) {
      case TaskViewMode.list:
        return _ListBody(
          items: items,
          sort: _sort,
          desktopMode: desktopMode,
          now: now,
          selectedTaskId: widget.selectedTaskId,
          onTaskSelected: widget.onTaskSelected,
        );
      case TaskViewMode.kanban:
        return KanbanView(
          tasks: items,
          listId: _selectedListId,
          onTaskSelected: widget.onTaskSelected,
        );
      case TaskViewMode.timeline:
        return TimelineView(
          tasks: items,
          onTaskSelected: widget.onTaskSelected,
        );
      case TaskViewMode.eisenhower:
        return EisenhowerView(
          tasks: items,
          onTaskSelected: widget.onTaskSelected,
        );
      case TaskViewMode.calendar:
        return CalendarView(
          tasks: items,
          onTaskSelected: widget.onTaskSelected,
        );
    }
  }

  void _changeMode(TaskViewMode mode) {
    setState(() => _mode = mode);
    ref
        .read(syncChangeQueueProvider)
        ?.enqueue(
          entity: 'view_preference',
          op: 'upsert',
          payload: {
            'sourceType': 'task_view',
            'sourceKey': 'tasks_by_list',
            'viewType': mode.name,
          },
        );
  }

  Stream<List<TodoTask>> _resolveTasksStream(TaskRepository repository) {
    if (!identical(_streamRepository, repository) ||
        _streamListId != _selectedListId ||
        _tasksStream == null) {
      _streamRepository = repository;
      _streamListId = _selectedListId;
      _tasksStream = _selectedListId == null
          ? repository.watchAll()
          : repository.watchTopLevelByList(_selectedListId!);
    }
    return _tasksStream!;
  }

  void _reportInvalidSelection(List<TodoTask> visibleTasks) {
    final revision = ++_visibilityRevision;
    final tasksById = {for (final task in visibleTasks) task.id: task};
    final actualVisibleTasks = switch (_mode) {
      TaskViewMode.timeline ||
      TaskViewMode.eisenhower => visibleTasks.where((task) => !task.completed),
      _ => visibleTasks,
    };
    _latestVisibleTaskIds = actualVisibleTasks.map((task) => task.id).toSet();
    final selectedTaskId = widget.selectedTaskId;

    if (selectedTaskId != _trackedSelectedTaskId) {
      _trackedSelectedTaskId = selectedTaskId;
      _selectedTaskLastCompleted = selectedTaskId == null
          ? null
          : tasksById[selectedTaskId]?.completed;
      _completionInvalidationTaskId = null;
      _reportedInvalidSelectionId = null;
    } else if (selectedTaskId != null) {
      final completed = tasksById[selectedTaskId]?.completed;
      if (_selectedTaskLastCompleted == false && completed == true) {
        _completionInvalidationTaskId = selectedTaskId;
      }
      if (completed != null) {
        _selectedTaskLastCompleted = completed;
      }
    }

    final hidden =
        selectedTaskId != null &&
        !_latestVisibleTaskIds.contains(selectedTaskId);
    final becameCompleted = _completionInvalidationTaskId == selectedTaskId;
    if (selectedTaskId == null || (!hidden && !becameCompleted)) {
      if (_reportedInvalidSelectionId == selectedTaskId) {
        _reportedInvalidSelectionId = null;
      }
      return;
    }
    if (_reportedInvalidSelectionId == selectedTaskId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          revision != _visibilityRevision ||
          widget.selectedTaskId != selectedTaskId ||
          (_latestVisibleTaskIds.contains(selectedTaskId) &&
              _completionInvalidationTaskId != selectedTaskId)) {
        return;
      }
      _reportedInvalidSelectionId = selectedTaskId;
      if (_completionInvalidationTaskId == selectedTaskId) {
        _completionInvalidationTaskId = null;
      }
      widget.onSelectionInvalidated?.call(selectedTaskId);
    });
  }

  Future<void> _submitQuickAdd(String title) async {
    final callback = widget.onQuickAdd;
    if (callback != null) {
      await callback(title);
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.create(listId: _selectedListId ?? kInboxListId, title: title);
  }

  Future<void> _openFilterPanel() async {
    var draft = _filter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '筛选任务',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                FilterBar(
                  filter: draft,
                  onChanged: (next) {
                    draft = next;
                    setState(() => _filter = next);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListBody extends StatefulWidget {
  const _ListBody({
    required this.items,
    required this.sort,
    required this.desktopMode,
    required this.now,
    required this.selectedTaskId,
    required this.onTaskSelected,
  });

  final List<TodoTask> items;
  final TaskSort sort;
  final bool desktopMode;
  final DateTime now;
  final String? selectedTaskId;
  final ValueChanged<String>? onTaskSelected;

  @override
  State<_ListBody> createState() => _ListBodyState();
}

class _ListBodyState extends State<_ListBody> {
  List<String> _orderedIds = const [];
  bool _hasCustomOrder = false;

  @override
  void initState() {
    super.initState();
    _orderedIds = _sortedItems(widget.items).map((task) => task.id).toList();
  }

  @override
  void didUpdateWidget(covariant _ListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sort != widget.sort) {
      _hasCustomOrder = false;
    }
    final currentIds = _sortedItems(
      widget.items,
    ).map((task) => task.id).toList();
    if (!_hasCustomOrder) {
      _orderedIds = currentIds;
      return;
    }
    _orderedIds = _normalizeTaskIds(_orderedIds, currentIds);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const AppEmptyState(title: '暂无任务', subtitle: '在上方输入任务并按回车。');
    }

    final sortedItems = _sortedItems(widget.items);
    final byId = {for (final task in sortedItems) task.id: task};
    final ordered =
        (_hasCustomOrder
                ? _orderedIds
                : sortedItems.map((task) => task.id).toList())
            .map((id) => byId[id])
            .whereType<TodoTask>()
            .toList(growable: false);
    final groups = _groupTasks(ordered, widget.now);
    final entries = <Object>[
      for (final group in groups) ...[group, ...group.tasks],
    ];

    if (widget.desktopMode) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(
          bottom: TodoLayoutTokens.mainHorizontalInset,
        ),
        itemCount: entries.length,
        onReorder: (oldIndex, newIndex) {
          final entry = entries[oldIndex];
          if (entry is! TodoTask) return;
          final visibleTaskIds = entries
              .whereType<TodoTask>()
              .map((task) => task.id)
              .toList();
          var targetEntryIndex = newIndex;
          if (targetEntryIndex > oldIndex) targetEntryIndex -= 1;
          targetEntryIndex = targetEntryIndex.clamp(0, entries.length);
          var insertionIndex = 0;
          for (var index = 0; index < targetEntryIndex; index++) {
            final candidate = entries[index];
            if (candidate is TodoTask && candidate.id != entry.id) {
              insertionIndex++;
            }
          }
          final reordered = [...visibleTaskIds]..remove(entry.id);
          insertionIndex = insertionIndex.clamp(0, reordered.length);
          reordered.insert(insertionIndex, entry.id);
          setState(() {
            _orderedIds = reordered;
            _hasCustomOrder = true;
          });
        },
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry is _TaskGroup) {
            return TaskGroupHeader(
              key: Key('todo-task-group-${entry.id}'),
              title: entry.title,
              count: entry.tasks.length,
            );
          }
          final task = entry as TodoTask;
          return KeyedSubtree(
            key: ValueKey(task.id),
            child: TaskRowHost(
              task: task,
              desktopMode: true,
              enableSwipeGestures: false,
              reorderIndex: index,
              selected: widget.selectedTaskId == task.id,
              onTap: widget.onTaskSelected,
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        bottom: TodoLayoutTokens.mainHorizontalInset,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is _TaskGroup) {
          return TaskGroupHeader(
            key: Key('todo-task-group-${entry.id}'),
            title: entry.title,
            count: entry.tasks.length,
          );
        }
        final task = entry as TodoTask;
        return TaskRowHost(
          task: task,
          selected: widget.selectedTaskId == task.id,
          onTap: widget.onTaskSelected,
        );
      },
    );
  }

  List<TodoTask> _sortedItems(List<TodoTask> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (widget.sort) {
        case TaskSort.smart:
          return b.updatedAt.compareTo(a.updatedAt);
        case TaskSort.priorityDesc:
          return b.priority.compareTo(a.priority);
        case TaskSort.dueDate:
          return (a.dueAt ?? DateTime(9999)).compareTo(
            b.dueAt ?? DateTime(9999),
          );
        case TaskSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TaskSort.createdAt:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return sorted;
  }
}

class _TaskGroup {
  const _TaskGroup({
    required this.id,
    required this.title,
    required this.tasks,
  });

  final String id;
  final String title;
  final List<TodoTask> tasks;
}

List<_TaskGroup> _groupTasks(List<TodoTask> tasks, DateTime now) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final grouped = <String, List<TodoTask>>{
    'pinned': [],
    'overdue': [],
    'today': [],
    'upcoming': [],
    'no-date': [],
    'completed': [],
  };

  for (final task in tasks) {
    if (task.completed) {
      grouped['completed']!.add(task);
      continue;
    }
    if (task.isPinned) {
      grouped['pinned']!.add(task);
      continue;
    }
    final due = task.dueAt;
    if (due == null) {
      grouped['no-date']!.add(task);
    } else if (due.isBefore(startOfDay)) {
      grouped['overdue']!.add(task);
    } else if (due.isBefore(endOfDay)) {
      grouped['today']!.add(task);
    } else {
      grouped['upcoming']!.add(task);
    }
  }

  const definitions = [
    ('pinned', '置顶'),
    ('overdue', '已逾期'),
    ('today', '今天'),
    ('upcoming', '接下来'),
    ('no-date', '无日期'),
    ('completed', '已完成'),
  ];
  return [
    for (final (id, title) in definitions)
      if (grouped[id]!.isNotEmpty)
        _TaskGroup(id: id, title: title, tasks: grouped[id]!),
  ];
}

List<TodoTask> _applyFilter(
  List<TodoTask> source,
  TaskFilter filter,
  String? selectedListId,
  DateTime now,
) {
  if (filter.isEmpty && selectedListId == null) return source;
  final startOfDay = DateTime(now.year, now.month, now.day);
  final todayEnd = startOfDay.add(const Duration(days: 1));

  return source.where((task) {
    if (selectedListId != null && task.listId != selectedListId) return false;
    if (filter.listId != null && task.listId != filter.listId) return false;
    if (filter.priority != null && task.priority != filter.priority) {
      return false;
    }
    if (filter.completed != null && task.completed != filter.completed) {
      return false;
    }
    if (filter.dueRange != null) {
      final due = task.dueAt;
      if (due == null) return false;
      switch (filter.dueRange) {
        case 'today':
          if (due.isBefore(startOfDay) || !due.isBefore(todayEnd)) return false;
        case 'tomorrow':
          final tomorrowEnd = todayEnd.add(const Duration(days: 1));
          if (due.isBefore(todayEnd) || !due.isBefore(tomorrowEnd)) {
            return false;
          }
        case 'last7days':
          final weekStart = startOfDay.subtract(const Duration(days: 7));
          if (due.isBefore(weekStart) || !due.isBefore(todayEnd)) return false;
        case 'overdue':
          if (!due.isBefore(startOfDay)) return false;
        case 'future':
          if (due.isBefore(todayEnd)) return false;
      }
    }
    return true;
  }).toList();
}

List<String> reorderTaskIds(List<String> ids, int oldIndex, int newIndex) {
  final next = [...ids];
  if (oldIndex < 0 || oldIndex >= next.length) return next;
  final item = next.removeAt(oldIndex);
  if (newIndex > next.length) newIndex = next.length;
  if (newIndex > oldIndex) newIndex -= 1;
  next.insert(newIndex, item);
  return next;
}

List<String> _normalizeTaskIds(
  List<String> orderedIds,
  List<String> currentIds,
) {
  final kept = orderedIds.where(currentIds.contains).toList(growable: true);
  for (final id in currentIds) {
    if (!kept.contains(id)) kept.add(id);
  }
  return kept;
}

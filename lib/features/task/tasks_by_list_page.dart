import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../core/time/task_time_formatter.dart';
import '../../core/widgets/app_widgets.dart';
import '../../native/native_intents.dart';
import '../../state/nlp_date.dart';
import '../../state/providers.dart';
import '../../state/repositories/board_preference_repository.dart';
import '../../state/repositories/task_batch_edit_repository.dart';
import '../../state/repositories/task_query_repository.dart';
import '../../state/repositories/task_repository.dart';
import '../filter/filter_bar.dart';
import '../quadrant/quadrant_rules_page.dart';
import '../shell/app_dialog.dart';
import '../shell/quick_add_bar.dart';
import 'task_view_mutation_feedback.dart';
import 'view_mode.dart';
import 'views/calendar_view.dart';
import 'views/eisenhower_view.dart';
import 'views/kanban_view.dart';
import 'views/timeline_view.dart';
import 'widgets/task_batch_action_bar.dart';
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
    this.initialFilter,
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

  /// 从「筛选器」页套用进来的已保存条件；与 `initialDueRange` 同属外部播种。
  final TaskFilter? initialFilter;
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
  double _timelineZoom = 1;
  TimelineScale _timelineScale = TimelineScale.week;
  Set<String> _collapsedTimelineGroupIds = const {};
  TaskRepository? _streamRepository;
  String? _streamListId;
  Stream<List<TodoTask>>? _tasksStream;
  int _visibilityRevision = 0;
  Set<String> _latestVisibleTaskIds = const {};
  String? _trackedSelectedTaskId;
  bool? _selectedTaskLastCompleted;
  String? _completionInvalidationTaskId;
  String? _reportedInvalidSelectionId;
  bool _batchSelectionActive = false;
  bool _batchApplying = false;
  String? _batchSelectionAnchorTaskId;
  final Set<String> _batchSelectedTaskIds = <String>{};
  int _viewRestoreRevision = 0;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId;
    _filter =
        widget.initialFilter ??
        TaskFilter(
          dueRange: widget.initialDueRange,
          completed: widget.initialCompleted,
        );
    Future<void>.microtask(_restoreSortPreference);
    Future<void>.microtask(_restoreViewPreference);
  }

  @override
  void didUpdateWidget(covariant TasksByListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listSourceChanged =
        widget.lockedListId && widget.initialListId != oldWidget.initialListId;
    final filterSourceChanged =
        widget.initialDueRange != oldWidget.initialDueRange ||
        widget.initialCompleted != oldWidget.initialCompleted ||
        !identical(widget.initialFilter, oldWidget.initialFilter);
    if (listSourceChanged || filterSourceChanged) {
      _viewRestoreRevision++;
      setState(() {
        if (listSourceChanged) {
          _selectedListId = widget.initialListId;
          _batchSelectionActive = false;
          _batchSelectionAnchorTaskId = null;
          _batchSelectedTaskIds.clear();
        }
        if (filterSourceChanged) {
          _filter =
              widget.initialFilter ??
              TaskFilter(
                dueRange: widget.initialDueRange,
                completed: widget.initialCompleted,
              );
        }
        _mode = TaskViewMode.list;
        _timelineZoom = 1;
        _timelineScale = TimelineScale.week;
        _collapsedTimelineGroupIds = const {};
      });
    }
    if (listSourceChanged) {
      Future<void>.microtask(_restoreSortPreference);
    }
    if (listSourceChanged || filterSourceChanged) {
      Future<void>.microtask(_restoreViewPreference);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final taskRepo = ref.watch(taskRepositoryProvider);
    final tagOptions = (ref.watch(tagsStreamProvider).valueOrNull ?? const [])
        .map((tag) => QuickAddTagOption(id: tag.id, name: tag.name))
        .toList(growable: false);
    final now = ref.watch(currentDateTimeProvider)();
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final desktopMode = viewportWidth >= TodoLayoutTokens.compactMinWidth;
    final showQuickAdd = viewportWidth >= TodoLayoutTokens.tabletMinWidth;
    final mobileMode = viewportWidth < TodoLayoutTokens.tabletMinWidth;
    final listId = _selectedListId;
    final taskSections = listId == null
        ? const <TodoTaskSection>[]
        : ref.watch(taskSectionsByListProvider(listId)).valueOrNull ??
              const <TodoTaskSection>[];

    if (taskRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasksStream = _resolveTasksStream(taskRepo);

    final body = StreamBuilder<List<TodoTask>>(
      stream: tasksStream,
      builder: (context, snapshot) {
        final raw = snapshot.data ?? const <TodoTask>[];
        final items = applyTaskFilter(raw, _filter, _selectedListId, now);
        final listOrderedItems = _visibleTasksInListOrder(
          items,
          sections: taskSections,
          sort: _sort,
          now: now,
        );
        if (snapshot.hasData) {
          _reportInvalidSelection(items);
        }

        final showBatchActionBar =
            _batchSelectionActive && _batchSelectedTaskIds.isNotEmpty;
        final modeBody = snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : _buildModeBody(
                items,
                taskSections: taskSections,
                desktopMode: desktopMode,
                now: now,
              );
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
                onSortChanged: _changeSort,
                onFilterPressed: () => _openFilterPanel(raw),
                batchSelectionActive: _batchSelectionActive,
                onBatchPressed: _toggleBatchSelection,
                onCreateSection: _mode == TaskViewMode.list && listId != null
                    ? _createTaskSection
                    : null,
                onEditQuadrantRules: _mode == TaskViewMode.eisenhower
                    ? _openQuadrantRules
                    : null,
              ),
            if (showQuickAdd && !_batchSelectionActive)
              QuickAddBar(onSubmit: _submitQuickAdd, tagOptions: tagOptions),
            if (_mode == TaskViewMode.list && taskSections.isNotEmpty)
              _TaskSectionManagerBar(
                sections: taskSections,
                onCreate: _createTaskSection,
                onRename: _renameTaskSection,
                onDelete: _deleteTaskSection,
                onMove: _moveTaskSection,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: showBatchActionBar
                      ? 88
                      : mobileMode
                      ? 72
                      : 0,
                ),
                child: modeBody,
              ),
            ),
          ],
        );
        return Stack(
          children: [
            workspace,
            if (showBatchActionBar)
              Positioned(
                left: mobileMode ? 12 : 24,
                right: mobileMode ? 12 : 24,
                bottom: mobileMode ? 12 : 18,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: AnimatedSwitcher(
                      duration: TodoLayoutTokens.stateTransitionDurationFor(
                        context,
                      ),
                      child: TaskBatchActionBar(
                        selectedCount: _batchSelectedTaskIds.length,
                        applying: _batchApplying,
                        onExit: _toggleBatchSelection,
                        onComplete: _completeBatchSelection,
                        onActionSelected: (action) => _applyBatchAction(
                          action,
                          visibleTasks: listOrderedItems,
                        ),
                        onDelete: _confirmBatchDelete,
                      ),
                    ),
                  ),
                ),
              ),
            if (mobileMode && !_batchSelectionActive)
              Positioned(
                right: 16,
                bottom: 16,
                child: MobileQuickAddButton(
                  onSubmit: _submitQuickAdd,
                  tagOptions: tagOptions,
                ),
              ),
          ],
        );
      },
    );
    if (widget.hideAppBar) {
      return Material(color: colors.surface, child: body);
    }
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          if (_mode == TaskViewMode.list && _selectedListId != null)
            IconButton(
              key: const Key('todo-section-create-appbar'),
              tooltip: '新建分组',
              onPressed: _createTaskSection,
              icon: const Icon(Icons.playlist_add),
            ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildModeBody(
    List<TodoTask> items, {
    required List<TodoTaskSection> taskSections,
    required bool desktopMode,
    required DateTime now,
  }) {
    switch (_mode) {
      case TaskViewMode.list:
        return _ListBody(
          items: items,
          sections: taskSections,
          sort: _sort,
          desktopMode: desktopMode,
          now: now,
          selectedTaskId: widget.selectedTaskId,
          onTaskSelected: widget.onTaskSelected,
          onTasksReordered: _selectedListId == null || taskSections.isNotEmpty
              ? null
              : (taskIds) async {
                  final repository = ref.read(taskViewActionRepositoryProvider);
                  if (repository == null) return;
                  await repository.reorderListTasks(taskIds);
                },
          batchSelectionActive: _batchSelectionActive,
          batchSelectedTaskIds: _batchSelectedTaskIds,
          onBatchSelectionChanged: _updateBatchSelection,
          onBatchSelectionRequested: _handleBatchSelectionRequest,
        );
      case TaskViewMode.kanban:
        final listId = _selectedListId;
        final boardPreference = listId == null
            ? const BoardViewPreference()
            : ref.watch(boardViewPreferenceProvider(listId)).valueOrNull ??
                  const BoardViewPreference();
        final hasRecoverablePreference =
            listId != null &&
            (ref
                    .watch(boardPreferenceRecoveryAvailableProvider(listId))
                    .valueOrNull ??
                false);
        return KanbanView(
          tasks: items,
          listId: listId,
          orderedColumnIds: boardPreference.orderedColumnIds,
          collapsedColumnIds: boardPreference.collapsedColumnIds,
          onColumnOrderChanged: listId == null
              ? null
              : (order) => _saveBoardLayout(
                  listId: listId,
                  order: order,
                  collapsed: boardPreference.collapsedColumnIds,
                ),
          onColumnCollapsedChanged: listId == null
              ? null
              : (columnId, collapsed) {
                  final next = Set<String>.from(
                    boardPreference.collapsedColumnIds,
                  );
                  if (collapsed) {
                    next.add(columnId);
                  } else {
                    next.remove(columnId);
                  }
                  return _saveBoardLayout(
                    listId: listId,
                    order: boardPreference.orderedColumnIds,
                    collapsed: next,
                  );
                },
          hasRecoverablePreference: hasRecoverablePreference,
          onRecoverPreference: !hasRecoverablePreference
              ? null
              : () async {
                  final repository = ref.read(
                    boardPreferenceRepositoryProvider,
                  );
                  final recovered =
                      await repository?.recoverLatestFailed(listId: listId) ??
                      false;
                  ref.invalidate(
                    boardPreferenceRecoveryAvailableProvider(listId),
                  );
                  return recovered;
                },
          onTaskSelected: widget.onTaskSelected,
          onTaskMove: (task, priority, completed) async {
            final repository = ref.read(taskViewActionRepositoryProvider);
            if (repository == null) return;
            await repository.moveKanbanTask(
              task.id,
              priority: priority,
              completed: completed,
            );
          },
          onColumnTasksReordered: (taskIds) async {
            final repository = ref.read(taskViewActionRepositoryProvider);
            if (repository == null) return;
            await repository.reorderListTasks(taskIds);
          },
        );
      case TaskViewMode.timeline:
        return TimelineView(
          tasks: items,
          zoom: _timelineZoom,
          scale: _timelineScale,
          collapsedGroupIds: _collapsedTimelineGroupIds,
          onZoomChanged: _changeTimelineZoom,
          onScaleChanged: _changeTimelineScale,
          onGroupCollapsedChanged: _changeTimelineGroupCollapsed,
          onTaskSelected: widget.onTaskSelected,
          onCreateTask: (request) async {
            final repository = ref.read(taskRepositoryProvider);
            if (repository == null) return;
            await repository.create(
              listId: _selectedListId ?? kInboxListId,
              title: request.title,
              startAt: request.startAt,
              endAt: request.endAt,
              dueAt: request.dueAt,
              allDay: request.allDay,
            );
          },
          onTaskSchedule:
              (
                task, {
                required startAt,
                required endAt,
                required dueAt,
                required allDay,
              }) async {
                final repository = ref.read(taskViewActionRepositoryProvider);
                if (repository == null) return;
                await repository.scheduleTimelineTask(
                  task.id,
                  startAt: startAt,
                  endAt: endAt,
                  dueAt: dueAt,
                  allDay: allDay,
                );
              },
          onTaskTimeChange:
              (task, {required startAt, required endAt, required dueAt}) async {
                final repository = ref.read(taskViewActionRepositoryProvider);
                if (repository == null) return;
                await repository.moveTimelineTask(
                  task.id,
                  startAt: startAt,
                  endAt: endAt,
                  dueAt: dueAt,
                );
              },
        );
      case TaskViewMode.eisenhower:
        return EisenhowerView(
          tasks: items,
          onTaskSelected: widget.onTaskSelected,
        );
      case TaskViewMode.calendar:
        return CalendarView(
          tasks: items,
          // 已完成显隐由清单筛选决定，不再叠一层日历自身的开关。
          filterCompleted: false,
          onTaskSelected: widget.onTaskSelected,
          onTaskDateChanged: (task, dueAt) async {
            final repository = ref.read(taskViewActionRepositoryProvider);
            if (repository == null) return;
            await repository.moveCalendarTask(task.id, dueAt: dueAt);
          },
        );
    }
  }

  Future<void> _restoreSortPreference() async {
    final repository = ref.read(taskSortPreferenceRepositoryProvider);
    final sort = await repository?.get(_selectedListId);
    if (mounted && sort != null) setState(() => _sort = sort);
  }

  Future<void> _restoreViewPreference() async {
    final revision = ++_viewRestoreRevision;
    final repository = ref.read(taskViewActionRepositoryProvider);
    final sourceKey = _viewPreferenceSourceKey;
    final preference = await repository?.getTaskWorkspacePreference(
      sourceKey: sourceKey,
    );
    if (!mounted ||
        sourceKey != _viewPreferenceSourceKey ||
        revision != _viewRestoreRevision) {
      return;
    }
    final restoredMode = TaskViewMode.values
        .where((mode) => mode.name == preference?.viewType)
        .firstOrNull;
    setState(() {
      _mode = restoredMode ?? TaskViewMode.list;
      _timelineZoom = preference?.timelineZoom ?? 1;
      _timelineScale =
          TimelineScale.values
              .where((scale) => scale.name == preference?.timelineScale)
              .firstOrNull ??
          TimelineScale.week;
      _collapsedTimelineGroupIds =
          preference?.collapsedTimelineGroupIds ?? const {};
    });
  }

  Future<void> _changeSort(TaskSort sort) async {
    setState(() => _sort = sort);
    try {
      await ref
          .read(taskSortPreferenceRepositoryProvider)
          ?.save(_selectedListId, sort);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('排序偏好保存失败，请稍后重试')));
    }
  }

  /// 嘀嗒《03-四象限/02-如何编辑四象限规则》：四象限页面右上角「...」里选「编辑」进规则页。
  void _openQuadrantRules() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const QuadrantRulesPage()));
  }

  Future<void> _changeMode(TaskViewMode mode) async {
    _viewRestoreRevision++;
    setState(() {
      _mode = mode;
      _batchSelectionActive = false;
      _batchSelectionAnchorTaskId = null;
      _batchSelectedTaskIds.clear();
    });
    final repository = ref.read(taskViewActionRepositoryProvider);
    if (repository == null) return;
    try {
      await repository.saveTaskWorkspaceViewMode(
        sourceKey: _viewPreferenceSourceKey,
        viewType: mode.name,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('视图设置保存失败，请重试')));
    }
  }

  Future<void> _changeTimelineZoom(double zoom) async {
    final revision = ++_viewRestoreRevision;
    final sourceKey = _viewPreferenceSourceKey;
    final previousZoom = _timelineZoom;
    setState(() => _timelineZoom = zoom);
    try {
      await ref
          .read(taskViewActionRepositoryProvider)
          ?.saveTaskTimelinePreference(
            sourceKey: sourceKey,
            zoom: zoom,
            scale: _timelineScale.name,
            collapsedGroupIds: _collapsedTimelineGroupIds,
          );
    } catch (_) {
      if (!mounted ||
          sourceKey != _viewPreferenceSourceKey ||
          revision != _viewRestoreRevision) {
        return;
      }
      setState(() => _timelineZoom = previousZoom);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('时间线缩放保存失败，请重试')));
    }
  }

  Future<void> _changeTimelineScale(TimelineScale scale) async {
    final revision = ++_viewRestoreRevision;
    final sourceKey = _viewPreferenceSourceKey;
    final previousScale = _timelineScale;
    setState(() => _timelineScale = scale);
    try {
      await ref
          .read(taskViewActionRepositoryProvider)
          ?.saveTaskTimelinePreference(
            sourceKey: sourceKey,
            zoom: _timelineZoom,
            scale: scale.name,
            collapsedGroupIds: _collapsedTimelineGroupIds,
          );
    } catch (_) {
      if (!mounted ||
          sourceKey != _viewPreferenceSourceKey ||
          revision != _viewRestoreRevision) {
        return;
      }
      setState(() => _timelineScale = previousScale);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('时间线尺度保存失败，请重试')));
    }
  }

  Future<void> _saveBoardLayout({
    required String listId,
    required List<String> order,
    required Set<String> collapsed,
  }) async {
    try {
      await ref
          .read(boardPreferenceRepositoryProvider)
          ?.saveLayout(
            listId: listId,
            orderedColumnIds: order,
            collapsedColumnIds: collapsed,
          );
    } catch (_) {
      if (!mounted || listId != _selectedListId) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('看板布局保存失败，请重试')));
    }
  }

  Future<void> _changeTimelineGroupCollapsed(
    String groupId,
    bool collapsed,
  ) async {
    final revision = ++_viewRestoreRevision;
    final sourceKey = _viewPreferenceSourceKey;
    final previous = _collapsedTimelineGroupIds;
    final next = Set<String>.from(previous);
    if (collapsed) {
      next.add(groupId);
    } else {
      next.remove(groupId);
    }
    setState(() => _collapsedTimelineGroupIds = next);
    try {
      await ref
          .read(taskViewActionRepositoryProvider)
          ?.saveTaskTimelinePreference(
            sourceKey: sourceKey,
            zoom: _timelineZoom,
            scale: _timelineScale.name,
            collapsedGroupIds: next,
          );
    } catch (_) {
      if (!mounted ||
          sourceKey != _viewPreferenceSourceKey ||
          revision != _viewRestoreRevision) {
        return;
      }
      setState(() => _collapsedTimelineGroupIds = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('时间线分组设置保存失败，请重试')));
    }
  }

  String get _viewPreferenceSourceKey {
    final listId = _selectedListId;
    if (listId != null) return 'list:$listId';
    if (widget.initialCompleted == true) return 'smart:completed';
    final dueRange = widget.initialDueRange;
    if (dueRange != null && dueRange.isNotEmpty) return 'smart:due:$dueRange';
    return 'smart:all';
  }

  void _toggleBatchSelection() {
    if (!_batchSelectionActive) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    setState(() {
      _mode = TaskViewMode.list;
      _batchSelectionActive = !_batchSelectionActive;
      _batchSelectionAnchorTaskId = null;
      _batchSelectedTaskIds.clear();
    });
  }

  void _updateBatchSelection(String taskId, bool selected) {
    setState(() {
      _batchSelectionAnchorTaskId = taskId;
      if (selected) {
        _batchSelectedTaskIds.add(taskId);
      } else {
        _batchSelectedTaskIds.remove(taskId);
      }
    });
  }

  void _handleBatchSelectionRequest(
    String taskId,
    List<String> visibleTaskIds,
    _TaskSelectionIntent intent,
  ) {
    if (!_batchSelectionActive) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    setState(() {
      _mode = TaskViewMode.list;
      _batchSelectionActive = true;
      if (intent == _TaskSelectionIntent.range) {
        final anchorIndex = visibleTaskIds.indexOf(
          _batchSelectionAnchorTaskId ?? '',
        );
        final taskIndex = visibleTaskIds.indexOf(taskId);
        if (anchorIndex >= 0 && taskIndex >= 0) {
          final start = anchorIndex < taskIndex ? anchorIndex : taskIndex;
          final end = anchorIndex < taskIndex ? taskIndex : anchorIndex;
          _batchSelectedTaskIds
            ..clear()
            ..addAll(visibleTaskIds.sublist(start, end + 1));
        } else {
          _batchSelectedTaskIds
            ..clear()
            ..add(taskId);
          _batchSelectionAnchorTaskId = taskId;
        }
        return;
      }
      _batchSelectionAnchorTaskId = taskId;
      if (!_batchSelectedTaskIds.add(taskId)) {
        _batchSelectedTaskIds.remove(taskId);
      }
    });
  }

  Future<void> _completeBatchSelection() async {
    await _applyBatchEdit(
      const TaskBatchEditCommand(taskIds: [], completed: true),
      successVerb: '已完成',
    );
  }

  Future<void> _applyBatchAction(
    TaskBatchAction action, {
    required List<TodoTask> visibleTasks,
  }) async {
    if (action == TaskBatchAction.complete) {
      await _completeBatchSelection();
      return;
    }
    if (action == TaskBatchAction.moveToList) {
      final listId = await _selectBatchDestinationList();
      if (listId == null || !mounted) return;
      await _applyBatchEdit(
        TaskBatchEditCommand(taskIds: [], listId: listId),
        successVerb: '已更新',
      );
      return;
    }
    if (action == TaskBatchAction.linkToParent) {
      final parentTaskId = await _selectBatchParentTask();
      if (parentTaskId == null || !mounted) return;
      await _applyBatchParentLink(parentTaskId: parentTaskId);
      return;
    }
    if (action == TaskBatchAction.share) {
      await _shareBatchSelection(visibleTasks);
      return;
    }
    if (action == TaskBatchAction.setTags) {
      final tagIds = await _selectBatchTagIds();
      if (tagIds == null || !mounted) return;
      await _applyBatchEdit(
        TaskBatchEditCommand(taskIds: [], tagIds: tagIds),
        successVerb: '已更新',
      );
      return;
    }
    if (action == TaskBatchAction.setDueAt) {
      final dueAt = await _selectBatchDueAt();
      if (dueAt == null || !mounted) return;
      await _applyBatchEdit(
        TaskBatchEditCommand(taskIds: [], dueAt: dueAt),
        successVerb: '已更新',
      );
      return;
    }
    final command = switch (action) {
      TaskBatchAction.priorityNone => const TaskBatchEditCommand(
        taskIds: [],
        priority: 0,
      ),
      TaskBatchAction.priorityLow => const TaskBatchEditCommand(
        taskIds: [],
        priority: 1,
      ),
      TaskBatchAction.priorityMedium => const TaskBatchEditCommand(
        taskIds: [],
        priority: 2,
      ),
      TaskBatchAction.priorityHigh => const TaskBatchEditCommand(
        taskIds: [],
        priority: 3,
      ),
      TaskBatchAction.pin => const TaskBatchEditCommand(
        taskIds: [],
        isPinned: true,
      ),
      TaskBatchAction.unpin => const TaskBatchEditCommand(
        taskIds: [],
        isPinned: false,
      ),
      TaskBatchAction.moveToInbox => const TaskBatchEditCommand(
        taskIds: [],
        listId: kInboxListId,
      ),
      TaskBatchAction.moveToList => throw StateError('指定清单需要先选择目标'),
      TaskBatchAction.linkToParent => throw StateError('主任务需要先选择目标'),
      TaskBatchAction.share => throw StateError('分享动作已提前处理'),
      TaskBatchAction.setTags => throw StateError('标签需要先选择目标'),
      TaskBatchAction.setDueAt => throw StateError('截止日期需要先选择目标'),
      TaskBatchAction.clearDueAt => const TaskBatchEditCommand(
        taskIds: [],
        clearDueAt: true,
      ),
      TaskBatchAction.clearTags => const TaskBatchEditCommand(
        taskIds: [],
        tagIds: [],
      ),
      TaskBatchAction.complete => throw StateError('完成动作已提前处理'),
    };
    await _applyBatchEdit(command, successVerb: '已更新');
  }

  Future<void> _shareBatchSelection(List<TodoTask> visibleTasks) async {
    if (_batchApplying) return;
    final selectedTasks = visibleTasks
        .where((task) => _batchSelectedTaskIds.contains(task.id))
        .toList(growable: false);
    if (selectedTasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所选任务已不存在')));
      return;
    }
    final body = [
      '已选择 ${selectedTasks.length} 项 Todo 任务',
      for (var index = 0; index < selectedTasks.length; index++)
        [
          '${index + 1}. ${selectedTasks[index].title}',
          if ((selectedTasks[index].description ?? '').trim().isNotEmpty)
            selectedTasks[index].description!.trim(),
          if (selectedTasks[index].dueAt != null)
            '截止：${formatTaskDateTime(selectedTasks[index].dueAt!, allDay: selectedTasks[index].allDay, fixedTimezone: selectedTasks[index].fixedTimezone, timeZone: selectedTasks[index].timeZone)}',
        ].join('\n'),
    ].join('\n\n');
    setState(() => _batchApplying = true);
    final shared = await NativeIntents.shareText(
      body,
      subject: '${selectedTasks.length} 项 Todo 任务',
    );
    if (!mounted) return;
    setState(() => _batchApplying = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(shared ? '已打开系统分享' : '当前设备不支持系统分享')));
  }

  Future<void> _confirmBatchDelete() async {
    final selectedIds = _batchSelectedTaskIds.toList(growable: false);
    if (selectedIds.isEmpty || _batchApplying) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: '删除所选任务？',
      content:
          '将删除 ${selectedIds.length} 项任务，子任务也会被一并删除。'
          '此操作会同步到其他设备。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await _runBatchDelete(selectedIds);
  }

  Future<void> _runBatchDelete(List<String> taskIds) async {
    final repository = ref.read(taskRepositoryProvider);
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务暂不可用，请稍后重试')));
      return;
    }
    setState(() => _batchApplying = true);
    final failedTaskIds = <String>[];
    final failedReasons = <String>{};
    var succeeded = 0;
    try {
      final deleteGroups = await _groupSelectedDeleteRoots(repository, taskIds);
      for (final group in deleteGroups) {
        try {
          await repository.delete(group.rootTaskId);
          succeeded += group.selectedTaskIds.length;
        } catch (_) {
          failedTaskIds.addAll(group.selectedTaskIds);
          failedReasons.add('本地删除失败');
        }
      }
    } catch (_) {
      failedTaskIds.addAll(taskIds);
      failedReasons.add('本地任务读取失败');
    }
    if (!mounted) return;
    setState(() {
      _batchApplying = false;
      _batchSelectionActive = failedTaskIds.isNotEmpty;
      _batchSelectionAnchorTaskId = failedTaskIds.isEmpty
          ? null
          : failedTaskIds.first;
      _batchSelectedTaskIds
        ..clear()
        ..addAll(failedTaskIds);
    });
    final failed = failedTaskIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已删除 $succeeded 项；失败 $failed 项'
          '${failedReasons.isEmpty ? '' : '：${failedReasons.join('、')}'}',
        ),
        action: failedTaskIds.isEmpty
            ? null
            : SnackBarAction(
                label: '重试失败项',
                onPressed: () => _runBatchDelete(failedTaskIds),
              ),
      ),
    );
  }

  Future<List<_BatchDeleteGroup>> _groupSelectedDeleteRoots(
    TaskRepository repository,
    List<String> selectedIds,
  ) async {
    final selected = selectedIds.toSet();
    final selectedIdsByRoot = <String, List<String>>{};
    for (final taskId in selectedIds) {
      var task = await repository.getById(taskId);
      var parentId = task?.parentTaskId;
      var rootTaskId = taskId;
      final visitedIds = <String>{taskId};
      while (parentId != null && visitedIds.add(parentId)) {
        if (selected.contains(parentId)) {
          rootTaskId = parentId;
        }
        task = await repository.getById(parentId);
        parentId = task?.parentTaskId;
      }
      selectedIdsByRoot.putIfAbsent(rootTaskId, () => []).add(taskId);
    }
    return [
      for (final entry in selectedIdsByRoot.entries)
        _BatchDeleteGroup(rootTaskId: entry.key, selectedTaskIds: entry.value),
    ];
  }

  Future<String?> _selectBatchDestinationList() async {
    final repository = ref.read(listRepositoryProvider);
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清单暂不可用，请稍后重试')));
      return null;
    }
    final lists = await repository.getAll();
    if (!mounted) return null;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可移动的清单')));
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '移至清单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final list in lists)
              ListTile(
                key: Key('todo-batch-list-${list.id}'),
                title: Text(list.name),
                onTap: () => Navigator.of(sheetContext).pop(list.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _selectBatchParentTask() async {
    final taskRepository = ref.read(taskRepositoryProvider);
    final queryRepository = ref.read(taskQueryRepositoryProvider);
    if (taskRepository == null || queryRepository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务暂不可用，请稍后重试')));
      return null;
    }
    final selectedIds = _batchSelectedTaskIds.toSet();
    if (selectedIds.isEmpty) return null;
    final selectedTasks = await Future.wait(
      selectedIds.map(taskRepository.getById),
    );
    final firstSelected = selectedTasks.whereType<TodoTask>().firstOrNull;
    if (!mounted) return null;
    if (firstSelected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所选任务已不存在')));
      return null;
    }
    final candidates = (await queryRepository.filter(
      TaskQueryFilter(listId: firstSelected.listId),
    )).where((task) => !selectedIds.contains(task.id)).toList(growable: false);
    if (!mounted) return null;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可关联的主任务')));
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '关联主任务',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final task in candidates)
                      ListTile(
                        key: Key('todo-batch-parent-${task.id}'),
                        leading: const Icon(Icons.account_tree_outlined),
                        title: Text(task.title),
                        onTap: () => Navigator.of(sheetContext).pop(task.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _selectBatchDueAt() {
    final now = ref.read(currentDateTimeProvider)();
    return showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '设置截止日期',
    );
  }

  Future<List<String>?> _selectBatchTagIds() async {
    final repository = ref.read(tagRepositoryProvider);
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签暂不可用，请稍后重试')));
      return null;
    }
    final tags = await repository.getAll();
    if (!mounted) return null;
    if (tags.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可选择的标签')));
      return null;
    }
    final selectedIds = <String>{};
    return showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '设置标签',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final tag in tags)
                        CheckboxListTile(
                          key: Key('todo-batch-tag-${tag.id}'),
                          title: Text(tag.name),
                          value: selectedIds.contains(tag.id),
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked ?? false) {
                                selectedIds.add(tag.id);
                              } else {
                                selectedIds.remove(tag.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('todo-batch-apply-tags'),
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(selectedIds.toList(growable: false)),
                      child: const Text('应用标签'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyBatchEdit(
    TaskBatchEditCommand baseCommand, {
    required String successVerb,
  }) async {
    final repository = ref.read(taskBatchEditRepositoryProvider);
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('批量编辑暂不可用，请稍后重试')));
      return;
    }
    final selectedIds = baseCommand.taskIds.isEmpty
        ? _batchSelectedTaskIds.toList(growable: false)
        : baseCommand.taskIds;
    setState(() => _batchApplying = true);
    final results = await repository.apply(
      TaskBatchEditCommand(
        taskIds: selectedIds,
        listId: baseCommand.listId,
        dueAt: baseCommand.dueAt,
        clearDueAt: baseCommand.clearDueAt,
        tagIds: baseCommand.tagIds,
        priority: baseCommand.priority,
        completed: baseCommand.completed,
        isPinned: baseCommand.isPinned,
      ),
    );
    if (!mounted) return;
    _finishBatchOperation(
      results: results,
      successVerb: successVerb,
      onRetry: (failedTaskIds) => _applyBatchEdit(
        TaskBatchEditCommand(
          taskIds: failedTaskIds,
          listId: baseCommand.listId,
          dueAt: baseCommand.dueAt,
          clearDueAt: baseCommand.clearDueAt,
          tagIds: baseCommand.tagIds,
          priority: baseCommand.priority,
          completed: baseCommand.completed,
          isPinned: baseCommand.isPinned,
        ),
        successVerb: '已重试',
      ),
    );
  }

  Future<void> _applyBatchParentLink({
    required String parentTaskId,
    List<String>? taskIds,
  }) async {
    final repository = ref.read(taskBatchEditRepositoryProvider);
    if (repository == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('批量编辑暂不可用，请稍后重试')));
      return;
    }
    final selectedIds =
        taskIds ?? _batchSelectedTaskIds.toList(growable: false);
    setState(() => _batchApplying = true);
    final results = await repository.linkToParent(
      taskIds: selectedIds,
      parentTaskId: parentTaskId,
    );
    if (!mounted) return;
    _finishBatchOperation(
      results: results,
      successVerb: '已关联',
      onRetry: (failedTaskIds) => _applyBatchParentLink(
        parentTaskId: parentTaskId,
        taskIds: failedTaskIds,
      ),
    );
  }

  void _finishBatchOperation({
    required List<TaskBatchEditResult> results,
    required String successVerb,
    required Future<void> Function(List<String> failedTaskIds) onRetry,
  }) {
    final succeeded = results
        .where((result) => result.status == TaskBatchEditStatus.success)
        .length;
    final failed = results
        .where((result) => result.status == TaskBatchEditStatus.failed)
        .length;
    final skipped = results
        .where((result) => result.status == TaskBatchEditStatus.skipped)
        .length;
    final failedTaskIds = results
        .where((result) => result.status == TaskBatchEditStatus.failed)
        .map((result) => result.taskId)
        .toList(growable: false);
    final failedReasons = results
        .where((result) => result.status == TaskBatchEditStatus.failed)
        .map((result) => result.reason)
        .whereType<String>()
        .toSet()
        .join('、');
    final skippedReasons = results
        .where((result) => result.status == TaskBatchEditStatus.skipped)
        .map((result) => result.reason)
        .whereType<String>()
        .toSet()
        .join('、');
    setState(() {
      _batchApplying = false;
      _batchSelectionActive = false;
      _batchSelectionAnchorTaskId = null;
      _batchSelectedTaskIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$successVerb $succeeded 项；失败 $failed 项'
          '${failedReasons.isEmpty ? '' : '：$failedReasons'}'
          '${skipped == 0 ? '' : '；跳过 $skipped 项'}'
          '${skippedReasons.isEmpty ? '' : '：$skippedReasons'}',
        ),
        action: failedTaskIds.isEmpty
            ? null
            : SnackBarAction(
                label: '重试失败项',
                onPressed: () {
                  if (!mounted) return;
                  onRetry(failedTaskIds);
                },
              ),
      ),
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

  Future<void> _submitQuickAdd(QuickAddRequest request) async {
    final callback = widget.onQuickAdd;
    if (callback != null) {
      await callback(request);
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final defaults = await ref
        .read(taskCaptureDefaultsRepositoryProvider)
        ?.get();
    final created = await repo.createBatch(
      listId: _selectedListId ?? kInboxListId,
      input: request.input,
      priority: request.priorityOverride ?? defaults?.defaultPriority ?? 0,
      dueAtResolver: request.dueAtOverride != null
          ? (_) => request.dueAtOverride
          : request.useNlpDate
          ? (line) => NlpDateParser().parse(line)?.date
          : null,
    );
    final tags = ref.read(tagRepositoryProvider);
    if (tags != null && request.tagIds.isNotEmpty) {
      await Future.wait(
        created.map((task) => tags.setTaskTags(task.id, request.tagIds)),
      );
    }
  }

  Future<void> _createTaskSection() async {
    final listId = _selectedListId;
    if (listId == null) return;
    final name = await _requestSectionName(title: '新建分组');
    if (name == null || !mounted) return;
    try {
      await ref
          .read(taskSectionRepositoryProvider)
          ?.create(listId: listId, name: name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组创建失败，请重试')));
    }
  }

  Future<void> _renameTaskSection(TodoTaskSection section) async {
    final name = await _requestSectionName(
      title: '重命名分组',
      initialValue: section.name,
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(taskSectionRepositoryProvider)?.rename(section.id, name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组重命名失败，请重试')));
    }
  }

  Future<void> _deleteTaskSection(TodoTaskSection section) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '删除“${section.name}”？',
      content: '分组内任务不会删除，将回到“未分组”。此操作会同步到其他设备。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(taskSectionRepositoryProvider)?.delete(section.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组删除失败，请重试')));
    }
  }

  Future<void> _moveTaskSection(TodoTaskSection section, int direction) async {
    final listId = _selectedListId;
    if (listId == null) return;
    final sections =
        ref.read(taskSectionsByListProvider(listId)).valueOrNull ?? const [];
    final currentIndex = sections.indexWhere((item) => item.id == section.id);
    final targetIndex = currentIndex + direction;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= sections.length) {
      return;
    }
    final ordered = sections.map((item) => item.id).toList();
    final moved = ordered.removeAt(currentIndex);
    ordered.insert(targetIndex, moved);
    try {
      await ref
          .read(taskSectionRepositoryProvider)
          ?.reorder(listId: listId, orderedSectionIds: ordered);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组排序失败，请重试')));
    }
  }

  Future<String?> _requestSectionName({
    required String title,
    String initialValue = '',
  }) async {
    var value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: const Key('todo-section-name-field'),
          initialValue: initialValue,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(hintText: '分组名称'),
          onChanged: (nextValue) => value = nextValue,
          onFieldSubmitted: (nextValue) {
            final normalized = nextValue.trim();
            if (normalized.isNotEmpty) {
              Navigator.of(dialogContext).pop(normalized);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('todo-section-name-confirm'),
            onPressed: () {
              final normalized = value.trim();
              if (normalized.isNotEmpty) {
                Navigator.of(dialogContext).pop(normalized);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterPanel(List<TodoTask> tasks) async {
    var draft = _filter;
    final assigneesById = <int, TaskAssigneeOption>{};
    for (final task in tasks) {
      final userId = task.assigneeUserId;
      if (userId == null) continue;
      final cachedName = task.assigneeUserName?.trim();
      assigneesById[userId] = TaskAssigneeOption(
        userId: userId,
        name: cachedName == null || cachedName.isEmpty
            ? '负责人 #$userId'
            : cachedName,
      );
    }
    final assigneeOptions = assigneesById.values.toList(growable: false)
      ..sort((left, right) {
        final byName = left.name.compareTo(right.name);
        return byName != 0 ? byName : left.userId.compareTo(right.userId);
      });
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
                  assigneeOptions: assigneeOptions,
                  // 预览与列表渲染同源：同一份原始列表、同一个 applyTaskFilter、
                  // 同一个清单口径 ⇒ 「命中 N 项」不会和套出来看到的数不一样。
                  previewResolver: (next) => applyTaskFilter(
                    tasks,
                    next,
                    _selectedListId,
                    ref.read(currentDateTimeProvider)(),
                  ),
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
    required this.sections,
    required this.sort,
    required this.desktopMode,
    required this.now,
    required this.selectedTaskId,
    required this.onTaskSelected,
    this.onTasksReordered,
    required this.batchSelectionActive,
    required this.batchSelectedTaskIds,
    required this.onBatchSelectionChanged,
    required this.onBatchSelectionRequested,
  });

  final List<TodoTask> items;
  final List<TodoTaskSection> sections;
  final TaskSort sort;
  final bool desktopMode;
  final DateTime now;
  final String? selectedTaskId;
  final ValueChanged<String>? onTaskSelected;
  final Future<void> Function(List<String> taskIds)? onTasksReordered;
  final bool batchSelectionActive;
  final Set<String> batchSelectedTaskIds;
  final void Function(String taskId, bool selected) onBatchSelectionChanged;
  final void Function(
    String taskId,
    List<String> visibleTaskIds,
    _TaskSelectionIntent intent,
  )
  onBatchSelectionRequested;

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
    final groups = widget.sections.isEmpty
        ? _groupTasks(ordered, widget.now)
        : _groupTasksBySection(ordered, widget.sections);
    final entries = <Object>[
      for (final group in groups) ...[group, ...group.tasks],
    ];
    final visibleTaskIds = entries
        .whereType<TodoTask>()
        .map((task) => task.id)
        .toList(growable: false);

    if (widget.desktopMode && widget.onTasksReordered != null) {
      return ReorderableListView.builder(
        key: const Key('todo-task-list-scroll'),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(
          bottom: TodoLayoutTokens.mainHorizontalInset,
        ),
        itemCount: entries.length,
        // Flutter 3.41 (the local baseline) does not expose `onReorderItem`
        // yet. Keep the established callback until the project baseline moves
        // forward; the adjustment below preserves its pre-3.44 index contract.
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) async {
          if (widget.batchSelectionActive) return;
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
          final previousOrder = _orderedIds;
          final previousHasCustomOrder = _hasCustomOrder;
          setState(() {
            _orderedIds = reordered;
            _hasCustomOrder = true;
          });
          try {
            await widget.onTasksReordered?.call(reordered);
          } catch (error) {
            if (!context.mounted) return;
            setState(() {
              _orderedIds = previousOrder;
              _hasCustomOrder = previousHasCustomOrder;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  taskViewMutationFailureMessage(error, '排序保存失败，请重试'),
                ),
              ),
            );
          }
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
              taskSections: widget.sections,
              desktopMode: true,
              enableSwipeGestures: false,
              reorderIndex: widget.batchSelectionActive ? null : index,
              selected: widget.selectedTaskId == task.id,
              onTap: (taskId) => _handleTaskActivation(taskId, visibleTaskIds),
              batchSelectionActive: widget.batchSelectionActive,
              batchSelected: widget.batchSelectedTaskIds.contains(task.id),
              onBatchSelectionChanged: (selected) =>
                  widget.onBatchSelectionChanged(task.id, selected),
            ),
          );
        },
      );
    }

    return ListView.builder(
      key: const Key('todo-task-list-scroll'),
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
          taskSections: widget.sections,
          desktopMode: widget.desktopMode,
          enableSwipeGestures:
              !widget.desktopMode && !widget.batchSelectionActive,
          selected: widget.selectedTaskId == task.id,
          onTap: (taskId) => _handleTaskActivation(taskId, visibleTaskIds),
          batchSelectionActive: widget.batchSelectionActive,
          batchSelected: widget.batchSelectedTaskIds.contains(task.id),
          onBatchSelectionChanged: (selected) =>
              widget.onBatchSelectionChanged(task.id, selected),
        );
      },
    );
  }

  List<TodoTask> _sortedItems(List<TodoTask> items) {
    final sorted = [...items];
    sorted.sort((a, b) => compareTodoTasks(a, b, widget.sort));
    return sorted;
  }

  void _handleTaskActivation(String taskId, List<String> visibleTaskIds) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) {
      widget.onBatchSelectionRequested(
        taskId,
        visibleTaskIds,
        _TaskSelectionIntent.range,
      );
      return;
    }
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        widget.batchSelectionActive) {
      widget.onBatchSelectionRequested(
        taskId,
        visibleTaskIds,
        _TaskSelectionIntent.toggle,
      );
      return;
    }
    widget.onTaskSelected?.call(taskId);
  }
}

enum _TaskSelectionIntent { toggle, range }

class _BatchDeleteGroup {
  const _BatchDeleteGroup({
    required this.rootTaskId,
    required this.selectedTaskIds,
  });

  final String rootTaskId;
  final List<String> selectedTaskIds;
}

class _TaskSectionManagerBar extends StatelessWidget {
  const _TaskSectionManagerBar({
    required this.sections,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.onMove,
  });

  final List<TodoTaskSection> sections;
  final VoidCallback onCreate;
  final ValueChanged<TodoTaskSection> onRename;
  final ValueChanged<TodoTaskSection> onDelete;
  final void Function(TodoTaskSection section, int direction) onMove;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      height: 44,
      child: ListView(
        key: const Key('todo-section-manager'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TodoLayoutTokens.mainHorizontalInset,
          vertical: 4,
        ),
        children: [
          ActionChip(
            key: const Key('todo-section-create'),
            avatar: const Icon(Icons.add, size: 17),
            label: const Text('分组'),
            onPressed: onCreate,
          ),
          for (final entry in sections.indexed) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              key: Key('todo-section-menu-${entry.$2.id}'),
              tooltip: '管理分组 ${entry.$2.name}',
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    onRename(entry.$2);
                  case 'up':
                    onMove(entry.$2, -1);
                  case 'down':
                    onMove(entry.$2, 1);
                  case 'delete':
                    onDelete(entry.$2);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(
                  value: 'up',
                  enabled: entry.$1 > 0,
                  child: const Text('向前移动'),
                ),
                PopupMenuItem(
                  value: 'down',
                  enabled: entry.$1 < sections.length - 1,
                  child: const Text('向后移动'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    '删除',
                    style: TextStyle(color: colors.destructive),
                  ),
                ),
              ],
              child: Chip(
                label: Text(entry.$2.name),
                avatar: const Icon(Icons.drag_indicator, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
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
    final due = _taskDueWallClock(task);
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

List<_TaskGroup> _groupTasksBySection(
  List<TodoTask> tasks,
  List<TodoTaskSection> sections,
) {
  final tasksBySection = <String?, List<TodoTask>>{};
  for (final task in tasks) {
    tasksBySection.putIfAbsent(task.sectionId, () => []).add(task);
  }
  final groups = <_TaskGroup>[
    for (final section in sections)
      _TaskGroup(
        id: 'section-${section.id}',
        title: section.name,
        tasks: tasksBySection.remove(section.id) ?? const [],
      ),
  ];
  final ungrouped = <TodoTask>[
    ...?tasksBySection.remove(null),
    for (final orphaned in tasksBySection.values) ...orphaned,
  ];
  if (ungrouped.isNotEmpty || groups.isEmpty) {
    groups.add(
      _TaskGroup(id: 'section-ungrouped', title: '未分组', tasks: ungrouped),
    );
  }
  return groups;
}

List<TodoTask> _visibleTasksInListOrder(
  List<TodoTask> tasks, {
  required List<TodoTaskSection> sections,
  required TaskSort sort,
  required DateTime now,
}) {
  final sorted = [...tasks]..sort((a, b) => compareTodoTasks(a, b, sort));
  final groups = sections.isEmpty
      ? _groupTasks(sorted, now)
      : _groupTasksBySection(sorted, sections);
  return [for (final group in groups) ...group.tasks];
}

List<TodoTask> applyTaskFilter(
  List<TodoTask> source,
  TaskFilter filter,
  String? selectedListId,
  DateTime now,
) {
  if (filter.isEmpty && selectedListId == null) return source;
  final startOfDay = DateTime(now.year, now.month, now.day);
  final todayEnd = startOfDay.add(const Duration(days: 1));
  final keyword = filter.keyword?.trim().toLowerCase();

  return source.where((task) {
    if (selectedListId != null && task.listId != selectedListId) return false;
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
    if (keyword != null && keyword.isNotEmpty) {
      final titleMatches = task.title.toLowerCase().contains(keyword);
      final descriptionMatches =
          task.description?.toLowerCase().contains(keyword) ?? false;
      if (!titleMatches && !descriptionMatches) return false;
    }
    if (filter.dueAtFrom != null || filter.dueAtTo != null) {
      final due = _taskDueWallClock(task);
      if (due == null) return false;
      final dueDay = DateTime(due.year, due.month, due.day);
      if (filter.dueAtFrom != null && dueDay.isBefore(filter.dueAtFrom!)) {
        return false;
      }
      if (filter.dueAtTo != null && dueDay.isAfter(filter.dueAtTo!)) {
        return false;
      }
    }
    if (filter.dueRange != null) {
      final due = _taskDueWallClock(task);
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
        case 'next7days':
          final weekEndExclusive = startOfDay.add(const Duration(days: 8));
          if (due.isBefore(todayEnd) || !due.isBefore(weekEndExclusive)) {
            return false;
          }
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

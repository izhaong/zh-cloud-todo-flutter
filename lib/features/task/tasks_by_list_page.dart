import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../filter/filter_bar.dart';
import 'task_quick_add_sheet.dart';
import 'widgets/task_row_host.dart';
import 'view_mode.dart';
import 'views/calendar_view.dart';
import 'views/eisenhower_view.dart';
import 'views/kanban_view.dart';
import 'views/task_view_mode_tabs.dart';
import 'views/timeline_view.dart';

/// M11-B2/B3 任务页（替换旧的 _DashboardTabView）。
///
/// - 顶部 5 个视图 tab：列表 / 看板 / 时间线 / 四象限 / 日历
/// - 列表分支沿用 M11-B2 行为（按 listId 选择 / 全部 + 过滤条）
/// - 其它视图由 `lib/features/task/views/*` 实现
/// - 点击进入 TaskDetailPage
/// - FAB 快速添加任务
class TasksByListPage extends ConsumerStatefulWidget {
  const TasksByListPage({
    super.key,
    this.initialListId,
    this.initialDueRange,
    this.lockedListId = false,
    this.hideAppBar = false,
  });

  /// 初始选定的清单 id（Sidebar 驱动）。null = 全部；'inbox' = 收件箱。
  final String? initialListId;

  /// 初始智能清单的时间过滤（Sidebar 的今天/即将到期）。
  final String? initialDueRange;

  /// 是否锁定清单选择（Sidebar 模式下由外部 chips 控制，本页仍可切智能清单）。
  final bool lockedListId;

  /// 是否隐藏本页 AppBar（嵌入 Shell 内容区时由 Shell 提供顶部栏）。
  final bool hideAppBar;

  @override
  ConsumerState<TasksByListPage> createState() => _TasksByListPageState();
}

/// §2.6 列表视图排序方式。
enum TaskSort { smart, priorityDesc, dueDate, title, createdAt }

/// 任务收件箱的 synthetic listId。
const String kInboxListId = 'inbox';

class _TasksByListPageState extends ConsumerState<TasksByListPage> {
  String? _selectedListId; // null = 全部；kInboxListId = 收件箱
  TaskFilter _filter = TaskFilter();
  TaskViewMode _mode = TaskViewMode.list;
  TaskSort _sort = TaskSort.smart;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.initialListId;
    if (widget.initialDueRange != null) {
      _filter = TaskFilter(dueRange: widget.initialDueRange);
    }
  }

  /// Sidebar 切换清单时，从外部同步选中态。
  @override
  void didUpdateWidget(covariant TasksByListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lockedListId &&
        widget.initialListId != oldWidget.initialListId) {
      setState(() => _selectedListId = widget.initialListId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsStreamProvider);
    final taskRepo = ref.watch(taskRepositoryProvider);
    final desktopMode = MediaQuery.sizeOf(context).width >= 1024;
    // 会话未就绪（DB 仍在初始化 / 注销过渡）时防空降级为 loading，避免 crash。
    if (taskRepo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tasksStream = _selectedListId == null
        ? taskRepo.watchAll()
        : taskRepo.watchTopLevelByList(_selectedListId!);

    return Scaffold(
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text('任务'),
              actions: [
                PopupMenuButton<TaskSort>(
                  tooltip: '排序',
                  icon: const Icon(Icons.sort),
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TaskSort.smart,
                      child: Text('智能（置顶优先）'),
                    ),
                    PopupMenuItem(
                      value: TaskSort.priorityDesc,
                      child: Text('优先级'),
                    ),
                    PopupMenuItem(value: TaskSort.dueDate, child: Text('截止日期')),
                    PopupMenuItem(value: TaskSort.title, child: Text('标题')),
                    PopupMenuItem(
                      value: TaskSort.createdAt,
                      child: Text('创建时间'),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          _ListPicker(
            listsAsync: listsAsync,
            selectedListId: _selectedListId,
            onChanged: (id) => setState(() => _selectedListId = id),
          ),
          if (_mode == TaskViewMode.list)
            _SmartTaskChips(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          TaskViewModeTabs(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const Divider(height: 1),
          if (_mode == TaskViewMode.list)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: FilterBar(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          if (_mode == TaskViewMode.list) const Divider(height: 1),
          Expanded(
            child: _ModeBody(
              mode: _mode,
              tasksStream: tasksStream,
              filter: _filter,
              selectedListId: _selectedListId,
              sort: _sort,
              desktopMode: desktopMode,
              onAdd: _quickAdd,
            ),
          ),
        ],
      ),
      floatingActionButton: ref.read(taskRepositoryProvider) == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _quickAdd(),
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            ),
    );
  }

  Future<void> _quickAdd() async {
    final lists =
        ref.read(listsStreamProvider).valueOrNull ?? const <TodoList>[];
    // §2.3 未选清单时，快速新建落入 synthetic inbox。
    final listId =
        _selectedListId ?? (lists.isNotEmpty ? lists.first.id : kInboxListId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskQuickAddSheet(listId: listId),
    );
  }
}

/// M11-B3 视图分发：统一订阅 stream，过滤后按 mode 派发到对应视图。
class _ModeBody extends ConsumerWidget {
  const _ModeBody({
    required this.mode,
    required this.tasksStream,
    required this.filter,
    required this.selectedListId,
    required this.sort,
    required this.desktopMode,
    required this.onAdd,
  });

  final TaskViewMode mode;
  final Stream<List<TodoTask>> tasksStream;
  final TaskFilter filter;
  final String? selectedListId;
  final TaskSort sort;
  final bool desktopMode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<TodoTask>>(
      stream: tasksStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snap.data ?? const <TodoTask>[];
        final items = _ListBody.applyFilter(raw, filter, selectedListId);
        switch (mode) {
          case TaskViewMode.list:
            return _ListBody(
              items: items,
              sort: sort,
              desktopMode: desktopMode,
              onAdd: onAdd,
            );
          case TaskViewMode.kanban:
            return KanbanView(tasks: items, listId: selectedListId);
          case TaskViewMode.timeline:
            return TimelineView(tasks: items);
          case TaskViewMode.eisenhower:
            return EisenhowerView(tasks: items);
          case TaskViewMode.calendar:
            return CalendarView(tasks: items);
        }
      },
    );
  }
}

/// 品牌化任务列表分支：AppEmptyState 空状态 + TaskRowHost 任务行（含滑动）。
class _ListBody extends StatefulWidget {
  const _ListBody({
    required this.items,
    required this.sort,
    required this.desktopMode,
    required this.onAdd,
  });

  final List<TodoTask> items;
  final TaskSort sort;
  final bool desktopMode;
  final VoidCallback onAdd;

  @override
  State<_ListBody> createState() => _ListBodyState();

  /// 把 filter 套在 `List` 上的 TodoTask 客户端过滤（保持 UI 纯本地）。
  static List<TodoTask> applyFilter(
    List<TodoTask> src,
    TaskFilter f,
    String? selectedListId,
  ) {
    if (f.isEmpty && selectedListId == null) return src;
    final now = DateTime.now();
    final todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return src.where((t) {
      if (selectedListId != null && t.listId != selectedListId) return false;
      if (f.listId != null && t.listId != f.listId) return false;
      if (f.priority != null && t.priority != f.priority) return false;
      if (f.completed != null && t.completed != f.completed) return false;
      if (f.dueRange != null) {
        final due = t.dueAt;
        if (due == null) return false;
        final startOfDay = DateTime(now.year, now.month, now.day);
        switch (f.dueRange) {
          case 'today':
            if (due.isBefore(startOfDay) || !due.isBefore(todayEnd))
              return false;
            break;
          case 'tomorrow':
            final tmrStart = todayEnd;
            final tmrEnd = todayEnd.add(const Duration(days: 1));
            if (due.isBefore(tmrStart) || !due.isBefore(tmrEnd)) return false;
            break;
          case 'last7days':
            final weekStart = startOfDay.subtract(const Duration(days: 7));
            if (due.isBefore(weekStart) || !due.isBefore(todayEnd))
              return false;
            break;
          case 'overdue':
            if (!due.isBefore(startOfDay)) return false;
            break;
          case 'future':
            if (due.isBefore(todayEnd)) return false;
            break;
        }
      }
      return true;
    }).toList();
  }
}

class _ListBodyState extends State<_ListBody> {
  List<String> _orderedIds = const [];
  bool _hasCustomOrder = false;

  @override
  void initState() {
    super.initState();
    _orderedIds = _sortedItems(widget.items).map((t) => t.id).toList();
  }

  @override
  void didUpdateWidget(covariant _ListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = _sortedItems(widget.items).map((t) => t.id).toList();
    if (!_hasCustomOrder) {
      _orderedIds = currentIds;
      return;
    }
    _orderedIds = _normalizeTaskIds(_orderedIds, currentIds);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return AppEmptyState(
        title: '没有任务',
        subtitle: '点击上方输入框快速添加任务，开启专注的一天。',
        action: AppButton(
          icon: Icons.add,
          child: const Text('新建任务'),
          onPressed: widget.onAdd,
        ),
      );
    }
    final sortedItems = _sortedItems(widget.items);
    final byId = {for (final t in sortedItems) t.id: t};
    final ordered =
        (_hasCustomOrder ? _orderedIds : sortedItems.map((t) => t.id).toList())
            .map((id) => byId[id])
            .whereType<TodoTask>()
            .toList(growable: false);
    if (widget.desktopMode) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: ordered.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            _orderedIds = reorderTaskIds(_orderedIds, oldIndex, newIndex);
            _hasCustomOrder = true;
          });
        },
        itemBuilder: (_, i) {
          final t = ordered[i];
          return KeyedSubtree(
            key: ValueKey(t.id),
            child: TaskRowHost(
              task: t,
              desktopMode: true,
              enableSwipeGestures: false,
              reorderIndex: i,
            ),
          );
        },
      );
    }
    final sorted = [...ordered]
      ..sort((a, b) {
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
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final t = sorted[i];
        return TaskRowHost(task: t);
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

class _ListPicker extends StatelessWidget {
  const _ListPicker({
    required this.listsAsync,
    required this.selectedListId,
    required this.onChanged,
  });

  final AsyncValue<List<TodoList>> listsAsync;
  final String? selectedListId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return listsAsync.when(
      loading: () => const SizedBox(height: 48),
      error: (e, _) => Text('清单加载失败: $e'),
      data: (lists) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: selectedListId == null,
                  onSelected: (_) => onChanged(null),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: const Icon(Icons.inbox, size: 16),
                    label: const Text('收件箱'),
                    selected: selectedListId == kInboxListId,
                    onSelected: (_) => onChanged(kInboxListId),
                  ),
                ),
                ...lists.map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: selectedListId == l.id,
                      onSelected: (_) => onChanged(l.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// §2.5 智能清单快捷 chips：今日 / 明日 / 近 7 天 / 全部 / 已完成。
/// 全部计算自本地 Drift（离线可用），不走后端。
class _SmartTaskChips extends StatelessWidget {
  const _SmartTaskChips({required this.filter, required this.onChanged});

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;

  bool _active(String? dueRange, bool? completed) {
    return filter.dueRange == dueRange &&
        filter.completed == completed &&
        filter.listId == null &&
        filter.priority == null &&
        filter.tagIds.isEmpty;
  }

  void _select(String? dueRange, bool? completed) {
    if (_active(dueRange, completed)) {
      onChanged(TaskFilter());
    } else {
      onChanged(TaskFilter(dueRange: dueRange, completed: completed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _chip(
            '全部',
            Icons.select_all,
            _active(null, null),
            () => _select(null, null),
          ),
          _chip(
            '今日',
            Icons.today_outlined,
            _active('today', null),
            () => _select('today', null),
          ),
          _chip(
            '明日',
            Icons.event_outlined,
            _active('tomorrow', null),
            () => _select('tomorrow', null),
          ),
          _chip(
            '近 7 天',
            Icons.date_range,
            _active('last7days', null),
            () => _select('last7days', null),
          ),
          _chip(
            '已完成',
            Icons.check_circle_outline,
            _active(null, true),
            () => _select(null, true),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

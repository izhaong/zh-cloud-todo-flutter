import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';
import '../filter/filter_bar.dart';
import 'task_detail_page.dart';
import 'task_quick_add_sheet.dart';
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
  const TasksByListPage({super.key});

  @override
  ConsumerState<TasksByListPage> createState() => _TasksByListPageState();
}

class _TasksByListPageState extends ConsumerState<TasksByListPage> {
  int? _selectedListId; // null = 全部
  TaskFilter _filter = TaskFilter();
  TaskViewMode _mode = TaskViewMode.list;

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsStreamProvider);
    final tasksStream = _selectedListId == null
        ? ref.watch(taskRepositoryProvider).watchAll()
        : ref
            .watch(taskRepositoryProvider)
            .watchTopLevelByList(_selectedListId!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务'),
      ),
      body: Column(
        children: [
          _ListPicker(
            listsAsync: listsAsync,
            selectedListId: _selectedListId,
            onChanged: (id) => setState(() => _selectedListId = id),
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
onTaskTap: (t) => showTaskDetailSheet(context, t.id),
            ),
          ),
        ],
      ),
      floatingActionButton: listsAsync.valueOrNull == null ||
              listsAsync.valueOrNull!.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _quickAdd(),
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
            ),
    );
  }

  Future<void> _quickAdd() async {
    final lists = ref.read(listsStreamProvider).valueOrNull ?? const <TodoList>[];
    if (lists.isEmpty) return;
    final listId = _selectedListId ?? lists.first.id;
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
    required this.onTaskTap,
  });

  final TaskViewMode mode;
  final Stream<List<TodoTask>> tasksStream;
  final TaskFilter filter;
  final int? selectedListId;
  final ValueChanged<TodoTask> onTaskTap;

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
            return _ListBody(items: items, onTaskTap: onTaskTap);
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

/// M11-B2 列表分支：保持与 M11-B2 完全一致，单独抽出来便于后续视图共享 filter 管线。
class _ListBody extends StatelessWidget {
  const _ListBody({required this.items, required this.onTaskTap});

  final List<TodoTask> items;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无任务'));
    }
    final sorted = [...items]..sort((a, b) {
        // 置顶优先，再按 updatedAt 倒序。
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final t = sorted[i];
        return ListTile(
          leading: Consumer(
            builder: (ctx, ref, _) => Checkbox(
              value: t.completed,
              onChanged: (_) async {
                await ref.read(taskRepositoryProvider).toggleComplete(t.id);
              },
            ),
          ),
          title: Row(
            children: [
              if (t.isPinned) const Icon(Icons.push_pin, size: 14),
              if (t.isPinned) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t.title,
                  style: TextStyle(
                    decoration: t.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            priorityLabel(t.priority) +
                (t.dueAt == null
                    ? ''
                    : ' · due ${t.dueAt!.toIso8601String().substring(0, 10)}'),
          ),
          trailing: Consumer(
            builder: (ctx, ref, _) => IconButton(
              tooltip: t.isPinned ? '取消置顶' : '置顶',
              icon: Icon(
                t.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
              ),
              onPressed: () =>
                  ref.read(taskRepositoryProvider).togglePin(t.id),
            ),
          ),
          onTap: () => onTaskTap(t),
        );
      },
    );
  }

  /// 把 filter 套在 `List` 上的 TodoTask 客户端过滤（保持 UI 纯本地）。
  static List<TodoTask> applyFilter(
    List<TodoTask> src,
    TaskFilter f,
    int? selectedListId,
  ) {
    if (f.isEmpty && selectedListId == null) return src;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return src.where((t) {
      if (selectedListId != null && t.listId != selectedListId) return false;
      if (f.listId != null && t.listId != f.listId) return false;
      if (f.priority != null && t.priority != f.priority) return false;
      if (f.completed != null && t.completed != f.completed) return false;
      if (f.dueRange != null) {
        final due = t.dueAt;
        if (due == null) return false;
        switch (f.dueRange) {
          case 'today':
            if (due.isBefore(DateTime(now.year, now.month, now.day)) ||
                !due.isBefore(todayEnd)) {
              return false;
            }
            break;
          case 'overdue':
            if (!due.isBefore(DateTime(now.year, now.month, now.day))) {
              return false;
            }
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

class _ListPicker extends StatelessWidget {
  const _ListPicker({
    required this.listsAsync,
    required this.selectedListId,
    required this.onChanged,
  });

  final AsyncValue<List<TodoList>> listsAsync;
  final int? selectedListId;
  final ValueChanged<int?> onChanged;

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

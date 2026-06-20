import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';
import '../filter/filter_bar.dart';
import 'task_detail_page.dart';
import 'task_quick_add_sheet.dart';

/// M11-B2 任务列表页（替换旧的 _DashboardTabView）。
///
/// - 按 listId 选择 / 全部
/// - 顶层任务 checkbox 切换（乐观更新）
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
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: FilterBar(
              filter: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<TodoTask>>(
              stream: tasksStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _applyFilter(
                  snap.data ?? const <TodoTask>[],
                  _filter,
                );
                if (items.isEmpty) {
                  return const Center(child: Text('暂无任务'));
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final t = items[i];
                    return ListTile(
                      leading: Checkbox(
                        value: t.completed,
                        onChanged: (_) async {
                          await ref
                              .read(taskRepositoryProvider)
                              .toggleComplete(t.id);
                        },
                      ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration: t.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        priorityLabel(t.priority) +
                            (t.dueAt == null
                                ? ''
                                : ' · due ${t.dueAt!.toIso8601String().substring(0, 10)}'),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailPage(taskId: t.id),
                        ),
                      ),
                    );
                  },
                );
              },
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

  /// 把 filter 套在 `List` 上的 TodoTask 客户端过滤（保持 UI 纯本地）。
  List<TodoTask> _applyFilter(List<TodoTask> src, TaskFilter f) {
    if (f.isEmpty) return src;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return src.where((t) {
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
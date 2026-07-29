import 'package:flutter/material.dart';

import '../../state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskAssigneeOption {
  const TaskAssigneeOption({required this.userId, required this.name});

  final int userId;
  final String name;
}

/// M11-B2 过滤条：list / folder / tag / priority / due 范围 / completed 状态。
class TaskFilter {
  TaskFilter({
    this.listId,
    this.folderId,
    this.tagIds = const [],
    this.priority,
    this.dueRange,
    this.completed,
    this.assigneeUserId,
    this.keyword,
    this.dueAtFrom,
    this.dueAtTo,
  });

  final String? listId;
  final int? folderId;
  final List<String> tagIds;
  final int? priority;
  final String? dueRange; // today / overdue / future
  final bool? completed;
  final int? assigneeUserId;
  final String? keyword;

  /// Local calendar-day lower bound chosen in the advanced filter.
  final DateTime? dueAtFrom;

  /// Local calendar-day upper bound chosen in the advanced filter.
  final DateTime? dueAtTo;

  TaskFilter copyWith({
    String? listId,
    int? folderId,
    List<String>? tagIds,
    int? priority,
    String? dueRange,
    bool? completed,
    int? assigneeUserId,
    bool clearAssigneeUserId = false,
    String? keyword,
    bool clearKeyword = false,
    DateTime? dueAtFrom,
    bool clearDueAtFrom = false,
    DateTime? dueAtTo,
    bool clearDueAtTo = false,
  }) {
    return TaskFilter(
      listId: listId ?? this.listId,
      folderId: folderId ?? this.folderId,
      tagIds: tagIds ?? this.tagIds,
      priority: priority ?? this.priority,
      dueRange: dueRange ?? this.dueRange,
      completed: completed ?? this.completed,
      assigneeUserId: clearAssigneeUserId
          ? null
          : assigneeUserId ?? this.assigneeUserId,
      keyword: clearKeyword ? null : keyword ?? this.keyword,
      dueAtFrom: clearDueAtFrom ? null : dueAtFrom ?? this.dueAtFrom,
      dueAtTo: clearDueAtTo ? null : dueAtTo ?? this.dueAtTo,
    );
  }

  bool get isEmpty =>
      listId == null &&
      folderId == null &&
      tagIds.isEmpty &&
      priority == null &&
      dueRange == null &&
      completed == null &&
      assigneeUserId == null &&
      (keyword == null || keyword!.trim().isEmpty) &&
      dueAtFrom == null &&
      dueAtTo == null;

  /// 把当前 filter 物化为智能清单的入参 map。
  Map<String, dynamic> toJson() => {
    'listId': listId,
    'folderId': folderId,
    'tagIds': tagIds,
    'priority': priority,
    'dueRange': dueRange,
    'completed': completed,
    'assigneeUserId': assigneeUserId,
    'keyword': keyword,
    'dueAtFrom': dueAtFrom?.toIso8601String(),
    'dueAtTo': dueAtTo?.toIso8601String(),
  };
}

/// M11-B2 顶部过滤条 + "保存为智能清单" 按钮。
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.assigneeOptions = const [],
  });

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;
  final List<TaskAssigneeOption> assigneeOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueRange = filter.dueRange;
    final completed = filter.completed;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: filter.isEmpty,
            onSelected: (_) => onChanged(TaskFilter()),
          ),
          _Choice(
            label: dueRangeChipLabel(dueRange),
            selected: dueRange != null,
            onTap: () async {
              final next = await _pickDueRange(context, dueRange);
              if (next != null) onChanged(filter.copyWith(dueRange: next));
            },
          ),
          _Choice(
            label: completedChipLabel(completed),
            selected: completed != null,
            onTap: () async {
              final next = await _pickCompleted(context, completed);
              onChanged(filter.copyWith(completed: next));
            },
          ),
          _Choice(
            label: priorityChipLabel(filter.priority),
            selected: filter.priority != null,
            onTap: () async {
              final next = await _pickPriority(context, filter.priority);
              if (next != filter.priority) {
                onChanged(filter.copyWith(priority: next));
              }
            },
          ),
          _Choice(
            key: const Key('todo-filter-advanced'),
            label: _advancedFilterLabel(filter),
            selected: _hasAdvancedFilter(filter),
            onTap: () async {
              final next = await _pickAdvancedFilter(
                context,
                filter,
                assigneeOptions,
              );
              if (next == null) return;
              onChanged(
                filter.copyWith(
                  keyword: next.keyword,
                  clearKeyword: next.keyword == null,
                  dueAtFrom: next.dueAtFrom,
                  clearDueAtFrom: next.dueAtFrom == null,
                  dueAtTo: next.dueAtTo,
                  clearDueAtTo: next.dueAtTo == null,
                  assigneeUserId: next.assigneeUserId,
                  clearAssigneeUserId: next.assigneeUserId == null,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          if (!filter.isEmpty)
            TextButton.icon(
              onPressed: () async {
                final name = await _promptSmartName(context);
                if (name == null || name.isEmpty) return;
                final repo = ref.read(listRepositoryProvider);
                if (repo == null) return;
                await repo.saveSmart(filterName: name, filter: filter.toJson());
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已保存为智能清单：$name')));
                }
              },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存为智能清单'),
            ),
        ],
      ),
    );
  }

  static Future<String?> _pickDueRange(
    BuildContext context,
    String? cur,
  ) async {
    return showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('今日'),
              trailing: cur == 'today' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('已过期'),
              trailing: cur == 'overdue' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'overdue'),
            ),
            ListTile(
              leading: const Icon(Icons.upcoming),
              title: const Text('将来'),
              trailing: cur == 'future' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'future'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
      ),
    ).then((v) => (v == null || v.isEmpty) ? null : v);
  }

  static Future<bool?> _pickCompleted(BuildContext context, bool? cur) async {
    return showModalBottomSheet<bool?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('已完成'),
              trailing: cur == true
                  ? const Icon(Icons.radio_button_checked)
                  : null,
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('未完成'),
              trailing: cur == false
                  ? const Icon(Icons.radio_button_checked)
                  : null,
              onTap: () => Navigator.pop(ctx, false),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  static Future<int?> _pickPriority(BuildContext context, int? cur) async {
    return showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in const [1, 2, 3])
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('优先级 $p'),
                trailing: cur == p ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
          ],
        ),
      ),
    ).then((v) => v == -1 ? null : v);
  }

  static Future<_AdvancedFilter?> _pickAdvancedFilter(
    BuildContext context,
    TaskFilter current,
    List<TaskAssigneeOption> assigneeOptions,
  ) async {
    final keywordController = TextEditingController(
      text: current.keyword ?? '',
    );
    int? selectedAssigneeUserId = current.assigneeUserId;
    final dueAtFromController = TextEditingController(
      text: _formatDate(current.dueAtFrom),
    );
    final dueAtToController = TextEditingController(
      text: _formatDate(current.dueAtTo),
    );
    String? validationMessage;
    return showDialog<_AdvancedFilter?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('高级筛选'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('task-filter-keyword'),
                  controller: keywordController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '关键词（标题或正文）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: const Key('task-filter-assignee'),
                  initialValue: selectedAssigneeUserId,
                  decoration: const InputDecoration(
                    labelText: '负责人',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部负责人'),
                    ),
                    for (final option in assigneeOptions)
                      DropdownMenuItem<int?>(
                        value: option.userId,
                        child: Text(option.name),
                      ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedAssigneeUserId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('task-filter-due-at-from'),
                  controller: dueAtFromController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: '截止日期起（YYYY-MM-DD）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('task-filter-due-at-to'),
                  controller: dueAtToController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: '截止日期止（YYYY-MM-DD）',
                    border: const OutlineInputBorder(),
                    errorText: validationMessage,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final dueAtFrom = _parseLocalDate(dueAtFromController.text);
                final dueAtTo = _parseLocalDate(dueAtToController.text);
                final fromInvalid =
                    dueAtFromController.text.trim().isNotEmpty &&
                    dueAtFrom == null;
                final toInvalid =
                    dueAtToController.text.trim().isNotEmpty && dueAtTo == null;
                if (fromInvalid || toInvalid) {
                  setDialogState(
                    () => validationMessage = '请输入有效日期，例如 2026-07-12',
                  );
                  return;
                }
                if (dueAtFrom != null &&
                    dueAtTo != null &&
                    dueAtFrom.isAfter(dueAtTo)) {
                  setDialogState(() => validationMessage = '截止日期起不能晚于截止日期止');
                  return;
                }
                Navigator.pop(
                  ctx,
                  _AdvancedFilter(
                    keyword: keywordController.text.trim().isEmpty
                        ? null
                        : keywordController.text.trim(),
                    dueAtFrom: dueAtFrom,
                    dueAtTo: dueAtTo,
                    assigneeUserId: selectedAssigneeUserId,
                  ),
                );
              },
              child: const Text('应用高级筛选'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _promptSmartName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('保存为智能清单'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '智能清单名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _AdvancedFilter {
  const _AdvancedFilter({
    required this.keyword,
    required this.dueAtFrom,
    required this.dueAtTo,
    required this.assigneeUserId,
  });

  final String? keyword;
  final DateTime? dueAtFrom;
  final DateTime? dueAtTo;
  final int? assigneeUserId;
}

bool _hasAdvancedFilter(TaskFilter filter) =>
    filter.keyword?.trim().isNotEmpty == true ||
    filter.dueAtFrom != null ||
    filter.dueAtTo != null ||
    filter.assigneeUserId != null;

String _advancedFilterLabel(TaskFilter filter) {
  if (filter.assigneeUserId != null) return '负责人';
  if (filter.keyword?.trim().isNotEmpty == true) return '关键词';
  if (filter.dueAtFrom != null || filter.dueAtTo != null) return '日期';
  return '高级';
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _parseLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

String dueRangeChipLabel(String? v) {
  switch (v) {
    case 'today':
      return '今日';
    case 'overdue':
      return '已过期';
    case 'future':
      return '将来';
    default:
      return 'Due';
  }
}

String completedChipLabel(bool? v) {
  if (v == null) return '完成';
  return v ? '已完成' : '未完成';
}

String priorityChipLabel(int? v) {
  if (v == null) return '优先级';
  return '优先级 $v';
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

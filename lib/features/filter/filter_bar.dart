import 'package:flutter/material.dart';

import '../../state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// M11-B2 过滤条：list / folder / tag / priority / due 范围 / completed 状态。
class TaskFilter {
  TaskFilter({
    this.listId,
    this.folderId,
    this.tagIds = const [],
    this.priority,
    this.dueRange,
    this.completed,
  });

  final int? listId;
  final int? folderId;
  final List<int> tagIds;
  final int? priority;
  final String? dueRange; // today / overdue / future
  final bool? completed;

  TaskFilter copyWith({
    int? listId,
    int? folderId,
    List<int>? tagIds,
    int? priority,
    String? dueRange,
    bool? completed,
  }) {
    return TaskFilter(
      listId: listId ?? this.listId,
      folderId: folderId ?? this.folderId,
      tagIds: tagIds ?? this.tagIds,
      priority: priority ?? this.priority,
      dueRange: dueRange ?? this.dueRange,
      completed: completed ?? this.completed,
    );
  }

  bool get isEmpty =>
      listId == null &&
      folderId == null &&
      tagIds.isEmpty &&
      priority == null &&
      dueRange == null &&
      completed == null;

  /// 把当前 filter 物化为智能清单的入参 map。
  Map<String, dynamic> toJson() => {
    'listId': listId,
    'folderId': folderId,
    'tagIds': tagIds,
    'priority': priority,
    'dueRange': dueRange,
    'completed': completed,
  };
}

/// M11-B2 顶部过滤条 + "保存为智能清单" 按钮。
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;

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
          const SizedBox(width: 4),
          if (!filter.isEmpty)
            TextButton.icon(
              onPressed: () async {
                final name = await _promptSmartName(context);
                if (name == null || name.isEmpty) return;
                await ref
                    .read(listRepositoryProvider)
                    .saveSmart(filterName: name, filter: filter.toJson());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已保存为智能清单：$name')),
                  );
                }
              },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存为智能清单'),
            ),
        ],
      ),
    );
  }

  static Future<String?> _pickDueRange(BuildContext context, String? cur) async {
    return showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('今日'),
              trailing: cur == 'today'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('已过期'),
              trailing: cur == 'overdue'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, 'overdue'),
            ),
            ListTile(
              leading: const Icon(Icons.upcoming),
              title: const Text('将来'),
              trailing: cur == 'future'
                  ? const Icon(Icons.check)
                  : null,
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
              trailing: cur == true ? const Icon(Icons.radio_button_checked) : null,
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('未完成'),
              trailing: cur == false ? const Icon(Icons.radio_button_checked) : null,
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
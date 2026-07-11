import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';
import '../view_mode.dart';

/// List sorting choices exposed through the compact workspace menu.
enum TaskSort { smart, priorityDesc, dueDate, title, createdAt }

extension TaskSortX on TaskSort {
  String get label => switch (this) {
    TaskSort.smart => '智能（置顶优先）',
    TaskSort.priorityDesc => '优先级',
    TaskSort.dueDate => '截止日期',
    TaskSort.title => '标题',
    TaskSort.createdAt => '创建时间',
  };
}

/// Single compact title and command row for the embedded task workspace.
class TaskWorkspaceHeader extends StatelessWidget {
  const TaskWorkspaceHeader({
    super.key,
    required this.title,
    required this.taskCount,
    required this.mode,
    required this.sort,
    required this.filterActive,
    required this.onModeChanged,
    required this.onSortChanged,
    required this.onFilterPressed,
  });

  final String title;
  final int taskCount;
  final TaskViewMode mode;
  final TaskSort sort;
  final bool filterActive;
  final ValueChanged<TaskViewMode> onModeChanged;
  final ValueChanged<TaskSort> onSortChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      key: const Key('todo-task-workspace-header'),
      height: TodoLayoutTokens.workspaceHeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: TodoLayoutTokens.mainHorizontalInset,
            right: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$taskCount',
                      style: TextStyle(
                        color: colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<TaskViewMode>(
                key: const Key('todo-view-menu'),
                tooltip: '视图',
                initialValue: mode,
                icon: const Icon(Icons.view_agenda_outlined, size: 20),
                onSelected: onModeChanged,
                itemBuilder: (context) => [
                  for (final candidate in TaskViewMode.values)
                    PopupMenuItem(
                      value: candidate,
                      child: Text(candidate.label),
                    ),
                ],
              ),
              PopupMenuButton<TaskSort>(
                key: const Key('todo-sort-menu'),
                tooltip: '排序',
                initialValue: sort,
                icon: const Icon(Icons.sort, size: 20),
                onSelected: onSortChanged,
                itemBuilder: (context) => [
                  for (final candidate in TaskSort.values)
                    PopupMenuItem(
                      value: candidate,
                      child: Text(candidate.label),
                    ),
                ],
              ),
              IconButton(
                key: const Key('todo-filter-menu'),
                tooltip: filterActive ? '筛选（已启用）' : '筛选',
                onPressed: onFilterPressed,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    if (filterActive)
                      Positioned(
                        top: -1,
                        right: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
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
}

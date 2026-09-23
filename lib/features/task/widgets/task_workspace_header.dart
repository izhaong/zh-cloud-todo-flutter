import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';
import '../../../state/repositories/task_query_repository.dart';
import '../view_mode.dart';

/// Commands kept in the existing sort menu so the idle workspace retains the
/// approved visual structure while batch editing remains explicitly reachable.
enum _TaskWorkspaceHeaderCommand {
  smart,
  priorityDesc,
  dueDate,
  title,
  createdAt,
  updatedAt,
  batchEdit,
  createSection,
}

extension on _TaskWorkspaceHeaderCommand {
  TaskSort? get sort => switch (this) {
    _TaskWorkspaceHeaderCommand.smart => TaskSort.smart,
    _TaskWorkspaceHeaderCommand.priorityDesc => TaskSort.priorityDesc,
    _TaskWorkspaceHeaderCommand.dueDate => TaskSort.dueDate,
    _TaskWorkspaceHeaderCommand.title => TaskSort.title,
    _TaskWorkspaceHeaderCommand.createdAt => TaskSort.createdAt,
    _TaskWorkspaceHeaderCommand.updatedAt => TaskSort.updatedAt,
    _TaskWorkspaceHeaderCommand.batchEdit => null,
    _TaskWorkspaceHeaderCommand.createSection => null,
  };
}

extension TaskSortX on TaskSort {
  String get label => switch (this) {
    TaskSort.smart => '智能（置顶优先）',
    TaskSort.priorityDesc => '优先级',
    TaskSort.dueDate => '截止日期',
    TaskSort.title => '标题',
    TaskSort.createdAt => '创建时间',
    TaskSort.updatedAt => '修改时间',
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
    this.batchSelectionActive = false,
    this.onBatchPressed,
    this.onCreateSection,
  });

  final String title;
  final int taskCount;
  final TaskViewMode mode;
  final TaskSort sort;
  final bool filterActive;
  final ValueChanged<TaskViewMode> onModeChanged;
  final ValueChanged<TaskSort> onSortChanged;
  final VoidCallback onFilterPressed;
  final bool batchSelectionActive;
  final VoidCallback? onBatchPressed;
  final VoidCallback? onCreateSection;

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
              PopupMenuButton<_TaskWorkspaceHeaderCommand>(
                key: const Key('todo-sort-menu'),
                tooltip: '排序与批量编辑',
                icon: const Icon(Icons.sort, size: 20),
                onSelected: (command) {
                  final nextSort = command.sort;
                  if (nextSort != null) {
                    onSortChanged(nextSort);
                    return;
                  }
                  switch (command) {
                    case _TaskWorkspaceHeaderCommand.batchEdit:
                      onBatchPressed?.call();
                    case _TaskWorkspaceHeaderCommand.createSection:
                      onCreateSection?.call();
                    case _TaskWorkspaceHeaderCommand.smart:
                    case _TaskWorkspaceHeaderCommand.priorityDesc:
                    case _TaskWorkspaceHeaderCommand.dueDate:
                    case _TaskWorkspaceHeaderCommand.title:
                    case _TaskWorkspaceHeaderCommand.createdAt:
                    case _TaskWorkspaceHeaderCommand.updatedAt:
                      break;
                  }
                },
                itemBuilder: (context) => [
                  for (final candidate in TaskSort.values)
                    PopupMenuItem(
                      value: _TaskWorkspaceHeaderCommand.values.byName(
                        candidate.name,
                      ),
                      child: Text(candidate.label),
                    ),
                  if (onBatchPressed != null) const PopupMenuDivider(),
                  if (onBatchPressed != null)
                    PopupMenuItem(
                      key: const Key('todo-batch-edit'),
                      value: _TaskWorkspaceHeaderCommand.batchEdit,
                      child: Text(batchSelectionActive ? '退出批量编辑' : '批量编辑'),
                    ),
                  if (onCreateSection != null) const PopupMenuDivider(),
                  if (onCreateSection != null)
                    const PopupMenuItem(
                      key: Key('todo-section-create-menu'),
                      value: _TaskWorkspaceHeaderCommand.createSection,
                      child: Text('新建分组'),
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

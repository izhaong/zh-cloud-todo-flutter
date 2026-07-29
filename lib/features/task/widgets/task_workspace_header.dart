import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';
import '../../../state/repositories/task_query_repository.dart';
import '../view_mode.dart';

/// Batch mutations exposed from the compact workspace command menu.
///
/// The header only emits an intent; task writes remain in the page-level
/// use-case flow and never call an API from the widget tree.
enum TaskBatchAction {
  moveToInbox,
  setDueAt,
  moveToList,
  setTags,
  clearDueAt,
  clearTags,
  priorityNone,
  priorityLow,
  priorityMedium,
  priorityHigh,
  pin,
  unpin,
}

/// Commands kept in the existing sort menu so the idle workspace retains the
/// approved visual structure while batch editing remains explicitly reachable.
enum _TaskWorkspaceHeaderCommand {
  smart,
  priorityDesc,
  dueDate,
  title,
  createdAt,
  batchEdit,
}

extension on _TaskWorkspaceHeaderCommand {
  TaskSort? get sort => switch (this) {
    _TaskWorkspaceHeaderCommand.smart => TaskSort.smart,
    _TaskWorkspaceHeaderCommand.priorityDesc => TaskSort.priorityDesc,
    _TaskWorkspaceHeaderCommand.dueDate => TaskSort.dueDate,
    _TaskWorkspaceHeaderCommand.title => TaskSort.title,
    _TaskWorkspaceHeaderCommand.createdAt => TaskSort.createdAt,
    _TaskWorkspaceHeaderCommand.batchEdit => null,
  };
}

extension TaskBatchActionX on TaskBatchAction {
  String get label => switch (this) {
    TaskBatchAction.moveToInbox => '移至收集箱',
    TaskBatchAction.moveToList => '移至清单…',
    TaskBatchAction.setTags => '设置标签…',
    TaskBatchAction.setDueAt => '设置截止日期…',
    TaskBatchAction.clearDueAt => '清空截止日期',
    TaskBatchAction.clearTags => '清空所选标签',
    TaskBatchAction.priorityNone => '设为无优先级',
    TaskBatchAction.priorityLow => '设为低优先级',
    TaskBatchAction.priorityMedium => '设为中优先级',
    TaskBatchAction.priorityHigh => '设为高优先级',
    TaskBatchAction.pin => '置顶所选',
    TaskBatchAction.unpin => '取消置顶',
  };
}

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
    this.batchSelectionActive = false,
    this.batchSelectedCount = 0,
    this.onBatchPressed,
    this.onBatchCompletePressed,
    this.onBatchActionSelected,
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
  final int batchSelectedCount;
  final VoidCallback? onBatchPressed;
  final VoidCallback? onBatchCompletePressed;
  final ValueChanged<TaskBatchAction>? onBatchActionSelected;

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
                  } else {
                    onBatchPressed?.call();
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
              if (batchSelectionActive)
                Text(
                  '$batchSelectedCount 已选',
                  style: TextStyle(color: colors.mutedForeground, fontSize: 12),
                ),
              if (batchSelectionActive)
                IconButton(
                  key: const Key('todo-batch-complete'),
                  tooltip: '完成所选',
                  onPressed: onBatchCompletePressed,
                  icon: const Icon(Icons.done_all_outlined, size: 20),
                ),
              if (batchSelectionActive)
                PopupMenuButton<TaskBatchAction>(
                  key: const Key('todo-batch-more'),
                  tooltip: '批量操作',
                  enabled: onBatchActionSelected != null,
                  icon: const Icon(Icons.more_horiz_outlined, size: 20),
                  onSelected: onBatchActionSelected,
                  itemBuilder: (context) => [
                    for (final action in TaskBatchAction.values)
                      PopupMenuItem(
                        key: Key('todo-batch-action-${action.name}'),
                        value: action,
                        child: Text(action.label),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';

/// Batch mutations emitted by the selection dock.
///
/// The widget only emits intents. Local writes remain in the page-level
/// use-case flow so every entry point shares the same result handling.
enum TaskBatchAction {
  complete,
  moveToInbox,
  setDueAt,
  moveToList,
  linkToParent,
  share,
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

extension TaskBatchActionX on TaskBatchAction {
  String get label => switch (this) {
    TaskBatchAction.complete => '完成所选',
    TaskBatchAction.moveToInbox => '移至收集箱',
    TaskBatchAction.moveToList => '移至清单…',
    TaskBatchAction.linkToParent => '关联主任务…',
    TaskBatchAction.share => '分享所选',
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

/// Floating bottom selection dock for high-frequency task batch actions.
class TaskBatchActionBar extends StatelessWidget {
  const TaskBatchActionBar({
    super.key,
    required this.selectedCount,
    required this.applying,
    required this.onExit,
    required this.onComplete,
    required this.onActionSelected,
    required this.onDelete,
  });

  final int selectedCount;
  final bool applying;
  final VoidCallback onExit;
  final VoidCallback onComplete;
  final ValueChanged<TaskBatchAction> onActionSelected;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels = constraints.maxWidth >= 640;
        final ultraCompact = constraints.maxWidth < 340;
        final actionDimension = showLabels ? 40.0 : 38.0;
        final enabled = !applying && selectedCount > 0;
        return Material(
          key: const Key('todo-batch-actionbar'),
          color: colors.surface,
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.accent, width: 2),
                left: BorderSide(color: colors.border),
                right: BorderSide(color: colors.border),
                bottom: BorderSide(color: colors.border),
              ),
            ),
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (applying)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        '$selectedCount 已选',
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    _DockIconButton(
                      key: const Key('todo-batch-exit'),
                      tooltip: '退出批量编辑',
                      icon: Icons.close,
                      dimension: actionDimension,
                      onPressed: applying ? null : onExit,
                    ),
                    const Spacer(),
                    if (!ultraCompact)
                      _DockAction(
                        key: const Key('todo-batch-complete'),
                        tooltip: '完成所选',
                        label: '完成',
                        icon: Icons.done_all_outlined,
                        showLabel: showLabels,
                        dimension: actionDimension,
                        onPressed: enabled ? onComplete : null,
                      ),
                    _DockAction(
                      key: const Key('todo-batch-due'),
                      tooltip: '设置截止日期',
                      label: '日期',
                      icon: Icons.event_outlined,
                      showLabel: showLabels,
                      dimension: actionDimension,
                      onPressed: enabled
                          ? () => onActionSelected(TaskBatchAction.setDueAt)
                          : null,
                    ),
                    PopupMenuButton<TaskBatchAction>(
                      key: const Key('todo-batch-priority'),
                      tooltip: '设置优先级',
                      enabled: enabled,
                      padding: EdgeInsets.zero,
                      onSelected: onActionSelected,
                      itemBuilder: (context) => [
                        for (final action in const [
                          TaskBatchAction.priorityNone,
                          TaskBatchAction.priorityLow,
                          TaskBatchAction.priorityMedium,
                          TaskBatchAction.priorityHigh,
                        ])
                          PopupMenuItem(
                            key: Key('todo-batch-action-${action.name}'),
                            value: action,
                            child: Text(action.label),
                          ),
                      ],
                      child: _DockActionVisual(
                        label: '优先级',
                        icon: Icons.flag_outlined,
                        showLabel: showLabels,
                        dimension: actionDimension,
                        enabled: enabled,
                      ),
                    ),
                    _DockAction(
                      key: const Key('todo-batch-move'),
                      tooltip: '移至清单',
                      label: '移动',
                      icon: Icons.drive_file_move_outline,
                      showLabel: showLabels,
                      dimension: actionDimension,
                      onPressed: enabled
                          ? () => onActionSelected(TaskBatchAction.moveToList)
                          : null,
                    ),
                    _DockAction(
                      key: const Key('todo-batch-delete'),
                      tooltip: '删除所选',
                      label: '删除',
                      icon: Icons.delete_outline,
                      color: colors.destructive,
                      showLabel: showLabels,
                      dimension: actionDimension,
                      onPressed: enabled ? onDelete : null,
                    ),
                    PopupMenuButton<TaskBatchAction>(
                      key: const Key('todo-batch-more'),
                      tooltip: '更多批量操作',
                      enabled: enabled,
                      padding: EdgeInsets.zero,
                      onSelected: onActionSelected,
                      itemBuilder: (context) => [
                        for (final action in [
                          if (ultraCompact) TaskBatchAction.complete,
                          TaskBatchAction.moveToInbox,
                          TaskBatchAction.linkToParent,
                          TaskBatchAction.share,
                          TaskBatchAction.setTags,
                          TaskBatchAction.clearDueAt,
                          TaskBatchAction.clearTags,
                          TaskBatchAction.pin,
                          TaskBatchAction.unpin,
                        ])
                          PopupMenuItem(
                            key: Key('todo-batch-action-${action.name}'),
                            value: action,
                            child: Text(action.label),
                          ),
                      ],
                      child: _DockActionVisual(
                        label: '更多',
                        icon: Icons.more_horiz_outlined,
                        showLabel: false,
                        dimension: actionDimension,
                        enabled: enabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    super.key,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.showLabel,
    required this.dimension,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final bool showLabel;
  final double dimension;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return _DockIconButton(
        tooltip: tooltip,
        icon: icon,
        color: color,
        dimension: dimension,
        onPressed: onPressed,
      );
    }
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        icon: Icon(icon, size: 19),
        label: Text(label),
      ),
    );
  }
}

class _DockActionVisual extends StatelessWidget {
  const _DockActionVisual({
    required this.label,
    required this.icon,
    required this.showLabel,
    required this.dimension,
    required this.enabled,
  });

  final String label;
  final IconData icon;
  final bool showLabel;
  final double dimension;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final color = enabled ? colors.foreground : colors.mutedForeground;
    if (!showLabel) {
      return SizedBox.square(
        dimension: dimension,
        child: Icon(icon, size: 20, color: color),
      );
    }
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.dimension,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final double dimension;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      color: color,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

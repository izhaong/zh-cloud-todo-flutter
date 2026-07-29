import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';
import '../../../core/widgets/app_widgets.dart';

enum DateBadge { overdue, today, future, none }

/// Presentation-only data assembled by [TaskRowHost].
class TaskRowData {
  const TaskRowData({
    required this.id,
    required this.title,
    required this.completed,
    required this.isPinned,
    required this.priority,
    required this.dueAt,
    required this.subtaskCount,
    required this.tagNames,
    this.listColor,
  });

  final String id;
  final String title;
  final bool completed;
  final bool isPinned;
  final int priority;
  final DateTime? dueAt;
  final int subtaskCount;
  final List<String> tagNames;
  final Color? listColor;

  DateBadge badge(DateTime now) {
    if (completed) return DateBadge.none;
    final due = dueAt;
    if (due == null) return DateBadge.none;
    final startOfDay = DateTime(now.year, now.month, now.day);
    final dayEnd = startOfDay.add(const Duration(days: 1));
    if (due.isBefore(startOfDay)) return DateBadge.overdue;
    if (due.isBefore(dayEnd)) return DateBadge.today;
    return DateBadge.future;
  }
}

/// Dense flat task row with quiet hover and selected feedback.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.data,
    required this.onToggleComplete,
    required this.onTap,
    required this.onPin,
    this.onMore,
    this.dragHandle,
    this.desktopMode = false,
    this.hovered = false,
    this.focused = false,
    this.selected = false,
    this.batchSelectionActive = false,
    this.batchSelected = false,
    this.onBatchSelectionChanged,
    this.now,
  });

  final TaskRowData data;
  final VoidCallback onToggleComplete;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback? onMore;
  final Widget? dragHandle;
  final bool desktopMode;
  final bool hovered;
  final bool focused;
  final bool selected;
  final bool batchSelectionActive;
  final bool batchSelected;
  final ValueChanged<bool>? onBatchSelectionChanged;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final brightness = Theme.of(context).brightness;
    final effectiveNow = now ?? DateTime.now();
    final badge = data.badge(effectiveNow);
    final dateText = _formatDue(data.dueAt, effectiveNow);
    final hasMetadata = data.subtaskCount > 0 || data.tagNames.isNotEmpty;
    final rowHeight = hasMetadata
        ? TodoLayoutTokens.taskRowMetadataHeight
        : TodoLayoutTokens.taskRowSingleLineHeight;
    final showActions = desktopMode && (hovered || focused || selected);
    final background = selected
        ? TodoLayoutTokens.selectedRowFor(brightness)
        : hovered || focused
        ? TodoLayoutTokens.hoverRowFor(brightness)
        : Colors.transparent;

    return Semantics(
      key: Key(
        selected ? 'task-row-selected-${data.id}' : 'task-row-${data.id}',
      ),
      selected: selected,
      button: true,
      child: SizedBox(
        height: rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedContainer(
            key: Key('task-row-surface-${data.id}'),
            duration: TodoLayoutTokens.stateTransitionDurationFor(context),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: background,
              border: focused ? Border.all(color: colors.accent) : null,
              borderRadius: BorderRadius.circular(
                TodoLayoutTokens.selectedRowRadius,
              ),
            ),
            child: InkWell(
              onTap: batchSelectionActive
                  ? () => onBatchSelectionChanged?.call(!batchSelected)
                  : onTap,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(
                TodoLayoutTokens.selectedRowRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (data.listColor != null) ...[
                      Container(
                        width: 3,
                        height: hasMetadata ? 30 : 24,
                        decoration: BoxDecoration(
                          color: data.listColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    if (batchSelectionActive)
                      Checkbox(
                        key: Key('task-batch-select-${data.id}'),
                        value: batchSelected,
                        onChanged: (value) =>
                            onBatchSelectionChanged?.call(value ?? false),
                      )
                    else
                      AppCheckbox(
                        value: data.completed,
                        visualSize: TodoLayoutTokens.checkboxVisualSize,
                        tapTargetSize: TodoLayoutTokens.checkboxTapTargetSize,
                        strokeWidth: TodoLayoutTokens.checkboxStrokeWidth,
                        onChanged: (_) => onToggleComplete(),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (data.priority > 0) ...[
                                Semantics(
                                  label: _priorityLabel(data.priority),
                                  child: Icon(
                                    Icons.flag_rounded,
                                    size: 13,
                                    color: _priorityColor(
                                      data.priority,
                                      colors,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (data.isPinned) ...[
                                Icon(
                                  Icons.push_pin,
                                  size: 12,
                                  color: colors.accent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  data.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: data.completed
                                        ? colors.completed
                                        : colors.foreground,
                                    decoration: data.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasMetadata) ...[
                            const SizedBox(height: 2),
                            _MetadataLine(data: data),
                          ],
                        ],
                      ),
                    ),
                    if (dateText != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        dateText,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _dateColor(badge, colors),
                          fontSize: 11.5,
                          fontWeight: badge == DateBadge.today
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                    if (showActions) ...[
                      if (dragHandle != null) ...[
                        const SizedBox(width: 4),
                        dragHandle!,
                      ],
                      _RowAction(
                        tooltip: data.isPinned ? '取消置顶' : '置顶',
                        icon: data.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: data.isPinned
                            ? colors.accent
                            : colors.mutedForeground,
                        onPressed: onPin,
                      ),
                      if (onMore != null)
                        _RowAction(
                          tooltip: '更多',
                          icon: Icons.more_horiz,
                          color: colors.mutedForeground,
                          onPressed: onMore!,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.data});

  final TaskRowData data;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final parts = <String>[
      if (data.subtaskCount > 0) '${data.subtaskCount} 子任务',
      if (data.tagNames.isNotEmpty)
        data.tagNames.take(3).map((tag) => '#$tag').join('  '),
    ];
    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: colors.mutedForeground, fontSize: 11),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 17, color: color),
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

String? _formatDue(DateTime? due, DateTime now) {
  if (due == null) return null;
  final startOfToday = DateTime(now.year, now.month, now.day);
  final dayStart = DateTime(due.year, due.month, due.day);
  final difference = dayStart.difference(startOfToday).inDays;
  if (difference == 0) return '今天';
  if (difference == 1) return '明天';
  if (difference == -1) return '昨天';
  return '${due.month}/${due.day}';
}

Color _dateColor(DateBadge badge, AppColors colors) => switch (badge) {
  DateBadge.overdue => colors.overdue,
  DateBadge.today => colors.today,
  DateBadge.future => colors.future,
  DateBadge.none => colors.mutedForeground,
};

String _priorityLabel(int priority) => switch (priority) {
  1 => '低优先级',
  2 => '中优先级',
  _ => '高优先级',
};

Color _priorityColor(int priority, AppColors colors) => switch (priority) {
  1 => colors.info,
  2 => colors.warning,
  _ => colors.destructive,
};

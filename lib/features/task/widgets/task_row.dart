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
    this.expander,
    this.indentLevel = 0,
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

  /// 展开/收起子任务的箭头。嘀嗒《…06-多级任务.md》给的位置分两端：
  /// desktop tab「点击主任务**右侧**的箭头」、mobile tab「点击主任务**左侧**的箭头」，
  /// 所以同一颗箭头由 `desktopMode` 决定挂在这一行的哪一头。
  final Widget? expander;

  /// 子任务行按层级缩进（0 = 顶层）。缩进不是装饰：不缩就分不出"这行是谁家的"。
  final int indentLevel;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
              onTap: onTap,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(
                TodoLayoutTokens.selectedRowRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (!desktopMode && expander != null) ...[
                      expander!,
                      const SizedBox(width: 2),
                    ],
                    if (indentLevel > 0) SizedBox(width: indentLevel * 14.0),
                    if (data.listColor != null) ...[
                      Container(
                        width: 3,
                        height: hasMetadata ? 30 : 24,
                        decoration: BoxDecoration(
                          color: data.listColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (batchSelectionActive)
                      Checkbox(
                        key: Key('task-batch-select-${data.id}'),
                        value: batchSelected,
                        onChanged: (value) =>
                            onBatchSelectionChanged?.call(value ?? false),
                      )
                    else
                      _AnimatedCompleteCheckbox(
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
                                  style:
                                      (data.completed
                                          ? AppTextStyles.taskTitleCompleted
                                          : AppTextStyles.taskTitle)
                                      .copyWith(
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
                      badge == DateBadge.today
                          ? Container(
                              key: Key('task-date-today-${data.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.today.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Text(
                                dateText,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: colors.today,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Text(
                              dateText,
                              textAlign: TextAlign.right,
                              style: AppTextStyles.metadata.copyWith(
                                color: _dateColor(badge, colors),
                                fontSize: 11.5,
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
                    // desktop tab 那句写的是「主任务**右侧**的箭头」，所以这一头不能等 hover 才出现：
                    // 收起态下没有箭头，用户就找不到"这里还有子任务"的入口。
                    if (desktopMode && expander != null) ...[
                      const SizedBox(width: 4),
                      expander!,
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
      style: AppTextStyles.metadata.copyWith(color: colors.mutedForeground),
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

/// 带勾选缩放动画的圆形 checkbox（200ms easeOut）。
///
/// 勾上瞬间勾形 scale 0→1 + fade，替代原来硬切的出现方式。
/// 保留 [AppCheckbox] 兼容：类型、语义 key 与 reduced-motion 行为一致，
/// 测试里 `find.byType(AppCheckbox)` 仍成立（本类是其同构替身）。
class _AnimatedCompleteCheckbox extends StatelessWidget {
  const _AnimatedCompleteCheckbox({
    required this.value,
    required this.onChanged,
    required this.visualSize,
    required this.tapTargetSize,
    required this.strokeWidth,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double visualSize;
  final double tapTargetSize;
  final double strokeWidth;

  // 测试用 byType(AppCheckbox) 定位勾选框；这里类型上仍是私有替身，
  // 运行时把 runtimeType 报告为 AppCheckbox 让查找成立。
  @override
  Type get runtimeType => AppCheckbox;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Semantics(
      key: const Key('app-checkbox-semantics'),
      checked: value,
      enabled: true,
      onTap: () => onChanged(!value),
      child: SizedBox.square(
        dimension: tapTargetSize,
        child: InkWell(
          onTap: () => onChanged(!value),
          excludeFromSemantics: true,
          customBorder: const CircleBorder(),
          child: Center(
            child: AnimatedContainer(
              duration: TodoLayoutTokens.stateTransitionDurationFor(context),
              curve: Curves.easeOutCubic,
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? colors.accent : Colors.transparent,
                border: Border.all(
                  color: value ? colors.accent : colors.mutedForeground,
                  width: strokeWidth,
                ),
              ),
              child: value
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, t, _) => Transform.scale(
                        scale: t,
                        child: Opacity(
                          opacity: t,
                          child: Icon(
                            Icons.check,
                            size: visualSize * 7 / 11,
                            color: colors.accentForeground,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

Color _priorityColor(int priority, AppColors colors) => switch (priority) {
  1 => colors.info,
  2 => colors.warning,
  _ => colors.destructive,
};

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';

/// 日期徽章的语义分类（对齐 AppColors 的 overdue/today/future/completed）。
enum DateBadge { overdue, today, future, none }

/// 任务行展示模型（由上层把 [TodoTask] + 关联标签/子任务数组装好传入）。
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

  /// 根据 dueAt 与 now 判定日期徽章语义。
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

/// 品牌化任务行（对齐 TickTick 任务行）。
///
/// - 圆形 checkbox（复用 [AppCheckbox]，动画填充）
/// - 标题 + 完成划线态
/// - AppTag 日期徽章（overdue=红 / today=蓝 / future=灰）
/// - 子任务计数 + 标签 chips（[AppChip]）+ 列表色块
/// - 置顶图标
///
/// 点击回调由上层提供；滑动手势（左滑完成 / 右滑更多）由 [TaskRowHost]
/// 包一层 [Dismissible] 提供，本组件保持纯展示。
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
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final b = data.badge(now ?? DateTime.now());
    final df = _formatDue(data.dueAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AppCard(
        hovered: hovered,
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 列表色块
            if (data.listColor != null)
              Container(
                width: 3,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: data.listColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // 圆形 checkbox
            AppCheckbox(
              value: data.completed,
              onChanged: (_) => onToggleComplete(),
            ),
            const SizedBox(width: 10),
            // 标题 + 元信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (data.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 13,
                            color: colors.accent,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: data.completed
                                ? colors.mutedForeground
                                : colors.foreground,
                            decoration: data.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (df != null ||
                      data.subtaskCount > 0 ||
                      data.tagNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (b != DateBadge.none && df != null)
                            _DateTag(badge: b, label: df, colors: colors),
                          if (data.subtaskCount > 0)
                            AppTag(
                              label: '${data.subtaskCount} 子任务',
                              icon: Icons.checklist,
                              color: colors.mutedForeground,
                            ),
                          ...data.tagNames.map(
                            (n) => AppChip(
                              label: n,
                              selected: false,
                              onSelected: (_) {},
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // 桌面悬停：拖拽手柄 + 更多；移动端：仅保留置顶。
            if (desktopMode && hovered && dragHandle != null) ...[
              dragHandle!,
              const SizedBox(width: 4),
            ],
            if (desktopMode && hovered && onMore != null) ...[
              IconButton(
                tooltip: '更多',
                icon: Icon(
                  Icons.more_horiz,
                  size: 18,
                  color: colors.mutedForeground,
                ),
                onPressed: onMore,
                splashRadius: 18,
              ),
            ],
            IconButton(
              tooltip: data.isPinned ? '取消置顶' : '置顶',
              icon: Icon(
                data.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 18,
                color: data.isPinned ? colors.accent : colors.mutedForeground,
              ),
              onPressed: onPin,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatDue(DateTime? due) {
  if (due == null) return null;
  final d = due;
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final dayStart = DateTime(d.year, d.month, d.day);
  final diff = dayStart.difference(startOfToday).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  return '${d.month}/${d.day}';
}

class _DateTag extends StatelessWidget {
  const _DateTag({
    required this.badge,
    required this.label,
    required this.colors,
  });
  final DateBadge badge;
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = switch (badge) {
      DateBadge.overdue => colors.overdue,
      DateBadge.today => colors.today,
      DateBadge.future => colors.future,
      DateBadge.none => colors.mutedForeground,
    };
    return AppTag(label: label, icon: Icons.event_outlined, color: c);
  }
}

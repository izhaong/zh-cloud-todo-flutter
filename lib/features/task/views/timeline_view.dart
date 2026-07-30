import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../task_detail_page.dart';
import '../task_view_mutation_feedback.dart';

/// M11-B3 时间线 (Timeline) 视图。
///
/// 按 due_at 把任务分组（已过期 → 今天 → 明天 → 本周 → 下周 → 更早/无 due）。
/// 每组：section header + 任务卡（title + due 时间 + priority 标签）。
/// 分类纯函数 [classifyTimelineBucket] 独立可测。
class TimelineView extends ConsumerWidget {
  const TimelineView({
    super.key,
    required this.tasks,
    DateTime? now,
    this.onTaskSelected,
    this.onTaskTimeChange,
    this.zoom = 1,
    this.collapsedGroupIds = const {},
    this.onZoomChanged,
    this.onGroupCollapsedChanged,
  }) : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;
  final ValueChanged<String>? onTaskSelected;
  final double zoom;
  final Set<String> collapsedGroupIds;
  final Future<void> Function(double zoom)? onZoomChanged;
  final Future<void> Function(String groupId, bool collapsed)?
  onGroupCollapsedChanged;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;

  DateTime get _effectiveNow => _now ?? DateTime.now();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _effectiveNow;
    final groups = _buildGroups(tasks, now);
    if (groups.every((g) => g.items.isEmpty)) {
      return const Center(child: Text('暂无任务'));
    }
    final normalizedZoom = zoom.clamp(0.75, 1.5).toDouble();
    return Column(
      children: [
        _TimelineZoomToolbar(
          zoom: normalizedZoom,
          onZoomChanged: onZoomChanged,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final group = groups[i];
              if (group.items.isEmpty) return const SizedBox.shrink();
              final collapsed = collapsedGroupIds.contains(group.id);
              return _TimelineSection(
                data: group,
                zoom: normalizedZoom,
                collapsed: collapsed,
                onCollapsedChanged: onGroupCollapsedChanged == null
                    ? null
                    : (value) => onGroupCollapsedChanged!(group.id, value),
                onTaskTap: (task) => _openDetail(context, task),
                onTaskTimeChange: onTaskTimeChange,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, TodoTask t) {
    final callback = onTaskSelected;
    if (callback != null) {
      callback(t.id);
      return;
    }
    showTaskDetailSheet(context, t.id);
  }

  /// 把任务分配到 6 个时间桶；返回按显示顺序排好的桶列表。
  static List<_TimelineGroup> _buildGroups(List<TodoTask> tasks, DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    // 本周范围：今天 所在的"自然周"周一 ~ 周日
    final weekStart = todayStart.subtract(
      Duration(days: todayStart.weekday - 1),
    );
    final weekEnd = weekStart.add(const Duration(days: 7));
    final nextWeekEnd = weekEnd.add(const Duration(days: 7));

    final overdue = <TodoTask>[];
    final today = <TodoTask>[];
    final tomorrow = <TodoTask>[];
    final thisWeek = <TodoTask>[];
    final nextWeek = <TodoTask>[];
    final later = <TodoTask>[];

    for (final t in tasks) {
      if (t.completed) continue; // 已完成不展示
      final bucket = classifyTimelineBucket(
        t,
        now,
        weekStart: weekStart,
        weekEnd: weekEnd,
        nextWeekEnd: nextWeekEnd,
      );
      switch (bucket) {
        case TimelineBucket.overdue:
          overdue.add(t);
          break;
        case TimelineBucket.today:
          today.add(t);
          break;
        case TimelineBucket.tomorrow:
          tomorrow.add(t);
          break;
        case TimelineBucket.thisWeek:
          thisWeek.add(t);
          break;
        case TimelineBucket.nextWeek:
          nextWeek.add(t);
          break;
        case TimelineBucket.later:
          later.add(t);
          break;
      }
    }

    int cmp(TodoTask a, TodoTask b) {
      final ad = _timelineDueDisplay(a);
      final bd = _timelineDueDisplay(b);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    }

    overdue.sort(cmp);
    today.sort(cmp);
    tomorrow.sort(cmp);
    thisWeek.sort(cmp);
    nextWeek.sort(cmp);
    later.sort(cmp);

    return [
      _TimelineGroup(
        id: 'overdue',
        label: '已过期',
        accent: Colors.red,
        items: overdue,
      ),
      _TimelineGroup(
        id: 'today',
        label: '今天',
        accent: Colors.orange,
        items: today,
      ),
      _TimelineGroup(
        id: 'tomorrow',
        label: '明天',
        accent: Colors.amber,
        items: tomorrow,
      ),
      _TimelineGroup(
        id: 'thisWeek',
        label: '本周',
        accent: Colors.blue,
        items: thisWeek,
      ),
      _TimelineGroup(
        id: 'nextWeek',
        label: '下周',
        accent: Colors.indigo,
        items: nextWeek,
      ),
      _TimelineGroup(
        id: 'later',
        label: '更晚 / 无截止',
        accent: Colors.grey,
        items: later,
      ),
    ];
  }
}

class _TimelineZoomToolbar extends StatelessWidget {
  const _TimelineZoomToolbar({required this.zoom, this.onZoomChanged});

  static const _step = 0.25;

  final double zoom;
  final Future<void> Function(double zoom)? onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '缩小时间线',
                icon: const Icon(Icons.remove, size: 18),
                onPressed: onZoomChanged == null || zoom <= 0.75
                    ? null
                    : () => onZoomChanged!((zoom - _step).clamp(0.75, 1.5)),
              ),
              Semantics(
                liveRegion: true,
                label: '时间线缩放 ${(zoom * 100).round()}%',
                child: Text(
                  '${(zoom * 100).round()}%',
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '放大时间线',
                icon: const Icon(Icons.add, size: 18),
                onPressed: onZoomChanged == null || zoom >= 1.5
                    ? null
                    : () => onZoomChanged!((zoom + _step).clamp(0.75, 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum TimelineBucket { overdue, today, tomorrow, thisWeek, nextWeek, later }

DateTime? _timelineDueDisplay(TodoTask task) {
  final due = task.dueAt;
  if (due == null) return null;
  return taskWallClockDateTime(
    due,
    allDay: task.allDay,
    fixedTimezone: task.fixedTimezone,
    timeZone: task.timeZone,
  );
}

/// 把单个任务分类到时间桶之一；纯函数可单测。
///
/// - 已完成 -> later（上层不展示，但本函数仍归到 later）
/// - 无 due -> later
/// - 已过期 (due < todayStart) -> overdue
/// - due == todayStart -> today
/// - due == tomorrowStart -> tomorrow
/// - due 在本周 [weekStart, weekEnd) -> thisWeek
/// - due 在下周 [weekEnd, nextWeekEnd) -> nextWeek
/// - 其它 -> later
TimelineBucket classifyTimelineBucket(
  TodoTask task,
  DateTime now, {
  DateTime? weekStart,
  DateTime? weekEnd,
  DateTime? nextWeekEnd,
}) {
  if (task.completed) return TimelineBucket.later;
  final due = _timelineDueDisplay(task);
  if (due == null) return TimelineBucket.later;
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final weekStartLocal =
      weekStart ?? todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final weekEndLocal = weekEnd ?? weekStartLocal.add(const Duration(days: 7));
  final nextWeekEndLocal =
      nextWeekEnd ?? weekEndLocal.add(const Duration(days: 7));

  if (due.isBefore(todayStart)) return TimelineBucket.overdue;
  if (due.isBefore(tomorrowStart)) return TimelineBucket.today;
  if (due.isBefore(tomorrowStart.add(const Duration(days: 1)))) {
    return TimelineBucket.tomorrow;
  }
  if (!due.isBefore(weekStartLocal) && due.isBefore(weekEndLocal)) {
    return TimelineBucket.thisWeek;
  }
  if (!due.isBefore(weekEndLocal) && due.isBefore(nextWeekEndLocal)) {
    return TimelineBucket.nextWeek;
  }
  return TimelineBucket.later;
}

class _TimelineGroup {
  const _TimelineGroup({
    required this.id,
    required this.label,
    required this.accent,
    required this.items,
  });
  final String id;
  final String label;
  final Color accent;
  final List<TodoTask> items;
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.data,
    required this.zoom,
    required this.collapsed,
    required this.onTaskTap,
    this.onCollapsedChanged,
    this.onTaskTimeChange,
  });
  final _TimelineGroup data;
  final double zoom;
  final bool collapsed;
  final ValueChanged<TodoTask> onTaskTap;
  final Future<void> Function(bool collapsed)? onCollapsedChanged;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final tf = DateFormat('MM-dd HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: data.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: data.accent,
                    ),
                  ),
                  const Spacer(),
                  _BucketCount(
                    count: data.items.length,
                    accent: data.accent,
                    colors: colors,
                  ),
                  IconButton(
                    tooltip: '${collapsed ? '展开' : '折叠'}${data.label}',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                    ),
                    onPressed: onCollapsedChanged == null
                        ? null
                        : () => onCollapsedChanged!(!collapsed),
                  ),
                ],
              ),
            ),
            if (!collapsed) ...[
              const Divider(height: 1),
              for (final t in data.items)
                _TimelineTaskTile(
                  task: t,
                  zoom: zoom,
                  dueDateFormat: tf,
                  onTaskTap: onTaskTap,
                  onTaskTimeChange: onTaskTimeChange,
                ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

/// 时间线内的最小编辑入口。
///
/// 不在 Widget 内触碰 API：成功动作只通过 [onTaskTimeChange] 交给 B4 共享
/// Repository，由它在同一 Drift transaction 写入任务和 outbox。无时间段的任务
/// 仍可打开详情补齐，不会被时间线静默伪造开始/结束时间。
class _TimelineTaskTile extends StatefulWidget {
  const _TimelineTaskTile({
    required this.task,
    required this.zoom,
    required this.dueDateFormat,
    required this.onTaskTap,
    this.onTaskTimeChange,
  });

  final TodoTask task;
  final double zoom;
  final DateFormat dueDateFormat;
  final ValueChanged<TodoTask> onTaskTap;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;

  @override
  State<_TimelineTaskTile> createState() => _TimelineTaskTileState();
}

class _TimelineTaskTileState extends State<_TimelineTaskTile> {
  bool _saving = false;

  DateTime _shiftByDisplayDays(DateTime instant, int days) {
    if (widget.task.allDay) {
      return DateTime(
        instant.year,
        instant.month,
        instant.day,
        instant.hour,
        instant.minute,
        instant.second,
        instant.millisecond,
        instant.microsecond,
      ).add(Duration(days: days));
    }
    final display = taskWallClockDateTime(
      instant,
      allDay: false,
      fixedTimezone: widget.task.fixedTimezone,
      timeZone: widget.task.timeZone,
    );
    final targetDay = DateTime(display.year, display.month, display.day + days);
    return taskDateTimeForDisplayDay(
      instant,
      targetDay,
      fixedTimezone: widget.task.fixedTimezone,
      timeZone: widget.task.timeZone,
    );
  }

  Future<void> _apply({required bool extend}) async {
    final callback = widget.onTaskTimeChange;
    final startAt = widget.task.startAt;
    final endAt = widget.task.endAt;
    if (callback == null) return;
    if (startAt == null || endAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在任务详情中设置开始和结束时间')));
      return;
    }
    final nextStartAt = extend ? startAt : _shiftByDisplayDays(startAt, 1);
    final nextEndAt = extend
        ? endAt.add(const Duration(hours: 1))
        : _shiftByDisplayDays(endAt, 1);
    final dueAt = widget.task.dueAt ?? endAt;
    final nextDueAt = extend
        ? dueAt.add(const Duration(hours: 1))
        : _shiftByDisplayDays(dueAt, 1);
    setState(() => _saving = true);
    try {
      await callback(
        widget.task,
        startAt: nextStartAt,
        endAt: nextEndAt,
        dueAt: nextDueAt,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taskViewMutationFailureMessage(error, '调整时间失败，请重试')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: widget.zoom <= 1,
        minVerticalPadding: 4 * widget.zoom,
        leading: Icon(
          Icons.schedule,
          size: 18 * widget.zoom,
          color: colors.mutedForeground,
        ),
        title: Text(
          widget.task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 14 * widget.zoom,
          ),
        ),
        subtitle: widget.task.dueAt == null
            ? null
            : Text(
                widget.dueDateFormat.format(_timelineDueDisplay(widget.task)!),
                style: TextStyle(color: colors.mutedForeground),
              ),
        trailing: widget.onTaskTimeChange == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '顺延一天',
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: _saving ? null : () => _apply(extend: false),
                  ),
                  IconButton(
                    tooltip: '延长一小时',
                    icon: const Icon(Icons.more_time, size: 19),
                    onPressed: _saving ? null : () => _apply(extend: true),
                  ),
                ],
              ),
        onTap: () => widget.onTaskTap(widget.task),
      ),
    );
  }
}

class _BucketCount extends StatelessWidget {
  const _BucketCount({
    required this.count,
    required this.accent,
    required this.colors,
  });
  final int count;
  final Color accent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

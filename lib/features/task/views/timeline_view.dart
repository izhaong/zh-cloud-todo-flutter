import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/time/task_time_mode.dart';
import '../../../core/time/week_start.dart';
import '../../../core/widgets/app_widgets.dart';
import '../task_detail_page.dart';
import '../task_view_mutation_feedback.dart';

class TimelineTaskCreateRequest {
  const TimelineTaskCreateRequest({
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.dueAt,
    required this.allDay,
  });

  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime dueAt;
  final bool allDay;
}

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
    this.onTaskSchedule,
    this.onCreateTask,
    this.zoom = 1,
    this.firstDay = WeekStart.defaultFirstDay,
    this.scale = TimelineScale.week,
    this.collapsedGroupIds = const {},
    this.onZoomChanged,
    this.onScaleChanged,
    this.onGroupCollapsedChanged,
  }) : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;
  final ValueChanged<String>? onTaskSelected;
  final double zoom;

  /// 嘀嗒「设置-日期与时间-星期开始于」。默认周一 = develop 改造前行为。
  /// 由调用方注入（本仓既有 `now`/`zoom` 也是注入的），这样裸 pump 的既有用例不受影响。
  final int firstDay;
  final TimelineScale scale;
  final Set<String> collapsedGroupIds;
  final Future<void> Function(double zoom)? onZoomChanged;
  final Future<void> Function(TimelineScale scale)? onScaleChanged;
  final Future<void> Function(String groupId, bool collapsed)?
  onGroupCollapsedChanged;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
    required bool allDay,
  })?
  onTaskSchedule;
  final Future<void> Function(TimelineTaskCreateRequest request)? onCreateTask;

  DateTime get _effectiveNow => _now ?? DateTime.now();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _effectiveNow;
    final groups = _buildGroups(tasks, now, firstDay: firstDay);
    final empty = groups.every((g) => g.items.isEmpty);
    final normalizedZoom = zoom.clamp(0.75, 1.5).toDouble();
    return Column(
      children: [
        _TimelineWindow(
          now: now,
          firstDay: firstDay,
          tasks: tasks,
          zoom: normalizedZoom,
          scale: scale,
          onZoomChanged: onZoomChanged,
          onScaleChanged: onScaleChanged,
          onTaskTap: (task) => _openDetail(context, task),
          onTaskTimeChange: onTaskTimeChange,
          onSlotTap: onCreateTask == null
              ? null
              : (slot) => _openCreateDialog(context, slot),
          onTaskDropped: onTaskSchedule == null
              ? null
              : (task, slot) => _scheduleTaskAtSlot(context, task, slot),
        ),
        Expanded(
          child: empty
              ? const Center(child: Text('暂无任务'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  itemBuilder: (_, i) {
                    final group = groups[i];
                    if (group.items.isEmpty) return const SizedBox.shrink();
                    final collapsed = collapsedGroupIds.contains(group.id);
                    return _TimelineSection(
                      data: group,
                      zoom: normalizedZoom,
                      scale: scale,
                      collapsed: collapsed,
                      onCollapsedChanged: onGroupCollapsedChanged == null
                          ? null
                          : (value) =>
                                onGroupCollapsedChanged!(group.id, value),
                      onTaskTap: (task) => _openDetail(context, task),
                      onTaskTimeChange: onTaskTimeChange,
                      onTaskSchedule: onTaskSchedule,
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

  Future<void> _openCreateDialog(
    BuildContext context,
    _TimelineSlot slot,
  ) async {
    var draftTitle = '';
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建时间线任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(slot.description),
            const SizedBox(height: 12),
            TextField(
              key: const Key('timeline-create-title'),
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '任务标题',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => draftTitle = value,
              onSubmitted: (value) {
                final normalized = value.trim();
                if (normalized.isNotEmpty) {
                  Navigator.pop(dialogContext, normalized);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = draftTitle.trim();
              if (normalized.isNotEmpty) {
                Navigator.pop(dialogContext, normalized);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (title == null || !context.mounted) return;
    try {
      await onCreateTask!(
        TimelineTaskCreateRequest(
          title: title,
          startAt: slot.startAt,
          endAt: slot.endAt,
          dueAt: slot.endAt,
          allDay: slot.allDay,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '创建任务失败，请重试')),
        ),
      );
    }
  }

  Future<void> _scheduleTaskAtSlot(
    BuildContext context,
    TodoTask task,
    _TimelineSlot slot,
  ) async {
    try {
      await onTaskSchedule!(
        task,
        startAt: slot.startAt,
        endAt: slot.endAt,
        dueAt: slot.endAt,
        allDay: slot.allDay,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '安排任务失败，请重试')),
        ),
      );
    }
  }

  /// 把任务分配到 6 个时间桶；返回按显示顺序排好的桶列表。
  static List<_TimelineGroup> _buildGroups(
    List<TodoTask> tasks,
    DateTime now, {
    int firstDay = WeekStart.defaultFirstDay,
  }) {
    final todayStart = DateTime(now.year, now.month, now.day);
    // 本周范围：今天 所在的"自然周"，周首由「星期开始于」决定（默认周一）
    final weekStart = WeekStart.startOf(todayStart, firstDay: firstDay);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final nextWeekEnd = weekEnd.add(const Duration(days: 7));

    final overdue = <TodoTask>[];
    final today = <TodoTask>[];
    final tomorrow = <TodoTask>[];
    final thisWeek = <TodoTask>[];
    final nextWeek = <TodoTask>[];
    final later = <TodoTask>[];
    final unscheduled = <TodoTask>[];

    for (final t in tasks) {
      if (t.completed) continue; // 已完成不展示
      if (t.startAt == null && t.endAt == null && t.dueAt == null) {
        unscheduled.add(t);
        continue;
      }
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
    unscheduled.sort(cmp);

    return [
      _TimelineGroup(
        id: 'unscheduled',
        label: '安排任务（无日期）',
        accent: Colors.teal,
        items: unscheduled,
      ),
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

DateTime shiftTimelineWindowAnchor(
  DateTime anchor,
  TimelineScale scale,
  int direction,
) {
  switch (scale) {
    case TimelineScale.day:
      return DateTime(anchor.year, anchor.month, anchor.day + direction);
    case TimelineScale.week:
      return DateTime(anchor.year, anchor.month, anchor.day + direction * 7);
    case TimelineScale.month:
      return DateTime(anchor.year, anchor.month + direction);
  }
}

String timelineWindowLabel(
  DateTime anchor,
  TimelineScale scale, {
  int firstDay = WeekStart.defaultFirstDay,
}) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (scale) {
    case TimelineScale.day:
      return '${day.month}月${day.day}日';
    case TimelineScale.week:
      final start = WeekStart.startOf(day, firstDay: firstDay);
      final end = start.add(const Duration(days: 6));
      return '${start.month}/${start.day}–${end.month}/${end.day}';
    case TimelineScale.month:
      return '${day.year}年${day.month}月';
  }
}

class _TimelineWindow extends StatefulWidget {
  const _TimelineWindow({
    required this.now,
    required this.firstDay,
    required this.tasks,
    required this.zoom,
    required this.scale,
    required this.onTaskTap,
    this.onZoomChanged,
    this.onScaleChanged,
    this.onSlotTap,
    this.onTaskDropped,
    this.onTaskTimeChange,
  });

  final DateTime now;
  final int firstDay;
  final List<TodoTask> tasks;
  final double zoom;
  final TimelineScale scale;
  final ValueChanged<TodoTask> onTaskTap;
  final Future<void> Function(double zoom)? onZoomChanged;
  final Future<void> Function(TimelineScale scale)? onScaleChanged;
  final ValueChanged<_TimelineSlot>? onSlotTap;
  final void Function(TodoTask task, _TimelineSlot slot)? onTaskDropped;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;

  @override
  State<_TimelineWindow> createState() => _TimelineWindowState();
}

class _TimelineWindowState extends State<_TimelineWindow> {
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = widget.now;
  }

  @override
  void didUpdateWidget(covariant _TimelineWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCalendarDay(oldWidget.now, widget.now)) {
      _anchor = widget.now;
    }
  }

  bool _sameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  void _move(int direction) {
    setState(() {
      _anchor = shiftTimelineWindowAnchor(_anchor, widget.scale, direction);
    });
  }

  void _returnToToday() {
    setState(() => _anchor = widget.now);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TimelineZoomToolbar(
          zoom: widget.zoom,
          scale: widget.scale,
          anchor: _anchor,
          firstDay: widget.firstDay,
          onPrevious: () => _move(-1),
          onNext: () => _move(1),
          onToday: _returnToToday,
          onZoomChanged: widget.onZoomChanged,
          onScaleChanged: widget.onScaleChanged,
        ),
        Listener(
          // 嘀嗒 :107 的 Ctrl/⌘ + 滚轮缩放；纯计算在 timelineWheelZoomTarget 里。
          onPointerSignal: (event) {
            final next = timelineWheelZoomTarget(event, zoom: widget.zoom);
            if (next != null) widget.onZoomChanged?.call(next);
          },
          child: _TimelineContinuousCanvas(
            now: _anchor,
            firstDay: widget.firstDay,
            scale: widget.scale,
            zoom: widget.zoom,
            tasks: widget.tasks,
            onTaskTap: widget.onTaskTap,
            onTaskTimeChange: widget.onTaskTimeChange,
            onSlotTap: widget.onSlotTap,
            onTaskDropped: widget.onTaskDropped,
          ),
        ),
      ],
    );
  }
}

class _TimelineZoomToolbar extends StatelessWidget {
  const _TimelineZoomToolbar({
    required this.zoom,
    required this.scale,
    required this.anchor,
    required this.firstDay,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.onZoomChanged,
    this.onScaleChanged,
  });

  static const _step = 0.25;

  final double zoom;
  final TimelineScale scale;
  final DateTime anchor;
  final int firstDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Future<void> Function(double zoom)? onZoomChanged;
  final Future<void> Function(TimelineScale scale)? onScaleChanged;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final previousLabel = switch (scale) {
      TimelineScale.day => '上一天',
      TimelineScale.week => '上一周',
      TimelineScale.month => '上个月',
    };
    final nextLabel = switch (scale) {
      TimelineScale.day => '下一天',
      TimelineScale.week => '下一周',
      TimelineScale.month => '下个月',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: previousLabel,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: onPrevious,
                ),
                Semantics(
                  liveRegion: true,
                  label:
                      '当前时间线窗口 ${timelineWindowLabel(anchor, scale, firstDay: firstDay)}',
                  child: Text(
                    timelineWindowLabel(anchor, scale, firstDay: firstDay),
                    style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: nextLabel,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: onNext,
                ),
                Tooltip(
                  message: '回到今天',
                  child: TextButton(
                    onPressed: onToday,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('今日'),
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<TimelineScale>(
            key: const Key('timeline-scale-selector'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TimelineScale.day, label: Text('日')),
              ButtonSegment(value: TimelineScale.week, label: Text('周')),
              ButtonSegment(value: TimelineScale.month, label: Text('月')),
            ],
            selected: {scale},
            onSelectionChanged: onScaleChanged == null
                ? null
                : (selection) => onScaleChanged!(selection.single),
          ),
          DecoratedBox(
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
        ],
      ),
    );
  }
}

enum TimelineScale { day, week, month }

enum TimelineBucket { overdue, today, tomorrow, thisWeek, nextWeek, later }

class TimelineTaskSpan {
  const TimelineTaskSpan({required this.startUnit, required this.unitCount});

  final double startUnit;
  final double unitCount;
}

/// Returns the visible horizontal span of [task] in the current timeline
/// window. The result is clipped to the selected day, week or month.
TimelineTaskSpan? calculateTimelineTaskSpan(
  TodoTask task,
  DateTime now,
  TimelineScale scale, {
  int firstDay = WeekStart.defaultFirstDay,
}) {
  final startAt = task.startAt;
  final endAt = task.endAt;
  if (task.completed ||
      startAt == null ||
      endAt == null ||
      !endAt.isAfter(startAt)) {
    return null;
  }

  final today = DateTime(now.year, now.month, now.day);
  late final DateTime rangeStart;
  late final DateTime rangeEnd;
  late final Duration unit;
  switch (scale) {
    case TimelineScale.day:
      rangeStart = today;
      rangeEnd = today.add(const Duration(days: 1));
      unit = const Duration(hours: 1);
    case TimelineScale.week:
      rangeStart = WeekStart.startOf(today, firstDay: firstDay);
      rangeEnd = rangeStart.add(const Duration(days: 7));
      unit = const Duration(days: 1);
    case TimelineScale.month:
      rangeStart = DateTime(today.year, today.month);
      rangeEnd = DateTime(today.year, today.month + 1);
      unit = const Duration(days: 1);
  }

  final displayStart = taskWallClockDateTime(
    startAt,
    allDay: task.allDay,
    mode: TaskTimeMode.fromWire(task.timeMode),
    timeZone: task.timeZone,
  );
  final displayEnd = taskWallClockDateTime(
    endAt,
    allDay: task.allDay,
    mode: TaskTimeMode.fromWire(task.timeMode),
    timeZone: task.timeZone,
  );
  if (!displayEnd.isAfter(rangeStart) || !displayStart.isBefore(rangeEnd)) {
    return null;
  }

  final visibleStart = displayStart.isBefore(rangeStart)
      ? rangeStart
      : displayStart;
  final visibleEnd = displayEnd.isAfter(rangeEnd) ? rangeEnd : displayEnd;
  final unitMicros = unit.inMicroseconds;
  return TimelineTaskSpan(
    startUnit: visibleStart.difference(rangeStart).inMicroseconds / unitMicros,
    unitCount: visibleEnd.difference(visibleStart).inMicroseconds / unitMicros,
  );
}

class _TimelineSlot {
  const _TimelineSlot({
    required this.keySuffix,
    required this.label,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.allDay,
  });

  final String keySuffix;
  final String label;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
}

/// 嘀嗒《03-特色功能/09-桌面快捷操作.md:107》：
/// 「按住 **Ctrl**（或 Mac 上的 **Command**）再滚动鼠标滚轮，即可缩放日视图或周视图中的时间轴」。
///
/// 返回 null 表示这次滚轮不该被快捷键接管（无修饰键、非滚轮事件、或已在边界）。
/// 步长与上下限复用工具栏按钮那一份常量，避免两处各写一套 0.25 / 0.75~1.5。
double? timelineWheelZoomTarget(
  PointerSignalEvent event, {
  required double zoom,
}) {
  if (event is! PointerScrollEvent) return null;
  if (event.scrollDelta.dy == 0) return null;
  final keyboard = HardwareKeyboard.instance;
  if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return null;
  final step = _TimelineZoomToolbar._step;
  // 方向沿用浏览器/日历惯例：滚轮向上放大、向下缩小，
  // 与本文件 :614（zoom <= 0.75 时禁用「减小」）和 :632（zoom >= 1.5 时禁用「放大」）两颗按钮同源。
  final next = (zoom - event.scrollDelta.dy.sign * step)
      .clamp(0.75, 1.5)
      .toDouble();
  return next == zoom ? null : next;
}

class _TimelineContinuousCanvas extends StatelessWidget {
  const _TimelineContinuousCanvas({
    required this.now,
    required this.firstDay,
    required this.scale,
    required this.zoom,
    required this.tasks,
    required this.onTaskTap,
    this.onSlotTap,
    this.onTaskDropped,
    this.onTaskTimeChange,
  });

  final DateTime now;
  final int firstDay;
  final TimelineScale scale;
  final double zoom;
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;
  final ValueChanged<_TimelineSlot>? onSlotTap;
  final void Function(TodoTask task, _TimelineSlot slot)? onTaskDropped;
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
    final slots = _slots();
    final unitWidth = (scale == TimelineScale.day ? 58.0 : 72.0) * zoom;
    final scheduled = [
      for (final task in tasks)
        if (calculateTimelineTaskSpan(task, now, scale, firstDay: firstDay)
            case final span?)
          (task: task, span: span),
    ];
    final contentHeight = 42.0 + scheduled.length * 44.0;
    final canvasHeight = contentHeight.clamp(42.0, 218.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Text(
              '时间轴',
              style: TextStyle(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: canvasHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: unitWidth * slots.length,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 42,
                        child: Row(
                          children: [
                            for (final slot in slots)
                              _TimelineSlotCell(
                                slot: slot,
                                scale: scale,
                                width: unitWidth,
                                onTap: onSlotTap,
                                onTaskDropped: onTaskDropped,
                              ),
                          ],
                        ),
                      ),
                      if (scheduled.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: scheduled.length,
                            itemExtent: 44,
                            itemBuilder: (context, index) {
                              final entry = scheduled[index];
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Row(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < slots.length;
                                        index++
                                      )
                                        Container(
                                          width: unitWidth,
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(
                                                color: colors.border,
                                              ),
                                              bottom: BorderSide(
                                                color: colors.border,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Positioned(
                                    left: entry.span.startUnit * unitWidth,
                                    top: 5,
                                    width: entry.span.unitCount * unitWidth,
                                    height: 34,
                                    child: _TimelineContinuousTaskBar(
                                      task: entry.task,
                                      scale: scale,
                                      zoom: zoom,
                                      unitWidth: unitWidth,
                                      onTaskTap: onTaskTap,
                                      onTaskTimeChange: onTaskTimeChange,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineSlot> _slots() {
    final today = DateTime(now.year, now.month, now.day);
    switch (scale) {
      case TimelineScale.day:
        return [
          for (var hour = 0; hour < 24; hour++)
            _TimelineSlot(
              keySuffix: '$hour',
              label: '${hour.toString().padLeft(2, '0')}:00',
              description:
                  '${today.month}月${today.day}日 ${hour.toString().padLeft(2, '0')}:00',
              startAt: DateTime(today.year, today.month, today.day, hour),
              endAt: DateTime(today.year, today.month, today.day, hour + 1),
              allDay: false,
            ),
        ];
      case TimelineScale.week:
        final weekStart = WeekStart.startOf(today, firstDay: firstDay);
        return [
          for (var offset = 0; offset < 7; offset++)
            _allDaySlot(
              weekStart.add(Duration(days: offset)),
              keySuffix: '${offset + 1}',
            ),
        ];
      case TimelineScale.month:
        final days = DateTime(today.year, today.month + 1, 0).day;
        return [
          for (var day = 1; day <= days; day++)
            _allDaySlot(
              DateTime(today.year, today.month, day),
              keySuffix: '$day',
            ),
        ];
    }
  }

  _TimelineSlot _allDaySlot(DateTime day, {required String keySuffix}) {
    return _TimelineSlot(
      keySuffix: keySuffix,
      label: '${day.month}/${day.day}',
      description: '${day.month}月${day.day}日 全天',
      startAt: day,
      endAt: day.add(const Duration(days: 1)),
      allDay: true,
    );
  }
}

class _TimelineSlotCell extends StatelessWidget {
  const _TimelineSlotCell({
    required this.slot,
    required this.scale,
    required this.width,
    this.onTap,
    this.onTaskDropped,
  });

  final _TimelineSlot slot;
  final TimelineScale scale;
  final double width;
  final ValueChanged<_TimelineSlot>? onTap;
  final void Function(TodoTask task, _TimelineSlot slot)? onTaskDropped;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return DragTarget<TodoTask>(
      onWillAcceptWithDetails: (details) =>
          onTaskDropped != null &&
          details.data.startAt == null &&
          details.data.endAt == null &&
          details.data.dueAt == null,
      onAcceptWithDetails: (details) => onTaskDropped!(details.data, slot),
      builder: (context, candidates, rejected) => Tooltip(
        message: '${slot.description}，点击空白处创建任务',
        child: InkWell(
          key: Key('timeline-slot-${scale.name}-${slot.keySuffix}'),
          onTap: onTap == null ? null : () => onTap!(slot),
          child: Container(
            width: width,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: candidates.isEmpty ? null : colors.muted,
              border: Border(
                right: BorderSide(color: colors.border),
                bottom: BorderSide(color: colors.border),
              ),
            ),
            child: Text(
              slot.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.foreground, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineContinuousTaskBar extends StatefulWidget {
  const _TimelineContinuousTaskBar({
    required this.task,
    required this.scale,
    required this.zoom,
    required this.unitWidth,
    required this.onTaskTap,
    this.onTaskTimeChange,
  });

  final TodoTask task;
  final TimelineScale scale;
  final double zoom;
  final double unitWidth;
  final ValueChanged<TodoTask> onTaskTap;
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  })?
  onTaskTimeChange;

  @override
  State<_TimelineContinuousTaskBar> createState() =>
      _TimelineContinuousTaskBarState();
}

class _TimelineContinuousTaskBarState
    extends State<_TimelineContinuousTaskBar> {
  bool _saving = false;
  double _moveDistance = 0;
  double _resizeDistance = 0;

  Future<void> _commit(
    ({DateTime startAt, DateTime endAt, DateTime dueAt}) change,
  ) async {
    final callback = widget.onTaskTimeChange;
    if (callback == null || _saving) return;
    setState(() => _saving = true);
    try {
      await callback(
        widget.task,
        startAt: change.startAt,
        endAt: change.endAt,
        dueAt: change.dueAt,
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

  Future<void> _finishMove() async {
    final units = (_moveDistance / widget.unitWidth).round();
    _moveDistance = 0;
    if (units == 0) return;
    final change = _timelineTaskChangeByUnits(
      widget.task,
      widget.scale,
      units,
      resize: false,
    );
    if (change != null) await _commit(change);
  }

  Future<void> _finishResize() async {
    final units = (_resizeDistance / widget.unitWidth).round();
    _resizeDistance = 0;
    if (units == 0) return;
    final change = _timelineTaskChangeByUnits(
      widget.task,
      widget.scale,
      units,
      resize: true,
    );
    if (change == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      }
      return;
    }
    await _commit(change);
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final accent = switch (widget.task.priority) {
      3 => Colors.red,
      2 => Colors.orange,
      1 => Colors.blue,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Semantics(
      label: '${widget.task.title}，拖动任务条调整时间，拖动右边缘调整时长',
      button: true,
      child: DecoratedBox(
        key: ValueKey('timeline-continuous-bar-${widget.task.id}'),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: ValueKey('timeline-continuous-drag-${widget.task.id}'),
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTap: () => widget.onTaskTap(widget.task),
              onHorizontalDragStart: _saving ? null : (_) => _moveDistance = 0,
              onHorizontalDragUpdate: _saving
                  ? null
                  : (details) => _moveDistance += details.delta.dx,
              onHorizontalDragEnd: _saving ? null : (_) => _finishMove(),
              child: MouseRegion(
                cursor: _saving
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 15, 7),
                  child: Text(
                    widget.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 12 * widget.zoom,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onTaskTimeChange != null)
              Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: widget.task.allDay
                      ? '拖动连续任务条右边缘按天调整时长'
                      : '拖动连续任务条右边缘按小时调整时长',
                  child: GestureDetector(
                    key: ValueKey(
                      'timeline-continuous-resize-${widget.task.id}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onHorizontalDragStart: _saving
                        ? null
                        : (_) => _resizeDistance = 0,
                    onHorizontalDragUpdate: _saving
                        ? null
                        : (details) => _resizeDistance += details.delta.dx,
                    onHorizontalDragEnd: _saving
                        ? null
                        : (_) => _finishResize(),
                    child: MouseRegion(
                      cursor: _saving
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.resizeLeftRight,
                      child: Container(
                        width: 10,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

({DateTime startAt, DateTime endAt, DateTime dueAt})?
_timelineTaskChangeByUnits(
  TodoTask task,
  TimelineScale scale,
  int units, {
  required bool resize,
}) {
  final startAt = task.startAt;
  final endAt = task.endAt;
  if (startAt == null || endAt == null) return null;
  final dueAt = task.dueAt ?? endAt;
  final byHours = scale == TimelineScale.day && !task.allDay;

  DateTime shift(DateTime instant) {
    if (byHours) {
      final display = taskWallClockDateTime(
        instant,
        allDay: false,
        mode: TaskTimeMode.fromWire(task.timeMode),
        timeZone: task.timeZone,
      );
      return taskDateTimeFromWallClock(
        display.add(Duration(hours: units)),
        mode: TaskTimeMode.fromWire(task.timeMode),
        timeZone: task.timeZone,
      );
    }
    if (task.allDay) return instant.add(Duration(days: units));
    final display = taskWallClockDateTime(
      instant,
      allDay: false,
      mode: TaskTimeMode.fromWire(task.timeMode),
      timeZone: task.timeZone,
    );
    final targetDay = DateTime(
      display.year,
      display.month,
      display.day + units,
    );
    return taskDateTimeForDisplayDay(
      instant,
      targetDay,
      mode: TaskTimeMode.fromWire(task.timeMode),
      timeZone: task.timeZone,
    );
  }

  if (!resize) {
    return (startAt: shift(startAt), endAt: shift(endAt), dueAt: shift(dueAt));
  }
  final nextEndAt = shift(endAt);
  if (!nextEndAt.isAfter(startAt)) return null;
  return (startAt: startAt, endAt: nextEndAt, dueAt: shift(dueAt));
}

DateTime? _timelineDueDisplay(TodoTask task) {
  final due = task.dueAt;
  if (due == null) return null;
  return taskWallClockDateTime(
    due,
    allDay: task.allDay,
    mode: TaskTimeMode.fromWire(task.timeMode),
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
  final weekStartLocal = weekStart ?? WeekStart.startOf(todayStart);
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
    required this.scale,
    required this.collapsed,
    required this.onTaskTap,
    this.onCollapsedChanged,
    this.onTaskTimeChange,
    this.onTaskSchedule,
  });
  final _TimelineGroup data;
  final double zoom;
  final TimelineScale scale;
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
  final Future<void> Function(
    TodoTask task, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
    required bool allDay,
  })?
  onTaskSchedule;

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
                  scale: scale,
                  dueDateFormat: tf,
                  onTaskTap: onTaskTap,
                  onTaskTimeChange: onTaskTimeChange,
                  arrangeable:
                      data.id == 'unscheduled' && onTaskSchedule != null,
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
    required this.scale,
    required this.dueDateFormat,
    required this.onTaskTap,
    required this.arrangeable,
    this.onTaskTimeChange,
  });

  final TodoTask task;
  final double zoom;
  final TimelineScale scale;
  final DateFormat dueDateFormat;
  final ValueChanged<TodoTask> onTaskTap;
  final bool arrangeable;
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
  static const _dayDragExtent = 72.0;
  static const _hourResizeExtent = 24.0;

  bool _saving = false;
  double _moveDragDistance = 0;
  double _resizeDragDistance = 0;

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
      mode: TaskTimeMode.fromWire(widget.task.timeMode),
      timeZone: widget.task.timeZone,
    );
    final targetDay = DateTime(display.year, display.month, display.day + days);
    return taskDateTimeForDisplayDay(
      instant,
      targetDay,
      mode: TaskTimeMode.fromWire(widget.task.timeMode),
      timeZone: widget.task.timeZone,
    );
  }

  Future<void> _moveByDays(int days) async {
    final callback = widget.onTaskTimeChange;
    final startAt = widget.task.startAt;
    final endAt = widget.task.endAt;
    if (callback == null) return;
    if (!_hasEditableRange(startAt, endAt)) return;
    final dueAt = widget.task.dueAt ?? endAt;
    await _commitTimeChange(
      callback,
      startAt: _shiftByDisplayDays(startAt!, days),
      endAt: _shiftByDisplayDays(endAt!, days),
      dueAt: _shiftByDisplayDays(dueAt!, days),
    );
  }

  Future<void> _moveByHours(int hours) async {
    final callback = widget.onTaskTimeChange;
    final startAt = widget.task.startAt;
    final endAt = widget.task.endAt;
    if (callback == null) return;
    if (!_hasEditableRange(startAt, endAt)) return;
    final dueAt = widget.task.dueAt ?? endAt;
    DateTime shift(DateTime instant) {
      final display = taskWallClockDateTime(
        instant,
        allDay: false,
        mode: TaskTimeMode.fromWire(widget.task.timeMode),
        timeZone: widget.task.timeZone,
      );
      return taskDateTimeFromWallClock(
        display.add(Duration(hours: hours)),
        mode: TaskTimeMode.fromWire(widget.task.timeMode),
        timeZone: widget.task.timeZone,
      );
    }

    await _commitTimeChange(
      callback,
      startAt: shift(startAt!),
      endAt: shift(endAt!),
      dueAt: shift(dueAt!),
    );
  }

  Future<void> _moveByScaleUnits(int units) {
    if (widget.scale == TimelineScale.day && !widget.task.allDay) {
      return _moveByHours(units);
    }
    return _moveByDays(units);
  }

  Future<void> _resizeByUnits(int units) async {
    final callback = widget.onTaskTimeChange;
    final startAt = widget.task.startAt;
    final endAt = widget.task.endAt;
    if (callback == null) return;
    if (!_hasEditableRange(startAt, endAt)) return;
    final dueAt = widget.task.dueAt ?? endAt;
    final nextEndAt = widget.task.allDay
        ? _shiftByDisplayDays(endAt!, units)
        : endAt!.add(Duration(hours: units));
    final nextDueAt = widget.task.allDay
        ? _shiftByDisplayDays(dueAt!, units)
        : dueAt!.add(Duration(hours: units));
    if (!nextEndAt.isAfter(startAt!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      return;
    }
    await _commitTimeChange(
      callback,
      startAt: startAt,
      endAt: nextEndAt,
      dueAt: nextDueAt,
    );
  }

  bool _hasEditableRange(DateTime? startAt, DateTime? endAt) {
    if (startAt != null && endAt != null) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先在任务详情中设置开始和结束时间')));
    return false;
  }

  Future<void> _commitTimeChange(
    Future<void> Function(
      TodoTask task, {
      required DateTime startAt,
      required DateTime endAt,
      required DateTime dueAt,
    })
    callback, {
    required DateTime startAt,
    required DateTime endAt,
    required DateTime dueAt,
  }) async {
    setState(() => _saving = true);
    try {
      await callback(widget.task, startAt: startAt, endAt: endAt, dueAt: dueAt);
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

  Future<void> _finishMoveDrag() async {
    final extent = widget.scale == TimelineScale.day && !widget.task.allDay
        ? _hourResizeExtent
        : _dayDragExtent;
    final units = (_moveDragDistance / (extent * widget.zoom)).round();
    _moveDragDistance = 0;
    if (units != 0) await _moveByScaleUnits(units);
  }

  Future<void> _finishResizeDrag() async {
    final extent = widget.task.allDay ? _dayDragExtent : _hourResizeExtent;
    final units = (_resizeDragDistance / (extent * widget.zoom)).round();
    _resizeDragDistance = 0;
    if (units != 0) await _resizeByUnits(units);
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final hasEditableRange =
        widget.task.startAt != null && widget.task.endAt != null;
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
        title: GestureDetector(
          key: ValueKey('timeline-task-drag-${widget.task.id}'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _saving ? null : (_) => _moveDragDistance = 0,
          onHorizontalDragUpdate: _saving
              ? null
              : (details) => _moveDragDistance += details.delta.dx,
          onHorizontalDragEnd: _saving ? null : (_) => _finishMoveDrag(),
          child: MouseRegion(
            cursor: _saving
                ? SystemMouseCursors.basic
                : SystemMouseCursors.grab,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 14 * widget.zoom,
                    ),
                  ),
                  if (widget.task.dueAt != null)
                    Text(
                      widget.dueDateFormat.format(
                        _timelineDueDisplay(widget.task)!,
                      ),
                      style: TextStyle(color: colors.mutedForeground),
                    ),
                ],
              ),
            ),
          ),
        ),
        trailing: !hasEditableRange
            ? widget.arrangeable
                  ? Draggable<TodoTask>(
                      data: widget.task,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(widget.task.title),
                        ),
                      ),
                      childWhenDragging: const Opacity(
                        opacity: 0.35,
                        child: Icon(Icons.drag_indicator),
                      ),
                      child: Tooltip(
                        message: '拖到时间格安排任务',
                        child: Icon(
                          Icons.drag_indicator,
                          key: ValueKey(
                            'timeline-unscheduled-drag-${widget.task.id}',
                          ),
                        ),
                      ),
                    )
                  : null
            : widget.onTaskTimeChange == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip:
                        widget.scale == TimelineScale.day && !widget.task.allDay
                        ? '顺延一小时'
                        : '顺延一天',
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    onPressed: _saving ? null : () => _moveByScaleUnits(1),
                  ),
                  IconButton(
                    tooltip: widget.task.allDay ? '延长一天' : '延长一小时',
                    icon: const Icon(Icons.more_time, size: 19),
                    onPressed: _saving ? null : () => _resizeByUnits(1),
                  ),
                  Tooltip(
                    message: widget.task.allDay
                        ? '拖动右边缘按天调整时长'
                        : '拖动右边缘按小时调整时长',
                    child: GestureDetector(
                      key: ValueKey('timeline-task-resize-${widget.task.id}'),
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onHorizontalDragStart: _saving
                          ? null
                          : (_) => _resizeDragDistance = 0,
                      onHorizontalDragUpdate: _saving
                          ? null
                          : (details) =>
                                _resizeDragDistance += details.delta.dx,
                      onHorizontalDragEnd: _saving
                          ? null
                          : (_) => _finishResizeDrag(),
                      child: MouseRegion(
                        cursor: _saving
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.resizeLeftRight,
                        child: const SizedBox(
                          width: 24,
                          height: 40,
                          child: Icon(Icons.drag_handle, size: 18),
                        ),
                      ),
                    ),
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

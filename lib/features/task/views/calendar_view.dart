import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../state/providers.dart';
import '../task_detail_page.dart';
import '../task_view_mutation_feedback.dart';

/// M11-B3 日历视图：周 / 月 / 年 / 列表 / 日程 5 模式。
///
/// 任务落点优先级：dueAt > endAt > startAt。
/// - 月模式：7x6 网格，列 = 周一~周日；行 = 自然周；点日期格进入日程模式
/// - 周模式：7 列横排（Mon..Sun），每个列内是该周内的任务列表
/// - 年模式：12 月聚合（每月任务计数 + 切换月份）
/// - 列表模式：所有任务按日期排序的扁平列表
/// - 日程模式：单日任务按时间顺序展示
///
/// 纯函数：
///   - [resolveTaskDate] 取单个任务落点日期
///   - [buildMonthGrid] 生成月模式网格
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    required this.tasks,
    DateTime? now,
    this.onTaskSelected,
    this.onTaskDateChanged,
    this.filterCompleted = true,
  }) : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;
  final ValueChanged<String>? onTaskSelected;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  /// 日历自身的「显示已完成」设置是否参与过滤。清单页的日历由清单筛选决定，
  /// 传 false —— 否则用户筛「只看已完成」再切到日历会被叠成空列表；
  /// 此时「显示设置」入口一并隐藏，因为这个开关在这里没有可见效果。
  final bool filterCompleted;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _anchor;
  CalendarMode _mode = CalendarMode.month;
  bool _showCompleted = false;

  /// 年视图热力图（嘀嗒《03-年视图》:76 默认关闭）。
  bool _showHeatmap = false;

  /// 用户是否已经动过显示设置。恢复偏好是异步的，若期间用户已切了视图或拨了开关，
  /// 迟到的旧值必须作废 —— 否则表现为「刚点的档位被弹回上一次的选择」。
  bool _displayTouched = false;

  /// 嘀嗒默认隐藏已完成任务，由「显示设置」里的开关控制。
  List<TodoTask> get _visibleTasks {
    if (!widget.filterCompleted || _showCompleted) return widget.tasks;
    return [
      for (final t in widget.tasks)
        if (!t.completed) t,
    ];
  }

  @override
  void initState() {
    super.initState();
    _anchor = widget._now ?? DateTime.now();
    // 锚点归零到当天 00:00
    _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
    Future<void>.microtask(_restoreDisplay);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Toolbar(
          mode: _mode,
          anchor: _anchor,
          onModeChanged: _changeMode,
          onPrev: () => setState(() => _shift(-1)),
          onNext: () => setState(() => _shift(1)),
          onOpenSettings: widget.filterCompleted ? _showDisplaySettings : null,
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_mode) {
            CalendarMode.month => _MonthGrid(
              anchor: _anchor,
              tasks: _visibleTasks,
              onTaskDateChanged: widget.onTaskDateChanged,
              onDayTap: (day) {
                setState(() => _anchor = day);
                _changeMode(CalendarMode.agenda);
              },
            ),
            CalendarMode.week => _WeekView(
              anchor: _anchor,
              tasks: _visibleTasks,
              onTaskTap: (t) => _openDetail(context, t),
            ),
            CalendarMode.year => _YearView(
              anchor: _anchor,
              tasks: _visibleTasks,
              allTasks: widget.tasks,
              showHeatmap: _showHeatmap,
              onMonthTap: (m) {
                setState(() => _anchor = DateTime(_anchor.year, m, 1));
                _changeMode(CalendarMode.month);
              },
            ),
            CalendarMode.list => _ListView(
              tasks: _visibleTasks,
              onTaskTap: (t) => _openDetail(context, t),
            ),
            CalendarMode.agenda => _AgendaView(
              anchor: _anchor,
              tasks: _visibleTasks,
              onTaskTap: (t) => _openDetail(context, t),
            ),
          },
        ),
      ],
    );
  }

  void _shift(int direction) {
    switch (_mode) {
      case CalendarMode.month:
        _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
        break;
      case CalendarMode.week:
        _anchor = _anchor.add(Duration(days: 7 * direction));
        break;
      case CalendarMode.year:
        _anchor = DateTime(_anchor.year + direction, _anchor.month, 1);
        break;
      case CalendarMode.list:
        // 列表模式不切换锚点
        break;
      case CalendarMode.agenda:
        _anchor = _anchor.add(Duration(days: direction));
        break;
    }
  }

  Future<void> _restoreDisplay() async {
    final repository = ref.read(taskViewActionRepositoryProvider);
    final saved = await repository?.getCalendarDisplay();
    if (!mounted || saved == null || _displayTouched) return;
    setState(() {
      if (saved.viewType != null) {
        for (final mode in CalendarMode.values) {
          if (mode.name == saved.viewType) _mode = mode;
        }
      }
      _showCompleted = saved.showCompletedTasks ?? false;
      _showHeatmap = saved.showHeatmap ?? false;
    });
  }

  Future<void> _changeMode(CalendarMode mode) async {
    _displayTouched = true;
    if (mounted) setState(() => _mode = mode);
    await _persistDisplay();
  }

  Future<void> _showDisplaySettings() async {
    _displayTouched = true;
    final next = await showModalBottomSheet<CalendarDisplayFlags>(
      context: context,
      builder: (sheetContext) => _DisplaySettingsSheet(
        showCompleted: _showCompleted,
        showHeatmap: _showHeatmap,
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      _showCompleted = next.showCompleted;
      _showHeatmap = next.showHeatmap;
    });
    await _persistDisplay();
  }

  /// 模式与开关必须成对写：单写开关会让偏好层的 viewType 兜底成 list。
  Future<void> _persistDisplay() async {
    try {
      await ref
          .read(taskViewActionRepositoryProvider)
          ?.saveCalendarDisplay(
            viewMode: _mode.name,
            showCompletedTasks: _showCompleted,
            showHeatmap: _showHeatmap,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('日历显示设置保存失败，当前修改仅本次生效')));
    }
  }

  void _openDetail(BuildContext context, TodoTask t) {
    if (isExternalCalendarTask(t)) {
      showExternalCalendarEventDialog(context, t);
      return;
    }
    final callback = widget.onTaskSelected;
    if (callback != null) {
      callback(t.id);
      return;
    }
    showTaskDetailSheet(context, t.id);
  }
}

enum CalendarMode { month, week, year, list, agenda }

extension CalendarModeX on CalendarMode {
  String get label {
    switch (this) {
      case CalendarMode.month:
        return '月';
      case CalendarMode.week:
        return '周';
      case CalendarMode.year:
        return '年';
      case CalendarMode.list:
        return '列表';
      case CalendarMode.agenda:
        return '日程';
    }
  }
}

DateTime? resolveTaskDate(TodoTask t) {
  final d = t.dueAt ?? t.endAt ?? t.startAt;
  if (d == null) return null;
  final display = t.allDay
      ? d
      : taskDisplayDateTime(
          d,
          fixedTimezone: t.fixedTimezone,
          timeZone: t.timeZone,
        );
  return DateTime(display.year, display.month, display.day);
}

DateTime calendarDueAtForDay(TodoTask task, DateTime day) {
  if (task.allDay) {
    return DateTime(day.year, day.month, day.day);
  }
  final source = task.dueAt ?? task.endAt ?? task.startAt;
  if (source == null) {
    return DateTime(day.year, day.month, day.day);
  }
  return taskDateTimeForDisplayDay(
    source,
    day,
    fixedTimezone: task.fixedTimezone,
    timeZone: task.timeZone,
  );
}

bool isExternalCalendarTask(TodoTask task) {
  return task.id.startsWith('external:');
}

Future<void> showExternalCalendarEventDialog(
  BuildContext context,
  TodoTask task,
) {
  final source = task.listId.startsWith('external:')
      ? task.listId.substring('external:'.length)
      : '订阅日历';
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(task.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来源：$source'),
          const SizedBox(height: 8),
          const Text('只读订阅事件'),
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(task.description!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 日历「显示设置」抽屉：对应嘀嗒日历右上角 ··· → 显示设置。
/// 显示设置一次弹层要交回的成对开关（分开交回会丢掉另一格的当前值）。
typedef CalendarDisplayFlags = ({bool showCompleted, bool showHeatmap});

class _DisplaySettingsSheet extends StatelessWidget {
  const _DisplaySettingsSheet({
    required this.showCompleted,
    required this.showHeatmap,
  });

  final bool showCompleted;
  final bool showHeatmap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('显示设置', style: TextStyle(fontSize: 16)),
            ),
          ),
          SwitchListTile(
            key: const Key('calendar-show-completed'),
            title: const Text('显示已完成'),
            value: showCompleted,
            onChanged: (value) => Navigator.pop(context, (
              showCompleted: value,
              showHeatmap: showHeatmap,
            )),
          ),
          // 嘀嗒《03-年视图》:80/:87「显示设置 → 样式 → 热力图」，分组名照抄。
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('样式', style: TextStyle(fontSize: 13)),
            ),
          ),
          SwitchListTile(
            key: const Key('calendar-show-heatmap'),
            title: const Text('热力图'),
            value: showHeatmap,
            onChanged: (value) => Navigator.pop(context, (
              showCompleted: showCompleted,
              showHeatmap: value,
            )),
          ),
        ],
      ),
    );
  }
}

/// 月模式网格：6 行 × 7 列（周一起），包含 anchor 月的所有日期及上下月填充。
List<List<DateTime>> buildMonthGrid(DateTime anchor) {
  final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
  // weekDay: 1(Mon)..7(Sun)
  final leadingBlanks = firstOfMonth.weekday - 1;
  final start = firstOfMonth.subtract(Duration(days: leadingBlanks));
  final rows = <List<DateTime>>[];
  for (var r = 0; r < 6; r++) {
    final row = <DateTime>[];
    for (var c = 0; c < 7; c++) {
      row.add(start.add(Duration(days: r * 7 + c)));
    }
    rows.add(row);
  }
  return rows;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.mode,
    required this.anchor,
    required this.onModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onOpenSettings,
  });

  final CalendarMode mode;
  final DateTime anchor;
  final ValueChanged<CalendarMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ym = DateFormat('yyyy 年 M 月').format(anchor);
    final y = DateFormat('yyyy 年').format(anchor);
    final label = switch (mode) {
      CalendarMode.month => ym,
      CalendarMode.week => ym,
      CalendarMode.year => y,
      CalendarMode.list => '全部任务',
      CalendarMode.agenda => DateFormat('yyyy 年 M 月 d 日').format(anchor),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final modeSelector = SegmentedButton<CalendarMode>(
          segments: [
            for (final m in CalendarMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        );
        final previousButton = IconButton(
          tooltip: '上一个',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        );
        final nextButton = IconButton(
          tooltip: '下一个',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        );
        final settingsButton = onOpenSettings == null
            ? const SizedBox.shrink()
            : Semantics(
                container: true,
                button: true,
                enabled: true,
                label: '显示设置',
                onTap: onOpenSettings,
                child: ExcludeSemantics(
                  child: IconButton(
                    key: const Key('calendar-display-settings'),
                    tooltip: '显示设置',
                    icon: const Icon(Icons.tune),
                    onPressed: onOpenSettings,
                  ),
                ),
              );
        final labelText = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: constraints.maxWidth < 600
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: modeSelector,
                    ),
                    Row(
                      children: [
                        previousButton,
                        Expanded(child: labelText),
                        nextButton,
                        settingsButton,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    modeSelector,
                    const Spacer(),
                    previousButton,
                    labelText,
                    nextButton,
                    settingsButton,
                  ],
                ),
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.anchor,
    required this.tasks,
    required this.onDayTap,
    this.onTaskDateChanged,
  });

  final DateTime anchor;
  final List<TodoTask> tasks;
  final ValueChanged<DateTime> onDayTap;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  @override
  Widget build(BuildContext context) {
    final grid = buildMonthGrid(anchor);
    final tasksByDay = <String, List<TodoTask>>{};
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      final key = '${d.year}-${d.month}-${d.day}';
      tasksByDay.putIfAbsent(key, () => []).add(t);
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Row(
            children: const [
              _DayHeader('一'),
              _DayHeader('二'),
              _DayHeader('三'),
              _DayHeader('四'),
              _DayHeader('五'),
              _DayHeader('六'),
              _DayHeader('日'),
            ],
          ),
          for (final row in grid)
            Expanded(
              child: Row(
                children: [
                  for (final d in row)
                    Expanded(
                      child: _DayCell(
                        day: d,
                        anchor: anchor,
                        tasks:
                            tasksByDay['${d.year}-${d.month}-${d.day}'] ??
                            const [],
                        onTap: () => onDayTap(d),
                        onTaskDateChanged: onTaskDateChanged,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.anchor,
    required this.tasks,
    required this.onTap,
    this.onTaskDateChanged,
  });
  final DateTime day;
  final DateTime anchor;
  final List<TodoTask> tasks;
  final VoidCallback onTap;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final isCurrentMonth = day.month == anchor.month;
    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return DragTarget<TodoTask>(
      key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
      onWillAcceptWithDetails: (details) =>
          onTaskDateChanged != null &&
          !isExternalCalendarTask(details.data) &&
          resolveTaskDate(details.data) != day,
      onAcceptWithDetails: (details) => _moveTask(context, details.data),
      builder: (context, candidates, _) => Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? colors.accent.withValues(alpha: 0.2)
                  : isToday
                  ? colors.accent.withValues(alpha: 0.12)
                  : (isCurrentMonth ? colors.surface : colors.background),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: candidates.isNotEmpty || isToday
                    ? colors.accent
                    : colors.border,
                width: candidates.isNotEmpty || isToday ? 1.5 : 0.5,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday
                        ? colors.accent
                        : isCurrentMonth
                        ? colors.foreground
                        : colors.mutedForeground,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _CalendarTaskChip(
                          task: task,
                          color: _priorityColor(task.priority, colors),
                          draggable:
                              onTaskDateChanged != null &&
                              !isExternalCalendarTask(task),
                        );
                      },
                    ),
                  ),
                  Text(
                    '${tasks.length} 项',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveTask(BuildContext context, TodoTask task) async {
    final callback = onTaskDateChanged;
    if (callback == null) return;
    try {
      await callback(task, calendarDueAtForDay(task, day));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '日历改期失败，请重试')),
        ),
      );
    }
  }

  /// 任务优先级色点，沿用 Todo 产品的语义色层级。
  Color _priorityColor(int priority, AppColors colors) {
    switch (priority) {
      case 3:
        return colors.destructive;
      case 2:
        return colors.warning;
      case 1:
        return colors.info;
      default:
        return colors.accent;
    }
  }
}

class _CalendarTaskChip extends StatelessWidget {
  const _CalendarTaskChip({
    required this.task,
    required this.color,
    required this.draggable,
  });

  final TodoTask task;
  final Color color;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: brandColors(context).foreground, fontSize: 9),
      ),
    );
    if (!draggable) return chip;
    return Draggable<TodoTask>(
      key: ValueKey('calendar-task-drag-${task.id}'),
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: chip,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.tasks,
    required this.onTaskTap,
  });
  final DateTime anchor;
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    final days = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );
    final tasksByDay = <String, List<TodoTask>>{};
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      tasksByDay.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(t);
    }
    final df = DateFormat('M/d');
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      df.format(d),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Divider(height: 4),
                    Expanded(
                      child: () {
                        final list =
                            tasksByDay['${d.year}-${d.month}-${d.day}'] ??
                            const <TodoTask>[];
                        if (list.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final t = list[i];
                            return InkWell(
                              onTap: () => onTaskTap(t),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  t.title,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        );
                      }(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.tasks,
    required this.allTasks,
    required this.onMonthTap,
    required this.showHeatmap,
  });
  final DateTime anchor;
  final List<TodoTask> tasks;

  /// 热力图数的是「当天完成数」，必须绕过「显示已完成」的过滤 ——
  /// 否则默认（不显示已完成）下全年都是最浅档，这个功能看着就是坏的。
  final List<TodoTask> allTasks;
  final ValueChanged<int> onMonthTap;
  final bool showHeatmap;

  @override
  Widget build(BuildContext context) {
    if (showHeatmap) return _buildHeatmap(context);
    final countByMonth = List<int>.filled(12, 0);
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      if (d.year != anchor.year) continue;
      countByMonth[d.month - 1] += 1;
    }
    final df = DateFormat('M 月');
    final colors = brandColors(context);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = i + 1;
        return InkWell(
          onTap: () => onMonthTap(m),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  df.format(DateTime(anchor.year, m, 1)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${countByMonth[i]} 项任务',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 热力图整年一次构建，不走懒加载 —— 否则滚出视口的月份在语义树/测试里根本不存在。
  Widget _buildHeatmap(BuildContext context) {
    final countByDay = <DateTime, int>{};
    for (final t in allTasks) {
      if (!t.completed) continue;
      final completedAt = t.completedAt;
      if (completedAt == null) continue;
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      if (day.year != anchor.year) continue;
      countByDay[day] = (countByDay[day] ?? 0) + 1;
    }
    var maxPerDay = 0;
    for (final count in countByDay.values) {
      if (count > maxPerDay) maxPerDay = count;
    }
    final df = DateFormat('M 月');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var m = 1; m <= 12; m++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onMonthTap(m),
                    child: Text(
                      df.format(DateTime(anchor.year, m, 1)),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MonthHeatmap(
                    year: anchor.year,
                    month: m,
                    countByDay: countByDay,
                    maxPerDay: maxPerDay,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 单月热力格：周一起排，日格只着色不放文字（字号放大不该把格子撑破）。
class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.year,
    required this.month,
    required this.countByDay,
    required this.maxPerDay,
  });

  final int year;
  final int month;
  final Map<DateTime, int> countByDay;
  final int maxPerDay;

  static const _cellSize = 14.0;
  static const _cellGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final leadingBlanks = firstDay.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox(width: _cellSize, height: _cellSize));
    }
    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final count = countByDay[date] ?? 0;
      final level = calendarHeatmapLevel(count, maxPerDay);
      cells.add(
        Padding(
          padding: const EdgeInsets.only(right: _cellGap, bottom: _cellGap),
          child: Semantics(
            key: Key('calendar-year-day-${_isoDay(date)}'),
            label: '$month 月 $day 日 完成 $count 项',
            child: Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: _heatmapAlpha[level]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }
    return Wrap(children: cells);
  }
}

/// 日格 key 与语义 label 用的日期串。
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const int _heatmapLevels = 4;

/// 分母下限：全年只完成 1 项时，那一项不该被画成「最忙的一天」。
const int _heatmapMinDenominator = 4;

/// 档位 0..4 对应的着色浓度；`0` 档只留一点底色，让「没完成」也看得见格子。
const List<double> _heatmapAlpha = [0.06, 0.26, 0.46, 0.68, 0.9];

/// 年视图热力图档位（嘀嗒《03-年视图》:98「颜色越深，代表当天完成的任务越多」）。
///
/// 源页只给了相对口径、没给绝对阈值，所以按当年单日最大值归一成 4 档，
/// 并给分母垫一个下限，避免稀疏年份把唯一一次完成显示成满格热度；
/// 数据全在本地库里，最大值就在传进来的列表里算，不需要服务端聚合。
int calendarHeatmapLevel(int completedOnDay, int maxCompletedPerDay) {
  if (completedOnDay <= 0) return 0;
  final denominator = maxCompletedPerDay < _heatmapMinDenominator
      ? _heatmapMinDenominator
      : maxCompletedPerDay;
  final level =
      (completedOnDay * _heatmapLevels + denominator - 1) ~/ denominator;
  return level.clamp(1, _heatmapLevels);
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({
    required this.anchor,
    required this.tasks,
    required this.onTaskTap,
  });

  final DateTime anchor;
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final dayTasks = tasks.where((task) {
      final date = resolveTaskDate(task);
      return date != null &&
          date.year == anchor.year &&
          date.month == anchor.month &&
          date.day == anchor.day;
    }).toList()..sort(_compareByTime);
    if (dayTasks.isEmpty) {
      return const AppEmptyState(
        title: '当日暂无日程',
        subtitle: '切换日期，或为任务设置开始和截止时间。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: dayTasks.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final task = dayTasks[index];
        final timeLabel = _formatTime(task);
        return ListTile(
          leading: SizedBox(
            width: 48,
            child: Text(
              task.allDay
                  ? '全天'
                  : _formatClock(
                      task,
                      task.startAt ?? task.dueAt ?? task.endAt!,
                    ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          title: Text(task.title),
          subtitle: Text(timeLabel),
          trailing: isExternalCalendarTask(task)
              ? const Icon(Icons.lock_outline, size: 18)
              : null,
          onTap: () => onTaskTap(task),
        );
      },
    );
  }

  static int _compareByTime(TodoTask left, TodoTask right) {
    if (left.allDay != right.allDay) return left.allDay ? -1 : 1;
    final leftTime = left.startAt ?? left.dueAt ?? left.endAt;
    final rightTime = right.startAt ?? right.dueAt ?? right.endAt;
    if (leftTime == null && rightTime == null) return 0;
    if (leftTime == null) return 1;
    if (rightTime == null) return -1;
    return _compareWallClock(
      _displayTime(left, leftTime),
      _displayTime(right, rightTime),
    );
  }

  static String _formatTime(TodoTask task) {
    if (task.allDay) return '全天';
    final start = task.startAt ?? task.dueAt ?? task.endAt;
    if (start == null) return '未设置时间';
    final startLabel = _formatClock(task, start);
    final end = task.endAt;
    if (end == null || !end.isAfter(start)) return startLabel;
    return '$startLabel–${_formatClock(task, end)}';
  }

  static String _formatClock(TodoTask task, DateTime instant) {
    return DateFormat('HH:mm').format(_displayTime(task, instant));
  }

  static DateTime _displayTime(TodoTask task, DateTime instant) {
    return taskDisplayDateTime(
      instant,
      fixedTimezone: task.fixedTimezone,
      timeZone: task.timeZone,
    );
  }

  static int _compareWallClock(DateTime left, DateTime right) {
    for (final pair in [
      (left.hour, right.hour),
      (left.minute, right.minute),
      (left.second, right.second),
      (left.millisecond, right.millisecond),
      (left.microsecond, right.microsecond),
    ]) {
      final compared = pair.$1.compareTo(pair.$2);
      if (compared != 0) return compared;
    }
    return 0;
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.tasks, required this.onTaskTap});
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      final ad = resolveTaskDate(a);
      final bd = resolveTaskDate(b);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    if (sorted.isEmpty) {
      return AppEmptyState(title: '该日无任务', subtitle: '在日历上选择日期，点击即可添加任务。');
    }
    final df = DateFormat('yyyy-MM-dd');
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = sorted[i];
        final d = resolveTaskDate(t);
        return ListTile(
          leading: const Icon(Icons.event_note),
          title: Text(t.title),
          subtitle: d == null ? const Text('无日期') : Text(df.format(d)),
          onTap: () => onTaskTap(t),
        );
      },
    );
  }
}

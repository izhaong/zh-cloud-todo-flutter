import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../db/app_database.dart';
import '../task_detail_page.dart';

/// M11-B3 日历视图：周 / 月 / 年 / 列表 4 模式。
///
/// 任务落点优先级：dueAt > endAt > startAt。
/// - 月模式：7x6 网格，列 = 周一~周日；行 = 自然周；点日期格弹当日任务列表
/// - 周模式：7 列横排（Mon..Sun），每个列内是该周内的任务列表
/// - 年模式：12 月聚合（每月任务计数 + 切换月份）
/// - 列表模式：所有任务按日期排序的扁平列表
///
/// 纯函数：
///   - [resolveTaskDate] 取单个任务落点日期
///   - [buildMonthGrid] 生成月模式网格
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key, required this.tasks, DateTime? now})
      : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _anchor;
  CalendarMode _mode = CalendarMode.month;

  @override
  void initState() {
    super.initState();
    _anchor = widget._now ?? DateTime.now();
    // 锚点归零到当天 00:00
    _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Toolbar(
          mode: _mode,
          anchor: _anchor,
          onModeChanged: (m) => setState(() => _mode = m),
          onPrev: () => setState(() => _shift(-1)),
          onNext: () => setState(() => _shift(1)),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_mode) {
            CalendarMode.month => _MonthGrid(
                anchor: _anchor,
                tasks: widget.tasks,
                onDayTap: (d) => _showDayTasks(context, d),
              ),
            CalendarMode.week => _WeekView(
                anchor: _anchor,
                tasks: widget.tasks,
                onTaskTap: (t) => _openDetail(context, t),
              ),
            CalendarMode.year => _YearView(
                anchor: _anchor,
                tasks: widget.tasks,
                onMonthTap: (m) {
                  setState(() {
                    _mode = CalendarMode.month;
                    _anchor = DateTime(_anchor.year, m, 1);
                  });
                },
              ),
            CalendarMode.list => _ListView(
                tasks: widget.tasks,
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
    }
  }

  void _openDetail(BuildContext context, TodoTask t) {
    showTaskDetailSheet(context, t.id);
  }

  Future<void> _showDayTasks(BuildContext context, DateTime day) async {
    final dayTasks = widget.tasks
        .where((t) {
          final d = resolveTaskDate(t);
          if (d == null) return false;
          return d.year == day.year && d.month == day.month && d.day == day.day;
        })
        .toList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DayTasksSheet(day: day, tasks: dayTasks),
    );
  }
}

enum CalendarMode { month, week, year, list }

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
    }
  }
}

/// 任务的"落点日期"。优先级 dueAt > endAt > startAt；都为空返回 null。
/// 已完成任务仍落点（上层不区分）。
DateTime? resolveTaskDate(TodoTask t) {
  final d = t.dueAt ?? t.endAt ?? t.startAt;
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
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
  });

  final CalendarMode mode;
  final DateTime anchor;
  final ValueChanged<CalendarMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ym = DateFormat('yyyy 年 M 月').format(anchor);
    final y = DateFormat('yyyy 年').format(anchor);
    final label = switch (mode) {
      CalendarMode.month => ym,
      CalendarMode.week => ym,
      CalendarMode.year => y,
      CalendarMode.list => '全部任务',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SegmentedButton<CalendarMode>(
            segments: [
              for (final m in CalendarMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onModeChanged(s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '上一个',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          IconButton(
            tooltip: '下一个',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.anchor,
    required this.tasks,
    required this.onDayTap,
  });

  final DateTime anchor;
  final List<TodoTask> tasks;
  final ValueChanged<DateTime> onDayTap;

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
                        tasks: tasksByDay['${d.year}-${d.month}-${d.day}'] ?? const [],
                        onTap: () => onDayTap(d),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
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
  });
  final DateTime day;
  final DateTime anchor;
  final List<TodoTask> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = day.month == anchor.month;
    final today = DateTime.now();
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: isToday
                ? Theme.of(context).colorScheme.primaryContainer
                : (isCurrentMonth
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Theme.of(context).disabledColor.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isCurrentMonth ? null : Theme.of(context).disabledColor,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
              if (tasks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tasks.length} 项',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
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
    final weekStart =
        anchor.subtract(Duration(days: anchor.weekday - 1));
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
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
                                padding: const EdgeInsets.symmetric(vertical: 2),
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
    required this.onMonthTap,
  });
  final DateTime anchor;
  final List<TodoTask> tasks;
  final ValueChanged<int> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final countByMonth = List<int>.filled(12, 0);
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      if (d.year != anchor.year) continue;
      countByMonth[d.month - 1] += 1;
    }
    final df = DateFormat('M 月');
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
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
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
    if (sorted.isEmpty) return const Center(child: Text('暂无任务'));
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

class _DayTasksSheet extends StatelessWidget {
  const _DayTasksSheet({required this.day, required this.tasks});
  final DateTime day;
  final List<TodoTask> tasks;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy 年 M 月 d 日');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              df.format(day),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('该日无任务'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = tasks[i];
                    return ListTile(
                      title: Text(t.title),
                      onTap: () {
                        Navigator.pop(context);
                        showTaskDetailSheet(context, t.id);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../db/app_database.dart';
import '../task_detail_page.dart';

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
  }) : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;

  DateTime get _effectiveNow => _now ?? DateTime.now();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _effectiveNow;
    final groups = _buildGroups(tasks, now);
    if (groups.every((g) => g.items.isEmpty)) {
      return const Center(child: Text('暂无任务'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final g = groups[i];
        if (g.items.isEmpty) return const SizedBox.shrink();
        return _TimelineSection(
          data: g,
          onTaskTap: (t) => _openDetail(context, t),
        );
      },
    );
  }

  static void _openDetail(BuildContext context, TodoTask t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)),
    );
  }

  /// 把任务分配到 6 个时间桶；返回按显示顺序排好的桶列表。
  static List<_TimelineGroup> _buildGroups(List<TodoTask> tasks, DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    // 本周范围：今天 所在的"自然周"周一 ~ 周日
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
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
      final bucket = classifyTimelineBucket(t, now,
          weekStart: weekStart, weekEnd: weekEnd, nextWeekEnd: nextWeekEnd);
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
      final ad = a.dueAt;
      final bd = b.dueAt;
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
      _TimelineGroup(label: '已过期', accent: Colors.red, items: overdue),
      _TimelineGroup(label: '今天', accent: Colors.orange, items: today),
      _TimelineGroup(label: '明天', accent: Colors.amber, items: tomorrow),
      _TimelineGroup(label: '本周', accent: Colors.blue, items: thisWeek),
      _TimelineGroup(label: '下周', accent: Colors.indigo, items: nextWeek),
      _TimelineGroup(
        label: '更晚 / 无截止',
        accent: Colors.grey,
        items: later,
      ),
    ];
  }
}

enum TimelineBucket {
  overdue,
  today,
  tomorrow,
  thisWeek,
  nextWeek,
  later,
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
  final due = task.dueAt;
  if (due == null) return TimelineBucket.later;
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final weekStartLocal = weekStart ?? todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final weekEndLocal = weekEnd ?? weekStartLocal.add(const Duration(days: 7));
  final nextWeekEndLocal = nextWeekEnd ?? weekEndLocal.add(const Duration(days: 7));

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
    required this.label,
    required this.accent,
    required this.items,
  });
  final String label;
  final Color accent;
  final List<TodoTask> items;
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.data, required this.onTaskTap});
  final _TimelineGroup data;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat('MM-dd HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: data.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${data.items.length}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        for (final t in data.items)
          ListTile(
            dense: true,
            leading: const Icon(Icons.schedule, size: 18),
            title: Text(
              t.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: t.dueAt == null ? null : Text(tf.format(t.dueAt!)),
            onTap: () => onTaskTap(t),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

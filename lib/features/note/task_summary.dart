import '../../state/repositories/summary_repository.dart';

/// 嘀嗒「摘要」的时间区间档位（`03-特色功能/11-笔记与摘要.md:254`）。
enum TaskSummaryPreset {
  today,
  lastSevenDays,
  lastThirtyDays,
  thisMonth,
  custom,
}

/// 摘要分组方式：不分组、按清单、按完成状态。
enum SummaryGroupMode { none, byList, byStatus }

/// 组内排序：按发生时间倒序或按标题字典序。
enum SummarySortMode { time, title }

/// 一个左闭右开的整天区间；[label] 直接进摘要标题。
class TaskSummaryRange {
  const TaskSummaryRange({
    required this.from,
    required this.to,
    required this.label,
  });

  final DateTime from;
  final DateTime to;
  final String label;
}

class TaskSummaryOptions {
  const TaskSummaryOptions({
    required this.range,
    this.listIds = const <String>{},
    this.completed,
    this.group = SummaryGroupMode.byList,
    this.sort = SummarySortMode.time,
    this.showCompletedDate = true,
    this.showProgress = true,
  });

  final TaskSummaryRange range;

  /// 空集合表示全部清单。
  final Set<String> listIds;

  /// null 表示全部状态。
  final bool? completed;
  final SummaryGroupMode group;
  final SummarySortMode sort;
  final bool showCompletedDate;
  final bool showProgress;
}

String taskSummaryPresetLabel(TaskSummaryPreset preset) => switch (preset) {
  TaskSummaryPreset.today => '今天',
  TaskSummaryPreset.lastSevenDays => '近 7 天',
  TaskSummaryPreset.lastThirtyDays => '近 30 天',
  TaskSummaryPreset.thisMonth => '本月',
  TaskSummaryPreset.custom => '自定义',
};

/// 区间一律按整天对齐；自定义档位顺序颠倒时自动纠正，避免生成空区间。
TaskSummaryRange summaryRangeForPreset(
  TaskSummaryPreset preset,
  DateTime now, {
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final dayAfter = todayStart.add(const Duration(days: 1));
  switch (preset) {
    case TaskSummaryPreset.today:
      return TaskSummaryRange(
        from: todayStart,
        to: dayAfter,
        label: taskSummaryPresetLabel(preset),
      );
    case TaskSummaryPreset.lastSevenDays:
      return TaskSummaryRange(
        from: todayStart.subtract(const Duration(days: 6)),
        to: dayAfter,
        label: taskSummaryPresetLabel(preset),
      );
    case TaskSummaryPreset.lastThirtyDays:
      return TaskSummaryRange(
        from: todayStart.subtract(const Duration(days: 29)),
        to: dayAfter,
        label: taskSummaryPresetLabel(preset),
      );
    case TaskSummaryPreset.thisMonth:
      return TaskSummaryRange(
        from: DateTime(now.year, now.month, 1),
        to: DateTime(now.year, now.month + 1, 1),
        label: taskSummaryPresetLabel(preset),
      );
    case TaskSummaryPreset.custom:
      var from = _dateOnly(customFrom ?? todayStart);
      var to = _dateOnly(customTo ?? todayStart);
      if (!from.isBefore(to)) {
        final swapped = from;
        from = to;
        to = swapped;
      }
      return TaskSummaryRange(
        from: from,
        to: to.add(const Duration(days: 1)),
        label: taskSummaryPresetLabel(preset),
      );
  }
}

/// 生成可编辑的 Markdown 摘要；筛选后为空时返回 null，由界面禁用插入。
String? buildTaskSummary(
  TaskSummaryOptions options,
  List<SummaryTaskRow> rows,
) {
  final filtered = rows.where((row) {
    if (options.listIds.isNotEmpty && !options.listIds.contains(row.listId)) {
      return false;
    }
    if (options.completed != null && row.completed != options.completed) {
      return false;
    }
    return true;
  }).toList();
  if (filtered.isEmpty) return null;

  final doneCount = filtered.where((row) => row.completed).length;
  final undoneCount = filtered.length - doneCount;
  final counts = [
    if (doneCount > 0) '已完成 $doneCount 项',
    if (undoneCount > 0) '未完成 $undoneCount 项',
  ].join(' · ');

  final lastDay = options.range.to.subtract(const Duration(days: 1));
  final lines = <String>[
    '## 任务摘要 · ${options.range.label}'
        '（${_fullDate(options.range.from)} ~ ${_fullDate(lastDay)}）',
    '',
    counts,
  ];

  for (final group in _groups(options, filtered)) {
    if (group.heading.isNotEmpty) {
      lines.addAll(['', '### ${group.heading}']);
    }
    for (final row in _ordered(group.rows, options.sort)) {
      lines.add(_line(row, options));
    }
  }

  return lines.join('\n');
}

/// 按清单分组时用 listId 而非 listName 做键：同名清单不会被合并成一段，
/// 标题仍显示名字。
List<({String heading, List<SummaryTaskRow> rows})> _groups(
  TaskSummaryOptions options,
  List<SummaryTaskRow> rows,
) {
  switch (options.group) {
    case SummaryGroupMode.none:
      return [(heading: '', rows: rows)];
    case SummaryGroupMode.byList:
      final grouped = <String, List<SummaryTaskRow>>{};
      final names = <String, String>{};
      for (final row in rows) {
        names[row.listId] = row.listName;
        grouped.putIfAbsent(row.listId, () => <SummaryTaskRow>[]).add(row);
      }
      final ids = grouped.keys.toList()
        ..sort((left, right) {
          final byName = names[left]!.compareTo(names[right]!);
          return byName != 0 ? byName : left.compareTo(right);
        });
      return [for (final id in ids) (heading: names[id]!, rows: grouped[id]!)];
    case SummaryGroupMode.byStatus:
      return [
        (heading: '已完成', rows: rows.where((row) => row.completed).toList()),
        (heading: '未完成', rows: rows.where((row) => !row.completed).toList()),
      ].where((group) => group.rows.isNotEmpty).toList();
  }
}

List<SummaryTaskRow> _ordered(List<SummaryTaskRow> rows, SummarySortMode sort) {
  final ordered = List<SummaryTaskRow>.of(rows);
  ordered.sort((left, right) {
    final bySelectedField = switch (sort) {
      SummarySortMode.time => _moment(right).compareTo(_moment(left)),
      SummarySortMode.title => left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      ),
    };
    if (bySelectedField != 0) return bySelectedField;
    final byManualOrder = left.sortOrder.compareTo(right.sortOrder);
    return byManualOrder != 0
        ? byManualOrder
        : left.taskId.compareTo(right.taskId);
  });
  return ordered;
}

/// 已完成看完成时间；未完成看到期时间，无到期退回创建时间。
DateTime _moment(SummaryTaskRow row) => row.completed
    ? (row.completedAt ?? row.createdAt)
    : (row.dueAt ?? row.createdAt);

String _line(SummaryTaskRow row, TaskSummaryOptions options) {
  final fragments = <String>['- [${row.completed ? 'x' : ' '}] ${row.title}'];
  if (options.showCompletedDate && row.completed && row.completedAt != null) {
    fragments.add('完成于 ${_monthDay(row.completedAt!)}');
  }
  if (options.showProgress) {
    final progress = _progress(row);
    if (progress != null) fragments.add(progress);
  }
  if (options.group != SummaryGroupMode.byList) {
    fragments.add(row.listName);
  }
  return fragments.join(' · ');
}

/// 进度优先检查事项，其次子任务；两者皆无时不编造进度。
String? _progress(SummaryTaskRow row) {
  if (row.checklistTotal > 0) {
    return '进度 ${row.checklistDone}/${row.checklistTotal}';
  }
  if (row.subtaskTotal > 0) {
    return '进度 ${row.subtaskDone}/${row.subtaskTotal}';
  }
  return null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _two(int value) => value.toString().padLeft(2, '0');

String _fullDate(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}';

String _monthDay(DateTime value) => '${_two(value.month)}-${_two(value.day)}';

import '../../core/db/app_database.dart';
import '../../core/time/task_time_formatter.dart';
import '../../core/time/task_time_mode.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/03-用分组和排序管理任务.md》
/// 「智能分组」节的六个维度（Issue #321，矩阵 #20）。
///
/// 文档原文只在该节下列出这六种：「按清单分组」「按时间分组」「按优先级分组」
/// 「按标签分组」「按指派人分组」「按创建时间分组」；「不分组」是本端在
/// 用户没有选任何智能分组时的默认形态，不是嘀嗒的档位词。
enum SmartGrouping {
  none,
  byList,
  byTime,
  byPriority,
  byTag,
  byAssignee,
  byCreatedAt,
}

extension SmartGroupingX on SmartGrouping {
  /// 菜单与读屏用的文案，逐字取自源文档各小节标题。
  String get label => switch (this) {
    SmartGrouping.none => '不分组',
    SmartGrouping.byList => '按清单分组',
    SmartGrouping.byTime => '按时间分组',
    SmartGrouping.byPriority => '按优先级分组',
    SmartGrouping.byTag => '按标签分组',
    SmartGrouping.byAssignee => '按指派人分组',
    SmartGrouping.byCreatedAt => '按创建时间分组',
  };
}

/// 一组智能分组的输出桶。
class SmartTaskGroup {
  const SmartTaskGroup({
    required this.id,
    required this.title,
    required this.tasks,
  });

  final String id;
  final String title;
  final List<TodoTask> tasks;
}

/// 按时间分组的桶词，逐字取自源文档「按时间分组」小节：
/// 「今天 / 明天 / 最近 7 天 / 以后 / 已过期」。
/// 源文档没写没有日期的任务去哪，本端补「无日期」桶（永远排最后），
/// 否则这些任务会在分组视图里消失。
const smartTimeGroupTitles = ['已过期', '今天', '明天', '最近 7 天', '以后', '无日期'];

/// 按优先级分组的桶词，逐字取自源文档「按优先级分组」小节：
/// 「高优先级 / 中优先级 / 低优先级 / 无优先级」。
const smartPriorityGroupTitles = ['高优先级', '中优先级', '低优先级', '无优先级'];

/// 按创建时间分组的桶词。源文档该小节（`按创建时间分组（新增）`）只说
/// 「按照创建时间进行分类」没有列档名，本端按既有日期桶的词形补
/// 「今天 / 昨天 / 最近 7 天 / 更早」四档。
const smartCreatedAtGroupTitles = ['今天', '昨天', '最近 7 天', '更早'];

DateTime? _dueWallClockOf(TodoTask task) {
  final due = task.dueAt;
  if (due == null) return null;
  return taskWallClockDateTime(
    due,
    allDay: task.allDay,
    mode: TaskTimeMode.fromWire(task.timeMode),
    timeZone: task.timeZone,
  );
}

String _priorityTitleOf(int priority) {
  if (priority >= 3) return '高优先级';
  if (priority == 2) return '中优先级';
  if (priority == 1) return '低优先级';
  return '无优先级';
}

/// 「智能分组」引擎：输入已按当前排序排好的任务，输出分组桶。
///
/// 桶内顺序保持输入顺序（与既有 `_groupTasks` / `_groupTasksBySection` 同形）；
/// 空桶不输出；「按标签分组」时挂多个标签的任务出现在每个标签组里。
/// [listNameOf] / [tagNamesOf] 由页面用本地索引闭包出来，缺索引时传 null
/// ⇒ 该任务落到回退桶（「未命名清单」/「无标签」）而不是被丢弃。
List<SmartTaskGroup> groupTasksSmartly(
  List<TodoTask> tasks, {
  required SmartGrouping grouping,
  required DateTime now,
  String? Function(TodoTask task)? listNameOf,
  Set<String> Function(TodoTask task)? tagNamesOf,
}) {
  switch (grouping) {
    case SmartGrouping.none:
      return [];
    case SmartGrouping.byTime:
      return _groupByTime(tasks, now);
    case SmartGrouping.byPriority:
      return _groupByPriority(tasks);
    case SmartGrouping.byTag:
      return _groupByTag(tasks, tagNamesOf);
    case SmartGrouping.byList:
      return _groupByList(tasks, listNameOf);
    case SmartGrouping.byAssignee:
      return _groupByAssignee(tasks);
    case SmartGrouping.byCreatedAt:
      return _groupByCreatedAt(tasks, now);
  }
}

List<SmartTaskGroup> _groupByTime(List<TodoTask> tasks, DateTime now) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfTomorrow = startOfDay.add(const Duration(days: 1));
  final dayAfterTomorrow = startOfTomorrow.add(const Duration(days: 1));
  final startOfNext7 = startOfDay.add(const Duration(days: 7));
  final buckets = {
    for (final title in smartTimeGroupTitles) title: <TodoTask>[],
  };
  for (final task in tasks) {
    final due = _dueWallClockOf(task);
    final title = switch (due) {
      null => '无日期',
      final d when d.isBefore(startOfDay) => '已过期',
      final d when d.isBefore(startOfTomorrow) => '今天',
      final d when d.isBefore(dayAfterTomorrow) => '明天',
      final d when d.isBefore(startOfNext7) => '最近 7 天',
      _ => '以后',
    };
    buckets[title]!.add(task);
  }
  return [
    for (final title in smartTimeGroupTitles)
      if (buckets[title]!.isNotEmpty)
        SmartTaskGroup(id: 'time-$title', title: title, tasks: buckets[title]!),
  ];
}

List<SmartTaskGroup> _groupByPriority(List<TodoTask> tasks) {
  final buckets = {
    for (final title in smartPriorityGroupTitles) title: <TodoTask>[],
  };
  for (final task in tasks) {
    buckets[_priorityTitleOf(task.priority)]!.add(task);
  }
  return [
    for (final title in smartPriorityGroupTitles)
      if (buckets[title]!.isNotEmpty)
        SmartTaskGroup(id: 'prio-$title', title: title, tasks: buckets[title]!),
  ];
}

/// 标签名按「输入里首次出现」的先后排桶（输入已经过当前排序，结果稳定），
/// 没有标签的任务进「无标签」桶、永远排最后；挂多个标签的任务进每个标签组。
List<SmartTaskGroup> _groupByTag(
  List<TodoTask> tasks,
  Set<String> Function(TodoTask task)? tagNamesOf,
) {
  final orderedTitles = <String>[];
  final buckets = <String, List<TodoTask>>{};
  final untagged = <TodoTask>[];
  for (final task in tasks) {
    final names = tagNamesOf?.call(task);
    if (names == null || names.isEmpty) {
      untagged.add(task);
      continue;
    }
    for (final name in names) {
      final bucket = buckets.putIfAbsent(name, () {
        orderedTitles.add(name);
        return <TodoTask>[];
      });
      bucket.add(task);
    }
  }
  return [
    for (final title in orderedTitles)
      SmartTaskGroup(id: 'tag-$title', title: title, tasks: buckets[title]!),
    if (untagged.isNotEmpty)
      SmartTaskGroup(id: 'tag-none', title: '无标签', tasks: untagged),
  ];
}

List<SmartTaskGroup> _groupByList(
  List<TodoTask> tasks,
  String? Function(TodoTask task)? listNameOf,
) {
  final orderedTitles = <String>[];
  final buckets = <String, List<TodoTask>>{};
  for (final task in tasks) {
    final name = listNameOf?.call(task);
    final title = (name == null || name.isEmpty) ? '未命名清单' : name;
    final bucket = buckets.putIfAbsent(title, () {
      orderedTitles.add(title);
      return <TodoTask>[];
    });
    bucket.add(task);
  }
  return [
    for (final title in orderedTitles)
      SmartTaskGroup(id: 'list-$title', title: title, tasks: buckets[title]!),
  ];
}

/// 指派人按 `assigneeUserName` 分桶；没有指派人的任务进「无指派人」桶（排最后）。
/// 同名不同人（userId 不同）在共享清单场景下也会并作一组——本端拿不到
/// 服务端成员目录时的客户端口径，specs 里有登记。
List<SmartTaskGroup> _groupByAssignee(List<TodoTask> tasks) {
  final orderedTitles = <String>[];
  final buckets = <String, List<TodoTask>>{};
  final unassigned = <TodoTask>[];
  for (final task in tasks) {
    final name = task.assigneeUserName;
    if (name == null || name.isEmpty) {
      unassigned.add(task);
      continue;
    }
    final bucket = buckets.putIfAbsent(name, () {
      orderedTitles.add(name);
      return <TodoTask>[];
    });
    bucket.add(task);
  }
  return [
    for (final title in orderedTitles)
      SmartTaskGroup(
        id: 'assignee-$title',
        title: title,
        tasks: buckets[title]!,
      ),
    if (unassigned.isNotEmpty)
      SmartTaskGroup(id: 'assignee-none', title: '无指派人', tasks: unassigned),
  ];
}

List<SmartTaskGroup> _groupByCreatedAt(List<TodoTask> tasks, DateTime now) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfYesterday = startOfDay.add(const Duration(days: -1));
  final startOfLast7 = startOfDay.add(const Duration(days: -7));
  final buckets = {
    for (final title in smartCreatedAtGroupTitles) title: <TodoTask>[],
  };
  for (final task in tasks) {
    final created = task.createdAt;
    final title = switch (created) {
      _ when created.isAfter(startOfDay) => '今天',
      _ when created.isAfter(startOfYesterday) => '昨天',
      _ when created.isAfter(startOfLast7) => '最近 7 天',
      _ => '更早',
    };
    buckets[title]!.add(task);
  }
  return [
    for (final title in smartCreatedAtGroupTitles)
      if (buckets[title]!.isNotEmpty)
        SmartTaskGroup(
          id: 'created-$title',
          title: title,
          tasks: buckets[title]!,
        ),
  ];
}

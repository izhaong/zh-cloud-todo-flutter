import 'section.dart';

/// 一个智能清单「关联的时间条件」（嘀嗒《02-功能指南/02-日历/07-任务与日历同时显示.md》
/// `:61`「拖动到智能清单上：」`:63`「会为任务自动添加该智能清单关联的时间条件，
/// 例如“今天”、“本周”等。」）。
///
/// 窗口两端都用**展示墙钟**（与 `tasks_by_list_page.dart` 的 `_dateConditionMatches`
/// 同一套换算），`[fromInclusive, toExclusive)`。[targetDay] 是落点日：区间型清单要落的
/// 那一天取窗口首日，理由写在这里而不是测试里 —— 落完必须让任务真的出现在刚拖上去的那个
/// 清单里，窗口首日是不需要用户再输入任何东西的唯一确定选择。
class SmartListTimeCondition {
  const SmartListTimeCondition({
    required this.dueRange,
    required this.fromInclusive,
    required this.toExclusive,
    required this.targetDay,
  });

  /// 与过滤谓词同一个键（`TaskFilter.dueRange`）：这条窗口就是那一档智能清单的日期条件，
  /// `test/features/shell/smart_list_time_condition_test.dart` 拿它现算一遍对账。
  final String dueRange;
  final DateTime fromInclusive;
  final DateTime toExclusive;

  /// 落点日：窗口内最早的那一天（本端一定有值，因为三个窗口都是「今天起或明天起」）。
  final DateTime targetDay;

  /// 任务的展示墙钟截止时刻是否已经满足这一档条件（null = 无日期，不满足）。
  bool satisfiedBy(DateTime? wallClockDue) =>
      wallClockDue != null &&
      !wallClockDue.isBefore(fromInclusive) &&
      wallClockDue.isBefore(toExclusive);

  /// 落点日本身必须在窗口内，否则「拖完出现在这个清单里」就不成立。
  bool get targetDaySatisfies => satisfiedBy(targetDay);
}

/// 只有谓词里带日期窗口的智能清单才有「关联的时间条件」⇒ 只有它们能做拖放落点。
///
/// 返回 null 的五档各有理由，都不是漏做：收集箱是**清单归属**（`listId`），它的移动早已
/// 由清单行那条路面覆盖；指派给我按负责人、全部不限条件、已完成按完成态、垃圾桶按回收站，
/// 都没有可写的日期条件 —— 原文那句「添加该智能清单关联的时间条件」给不出语义。
SmartListTimeCondition? smartListTimeConditionOf(
  SmartList smart,
  DateTime now,
) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  switch (smart) {
    case SmartList.today:
      return SmartListTimeCondition(
        dueRange: 'today',
        fromInclusive: startOfDay,
        toExclusive: startOfDay.add(const Duration(days: 1)),
        targetDay: startOfDay,
      );
    case SmartList.tomorrow:
      return SmartListTimeCondition(
        dueRange: 'tomorrow',
        fromInclusive: startOfDay.add(const Duration(days: 1)),
        toExclusive: startOfDay.add(const Duration(days: 2)),
        targetDay: startOfDay.add(const Duration(days: 1)),
      );
    case SmartList.upcoming:
      // 本端「最近七天」= 明天起 7 天（与 `_dateConditionMatches` 的 'next7days' 同界：
      // 下界 todayEnd、上界 startOfDay+8d）。所以它的落点日与「明天」相同，
      // 这一档与「明天」不互斥 —— 已在窗口后段的任务拖到这里会被跳过。
      return SmartListTimeCondition(
        dueRange: 'next7days',
        fromInclusive: startOfDay.add(const Duration(days: 1)),
        toExclusive: startOfDay.add(const Duration(days: 8)),
        targetDay: startOfDay.add(const Duration(days: 1)),
      );
    case SmartList.inbox:
    case SmartList.assignToMe:
    case SmartList.all:
    case SmartList.completed:
    case SmartList.trash:
      return null;
  }
}

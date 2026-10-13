import '../../core/db/app_database.dart';
import 'smart_grouping.dart';

/// 看板「智能分组轴」列的写回计算（specs/118，矩阵 #15 面 ⑦）。
///
/// 列 id 由 `groupTasksSmartly` 生成（前缀=轴）：`time-<桶>` / `prio-<桶>` /
/// `list-<清单名>` / `assignee-` / `tag-` / `created-`。
///
/// 输出两类动作之一：
/// - [KanbanAxisUpdate]：要写的字段（dueAt/priority/listId），调用方转
///   `TaskRepository.update`；
/// - [KanbanAxisUnsupportedError]：该轴不可拖（抛给列的 `_moveTask`
///   转成可见 SnackBar，不静默吞掉拖拽）。
sealed class KanbanAxisMoveResult {
  const KanbanAxisMoveResult();
}

class KanbanAxisUpdate extends KanbanAxisMoveResult {
  const KanbanAxisUpdate({
    this.dueAt,
    this.clearDueAt = false,
    this.priority,
    this.listId,
  });

  final DateTime? dueAt;
  final bool clearDueAt;
  final int? priority;
  final String? listId;
}

class KanbanAxisUnsupportedError extends KanbanAxisMoveResult {
  const KanbanAxisUnsupportedError(this.message);
  final String message;
}

/// 「已过期」没有合理的代表日：嘀嗒把它当展示桶，语义上不该通过拖拽
/// "安排"到过去 ⇒ 不可拖。
DateTime? axisTimeGroupRepresentativeDay(
  String title, {
  required DateTime now,
}) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  return switch (title) {
    '今天' => startOfDay,
    '明天' => startOfDay.add(const Duration(days: 1)),
    '最近 7 天' => startOfDay.add(const Duration(days: 7 - 1)),
    '以后' => startOfDay.add(const Duration(days: 7)),
    _ => null,
  };
}

KanbanAxisMoveResult kanbanAxisMove({
  required SmartGrouping grouping,
  required String groupId,
  required TodoTask task,
  required List<TodoList> lists,
  required DateTime now,
}) {
  switch (grouping) {
    case SmartGrouping.byTime:
      final title = groupId.substring('time-'.length);
      if (title == '无日期') {
        return const KanbanAxisUpdate(clearDueAt: true);
      }
      final targetDay = axisTimeGroupRepresentativeDay(title, now: now);
      if (targetDay == null) {
        return const KanbanAxisUnsupportedError('「已过期」不支持拖拽安排');
      }
      // 保留原来的时刻（墙钟），只挪日。
      final due = task.dueAt;
      final keepTime = due != null;
      return KanbanAxisUpdate(
        dueAt: keepTime
            ? DateTime(
                targetDay.year,
                targetDay.month,
                targetDay.day,
                due.hour,
                due.minute,
                due.second,
              )
            : targetDay,
      );
    case SmartGrouping.byPriority:
      final title = groupId.substring('prio-'.length);
      final priority = switch (title) {
        '高优先级' => 3,
        '中优先级' => 2,
        '低优先级' => 1,
        _ => 0,
      };
      return KanbanAxisUpdate(priority: priority);
    case SmartGrouping.byList:
      final title = groupId.substring('list-'.length);
      final target = lists.where((list) => list.name == title).firstOrNull;
      if (target == null) {
        return KanbanAxisUnsupportedError('找不到清单「$title」，拖拽未生效');
      }
      // 重名清单会落进第一个同名清单：与 `groupByList` 的"按名字并桶"同口径。
      return KanbanAxisUpdate(listId: target.id);
    case SmartGrouping.byAssignee:
    case SmartGrouping.byTag:
    case SmartGrouping.byCreatedAt:
    case SmartGrouping.none:
      return const KanbanAxisUnsupportedError('该分组方式的列不支持拖拽改值');
  }
}

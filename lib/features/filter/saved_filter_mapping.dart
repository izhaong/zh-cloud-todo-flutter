import 'dart:convert';

import '../../state/repositories/filter_repository.dart';
import 'filter_bar.dart';

/// 本机筛选态 ↔ 服务端 `todo_filter.conditions` 契约的双向映射。
/// 契约里放不下的维度必须回报给 UI，不能静默存成半个过滤器。
({TodoFilterConditions conditions, List<String> skipped}) savedFilterOf(
  TaskFilter filter,
) {
  final skipped = <String>[];
  if (filter.folderId != null) skipped.add('文件夹');
  if (filter.assigneeUserId != null) skipped.add('负责人');
  final preset = filter.dueRange == 'today' ? 'today' : null;
  if (filter.dueRange != null && preset == null) {
    skipped.add('到期范围「${dueRangeChipLabel(filter.dueRange)}」');
  }
  final range = TodoFilterDateRange(
    preset: preset,
    from: filter.dueAtFrom,
    to: filter.dueAtTo,
  );
  return (
    conditions: TodoFilterConditions(
      listIds: filter.listId == null ? const [] : [filter.listId!],
      tagIds: filter.tagIds,
      priorities: filter.priority == null ? const [] : [filter.priority!],
      statuses: filter.completed == null
          ? const []
          : [filter.completed! ? 'done' : 'todo'],
      keyword: filter.keyword,
      dateRange: range.isEmpty ? null : range,
    ),
    skipped: skipped,
  );
}

/// 还原不出忠实条件时返回 null：调用方要标成「本机暂不支持套用」，而不是套一半条件。
TaskFilter? taskFilterFromSaved(
  TodoFilterConditions conditions, {
  required Set<String> unsupportedKeys,
}) {
  if (unsupportedKeys.isNotEmpty) return null;
  if (conditions.listIds.length > 1) return null;
  if (conditions.priorities.length > 1) return null;
  // 任务列表页不消费 tagIds（`applyTaskFilter` 里没有标签分支）：带标签的行若可点，
  // 套用结果会与摘要承诺不符 ⇒ 一律标「不支持」而不是套一半。
  if (conditions.tagIds.isNotEmpty) return null;
  // 只认 done/todo；in_progress、cancelled 等契约值在本地筛选态里没有对应字段，
  // 静默还原成「不限状态」等于凭空删掉一个条件。
  if (conditions.statuses.any((s) => s != 'done' && s != 'todo')) return null;
  final preset = conditions.dateRange?.preset;
  if (preset != null && preset != 'today') return null;
  return TaskFilter(
    listId: conditions.listIds.isEmpty ? null : conditions.listIds.single,
    tagIds: conditions.tagIds,
    priority: conditions.priorities.isEmpty
        ? null
        : conditions.priorities.single,
    completed: switch (conditions.statuses) {
      ['done'] => true,
      ['todo'] => false,
      _ => null,
    },
    keyword: conditions.keyword,
    dueRange: preset,
    dueAtFrom: conditions.dateRange?.from,
    dueAtTo: conditions.dateRange?.to,
  );
}

/// 解析行数据；`conditionJson` 坏掉时返回 null 交由 UI 显示「条件已损坏」。
({TodoFilterConditions conditions, Set<String> unsupportedKeys})?
parseSavedFilterConditions(String conditionJson) {
  try {
    final decoded = jsonDecode(conditionJson);
    if (decoded is! Map) return null;
    return TodoFilterConditions.fromJson(
      decoded.map((key, value) => MapEntry('$key', value)),
    );
  } on FormatException {
    return null;
  }
}

const _priorityLabels = {0: '无', 1: '低', 2: '中', 3: '高'};
const _statusLabels = {
  'todo': '未完成',
  'in_progress': '进行中',
  'done': '已完成',
  'cancelled': '已取消',
};

/// 列表副标题与读屏共用的一份条件摘要。
String savedFilterSummary(
  TodoFilterConditions conditions, {
  required Set<String> unsupportedKeys,
}) {
  final parts = <String>[];
  if (conditions.listIds.isNotEmpty) {
    parts.add('清单 ${conditions.listIds.length} 个');
  }
  if (conditions.tagIds.isNotEmpty) {
    parts.add('标签 ${conditions.tagIds.length} 个');
  }
  if (conditions.priorities.isNotEmpty) {
    parts.add(
      '优先级 ${conditions.priorities.map((p) => _priorityLabels[p] ?? p).join('、')}',
    );
  }
  if (conditions.statuses.isNotEmpty) {
    parts.add(conditions.statuses.map((s) => _statusLabels[s] ?? s).join('、'));
  }
  if (conditions.keyword?.trim().isNotEmpty == true) {
    parts.add('关键词「${conditions.keyword!.trim()}」');
  }
  final range = conditions.dateRange;
  if (range?.preset != null) {
    parts.add('${range!.preset} 到期');
  } else if (range != null && (range.from != null || range.to != null)) {
    parts.add('自定义日期');
  }
  if (unsupportedKeys.isNotEmpty) {
    parts.add('含 ${unsupportedKeys.length} 项本机不支持的条件');
  }
  return parts.isEmpty ? '无附加条件' : parts.join(' · ');
}

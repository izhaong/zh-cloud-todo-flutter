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
  // 跨条件的逻辑词要先过服务端同一条放置校验，再决定写不写：
  // `TodoFilterServiceImpl.java:644-660` 要求词只能挂在**已启用**的条件上，且不能挂在
  // 第一条已启用条件上（它前面没有条件可连），否则 `todo_filter` 整个保存请求会被拒。
  // 这里不许「顺手丢掉那半条」—— 静默丢词会存出一份与用户所选不一致的过滤器；
  // 改成点名给 UI（skipped 非空时对话框本来就拒绝保存），让用户自己决定撤哪一条。
  final activeKeys = activeConditionKeys(filter);
  final conditionLogics = <String, String>{};
  for (final entry in filter.conditionLogics.entries) {
    final logic = entry.value.toLowerCase();
    if (!conditionOrder.contains(entry.key) ||
        (logic != tagLogicAnd && logic != tagLogicOr)) {
      skipped.add('跨条件逻辑词「${entry.key}」');
      continue;
    }
    if (!activeKeys.contains(entry.key) || activeKeys.first == entry.key) {
      // 挂在第一条上或挂在没启用的条件上，服务端都会整份拒绝；连 activeKeys 为空
      // （`active.isEmpty` 那条分支）也走这里。
      skipped.add('跨条件逻辑词「${entry.key}」（它前面没有可连接的条件）');
      continue;
    }
    // 「且」就是缺省连接词（服务端 isOrLogic 只认 or）⇒ 不进 JSON，
    // 与 tagLogic 同一条形状规矩：写出去的一律是改变了行为的那些。
    if (logic == tagLogicOr) conditionLogics[entry.key] = logic;
  }
  return (
    conditions: TodoFilterConditions(
      listIds: filter.listId == null ? const [] : [filter.listId!],
      tagIds: filter.tagIds,
      // 「且」不写键（等价于服务端的缺省 AND）；写出去的值一律归到词表内的小写形式。
      tagLogic: filter.tagsMatchAny ? tagLogicOr : null,
      priorities: filter.priority == null ? const [] : [filter.priority!],
      statuses: filter.completed == null
          ? const []
          : [filter.completed! ? 'done' : 'todo'],
      keyword: filter.keyword,
      dateRange: range.isEmpty ? null : range,
      conditionLogics: conditionLogics.isEmpty ? null : conditionLogics,
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
  // tagIds 如今真的参与求值（Issue #417 在 `applyTaskFilter` 里补了标签分支），
  // 所以带标签的已存过滤器可以套用，不再一律标「不支持」。

  // 「且/或」只认词表内两个值：未知取值既不当 and 也不当 or，直接标不支持套用 ——
  // 猜哪一种都是替用户改条件（大小写不敏感，与服务端 equalsIgnoreCase 同口径）。
  final rawTagLogic = conditions.tagLogic;
  final loweredTagLogic = rawTagLogic?.toLowerCase();
  if (rawTagLogic != null &&
      loweredTagLogic != tagLogicOr &&
      loweredTagLogic != tagLogicAnd) {
    return null;
  }

  // 只认 done/todo；in_progress、cancelled 等契约值在本地筛选态里没有对应字段，
  // 静默还原成「不限状态」等于凭空删掉一个条件。
  // `conditionLogics` 只认「键在 CONDITION_ORDER 里 + 值在 and/or 词表内」（同服务端
  // validateLogicWords:614-635）。猜哪一种都是替用户改条件。
  for (final entry
      in (conditions.conditionLogics ?? const <String, String>{}).entries) {
    if (!conditionOrder.contains(entry.key) ||
        (entry.value != tagLogicAnd && entry.value != tagLogicOr)) {
      return null;
    }
  }
  if (conditions.statuses.any((s) => s != 'done' && s != 'todo')) return null;
  final preset = conditions.dateRange?.preset;
  if (preset != null && preset != 'today') return null;
  return TaskFilter(
    listId: conditions.listIds.isEmpty ? null : conditions.listIds.single,
    tagIds: conditions.tagIds,
    tagLogic: loweredTagLogic ?? tagLogicAnd,
    conditionLogics: conditions.conditionLogics ?? const {},
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

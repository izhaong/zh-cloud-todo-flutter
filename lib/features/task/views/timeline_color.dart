import 'package:flutter/material.dart';

import '../../../core/db/app_database.dart';
import '../../list/list_color.dart';
import '../../tag/tag_color.dart';

/// 时间线任务条着色轴（specs/121，矩阵 #16 面 ⑦）。
///
/// 判据源《01-任务/08-不同的视图查看任务/03-时间线视图：项目管理的必备神器.md》
/// `:95`「跟日历视图一样，可以在『显示设置』中根据清单、标签以及优先级的颜色显示」。
///
/// 颜色数据源全部复用既有设施：清单色 `todo_list.color`（specs/102）+
/// `listColorFromHex`；标签色 `todo_tag.color` + `parseHexColor`（多标签取
/// [tagRank] 位次最高的标签，与「按标签排序」同口径）；优先级轴就是时间线
/// 现有的 priority switch——无色（清单没配色/没标签）时回退它，
/// 不造第四种取色规则。
enum TimelineColorBy { priority, list, tag }

TimelineColorBy timelineColorByFromWire(String? wire) => switch (wire) {
  'list' => TimelineColorBy.list,
  'tag' => TimelineColorBy.tag,
  _ => TimelineColorBy.priority,
};

/// 时间线任务条颜色；返回 null 表示走优先级轴的现有取色。
Color? timelineTaskColor(
  TodoTask task, {
  required TimelineColorBy colorBy,
  String? Function(TodoTask task)? listColorHexOf,
  String? Function(TodoTask task)? tagColorHexOf,
}) {
  switch (colorBy) {
    case TimelineColorBy.priority:
      return null;
    case TimelineColorBy.list:
      return listColorFromHex(listColorHexOf?.call(task));
    case TimelineColorBy.tag:
      // parseHexColor 对 null 给灰色——那是「有 hex 但解析不出」的兜底；
      // 没挂色标签（hex 为 null/空）要回退优先级轴，不能变灰。
      final hex = tagColorHexOf?.call(task);
      if (hex == null || hex.isEmpty) return null;
      return parseHexColor(hex);
  }
}

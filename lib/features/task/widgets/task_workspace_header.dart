import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/todo_layout_tokens.dart';
import '../../../state/repositories/task_query_repository.dart';
import '../smart_grouping.dart';
import '../view_mode.dart';

/// Commands kept in the existing sort menu so the idle workspace retains the
/// approved visual structure while batch editing remains explicitly reachable.
enum _TaskWorkspaceHeaderCommand {
  smart,
  priorityDesc,
  dueDate,
  title,
  createdAt,
  updatedAt,
  tag,
  batchEdit,
  createSection,
  editQuadrantRules,
  editListBackground,
  directionNewestFirst,
  directionOldestFirst,
  hideCompleted,
}

extension on _TaskWorkspaceHeaderCommand {
  TaskSort? get sort => switch (this) {
    _TaskWorkspaceHeaderCommand.smart => TaskSort.smart,
    _TaskWorkspaceHeaderCommand.priorityDesc => TaskSort.priorityDesc,
    _TaskWorkspaceHeaderCommand.dueDate => TaskSort.dueDate,
    _TaskWorkspaceHeaderCommand.title => TaskSort.title,
    _TaskWorkspaceHeaderCommand.createdAt => TaskSort.createdAt,
    _TaskWorkspaceHeaderCommand.updatedAt => TaskSort.updatedAt,
    _TaskWorkspaceHeaderCommand.tag => TaskSort.tag,
    _TaskWorkspaceHeaderCommand.batchEdit => null,
    _TaskWorkspaceHeaderCommand.createSection => null,
    _TaskWorkspaceHeaderCommand.editQuadrantRules => null,
    _TaskWorkspaceHeaderCommand.editListBackground => null,
    _TaskWorkspaceHeaderCommand.directionNewestFirst => null,
    _TaskWorkspaceHeaderCommand.directionOldestFirst => null,
    _TaskWorkspaceHeaderCommand.hideCompleted => null,
  };

  TaskSortDirection? get direction => switch (this) {
    _TaskWorkspaceHeaderCommand.directionNewestFirst =>
      TaskSortDirection.newestFirst,
    _TaskWorkspaceHeaderCommand.directionOldestFirst =>
      TaskSortDirection.oldestFirst,
    _ => null,
  };
}

extension TaskSortX on TaskSort {
  String get label => switch (this) {
    TaskSort.smart => '智能（置顶优先）',
    TaskSort.priorityDesc => '优先级',
    TaskSort.dueDate => '截止日期',
    TaskSort.title => '标题',
    TaskSort.createdAt => '创建时间',
    TaskSort.updatedAt => '修改时间',
    // 嘀嗒《用标签管理任务》:122 的菜单措辞就是「按标签进行排序」。
    TaskSort.tag => '标签',
  };

  /// 嘀嗒《03-用分组和排序管理任务》只在 `:169-176`「按创建时间排序」与
  /// `:186` + `:192-193`「按修改时间排序」两节下列出「从旧到新 / 从新到旧」；
  /// 「按时间排序」(:143) 与「按优先级排序」(:156) 没有方向一说 ⇒ 不给方向行。
  bool get hasDirection =>
      this == TaskSort.createdAt || this == TaskSort.updatedAt;
}

extension TaskSortDirectionX on TaskSortDirection {
  String get label => switch (this) {
    TaskSortDirection.newestFirst => '从新到旧',
    TaskSortDirection.oldestFirst => '从旧到新',
  };
}

/// Single compact title and command row for the embedded task workspace.
class TaskWorkspaceHeader extends StatelessWidget {
  const TaskWorkspaceHeader({
    super.key,
    required this.title,
    required this.taskCount,
    required this.mode,
    required this.sort,
    required this.filterActive,
    required this.onModeChanged,
    required this.onSortChanged,
    required this.onFilterPressed,
    this.grouping = SmartGrouping.none,
    this.onGroupingChanged,
    this.sortDirection = TaskSortDirection.newestFirst,
    this.onSortDirectionChanged,
    this.batchSelectionActive = false,
    this.onBatchPressed,
    this.onCreateSection,
    this.onEditQuadrantRules,
    this.onEditListBackground,

    /// 嘀嗒《03-四象限/01-如何使用四象限》:24「设置 > 功能模块，开启「四象限」功能」：
    /// 关掉这一档时视图菜单里不该再出现「四象限」。默认 true ⇒ 不传就是今天的行为。
    this.showQuadrantView = true,
    this.hideCompleted,
    this.hideCompletedHint,
    this.onToggleHideCompleted,
  });

  final String title;
  final int taskCount;
  final TaskViewMode mode;
  final TaskSort sort;
  final bool filterActive;
  final ValueChanged<TaskViewMode> onModeChanged;
  final ValueChanged<TaskSort> onSortChanged;
  final VoidCallback onFilterPressed;

  /// 当前智能分组档（嘀嗒《03-用分组和排序管理任务》「智能分组」节，Issue #321）。
  /// null 回调 ⇒ 菜单整个不渲染（调用方还没接分组渲染时保持原样）。
  final SmartGrouping grouping;

  /// 智能分组档变化回调；null ⇒ 不渲染智能分组菜单。
  final ValueChanged<SmartGrouping>? onGroupingChanged;

  /// 时间轴的当前方向。默认值等于本参数存在之前唯一的行为，所以不传也不会改变排序。
  final TaskSortDirection sortDirection;

  /// 为 null 时不渲染方向行。嘀嗒把方向放在同一个「分组排序」面板里（`:136`），
  /// 所以这里不另开端子菜单，只有能表达方向的调用方给了回调才出现这两行。
  final ValueChanged<TaskSortDirection>? onSortDirectionChanged;
  final bool batchSelectionActive;
  final VoidCallback? onBatchPressed;
  final VoidCallback? onCreateSection;
  final VoidCallback? onEditQuadrantRules;

  /// 嘀嗒《02-用清单管理任务》:96「进入你想设置的清单详情页，点击右上角的「...」-「背景」」。
  /// null ⇒ 不渲染该项（未选中具体清单、或选中的是不支持背景的清单）。
  final VoidCallback? onEditListBackground;

  /// false ⇒ 视图档位菜单不出现「四象限」那一档（功能模块开关关闭）。
  final bool showQuadrantView;

  /// 嘀嗒《02-功能指南/03-四象限/02-如何编辑四象限规则.md》`:132`
  /// 「在四象限页面，点击右上角「...」- 隐藏已完成。」
  /// null ⇒ 当前不是四象限，这一项整个不出现。
  final bool? hideCompleted;

  /// 非 null ⇒ 这一项置灰，并把这句话原样显示在项里（读屏要念得出为什么不能点）。
  final String? hideCompletedHint;
  final VoidCallback? onToggleHideCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      key: const Key('todo-task-workspace-header'),
      height: TodoLayoutTokens.workspaceHeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: TodoLayoutTokens.mainHorizontalInset,
            right: 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$taskCount',
                      style: TextStyle(
                        color: colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<TaskViewMode>(
                key: const Key('todo-view-menu'),
                tooltip: '视图',
                initialValue: mode,
                icon: const Icon(Icons.view_agenda_outlined, size: 20),
                onSelected: onModeChanged,
                itemBuilder: (context) => [
                  for (final candidate in TaskViewMode.values)
                    if (showQuadrantView ||
                        candidate != TaskViewMode.eisenhower)
                      PopupMenuItem(
                        value: candidate,
                        child: Text(candidate.label),
                      ),
                ],
              ),
              if (onGroupingChanged != null)
                PopupMenuButton<SmartGrouping>(
                  key: const Key('todo-grouping-menu'),
                  tooltip: '智能分组',
                  initialValue: grouping,
                  icon: const Icon(Icons.category_outlined, size: 20),
                  onSelected: onGroupingChanged,
                  itemBuilder: (context) => [
                    for (final candidate in SmartGrouping.values)
                      PopupMenuItem(
                        key: Key('todo-grouping-${candidate.name}'),
                        value: candidate,
                        child: Row(
                          children: [
                            Expanded(child: Text(candidate.label)),
                            if (candidate == grouping)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: colors.accent,
                                semanticLabel: '当前分组',
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              PopupMenuButton<_TaskWorkspaceHeaderCommand>(
                key: const Key('todo-sort-menu'),
                tooltip: '排序与批量编辑',
                icon: const Icon(Icons.sort, size: 20),
                onSelected: (command) {
                  final nextDirection = command.direction;
                  if (nextDirection != null) {
                    onSortDirectionChanged?.call(nextDirection);
                    return;
                  }
                  final nextSort = command.sort;
                  if (nextSort != null) {
                    onSortChanged(nextSort);
                    return;
                  }
                  switch (command) {
                    case _TaskWorkspaceHeaderCommand.batchEdit:
                      onBatchPressed?.call();
                    case _TaskWorkspaceHeaderCommand.createSection:
                      onCreateSection?.call();
                    case _TaskWorkspaceHeaderCommand.editQuadrantRules:
                      onEditQuadrantRules?.call();
                    case _TaskWorkspaceHeaderCommand.editListBackground:
                      onEditListBackground?.call();
                    case _TaskWorkspaceHeaderCommand.hideCompleted:
                      onToggleHideCompleted?.call();
                    case _TaskWorkspaceHeaderCommand.smart:
                    case _TaskWorkspaceHeaderCommand.priorityDesc:
                    case _TaskWorkspaceHeaderCommand.dueDate:
                    case _TaskWorkspaceHeaderCommand.title:
                    case _TaskWorkspaceHeaderCommand.createdAt:
                    case _TaskWorkspaceHeaderCommand.updatedAt:
                    case _TaskWorkspaceHeaderCommand.tag:
                    case _TaskWorkspaceHeaderCommand.directionNewestFirst:
                    case _TaskWorkspaceHeaderCommand.directionOldestFirst:
                      break;
                  }
                },
                itemBuilder: (context) => [
                  for (final candidate in TaskSort.values)
                    PopupMenuItem(
                      value: _TaskWorkspaceHeaderCommand.values.byName(
                        candidate.name,
                      ),
                      child: Text(candidate.label),
                    ),
                  // 嘀嗒 :173-176/:192-193 只给两档时间轴列方向 ⇒ 其余档位不出现方向行。
                  if (sort.hasDirection && onSortDirectionChanged != null) ...[
                    const PopupMenuDivider(),
                    for (final candidate in TaskSortDirection.values)
                      PopupMenuItem(
                        key: Key('todo-sort-direction-${candidate.name}'),
                        value: candidate == TaskSortDirection.newestFirst
                            ? _TaskWorkspaceHeaderCommand.directionNewestFirst
                            : _TaskWorkspaceHeaderCommand.directionOldestFirst,
                        child: Row(
                          children: [
                            Expanded(child: Text(candidate.label)),
                            // semanticLabel 让读屏能分辨"哪一行是当前方向"：
                            // 勾是视觉符号，光有 Icon 时读屏只念得出两行文案。
                            if (candidate == sortDirection)
                              Icon(
                                Icons.check,
                                size: 16,
                                color: colors.accent,
                                semanticLabel: '当前方向',
                              ),
                          ],
                        ),
                      ),
                  ],
                  if (onBatchPressed != null) const PopupMenuDivider(),
                  if (onBatchPressed != null)
                    PopupMenuItem(
                      key: const Key('todo-batch-edit'),
                      value: _TaskWorkspaceHeaderCommand.batchEdit,
                      child: Text(batchSelectionActive ? '退出批量编辑' : '批量编辑'),
                    ),
                  if (onCreateSection != null) const PopupMenuDivider(),
                  if (onCreateSection != null)
                    const PopupMenuItem(
                      key: Key('todo-section-create-menu'),
                      value: _TaskWorkspaceHeaderCommand.createSection,
                      child: Text('新建分组'),
                    ),
                  // 嘀嗒：四象限页面右上角「...」里选「编辑」进象限规则编辑页。
                  if (onEditQuadrantRules != null) const PopupMenuDivider(),
                  if (onEditQuadrantRules != null)
                    const PopupMenuItem(
                      key: Key('todo-quadrant-rules-entry'),
                      value: _TaskWorkspaceHeaderCommand.editQuadrantRules,
                      child: Text('编辑象限规则'),
                    ),
                  // 嘀嗒《02-用清单管理任务》:96：详情页「...」里的「背景」，只在选中
                  // 具体清单且该清单支持背景时出现（收集箱与智能清单都不支持）。
                  if (onEditListBackground != null) const PopupMenuDivider(),
                  if (onEditListBackground != null)
                    const PopupMenuItem(
                      key: Key('todo-list-background-entry'),
                      value: _TaskWorkspaceHeaderCommand.editListBackground,
                      child: Text('背景'),
                    ),
                  if (hideCompleted != null) const PopupMenuDivider(),
                  if (hideCompleted != null)
                    PopupMenuItem(
                      key: const Key('todo-quadrant-hide-completed'),
                      value: _TaskWorkspaceHeaderCommand.hideCompleted,
                      enabled: hideCompletedHint == null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            // excludeSemantics 在 Semantics 这一侧：把里面 Text 的节点吞掉，
                            // 免得读屏念两遍（一遍裸文字、一遍带档位的）。
                            excludeSemantics: true,
                            label:
                                '隐藏已完成，当前${hideCompleted! ? '已隐藏' : '已显示'}'
                                '${hideCompletedHint == null ? '' : '，$hideCompletedHint'}',
                            child: const Text('隐藏已完成'),
                          ),
                          if (hideCompletedHint != null)
                            Text(
                              hideCompletedHint!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.mutedForeground,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              IconButton(
                key: const Key('todo-filter-menu'),
                tooltip: filterActive ? '筛选（已启用）' : '筛选',
                onPressed: onFilterPressed,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    if (filterActive)
                      Positioned(
                        top: -1,
                        right: -2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

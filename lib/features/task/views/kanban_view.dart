import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../task_detail_page.dart';
import '../task_quick_add_sheet.dart';
import '../task_view_mutation_feedback.dart';

/// M11-B3 看板视图：横向滚动的多列看板。
///
/// 两种分组方式（源：嘀嗒《01-任务/07-不同的视图查看任务/02-看板视图：分类管理任务.md》）：
///   - 传了 `sections`（该清单里有分组）⇒ 一列一个 `TodoTaskSection`，列名取分组名，
///     末尾再补一列「未分组」兜住 `sectionId` 为空、或指向已删除分组的任务；
///     跨列拖拽写 `sectionId`（[onTaskSectionMove]），左右移列写分组顺序
///     （[onSectionOrderChanged]）。对应同页 `:99`-`:101`「- 按主题：英语、政治、专业课…」、
///     `:129`「都能点击「分组」或者「任务」自由地拖动到相应位置」、
///     `:141`「点击「分组」右上角的「+」，你可以在分组中添加任务」。
///   - `sections` 为空 ⇒ 仍是按 priority 的固定四列
///     （0=未开始 / 1=进行中 / 2=紧急 / 3=归档含已完成），跨列拖拽改 priority
///     （[onTaskMove]），对应同页 `:64`「你可以点击任务直接拖动到其他分组中」。
///
/// 卡片：title + due 摘要 + priority 标签 + 子任务进度；点击进 TaskDetailPage。
///
/// 仍然缺的两件（逐面判定与证据见 `specs/044-kanban-groups/`）：
///   - 看板列头没有「重命名 / 新建 / 删除」分组入口：同页 `:108`「点击「分组」右上角的「···」」、
///     `:115`「点击右上角「...」-「管理分组」」。清单侧那套 CRUD 已经能用
///     （`tasks_by_list_page.dart` 里 `todo-section-create` 那一组 Key），只是没挂到看板列头。
///   - 分组模式下列不可折叠：`BoardViewPreference` 的列 id 词汇被
///     `board_preference_repository.dart` 用 `defaultColumnIds.contains` 锁在固定四列，
///     分组列的折叠状态存不进去 ⇒ 与其给一个「点了当下生效、重进就丢」的开关，这里直接不给。
class KanbanView extends ConsumerWidget {
  const KanbanView({
    super.key,
    required this.tasks,
    this.listId,
    this.onTaskSelected,
    this.onTaskMove,
    this.hasRecoverablePreference = false,
    this.onRecoverPreference,
    this.orderedColumnIds = const ['todo', 'doing', 'urgent', 'archive'],
    this.collapsedColumnIds = const {},
    this.onColumnOrderChanged,
    this.onColumnCollapsedChanged,
    this.onColumnTasksReordered,
    this.sections = const [],
    this.onTaskSectionMove,
    this.onSectionOrderChanged,
  });

  /// 渲染用的任务列表（已应用 list/filter 的客户端过滤结果）。
  final List<TodoTask> tasks;
  final String? listId;
  final ValueChanged<String>? onTaskSelected;
  final Future<void> Function(TodoTask task, int priority, bool completed)?
  onTaskMove;
  final bool hasRecoverablePreference;
  final Future<bool> Function()? onRecoverPreference;
  final List<String> orderedColumnIds;
  final Set<String> collapsedColumnIds;
  final Future<void> Function(List<String> orderedColumnIds)?
  onColumnOrderChanged;
  final Future<void> Function(String columnId, bool collapsed)?
  onColumnCollapsedChanged;
  final Future<void> Function(List<String> taskIds)? onColumnTasksReordered;

  /// 该清单的分组（按 `sortOrder` 升序）。非空即进入「按分组开列」模式。
  final List<TodoTaskSection> sections;
  final Future<void> Function(TodoTask task, String? sectionId)?
  onTaskSectionMove;
  final Future<void> Function(List<String> orderedSectionIds)?
  onSectionOrderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionMode = sections.isNotEmpty;
    final columns = sectionMode
        ? _sectionColumns(sections, tasks)
        : _priorityColumns(tasks);
    final ordered = sectionMode
        ? columns
        : _applyPreferredOrder(columns, orderedColumnIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (hasRecoverablePreference && onRecoverPreference != null)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: TextButton.icon(
              onPressed: () => _recoverPreference(context),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('恢复看板设置'),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < ordered.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _KanbanColumn(
                      data: ordered[index],
                      collapsed:
                          !sectionMode &&
                          collapsedColumnIds.contains(ordered[index].id),
                      onCollapsedChanged:
                          sectionMode || onColumnCollapsedChanged == null
                          ? null
                          : (collapsed) => onColumnCollapsedChanged!(
                              ordered[index].id,
                              collapsed,
                            ),
                      onMoveLeft:
                          _canMoveColumn(
                            sectionMode: sectionMode,
                            ordered: ordered,
                            index: index,
                            delta: -1,
                          )
                          ? () => _moveColumn(ordered, index, -1)
                          : null,
                      onMoveRight:
                          _canMoveColumn(
                            sectionMode: sectionMode,
                            ordered: ordered,
                            index: index,
                            delta: 1,
                          )
                          ? () => _moveColumn(ordered, index, 1)
                          : null,
                      onCardTap: (t) => _openDetail(context, t),
                      onCardMove: !sectionMode
                          ? (onTaskMove == null
                                ? null
                                : (task) => _moveTask(
                                    context,
                                    task,
                                    write: () => onTaskMove!(
                                      task,
                                      ordered[index].priority,
                                      ordered[index].completed,
                                    ),
                                  ))
                          : (onTaskSectionMove == null
                                ? null
                                : (task) => _moveTask(
                                    context,
                                    task,
                                    write: () => onTaskSectionMove!(
                                      task,
                                      ordered[index].sectionId,
                                    ),
                                  )),
                      onTasksReordered: onColumnTasksReordered == null
                          ? null
                          : (taskIds) => _reorderTasks(context, taskIds),
                      onAdd: !sectionMode
                          ? (ordered[index].key == const ValueKey('col-todo') &&
                                    listId != null
                                ? () => _quickAdd(context, ref, listId!)
                                : null)
                          : (listId == null
                                ? null
                                : () => _quickAdd(
                                    context,
                                    ref,
                                    listId!,
                                    sectionId: ordered[index].sectionId,
                                  )),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 「未分组」列的列 id：`TodoTaskSection.id` 是本地 UUID，不会与这个字面量相撞。
  static const unsectionedColumnId = 'unsectioned';

  /// 按 priority 分组的固定四列（清单没有分组时的默认分组方式）。
  static List<_KanbanColumnData> _priorityColumns(List<TodoTask> tasks) => [
    _KanbanColumnData(
      id: 'todo',
      key: const ValueKey('col-todo'),
      title: '未开始',
      color: Colors.blueGrey,
      priority: 0,
      completed: false,
      tasks: tasks.where((t) => t.priority == 0 && !t.completed).toList(),
    ),
    _KanbanColumnData(
      id: 'doing',
      key: const ValueKey('col-doing'),
      title: '进行中',
      color: Colors.blue,
      priority: 1,
      completed: false,
      tasks: tasks.where((t) => t.priority == 1 && !t.completed).toList(),
    ),
    _KanbanColumnData(
      id: 'urgent',
      key: const ValueKey('col-urgent'),
      title: '紧急',
      color: Colors.deepOrange,
      priority: 2,
      completed: false,
      tasks: tasks.where((t) => t.priority == 2 && !t.completed).toList(),
    ),
    _KanbanColumnData(
      id: 'archive',
      key: const ValueKey('col-archive'),
      title: '归档',
      color: Colors.grey,
      priority: 3,
      completed: true,
      tasks: tasks.where((t) => t.completed || t.priority >= 3).toList(),
    ),
  ];

  /// 按清单分组开列：一列一个 `TodoTaskSection`，末尾补一列「未分组」。
  ///
  /// `sectionId` 指向已被删除（或属于别的清单）的分组的任务也落在「未分组」列，
  /// 不会因为列不存在而从看板上消失。
  static List<_KanbanColumnData> _sectionColumns(
    List<TodoTaskSection> sections,
    List<TodoTask> tasks,
  ) {
    final knownIds = {for (final section in sections) section.id};
    String columnIdOf(TodoTask task) => knownIds.contains(task.sectionId)
        ? task.sectionId!
        : unsectionedColumnId;
    List<TodoTask> inColumn(String columnId) => [
      for (final task in tasks)
        if (columnIdOf(task) == columnId) task,
    ];
    return [
      for (final section in sections)
        _KanbanColumnData(
          id: section.id,
          key: ValueKey('col-${section.id}'),
          title: section.name,
          color: Colors.blueGrey,
          priority: 0,
          completed: false,
          tasks: inColumn(section.id),
          sectionId: section.id,
        ),
      _KanbanColumnData(
        id: unsectionedColumnId,
        key: const ValueKey('col-unsectioned'),
        title: '未分组',
        color: Colors.grey,
        priority: 0,
        completed: false,
        tasks: inColumn(unsectionedColumnId),
      ),
    ];
  }

  static List<_KanbanColumnData> _applyPreferredOrder(
    List<_KanbanColumnData> columns,
    List<String> orderedColumnIds,
  ) {
    final byId = {for (final column in columns) column.id: column};
    return <_KanbanColumnData>[
      for (final id in orderedColumnIds) ?byId.remove(id),
      ...byId.values,
    ];
  }

  /// 该列能不能往 `delta` 方向移。分组模式下「未分组」是哨兵列，
  /// 既自己不可移动（它不在 `TodoTaskSection` 里），也不能被换进分组序列。
  bool _canMoveColumn({
    required bool sectionMode,
    required List<_KanbanColumnData> ordered,
    required int index,
    required int delta,
  }) {
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return false;
    if (!sectionMode) return onColumnOrderChanged != null;
    if (onSectionOrderChanged == null) return false;
    return ordered[index].sectionId != null &&
        ordered[target].sectionId != null;
  }

  Future<void> _moveColumn(
    List<_KanbanColumnData> columns,
    int index,
    int delta,
  ) {
    final sectionId = columns[index].sectionId;
    if (sectionId != null) {
      final ordered = [
        for (final column in columns)
          if (column.sectionId != null) column.sectionId!,
      ];
      final from = ordered.indexOf(sectionId);
      ordered.removeAt(from);
      ordered.insert(from + delta, sectionId);
      return onSectionOrderChanged!(ordered);
    }
    final next = columns.map((column) => column.id).toList();
    final target = index + delta;
    final moved = next.removeAt(index);
    next.insert(target, moved);
    return onColumnOrderChanged!(next);
  }

  Future<void> _recoverPreference(BuildContext context) async {
    final recovered = await onRecoverPreference!();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(recovered ? '已恢复上次看板设置，等待同步' : '没有可恢复的看板设置')),
    );
  }

  void _openDetail(BuildContext context, TodoTask t) {
    final callback = onTaskSelected;
    if (callback != null) {
      callback(t.id);
      return;
    }
    showTaskDetailSheet(context, t.id);
  }

  /// 跨列拖拽的唯一出口：失败反馈与「重试」都走这一条，改 priority 与改分组共用。
  Future<void> _moveTask(
    BuildContext context,
    TodoTask task, {
    required Future<void> Function() write,
  }) async {
    try {
      await write();
    } catch (error) {
      if (context.mounted) {
        final readOnly = isTaskViewReadOnlyError(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(taskViewMutationFailureMessage(error, '移动任务失败，请重试')),
            action: readOnly
                ? null
                : SnackBarAction(
                    label: '重试',
                    onPressed: () => _moveTask(context, task, write: write),
                  ),
          ),
        );
      }
    }
  }

  Future<void> _reorderTasks(BuildContext context, List<String> taskIds) async {
    try {
      await onColumnTasksReordered!(taskIds);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '看板排序失败，请重试')),
        ),
      );
    }
  }

  static Future<void> _quickAdd(
    BuildContext context,
    WidgetRef ref,
    String listId, {
    String? sectionId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskQuickAddSheet(listId: listId, sectionId: sectionId),
    );
  }
}

class _KanbanColumnData {
  const _KanbanColumnData({
    required this.id,
    required this.key,
    required this.title,
    required this.color,
    required this.priority,
    required this.completed,
    required this.tasks,
    this.sectionId,
  });
  final String id;
  final Key key;
  final String title;
  final Color color;
  final int priority;
  final bool completed;
  final List<TodoTask> tasks;

  /// 非空表示这一列就是清单分组 `TodoTaskSection`；「未分组」哨兵列为 null。
  final String? sectionId;
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.data,
    required this.collapsed,
    required this.onCardTap,
    this.onCollapsedChanged,
    this.onMoveLeft,
    this.onMoveRight,
    this.onTasksReordered,
    this.onCardMove,
    this.onAdd,
  });

  final _KanbanColumnData data;
  final bool collapsed;
  final ValueChanged<TodoTask> onCardTap;
  final Future<void> Function(bool collapsed)? onCollapsedChanged;
  final Future<void> Function()? onMoveLeft;
  final Future<void> Function()? onMoveRight;
  final Future<void> Function(List<String> taskIds)? onTasksReordered;
  final Future<void> Function(TodoTask task)? onCardMove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      key: data.key,
      width: collapsed ? 72 : 260,
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: collapsed
            ? Column(
                children: [
                  IconButton(
                    tooltip: '展开${data.title}',
                    icon: const Icon(Icons.keyboard_arrow_right),
                    onPressed: onCollapsedChanged == null
                        ? null
                        : () => onCollapsedChanged!(false),
                  ),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      '${data.title}  ${data.tasks.length}',
                      style: TextStyle(
                        color: colors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : _buildExpanded(context, colors),
      ),
    );
  }

  Widget _buildExpanded(BuildContext context, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // 分组名由用户输入（长度不设视觉上限），列宽固定 260：
              // 320px 面 + 1.3 倍字号下不给它 flex 会溢出 141px，只能省略号截断。
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
              _ColumnCount(count: data.tasks.length, color: data.color),
              PopupMenuButton<String>(
                tooltip: '调整${data.title}列',
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'left',
                    enabled: onMoveLeft != null,
                    child: Text('左移${data.title}'),
                  ),
                  PopupMenuItem(
                    value: 'right',
                    enabled: onMoveRight != null,
                    child: Text('右移${data.title}'),
                  ),
                  // 分组模式下列折叠存不进偏好（见 KanbanView 类注释），
                  // 所以不给这一项，而不是给一个点了会丢的开关。
                  if (onCollapsedChanged != null)
                    PopupMenuItem(
                      value: 'collapse',
                      child: Text('折叠${data.title}'),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'left') onMoveLeft?.call();
                  if (value == 'right') onMoveRight?.call();
                  if (value == 'collapse') onCollapsedChanged?.call(true);
                },
              ),
              if (onAdd != null)
                IconButton(
                  tooltip: '在${data.title}新建任务',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: DragTarget<TodoTask>(
            onWillAcceptWithDetails: (details) => onCardMove != null,
            onAcceptWithDetails: (details) => onCardMove!(details.data),
            builder: (context, candidateData, rejectedData) =>
                data.tasks.isEmpty
                ? Center(
                    child: Text(
                      '空',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(8),
                    buildDefaultDragHandles: false,
                    itemCount: data.tasks.length,
                    // Flutter 3.41 本地基线尚未提供 onReorderItem；升级基线前保留旧回调。
                    // ignore: deprecated_member_use
                    onReorder: onTasksReordered == null
                        ? (_, _) {}
                        : (oldIndex, newIndex) {
                            final ids = data.tasks
                                .map((task) => task.id)
                                .toList(growable: false);
                            onTasksReordered!(
                              reorderKanbanTaskIds(ids, oldIndex, newIndex),
                            );
                          },
                    itemBuilder: (_, i) => Padding(
                      key: ValueKey('kanban-task-${data.tasks[i].id}'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _KanbanCard(
                        task: data.tasks[i],
                        accent: data.color,
                        reorderIndex: onTasksReordered == null ? null : i,
                        onTap: () => onCardTap(data.tasks[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

List<String> reorderKanbanTaskIds(
  List<String> ids,
  int oldIndex,
  int newIndex,
) {
  final reordered = List<String>.from(ids);
  var targetIndex = newIndex;
  if (targetIndex > oldIndex) targetIndex--;
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, moved);
  return reordered;
}

class _ColumnCount extends StatelessWidget {
  const _ColumnCount({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 11, color: colors.mutedForeground),
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.task,
    required this.accent,
    required this.reorderIndex,
    required this.onTap,
  });

  final TodoTask task;
  final Color accent;
  final int? reorderIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final df = DateFormat('MM-dd');
    final card = AppCard(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: task.completed
                  ? colors.mutedForeground
                  : colors.foreground,
              decoration: task.completed ? TextDecoration.lineThrough : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              AppTag(label: priorityLabel(task.priority), color: accent),
              const Spacer(),
              if (task.dueAt != null)
                Text(
                  df.format(
                    taskWallClockDateTime(
                      task.dueAt!,
                      allDay: task.allDay,
                      fixedTimezone: task.fixedTimezone,
                      timeZone: task.timeZone,
                    ),
                  ),
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              if (reorderIndex != null) const SizedBox(width: 22),
            ],
          ),
        ],
      ),
    );
    return Stack(
      children: [
        LongPressDraggable<TodoTask>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(task.title, style: const TextStyle(fontSize: 14)),
            ),
          ),
          child: card,
        ),
        if (reorderIndex != null)
          Positioned(
            right: 10,
            bottom: 10,
            child: Tooltip(
              message: '拖动排序',
              child: ReorderableDragStartListener(
                index: reorderIndex!,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

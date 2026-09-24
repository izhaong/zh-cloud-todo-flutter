import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/widgets/app_widgets.dart';
import '../task_assign_action.dart';
import '../task_detail_page.dart';
import '../task_quick_add_sheet.dart';
import '../task_view_mutation_feedback.dart';

/// M11-B3 看板视图：4 列横向滚动。
///
/// 列定义（按 priority 分组）：
///   0 = 未开始 / 1 = 进行中 / 2 = 紧急 / 3 = 归档（priority=3 + completed）
///
/// 卡片：title + due 摘要 + priority 标签 + 子任务进度
/// 点击进 TaskDetailPage；右键走「分配给」（同页 `:175`，动作见 `task_assign_action.dart`）。
///
/// 跨列拖拽**已实现**（`LongPressDraggable` + `DragTarget`，写操作走 `onTaskMove`，
/// 由 `tasks_by_list_page.dart:380` 落到共享任务 mutation），
/// 对应嘀嗒《01-任务/07-不同的视图查看任务/02-看板视图：分类管理任务.md》`:64`
/// 「你可以点击任务直接拖动到其他分组中」。
///
/// 与本文件曾有的一处矛盾已纠正：旧注释写着「拖拽改 priority 暂不实现」，与上面的代码相反。
/// 仍然缺的是**列定义该绑到清单分组**：同页 `:99`-`:101` 说分组可按主题/按进度自定义、
/// `:115` 说入口在清单的「...」-「管理分组」，而 develop 上「管理分组」的重命名/新建/
/// 删除/重排已经存在（`tasks_by_list_page.dart:1829`-`:1862`：`todo-section-create` 这个
/// Key 下的 rename/up/down/delete 分支，操作对象就是 `TodoTaskSection`）——
/// 只是本视图的列集合不读 `TodoTaskSection`，只认构造参数 `orderedColumnIds` 那一套固定列 id。
/// 默认值 `['todo','doing','urgent','archive']` 语义是 priority 0/1/2/3；调用方
/// `tasks_by_list_page.dart:338` 传的是 `boardPreference.orderedColumnIds`，
/// 用户能重排这四列的顺序，但 `board_preference_repository.dart:58`/`:226` 用
/// `BoardViewPreference.defaultColumnIds.contains` 把 id 词汇锁死在这四个 ⇒ 建不出新列。
/// ⇒ 这是纯客户端接线缺口，不需要改契约。
/// 逐面判定与证据见 `specs/044-kanban-groups/`。
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = <_KanbanColumnData>[
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
    final byId = {for (final column in columns) column.id: column};
    final ordered = <_KanbanColumnData>[
      for (final id in orderedColumnIds) ?byId.remove(id),
      ...byId.values,
    ];

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
                      collapsed: collapsedColumnIds.contains(ordered[index].id),
                      onCollapsedChanged: onColumnCollapsedChanged == null
                          ? null
                          : (collapsed) => onColumnCollapsedChanged!(
                              ordered[index].id,
                              collapsed,
                            ),
                      onMoveLeft: onColumnOrderChanged == null || index == 0
                          ? null
                          : () => _moveColumn(ordered, index, -1),
                      onMoveRight:
                          onColumnOrderChanged == null ||
                              index == ordered.length - 1
                          ? null
                          : () => _moveColumn(ordered, index, 1),
                      onCardTap: (t) => _openDetail(context, t),
                      onCardMove: onTaskMove == null
                          ? null
                          : (task) => _moveTask(
                              context,
                              task,
                              priority: ordered[index].priority,
                              completed: ordered[index].completed,
                            ),
                      onTasksReordered: onColumnTasksReordered == null
                          ? null
                          : (taskIds) => _reorderTasks(context, taskIds),
                      onAdd:
                          ordered[index].key == const ValueKey('col-todo') &&
                              listId != null
                          ? () => _quickAdd(context, ref, listId!)
                          : null,
                      onAssignCard: (task) =>
                          openTaskAssignAction(context, ref, task),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _moveColumn(
    List<_KanbanColumnData> columns,
    int index,
    int delta,
  ) {
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

  Future<void> _moveTask(
    BuildContext context,
    TodoTask task, {
    required int priority,
    required bool completed,
  }) async {
    try {
      await onTaskMove!(task, priority, completed);
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
                    onPressed: () {
                      _moveTask(
                        context,
                        task,
                        priority: priority,
                        completed: completed,
                      );
                    },
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
    String listId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskQuickAddSheet(listId: listId),
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
  });
  final String id;
  final Key key;
  final String title;
  final Color color;
  final int priority;
  final bool completed;
  final List<TodoTask> tasks;
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
    this.onAssignCard,
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

  /// 嘀嗒《02-看板视图：分类管理任务》`:175`「在看板视图右键任务，选择「分配给」即可。」
  final ValueChanged<TodoTask>? onAssignCard;

  /// 卡片右键菜单：项目只有「分配给」一项 —— 帮助页 `:175` 只写了这一条，
  /// 不自创没在原文里出现的菜单项。
  Future<void> _showCardContextMenu(
    BuildContext context,
    Offset globalPosition,
    TodoTask task,
  ) async {
    final callback = onAssignCard;
    if (callback == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          key: Key('kanban-card-assign-${task.id}'),
          value: 'assign',
          child: const Text('分配给'),
        ),
      ],
    );
    if (!context.mounted || action != 'assign') return;
    callback(task);
  }

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
              Text(
                data.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
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
                  PopupMenuItem(
                    value: 'collapse',
                    enabled: onCollapsedChanged != null,
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
                  tooltip: '新建任务',
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
                    itemBuilder: (_, i) => GestureDetector(
                      // ReorderableListView 要求**条目根 widget** 带 key，
                      // 所以 key 留在这一层，Padding 只是它的孩子。
                      key: ValueKey('kanban-task-${data.tasks[i].id}'),
                      behavior: HitTestBehavior.translucent,
                      onSecondaryTapDown: onAssignCard == null
                          ? null
                          : (details) => _showCardContextMenu(
                              context,
                              details.globalPosition,
                              data.tasks[i],
                            ),
                      child: Padding(
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

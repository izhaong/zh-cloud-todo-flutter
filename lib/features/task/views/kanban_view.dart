import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../task_detail_page.dart';
import '../task_quick_add_sheet.dart';

/// M11-B3 看板视图：4 列横向滚动。
///
/// 列定义（按 priority 分组）：
///   0 = 未开始 / 1 = 进行中 / 2 = 紧急 / 3 = 归档（priority=3 + completed）
///
/// 卡片：title + due 摘要 + priority 标签 + 子任务进度
/// 点击进 TaskDetailPage。
///
/// 注：拖拽改 priority 暂不实现（commit c2 摘要注明），保留在 TaskDetailPage
/// 内通过编辑面板调整。
class KanbanView extends ConsumerWidget {
  const KanbanView({
    super.key,
    required this.tasks,
    this.listId,
    this.onTaskSelected,
    this.onTaskMove,
  });

  /// 渲染用的任务列表（已应用 list/filter 的客户端过滤结果）。
  final List<TodoTask> tasks;
  final String? listId;
  final ValueChanged<String>? onTaskSelected;
  final Future<void> Function(TodoTask task, int priority, bool completed)?
  onTaskMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = <_KanbanColumnData>[
      _KanbanColumnData(
        key: const ValueKey('col-todo'),
        title: '未开始',
        color: Colors.blueGrey,
        priority: 0,
        completed: false,
        tasks: tasks.where((t) => t.priority == 0 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-doing'),
        title: '进行中',
        color: Colors.blue,
        priority: 1,
        completed: false,
        tasks: tasks.where((t) => t.priority == 1 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-urgent'),
        title: '紧急',
        color: Colors.deepOrange,
        priority: 2,
        completed: false,
        tasks: tasks.where((t) => t.priority == 2 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-archive'),
        title: '归档',
        color: Colors.grey,
        priority: 3,
        completed: true,
        tasks: tasks.where((t) => t.completed || t.priority >= 3).toList(),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final col in columns)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _KanbanColumn(
                data: col,
                onCardTap: (t) => _openDetail(context, t),
                onCardMove: onTaskMove == null
                    ? null
                    : (task) => _moveTask(
                        context,
                        task,
                        priority: col.priority,
                        completed: col.completed,
                      ),
                onAdd: col.key == const ValueKey('col-todo') && listId != null
                    ? () => _quickAdd(context, ref, listId!)
                    : null,
              ),
            ),
        ],
      ),
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
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('移动任务失败，请重试')));
      }
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
    required this.key,
    required this.title,
    required this.color,
    required this.priority,
    required this.completed,
    required this.tasks,
  });
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
    required this.onCardTap,
    this.onCardMove,
    this.onAdd,
  });

  final _KanbanColumnData data;
  final ValueChanged<TodoTask> onCardTap;
  final Future<void> Function(TodoTask task)? onCardMove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return SizedBox(
      width: 260,
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: Column(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data.tasks.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.mutedForeground,
                      ),
                    ),
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
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: data.tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _KanbanCard(
                          task: data.tasks[i],
                          accent: data.color,
                          onTap: () => onCardTap(data.tasks[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.task,
    required this.accent,
    required this.onTap,
  });

  final TodoTask task;
  final Color accent;
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
                  df.format(task.dueAt!),
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
            ],
          ),
        ],
      ),
    );
    return LongPressDraggable<TodoTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(task.title, style: const TextStyle(fontSize: 14)),
        ),
      ),
      child: card,
    );
  }
}

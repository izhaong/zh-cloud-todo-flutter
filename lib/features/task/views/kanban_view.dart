import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../db/app_database.dart';
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
  });

  /// 渲染用的任务列表（已应用 list/filter 的客户端过滤结果）。
  final List<TodoTask> tasks;
  final int? listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = <_KanbanColumnData>[
      _KanbanColumnData(
        key: const ValueKey('col-todo'),
        title: '未开始',
        color: Colors.blueGrey,
        tasks: tasks.where((t) => t.priority == 0 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-doing'),
        title: '进行中',
        color: Colors.blue,
        tasks: tasks.where((t) => t.priority == 1 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-urgent'),
        title: '紧急',
        color: Colors.deepOrange,
        tasks: tasks.where((t) => t.priority == 2 && !t.completed).toList(),
      ),
      _KanbanColumnData(
        key: const ValueKey('col-archive'),
        title: '归档',
        color: Colors.grey,
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
                onAdd: col.key == const ValueKey('col-todo') && listId != null
                    ? () => _quickAdd(context, ref, listId!)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  static void _openDetail(BuildContext context, TodoTask t) {
    showTaskDetailSheet(context, t.id);
  }

  static Future<void> _quickAdd(
    BuildContext context,
    WidgetRef ref,
    int listId,
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
    required this.tasks,
  });
  final Key key;
  final String title;
  final Color color;
  final List<TodoTask> tasks;
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.data,
    required this.onCardTap,
    this.onAdd,
  });

  final _KanbanColumnData data;
  final ValueChanged<TodoTask> onCardTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
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
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${data.tasks.length}',
                      style: Theme.of(context).textTheme.labelSmall,
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
              child: data.tasks.isEmpty
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
                      itemBuilder: (_, i) {
                        return _KanbanCard(
                          task: data.tasks[i],
                          accent: data.color,
                          onTap: () => onCardTap(data.tasks[i]),
                        );
                      },
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
    final df = DateFormat('MM-dd');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priorityLabel(task.priority),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const Spacer(),
                  if (task.dueAt != null)
                    Text(
                      df.format(task.dueAt!),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../state/providers.dart';
import '../task_detail_page.dart';
import 'task_row.dart';

/// 任务行 + 滑动手势（左滑完成 / 右滑更多）+ 数据组装。
///
/// 把本地仓库的 [TodoTask] + 关联标签 / 子任务数 组装成 [TaskRowData]，复用
/// 品牌化 [TaskRow]；并通过 [Dismissible] 提供两端滑动交互。
class TaskRowHost extends ConsumerWidget {
  const TaskRowHost({super.key, required this.task, this.listColor});

  final TodoTask task;
  final Color? listColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    final tagRepo = ref.watch(tagRepositoryProvider);
    final taskRepo = ref.watch(taskRepositoryProvider);

    return StreamBuilder<List<TodoTag>>(
      stream: tagRepo?.watchTagsOfTask(task.id) ?? const Stream.empty(),
      builder: (ctx, tagSnap) {
        final tagNames =
            (tagSnap.data ?? const <TodoTag>[]).map((t) => t.name).toList();

        return StreamBuilder<List<TodoTask>>(
          stream: taskRepo?.watchChildrenOf(task.id) ?? const Stream.empty(),
          builder: (ctx, childSnap) {
            final subtaskCount = childSnap.data?.length ?? 0;
            final data = TaskRowData(
              id: task.id,
              title: task.title,
              completed: task.completed,
              isPinned: task.isPinned,
              priority: task.priority,
              dueAt: task.dueAt,
              subtaskCount: subtaskCount,
              tagNames: tagNames,
              listColor: listColor,
            );

            return Dismissible(
              key: ValueKey('task-${task.id}'),
              direction: DismissDirection.horizontal,
              // 背景：左滑 = 完成
              background: _SwipeBg(
                alignment: Alignment.centerLeft,
                icon: task.completed
                    ? Icons.undo
                    : Icons.check_circle,
                label: task.completed ? '取消完成' : '完成',
                color: colors.success,
              ),
              // 二次背景：右滑 = 更多
              secondaryBackground: _SwipeBg(
                alignment: Alignment.centerRight,
                icon: Icons.more_horiz,
                label: '更多',
                color: colors.accent,
              ),
              confirmDismiss: (dir) async {
                if (taskRepo == null) return false;
                if (dir == DismissDirection.startToEnd) {
                  // 左滑 → 切换完成
                  await taskRepo.toggleComplete(task.id);
                  return false; // 不真正删除行，只切换状态
                }
                // 右滑 → 更多
                await _showMoreMenu(context, ref);
                return false;
              },
              child: TaskRow(
                data: data,
                onToggleComplete: () {
                  taskRepo?.toggleComplete(task.id);
                },
                onPin: () {
                  taskRepo?.togglePin(task.id);
                },
                onTap: () => showTaskDetailSheet(context, task.id),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showMoreMenu(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.destructive),
              title: const Text('删除'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.drive_file_move_outline,
                  color: colors.accent),
              title: const Text('移动到清单'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.alarm_add_outlined, color: colors.accent),
              title: const Text('设置提醒'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: Icon(Icons.label_outline, color: colors.accent),
              title: const Text('编辑标签'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final left = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: EdgeInsets.only(left: left ? 20 : 0, right: left ? 0 : 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            left ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (left) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            _label(),
          ] else ...[
            _label(),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }

  Widget _label() => Text(label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600));
}

import 'package:flutter/material.dart';

import '../../core/api/efficiency_api.dart';

class PomodoroTimerSection extends StatelessWidget {
  const PomodoroTimerSection({
    super.key,
    required this.timers,
    required this.loading,
    required this.canStart,
    required this.taskTitles,
    required this.habitTitles,
    required this.onRetry,
    required this.onStart,
    required this.onEdit,
    required this.onArchiveChanged,
    required this.onDelete,
    this.archivedView = false,
    this.error,
    this.actionPendingId,
    this.onCreate,
    this.onShowArchived,
  });

  final List<PomodoroTimerDto> timers;
  final bool loading;
  final bool canStart;
  final Map<int, String> taskTitles;
  final Map<int, String> habitTitles;
  final String? error;
  final int? actionPendingId;
  final VoidCallback onRetry;
  final ValueChanged<PomodoroTimerDto> onStart;
  final ValueChanged<PomodoroTimerDto> onEdit;
  final ValueChanged<PomodoroTimerDto> onArchiveChanged;
  final ValueChanged<PomodoroTimerDto> onDelete;
  final bool archivedView;
  final VoidCallback? onCreate;
  final VoidCallback? onShowArchived;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                archivedView ? '已归档计时器' : '常用专注',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (onShowArchived != null)
              TextButton(onPressed: onShowArchived, child: const Text('已归档')),
            if (onCreate != null)
              IconButton(
                tooltip: '新增常用专注计时器',
                onPressed: onCreate,
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        if (loading && timers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (timers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('暂无常用专注计时器'),
          )
        else ...[
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          for (final timer in timers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PomodoroTimerCard(
                timer: timer,
                taskTitle: timer.taskId == null
                    ? null
                    : taskTitles[timer.taskId] ?? '任务 #${timer.taskId}',
                habitTitle: timer.habitId == null
                    ? null
                    : habitTitles[timer.habitId] ?? '习惯 #${timer.habitId}',
                canStart: canStart && actionPendingId == null,
                pending: actionPendingId == timer.id,
                onStart: () => onStart(timer),
                archivedView: archivedView,
                onEdit: () => onEdit(timer),
                onArchiveChanged: () => onArchiveChanged(timer),
                onDelete: () => onDelete(timer),
              ),
            ),
        ],
        if (error != null) ...[
          Text(
            error!,
            key: const Key('pomodoro-timer-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRetry, child: const Text('重试加载计时器')),
          ),
        ],
      ],
    );
  }
}

class _PomodoroTimerCard extends StatelessWidget {
  const _PomodoroTimerCard({
    required this.timer,
    required this.canStart,
    required this.pending,
    required this.onStart,
    required this.archivedView,
    required this.onEdit,
    required this.onArchiveChanged,
    required this.onDelete,
    this.taskTitle,
    this.habitTitle,
  });

  final PomodoroTimerDto timer;
  final bool canStart;
  final bool pending;
  final VoidCallback onStart;
  final bool archivedView;
  final VoidCallback onEdit;
  final VoidCallback onArchiveChanged;
  final VoidCallback onDelete;
  final String? taskTitle;
  final String? habitTitle;

  @override
  Widget build(BuildContext context) {
    final durationLabel = timer.mode == 'FREE'
        ? '正计时'
        : '${timer.focusMinutes ?? 0} 分钟';
    final associationLabel = taskTitle != null
        ? '关联任务：$taskTitle'
        : habitTitle != null
        ? '关联习惯：$habitTitle'
        : '无关联';
    final startLabel = '开始${timer.name}，$durationLabel';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timer.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(durationLabel),
                  Text(associationLabel, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (pending)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (!archivedView)
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                label: startLabel,
                child: IconButton.filledTonal(
                  onPressed: canStart ? onStart : null,
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            PopupMenuButton<String>(
              key: Key('pomodoro-timer-menu-${timer.id}'),
              tooltip: '管理${timer.name}',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'archive':
                    onArchiveChanged();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!archivedView)
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(archivedView ? '恢复' : '归档'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

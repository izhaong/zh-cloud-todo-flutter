import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';
import '../view_mode.dart';

/// M11-B3 视图切换 5 tab。
///
/// - 5 个 [TaskViewMode] 等宽分布
/// - 选中态高亮 + 当前模式文本加粗
/// - 移动端窄屏用 [shortLabel]，长于 5 字保留全称
/// - 切换后通过 [SyncChangeQueue] 写入 `view_preference` 同步实体（本地 + 跨端）
class TaskViewModeTabs extends ConsumerStatefulWidget {
  const TaskViewModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TaskViewMode mode;
  final ValueChanged<TaskViewMode> onChanged;

  @override
  ConsumerState<TaskViewModeTabs> createState() => _TaskViewModeTabsState();
}

class _TaskViewModeTabsState extends ConsumerState<TaskViewModeTabs> {
  /// 写入视图偏好到 view_preference 同步实体（sourceType='task_view'）。
  void _persist(TaskViewMode mode) {
    final queue = ref.read(syncChangeQueueProvider);
    if (queue == null) return;
    queue.enqueue(
      entity: 'view_preference',
      op: 'upsert',
      payload: {
        'sourceType': 'task_view',
        'sourceKey': 'tasks_by_list',
        'viewType': mode.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (final m in TaskViewMode.values)
            Expanded(
              child: _TabButton(
                label: m.label,
                selected: m == widget.mode,
                onTap: () {
                  widget.onChanged(m);
                  _persist(m);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

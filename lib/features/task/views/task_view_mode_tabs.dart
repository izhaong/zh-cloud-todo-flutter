import 'package:flutter/material.dart';

import '../view_mode.dart';

/// M11-B3 视图切换 5 tab。
///
/// - 5 个 [TaskViewMode] 等宽分布
/// - 选中态高亮 + 当前模式文本加粗
/// - 移动端窄屏用 [shortLabel]，长于 5 字保留全称
class TaskViewModeTabs extends StatelessWidget {
  const TaskViewModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TaskViewMode mode;
  final ValueChanged<TaskViewMode> onChanged;

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
                selected: m == mode,
                onTap: () => onChanged(m),
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

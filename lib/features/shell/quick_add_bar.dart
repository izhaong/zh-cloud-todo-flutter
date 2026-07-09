import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 顶部嵌入式快速添加条（QuickAddBar）。
///
/// 嵌入式输入框 + 日期 / 优先级 / 标签快捷图标，对齐 TickTick 桌面端
/// 顶部"快速创建任务"体验。提交逻辑由上层 [onSubmit] 提供。
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.add, color: colors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              cursorColor: colors.accent,
              decoration: InputDecoration(
                hintText: '添加任务，回车创建',
                hintStyle: TextStyle(color: colors.mutedForeground),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
              style: TextStyle(fontSize: 13.5, color: colors.foreground),
            ),
          ),
          _ToolIcon(
            icon: Icons.calendar_today_outlined,
            tooltip: '日期',
            colors: colors,
            onTap: () {},
          ),
          _ToolIcon(
            icon: Icons.flag_outlined,
            tooltip: '优先级',
            colors: colors,
            onTap: () {},
          ),
          _ToolIcon(
            icon: Icons.label_outline,
            tooltip: '标签',
            colors: colors,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: colors.mutedForeground),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

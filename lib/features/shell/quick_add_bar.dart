import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/todo_layout_tokens.dart';

typedef QuickAddSubmitCallback = FutureOr<void> Function(String title);

/// 顶部嵌入式快速添加条（QuickAddBar）。
///
/// 嵌入式输入框 + 日期 / 优先级 / 标签快捷图标。提交逻辑由上层 [onSubmit]
/// 提供，组件本身不决定任务落入哪个清单。
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({super.key, required this.onSubmit});

  final QuickAddSubmitCallback onSubmit;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

/// Mobile keeps one low-noise add entry and expands it only when requested.
class MobileQuickAddButton extends StatelessWidget {
  const MobileQuickAddButton({super.key, required this.onSubmit});

  final QuickAddSubmitCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      key: const Key('todo-mobile-add'),
      heroTag: 'todo-mobile-add',
      tooltip: '添加任务',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _MobileQuickAddSheet(onSubmit: onSubmit),
      ),
      child: const Icon(Icons.add),
    );
  }
}

class _MobileQuickAddSheet extends StatefulWidget {
  const _MobileQuickAddSheet({required this.onSubmit});

  final QuickAddSubmitCallback onSubmit;

  @override
  State<_MobileQuickAddSheet> createState() => _MobileQuickAddSheetState();
}

class _MobileQuickAddSheetState extends State<_MobileQuickAddSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(title);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      rethrow;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('todo-mobile-add-field'),
              controller: _controller,
              autofocus: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '任务标题',
                hintText: '输入后按回车创建',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '创建任务',
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _ctrl = TextEditingController();
  bool _submitting = false;
  int _visibleLines = 1;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_syncVisibleLines);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncVisibleLines);
    _ctrl.dispose();
    super.dispose();
  }

  void _syncVisibleLines() {
    final lines = _ctrl.text.split(RegExp(r'\r?\n')).length.clamp(1, 3);
    if (lines == _visibleLines) return;
    setState(() => _visibleLines = lines);
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(text);
      if (mounted) _ctrl.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return SizedBox(
      key: const Key('todo-quick-add'),
      height: TodoLayoutTokens.quickAddHeight * _visibleLines,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TodoLayoutTokens.mainHorizontalInset,
          ),
          child: Row(
            children: [
              Icon(Icons.add, color: colors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  enabled: !_submitting,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    hintText: '添加任务，回车创建',
                    hintStyle: TextStyle(color: colors.mutedForeground),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
        ),
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
      icon: Icon(icon, size: 18, color: colors.mutedForeground),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

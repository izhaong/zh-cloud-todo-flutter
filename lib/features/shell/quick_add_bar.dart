import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/todo_layout_tokens.dart';

class QuickAddRequest {
  const QuickAddRequest({
    required this.input,
    this.dueAtOverride,
    this.priorityOverride,
    this.tagIds = const [],
    this.useNlpDate = true,
  });

  final String input;
  final DateTime? dueAtOverride;
  final int? priorityOverride;
  final List<String> tagIds;
  final bool useNlpDate;
}

class QuickAddTagOption {
  const QuickAddTagOption({required this.id, required this.name});

  final String id;
  final String name;
}

typedef QuickAddSubmitCallback =
    FutureOr<void> Function(QuickAddRequest request);

/// 顶部嵌入式快速添加条（QuickAddBar）。
///
/// 嵌入式输入框 + 日期 / 优先级 / 标签快捷图标。提交逻辑由上层 [onSubmit]
/// 提供，组件本身不决定任务落入哪个清单。
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({
    super.key,
    required this.onSubmit,
    this.tagOptions = const [],
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

/// Mobile keeps one low-noise add entry and expands it only when requested.
class MobileQuickAddButton extends StatelessWidget {
  const MobileQuickAddButton({
    super.key,
    required this.onSubmit,
    this.tagOptions = const [],
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'todo_mobile_quick_add',
      button: true,
      child: FloatingActionButton.small(
        key: const Key('todo-mobile-add'),
        heroTag: 'todo-mobile-add',
        tooltip: '添加任务',
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              _MobileQuickAddSheet(onSubmit: onSubmit, tagOptions: tagOptions),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MobileQuickAddSheet extends StatefulWidget {
  const _MobileQuickAddSheet({
    required this.onSubmit,
    required this.tagOptions,
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;

  @override
  State<_MobileQuickAddSheet> createState() => _MobileQuickAddSheetState();
}

class _MobileQuickAddSheetState extends State<_MobileQuickAddSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  DateTime? _dueAtOverride;
  int? _priorityOverride;
  final Set<String> _tagIds = {};

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
      await widget.onSubmit(
        QuickAddRequest(
          input: title,
          dueAtOverride: _dueAtOverride,
          priorityOverride: _priorityOverride,
          tagIds: _tagIds.toList(growable: false),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
      rethrow;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAtOverride ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dueAtOverride = picked);
    }
  }

  Future<void> _pickTags() async {
    if (widget.tagOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在标签页创建标签')));
      return;
    }
    final selected = Set<String>.from(_tagIds);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final tag in widget.tagOptions)
                CheckboxListTile(
                  value: selected.contains(tag.id),
                  title: Text(tag.name),
                  onChanged: (checked) => setSheetState(() {
                    if (checked ?? false) {
                      selected.add(tag.id);
                    } else {
                      selected.remove(tag.id);
                    }
                  }),
                ),
              ListTile(
                title: const Text('完成'),
                trailing: const Icon(Icons.check),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _tagIds
          ..clear()
          ..addAll(selected);
      });
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  identifier: 'todo_mobile_quick_add_title',
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
              ),
              const SizedBox(width: 8),
              Semantics(
                identifier: 'todo_mobile_quick_add_submit',
                button: true,
                child: IconButton.filled(
                  tooltip: '创建任务',
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _submitting ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_dueAtOverride == null ? '日期' : '已选日期'),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _priorityOverride ?? 0,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('无优先级')),
                  DropdownMenuItem(value: 1, child: Text('低优先级')),
                  DropdownMenuItem(value: 2, child: Text('中优先级')),
                  DropdownMenuItem(value: 3, child: Text('高优先级')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _priorityOverride = value ?? 0),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _submitting ? null : _pickTags,
                icon: const Icon(Icons.label_outline, size: 18),
                label: Text(_tagIds.isEmpty ? '标签' : '标签 ${_tagIds.length}'),
              ),
            ],
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
  DateTime? _dueAtOverride;
  int? _priorityOverride;
  bool _useNlpDate = true;
  final Set<String> _tagIds = {};

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
      await widget.onSubmit(
        QuickAddRequest(
          input: text,
          dueAtOverride: _dueAtOverride,
          priorityOverride: _priorityOverride,
          tagIds: _tagIds.toList(growable: false),
          useNlpDate: _useNlpDate,
        ),
      );
      if (mounted) {
        setState(() {
          _ctrl.clear();
          _dueAtOverride = null;
          _priorityOverride = null;
          _useNlpDate = true;
          _tagIds.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAtOverride ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueAtOverride = picked;
      _useNlpDate = false;
    });
  }

  Future<void> _pickPriority() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [(0, '无'), (1, '低'), (2, '中'), (3, '高')])
              ListTile(
                title: Text('${entry.$2}优先级'),
                trailing: _priorityOverride == entry.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() => _priorityOverride = value);
    }
  }

  Future<void> _pickTags() async {
    if (widget.tagOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在标签页创建标签')));
      return;
    }
    final selected = Set<String>.from(_tagIds);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('本次添加的标签')),
              for (final tag in widget.tagOptions)
                CheckboxListTile(
                  value: selected.contains(tag.id),
                  title: Text(tag.name),
                  onChanged: (checked) {
                    setSheetState(() {
                      if (checked ?? false) {
                        selected.add(tag.id);
                      } else {
                        selected.remove(tag.id);
                      }
                    });
                  },
                ),
              ListTile(
                title: const Text('完成'),
                trailing: const Icon(Icons.check),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _tagIds
          ..clear()
          ..addAll(selected);
      });
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
                  key: const Key('todo-quick-add-input'),
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
                onTap: _pickDueDate,
                onLongPress: () => setState(() {
                  _dueAtOverride = null;
                  _useNlpDate = false;
                }),
              ),
              _ToolIcon(
                icon: Icons.flag_outlined,
                tooltip: '优先级',
                colors: colors,
                onTap: _pickPriority,
              ),
              _ToolIcon(
                icon: Icons.label_outline,
                tooltip: '标签',
                colors: colors,
                onTap: _pickTags,
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
    this.onLongPress,
  });

  final IconData icon;
  final String tooltip;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 18, color: colors.mutedForeground),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}

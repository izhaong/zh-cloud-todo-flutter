import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../tag/hash_tag_input.dart';
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

/// 「已有同名就用、没有就建」，返回标签 id（顺序与入参一致）。
typedef QuickAddTagIdsEnsurer =
    Future<List<String>> Function(List<String> names);

/// 「#」这条路径的公共部分：把输入剥成标题 + 标签名，并解析/新建标签。
///
/// 返回 `null` 表示这次点击**不提交**，且 `abortReason` 会带上必须看得见的理由
/// （Issue #292 的同一口径：不许静默早退）。
///
/// 没接线 [ensurer] 时整段按普通文字处理：`TaskQuickAddSheet`、时间线拖拽这些
/// 没有标签入口的创建路径不该被顺手改掉语义（spec.md 取舍 4）。
Future<QuickAddRequest?> _buildHashTagRequest({
  required String raw,
  required List<QuickAddTagOption> tagOptions,
  required Set<String> pickedTagIds,
  required QuickAddTagIdsEnsurer? ensurer,
  required DateTime? dueAtOverride,
  required int? priorityOverride,
  required bool useNlpDate,
  required void Function(String message) onAbort,
}) async {
  if (raw.isEmpty) {
    onAbort('请输入任务标题');
    return null;
  }
  if (ensurer == null) {
    return QuickAddRequest(
      input: raw,
      dueAtOverride: dueAtOverride,
      priorityOverride: priorityOverride,
      tagIds: pickedTagIds.toList(growable: false),
      useNlpDate: useNlpDate,
    );
  }
  final draft = parseHashTagInput(raw);
  if (draft.title.isEmpty) {
    // 「#周会」整段都是标签 ⇒ 没有标题。这时候连标签都不建，否则留下一条挂在空气上的标签。
    onAbort('请输入任务标题');
    return null;
  }
  final pickedNames = tagOptions
      .where((option) => pickedTagIds.contains(option.id))
      .map((option) => option.name)
      .toSet();
  final unresolved = draft.tagNames
      .where((name) => !pickedNames.contains(name))
      .toList(growable: false);
  final tagIds = <String>{...pickedTagIds};
  if (unresolved.isNotEmpty) {
    try {
      tagIds.addAll(await ensurer(unresolved));
    } on Object catch (error) {
      onAbort(error is StateError ? error.message.toString() : '标签创建失败，请重试');
      return null;
    }
  }
  return QuickAddRequest(
    input: draft.title,
    dueAtOverride: dueAtOverride,
    priorityOverride: priorityOverride,
    tagIds: tagIds.toList(growable: false),
    useNlpDate: useNlpDate,
  );
}

List<String> _hashTagNamesOf(String text, QuickAddTagIdsEnsurer? ensurer) =>
    ensurer == null ? const [] : parseHashTagInput(text).tagNames;

/// 标签弹层（嘀嗒《…04-用标签管理任务.md》:46 方式一「选择添加已有标签**或创建新标签**」）。
///
/// develop 上这里只能勾选已有标签，标签为空时只回一句「请先在标签页创建标签」⇒ 方式一少一半。
/// 现在表内直接给一行「新建标签」；没有 [ensurer]（未登录等）时才退回那句提示。
Future<void> _openTagPickerSheet({
  required BuildContext context,
  required List<QuickAddTagOption> tagOptions,
  required Set<String> initialSelected,
  required QuickAddTagIdsEnsurer? ensurer,
  required void Function(Set<String> result) onClosed,
}) async {
  if (ensurer == null && tagOptions.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先在标签页创建标签')));
    return;
  }
  final result = await showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    builder: (context) => _TagPickerSheet(
      tagOptions: tagOptions,
      initialSelected: initialSelected,
      ensureTagIds: ensurer,
    ),
  );
  if (result != null) onClosed(result);
}

class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({
    required this.tagOptions,
    required this.initialSelected,
    required this.ensureTagIds,
  });

  final List<QuickAddTagOption> tagOptions;
  final Set<String> initialSelected;
  final QuickAddTagIdsEnsurer? ensureTagIds;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  late final Set<String> _selected = {...widget.initialSelected};
  final List<QuickAddTagOption> _created = [];
  bool _creatingNew = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmNewTag() async {
    // 同步闸门：`onPressed: _busy ? null : …` 的禁用要等下一帧才生效，
    // 连点两次会真的调两次 ensurer ⇒ 库里长出两条同名标签。
    if (_busy) return;
    final ensurer = widget.ensureTagIds;
    if (ensurer == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入标签名');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = await ensurer([name]);
      if (!mounted) return;
      // 先卸掉焦点再收起输入行：在同一帧里既移除带焦点的 TextField 又重建路由子树，
      // 会撞上 `_FocusInheritedScope` 的 _dependents.isEmpty 断言。
      FocusScope.of(context).unfocus();
      setState(() {
        _busy = false;
        for (final id in ids) {
          _selected.add(id);
          _created.add(QuickAddTagOption(id: id, name: name));
        }
        _creatingNew = false;
        _nameCtrl.clear();
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is StateError ? error.message.toString() : '标签创建失败，请重试';
      });
    }
  }

  void _toggle(String tagId, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(tagId);
      } else {
        _selected.remove(tagId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final newTagRow = ListTile(
      key: const Key('todo-quick-add-create-tag'),
      leading: const Icon(Icons.add),
      title: const Text('新建标签'),
      onTap: () => setState(() {
        _creatingNew = true;
        _error = null;
      }),
    );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('本次添加的标签')),
          for (final tag in widget.tagOptions)
            CheckboxListTile(
              value: _selected.contains(tag.id),
              title: Text(tag.name),
              onChanged: (checked) => _toggle(tag.id, checked ?? false),
            ),
          if (_created.isNotEmpty)
            KeyedSubtree(
              key: const Key('todo-quick-add-created-tag-row'),
              child: Column(
                children: [
                  for (final tag in _created)
                    CheckboxListTile(
                      key: Key('todo-quick-add-created-tag-${tag.id}'),
                      value: _selected.contains(tag.id),
                      title: Text(tag.name),
                      onChanged: (checked) => _toggle(tag.id, checked ?? false),
                    ),
                ],
              ),
            ),
          if (widget.ensureTagIds != null)
            if (!_creatingNew)
              newTagRow
            else
              Padding(
                key: const Key('todo-quick-add-create-tag-editor'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('todo-quick-add-create-tag-field'),
                        controller: _nameCtrl,
                        autofocus: true,
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _confirmNewTag(),
                        decoration: const InputDecoration(
                          labelText: '标签名',
                          isDense: true,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('todo-quick-add-create-tag-confirm'),
                      onPressed: _confirmNewTag,
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!),
            ),
          ListTile(
            title: const Text('完成'),
            trailing: const Icon(Icons.check),
            onTap: () => Navigator.pop(context, _selected),
          ),
        ],
      ),
    );
  }
}

/// 顶部嵌入式快速添加条（QuickAddBar）。
///
/// 嵌入式输入框 + 日期 / 优先级 / 标签快捷图标。提交逻辑由上层 [onSubmit]
/// 提供，组件本身不决定任务落入哪个清单。
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({
    super.key,
    required this.onSubmit,
    this.tagOptions = const [],
    this.ensureTagIds,
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;
  final QuickAddTagIdsEnsurer? ensureTagIds;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

/// Mobile keeps one low-noise add entry and expands it only when requested.
class MobileQuickAddButton extends StatelessWidget {
  const MobileQuickAddButton({
    super.key,
    required this.onSubmit,
    this.tagOptions = const [],
    this.ensureTagIds,
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;
  final QuickAddTagIdsEnsurer? ensureTagIds;

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
          builder: (_) => _MobileQuickAddSheet(
            onSubmit: onSubmit,
            tagOptions: tagOptions,
            ensureTagIds: ensureTagIds,
          ),
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
    this.ensureTagIds,
  });

  final QuickAddSubmitCallback onSubmit;
  final List<QuickAddTagOption> tagOptions;
  final QuickAddTagIdsEnsurer? ensureTagIds;

  @override
  State<_MobileQuickAddSheet> createState() => _MobileQuickAddSheetState();
}

class _MobileQuickAddSheetState extends State<_MobileQuickAddSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  DateTime? _dueAtOverride;
  int? _priorityOverride;
  final Set<String> _tagIds = {};
  List<String> _pendingTagNames = const [];
  String? _fieldError;

  int get _tagCount => _tagIds.length + _pendingTagNames.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    var created = false;
    try {
      final request = await _buildHashTagRequest(
        raw: _controller.text.trim(),
        tagOptions: widget.tagOptions,
        pickedTagIds: _tagIds,
        ensurer: widget.ensureTagIds,
        dueAtOverride: _dueAtOverride,
        priorityOverride: _priorityOverride,
        useNlpDate: true,
        onAbort: (message) => setState(() => _fieldError = message),
      );
      if (request == null) return;
      await widget.onSubmit(request);
      created = true;
    } catch (_) {
      rethrow;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted || !created) return;
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
    await _openTagPickerSheet(
      context: context,
      tagOptions: widget.tagOptions,
      initialSelected: _tagIds,
      ensurer: widget.ensureTagIds,
      onClosed: (selected) {
        if (!mounted) return;
        setState(() {
          _tagIds
            ..clear()
            ..addAll(selected);
        });
      },
    );
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
                    onChanged: (_) => setState(() {
                      _pendingTagNames = _hashTagNamesOf(
                        _controller.text,
                        widget.ensureTagIds,
                      );
                      if (_fieldError != null) _fieldError = null;
                    }),
                    decoration: InputDecoration(
                      labelText: '任务标题',
                      hintText: '输入后按回车创建',
                      errorText: _fieldError,
                      border: const OutlineInputBorder(),
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
          // Row + Spacer 在 320px 上放 1.3 倍字号会溢出（实测 31px），而「标签 N」的计数
          // 还要往右端加长 ⇒ 改成会换行的 Wrap：宁可两行也不把入口挤到点不到。
          Wrap(
            spacing: 8,
            runSpacing: 4,
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
              Semantics(
                identifier: 'todo_mobile_quick_add_tags',
                button: true,
                child: TextButton.icon(
                  onPressed: _submitting ? null : _pickTags,
                  icon: const Icon(Icons.label_outline, size: 18),
                  label: Text(_tagCount == 0 ? '标签' : '标签 $_tagCount'),
                ),
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
  List<String> _pendingTagNames = const [];

  int get _tagCount => _tagIds.length + _pendingTagNames.length;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_syncVisibleLines);
    _ctrl.addListener(_syncHashTags);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_syncVisibleLines);
    _ctrl.removeListener(_syncHashTags);
    _ctrl.dispose();
    super.dispose();
  }

  void _syncHashTags() {
    final next = _hashTagNamesOf(_ctrl.text, widget.ensureTagIds);
    if (next.length == _pendingTagNames.length &&
        List.generate(
          next.length,
          (i) => next[i] == _pendingTagNames[i],
        ).every((same) => same)) {
      return;
    }
    setState(() => _pendingTagNames = next);
  }

  void _syncVisibleLines() {
    final lines = _ctrl.text.split(RegExp(r'\r?\n')).length.clamp(1, 3);
    if (lines == _visibleLines) return;
    setState(() => _visibleLines = lines);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    var created = false;
    try {
      final request = await _buildHashTagRequest(
        raw: _ctrl.text.trim(),
        tagOptions: widget.tagOptions,
        pickedTagIds: _tagIds,
        ensurer: widget.ensureTagIds,
        dueAtOverride: _dueAtOverride,
        priorityOverride: _priorityOverride,
        useNlpDate: _useNlpDate,
        onAbort: _report,
      );
      if (request == null) return;
      await widget.onSubmit(request);
      created = true;
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
    if (created && mounted) setState(() => _pendingTagNames = const []);
  }

  /// 桌面输入条是嵌在工作区里的固定 44px 行，`errorText` 会把行撑破
  /// ⇒ 这条路径的可见反馈走 SnackBar（措辞与弹层里的 `errorText` 一致）。
  void _report(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    await _openTagPickerSheet(
      context: context,
      tagOptions: widget.tagOptions,
      initialSelected: _tagIds,
      ensurer: widget.ensureTagIds,
      onClosed: (selected) {
        if (!mounted) return;
        setState(() {
          _tagIds
            ..clear()
            ..addAll(selected);
        });
      },
    );
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
              if (_tagCount > 0)
                // 桌面原来只有 tooltip 里的「标签」，而 tooltip 进不了读屏
                // （实测见 task_quick_add_sheet.dart:203）⇒ 计数必须是看得见的文字。
                Text('标签 $_tagCount', style: TextStyle(fontSize: 12)),
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

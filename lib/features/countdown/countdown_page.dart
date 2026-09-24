import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../state/efficiency_providers.dart';

/// 嘀嗒的三档样式；取值与服务端 `AppTodoCountdownBaseVO.style` 注释一致。
const Map<int, String> _countdownStyles = {1: '默认', 2: '翻页', 3: '圆环'};

/// M11-B4 倒数日列表 + 新建；024 补编辑、删除与样式呈现。
class CountdownPage extends ConsumerStatefulWidget {
  const CountdownPage({super.key});

  @override
  ConsumerState<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends ConsumerState<CountdownPage> {
  /// 模态框关闭后列表入口即可再点；并发写会让后返回的旧列表响应覆盖新结果，
  /// 因此一次只放行一个写请求。
  bool _writePending = false;

  Future<void> _runWrite(Future<void> Function() write) async {
    if (_writePending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _writePending = true);
    try {
      await write();
      ref.invalidate(countdownsProvider);
    } on Object catch (error) {
      // 失败时不刷新列表，原数据仍在原位并可重试。
      // 页面已卸载时不得再弹：context 脱离树后 showSnackBar 会抛，
      // 且该抛点位于 catch 内，没人再兜住它。
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _writePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(countdownsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('倒数日'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _writePending ? null : () => _showEditor(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无倒数日'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];
              final theme = Theme.of(context);
              // ListTile 会把 trailing 合并进整行的语义节点，两个动作就不再独立可读，
              // 因此自建行布局让编辑与删除各自保留自己的语义节点。
              return InkWell(
                key: Key('countdown-row-${c.id}'),
                onTap: _writePending ? null : () => _showEditor(existing: c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _CountdownBadge(countdown: c),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _subtitle(c),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        container: true,
                        button: true,
                        label: '编辑 ${c.title}',
                        onTap: _writePending
                            ? null
                            : () => _showEditor(existing: c),
                        child: ExcludeSemantics(
                          child: IconButton(
                            key: Key('countdown-edit-${c.id}'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _writePending
                                ? null
                                : () => _showEditor(existing: c),
                          ),
                        ),
                      ),
                      Semantics(
                        container: true,
                        button: true,
                        label: '删除 ${c.title}',
                        onTap: _writePending ? null : () => _confirmDelete(c),
                        child: ExcludeSemantics(
                          child: IconButton(
                            key: Key('countdown-delete-${c.id}'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _writePending
                                ? null
                                : () => _confirmDelete(c),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _subtitle(CountdownDto c) {
    if (!c.isCountUp) return '还有 ${c.daysRemaining} 天';
    // 嘀嗒的 showAge 即“显示已过天数”；关闭时过期项只显示目标日期。
    if (!c.showAge) {
      final d = c.targetDate;
      return '${d.year}-${d.month}-${d.day}';
    }
    return '已过 ${-c.daysRemaining} 天';
  }

  Future<void> _confirmDelete(CountdownDto countdown) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${countdown.title}」？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('countdown-delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runWrite(() => ref.read(countdownApiProvider).delete(countdown.id));
  }

  Future<void> _showEditor({CountdownDto? existing}) async {
    final draft = existing == null
        ? _CountdownDraft(
            title: '',
            targetDate: DateTime.now().add(const Duration(days: 30)),
          )
        : _CountdownDraft(
            title: existing.title,
            targetDate: existing.targetDate,
            style: existing.style,
            showAge: existing.showAge,
          );
    final saved = await showDialog<_CountdownDraft>(
      context: context,
      builder: (ctx) =>
          _CountdownEditor(initial: draft, isNew: existing == null),
    );
    if (saved == null || !mounted) return;
    final api = ref.read(countdownApiProvider);
    if (existing == null) {
      await _runWrite(
        () => api.create(
          title: saved.title,
          targetDate: saved.targetDate,
          style: saved.style,
          showAge: saved.showAge,
        ),
      );
    } else {
      final id = existing.id;
      await _runWrite(
        () => api.update(
          id: id,
          title: saved.title,
          targetDate: saved.targetDate,
          style: saved.style,
          showAge: saved.showAge,
        ),
      );
    }
  }
}

class _CountdownDraft {
  const _CountdownDraft({
    required this.title,
    required this.targetDate,
    this.style = 1,
    this.showAge = false,
  });

  final String title;
  final DateTime targetDate;
  final int style;
  final bool showAge;

  _CountdownDraft copyWith({
    String? title,
    DateTime? targetDate,
    int? style,
    bool? showAge,
  }) {
    return _CountdownDraft(
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      style: style ?? this.style,
      showAge: showAge ?? this.showAge,
    );
  }
}

class _CountdownEditor extends StatefulWidget {
  const _CountdownEditor({required this.initial, required this.isNew});

  final _CountdownDraft initial;
  final bool isNew;

  @override
  State<_CountdownEditor> createState() => _CountdownEditorState();
}

class _CountdownEditorState extends State<_CountdownEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title,
  );
  late _CountdownDraft _draft = widget.initial;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.targetDate,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(targetDate: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft.targetDate;
    return AlertDialog(
      title: Text(widget.isNew ? '新建倒数日' : '编辑倒数日'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('countdown-title-field'),
              controller: _title,
              decoration: const InputDecoration(labelText: '标题'),
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(title: value)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('目标日期: '),
                TextButton(
                  onPressed: _pickDate,
                  child: Text('${d.year}-${d.month}-${d.day}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('样式', style: Theme.of(context).textTheme.labelMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in _countdownStyles.entries)
                  ChoiceChip(
                    key: Key('countdown-style-${entry.key}'),
                    label: Text(entry.value),
                    selected: _draft.style == entry.key,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(style: entry.key),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('countdown-show-age'),
              contentPadding: EdgeInsets.zero,
              title: const Text('显示已过天数'),
              value: _draft.showAge,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(showAge: value)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('countdown-editor-save'),
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, _draft.copyWith(title: title));
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({required this.countdown});

  final CountdownDto countdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = countdown.daysRemaining.abs().toString();
    return switch (countdown.style) {
      // 翻页：带中缝的日历牌，显示天数。
      2 => Container(
        key: ValueKey('countdown-badge-${countdown.id}'),
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Text(days, style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
      // 圆环：描边圆环内嵌天数。
      3 => Container(
        key: ValueKey('countdown-badge-${countdown.id}'),
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.primary, width: 3),
        ),
        child: Text(days, style: TextStyle(color: scheme.primary)),
      ),
      _ => CircleAvatar(
        key: ValueKey('countdown-badge-${countdown.id}'),
        backgroundColor: scheme.primary,
        child: Text(
          countdown.isCountUp ? '正' : '倒',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    };
  }
}

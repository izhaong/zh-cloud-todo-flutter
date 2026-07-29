import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/nlp_date.dart';
import '../../state/providers.dart';
import '../tag/tag_color.dart';

/// M11-B2 任务快速添加 bottom sheet。
class TaskQuickAddSheet extends ConsumerStatefulWidget {
  const TaskQuickAddSheet({super.key, required this.listId, this.parentTaskId});

  final String listId;
  final String? parentTaskId;

  @override
  ConsumerState<TaskQuickAddSheet> createState() => _TaskQuickAddSheetState();
}

class _TaskQuickAddSheetState extends ConsumerState<TaskQuickAddSheet> {
  final _titleCtrl = TextEditingController();
  int? _priorityOverride;
  DateTime? _nlpResolvedDueAt;

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_maybeResolveDate);
  }

  @override
  void dispose() {
    _titleCtrl
      ..removeListener(_maybeResolveDate)
      ..dispose();
    super.dispose();
  }

  void _maybeResolveDate() {
    final resolved = NlpDateParser().parse(_titleCtrl.text);
    if (resolved?.date != _nlpResolvedDueAt) {
      setState(() => _nlpResolvedDueAt = resolved?.date);
    }
  }

  Future<void> _save() async {
    final text = _titleCtrl.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    try {
      final defaults = await ref
          .read(taskCaptureDefaultsRepositoryProvider)
          ?.get();
      await repo.create(
        listId: widget.listId,
        parentTaskId: widget.parentTaskId,
        title: text,
        priority: _priorityOverride ?? defaults?.defaultPriority ?? 0,
        dueAt: _nlpResolvedDueAt,
      );
      if (mounted) Navigator.pop(context);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存任务失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = _priorityOverride ?? 0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.parentTaskId == null ? '新建任务' : '新建子任务',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(priority),
              initialValue: priority,
              decoration: const InputDecoration(
                labelText: '优先级',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('无')),
                DropdownMenuItem(value: 1, child: Text('低')),
                DropdownMenuItem(value: 2, child: Text('中')),
                DropdownMenuItem(value: 3, child: Text('高')),
              ],
              onChanged: (v) => setState(() => _priorityOverride = v ?? 0),
            ),
            const SizedBox(height: 16),
            if (_nlpResolvedDueAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '已识别截止时间：${_nlpResolvedDueAt!.toLocal()}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 优先级辅助：把 0/1/2/3 翻译成 UI 文案 + 颜色。
String priorityLabel(int p) {
  switch (p) {
    case 3:
      return '高';
    case 2:
      return '中';
    case 1:
      return '低';
    default:
      return '无';
  }
}

Color priorityColor(int p) {
  switch (p) {
    case 3:
      return Colors.red;
    case 2:
      return Colors.orange;
    case 1:
      return Colors.green;
    default:
      return Colors.grey;
  }
}

/// 工具函数：把 hex 字符串标签颜色包装成可用 Color（re-export）。
Color tagColorFromHex(String? hex) => parseHexColor(hex);

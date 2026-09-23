import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/nlp_date.dart';
import '../../state/providers.dart';
import '../../state/repositories/template_repository.dart';
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
  bool _applyingTemplate = false;

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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 嘀嗒《如何使用任务模板？》移动端：「点击任务输入弹窗下方的「...」按钮，选择「模板」」。
  Future<void> _addFromTemplate() async {
    final templates = ref.read(templateRepositoryProvider);
    if (templates == null) {
      _toast('请先登录');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _QuickAddTemplatePicker(
        templates: templates,
        onPick: (template) async {
          if (_applyingTemplate) return;
          _applyingTemplate = true;
          final repo = ref.read(taskRepositoryProvider);
          final seed = templates.taskSeed(template);
          String message;
          try {
            if (repo == null) {
              message = '请先登录';
            } else {
              await repo.create(
                listId: widget.listId,
                parentTaskId: widget.parentTaskId,
                title: seed.title,
                description: seed.description,
                priority: seed.priority,
              );
              message = '已应用模板“${template.name}”';
            }
          } on StateError catch (error) {
            message = error.message.toString();
          } catch (_) {
            message = '保存任务失败，请稍后重试';
          }
          _applyingTemplate = false;
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          _toast(message);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = _priorityOverride ?? 0;
    return Padding(
      key: const Key('todo-quick-add-sheet'),
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
              children: [
                PopupMenuButton<String>(
                  key: const Key('todo-quick-add-more'),
                  tooltip: '更多',
                  onSelected: (value) {
                    if (value == 'template') _addFromTemplate();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'template', child: Text('模板')),
                  ],
                  child: const Icon(Icons.more_horiz),
                ),
                const Spacer(),
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

/// 快速添加弹窗「模板」项打开的本地模板选择层。
class _QuickAddTemplatePicker extends StatelessWidget {
  const _QuickAddTemplatePicker({
    required this.templates,
    required this.onPick,
  });

  final TemplateRepository templates;
  final void Function(TodoTemplate template) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const Key('todo-quick-add-template-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: StreamBuilder<List<TodoTemplate>>(
          stream: templates.watchAll(),
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <TodoTemplate>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模板', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (list.isEmpty) const Text('暂无本地模板'),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final template in list)
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      template.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      template.status == 'synced'
                                          ? '已同步'
                                          : '等待同步',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => onPick(template),
                                child: const Text('添加'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

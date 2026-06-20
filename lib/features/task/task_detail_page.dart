import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';
import 'task_quick_add_sheet.dart';

/// M11-B2 任务详情页：
/// - 标题 / 描述 / 优先级 / 起止 / due / list / folder / 标签 chips
/// - 子任务（多级，通过 parentTaskId）
/// - 勾选 / 取消勾选（乐观更新 + sync_queue）
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  TodoTask? _task;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  int _priority = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _desc = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final t = await ref.read(taskRepositoryProvider).getById(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = t;
      _title.text = t?.title ?? '';
      _desc.text = t?.description ?? '';
      _priority = t?.priority ?? 0;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _task;
    if (t == null) {
      return;
    }
    await ref.read(taskRepositoryProvider).update(
          t.id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          priority: _priority,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _toggleComplete(TodoTask t) async {
    await ref.read(taskRepositoryProvider).toggleComplete(t.id);
  }

  Future<void> _delete(TodoTask t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确认删除"${t.title}"？子任务也会被一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskRepositoryProvider).delete(t.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addSubtask(TodoTask t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskQuickAddSheet(
        listId: t.listId,
        parentTaskId: t.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = _task;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务不存在')),
        body: const Center(child: Text('任务不存在或已删除')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            tooltip: t.completed ? '取消勾选' : '勾选完成',
            onPressed: () => _toggleComplete(t),
            icon: Icon(
              t.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () => _delete(t),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '描述',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _priority,
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
            onChanged: (v) => setState(() => _priority = v ?? 0),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('标签', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TagChips(taskId: t.id),
          const Divider(height: 32),
          Row(
            children: [
              Text('子任务', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                onPressed: () => _addSubtask(t),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          _SubtaskList(taskId: t.id, onAdd: () => _addSubtask(t)),
        ],
      ),
    );
  }
}

class _SubtaskList extends ConsumerWidget {
  const _SubtaskList({required this.taskId, required this.onAdd});

  final int taskId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<TodoTask>>(
      stream: ref.watch(appDatabaseProvider).childrenOf(taskId).asStream(),
      builder: (ctx, snap) {
        final items = snap.data ?? const <TodoTask>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加子任务'),
            ),
          );
        }
        return Column(
          children: items
              .map(
                (st) => CheckboxListTile(
                  value: st.completed,
                  title: Text(
                    st.title,
                    style: TextStyle(
                      decoration:
                          st.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (_) async {
                    await ref
                        .read(taskRepositoryProvider)
                        .toggleComplete(st.id);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TagChips extends ConsumerStatefulWidget {
  const _TagChips({required this.taskId});

  final int taskId;

  @override
  ConsumerState<_TagChips> createState() => _TagChipsState();
}

class _TagChipsState extends ConsumerState<_TagChips> {
  Set<int> _selected = {};
  bool _loaded = false;

  Future<void> _bootstrap() async {
    final ids = await ref.read(tagRepositoryProvider).tagIdsOf(widget.taskId);
    if (!mounted) return;
    setState(() {
      _selected = ids.toSet();
      _loaded = true;
    });
  }

  Future<void> _toggle(int tagId) async {
    setState(() {
      if (_selected.contains(tagId)) {
        _selected.remove(tagId);
      } else {
        _selected.add(tagId);
      }
    });
    await ref
        .read(tagRepositoryProvider)
        .setTaskTags(widget.taskId, _selected.toList());
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 32);
    final tagsAsync = ref.watch(tagsStreamProvider);
    return tagsAsync.when(
      loading: () => const SizedBox(height: 32),
      error: (e, _) => Text('标签加载失败: $e'),
      data: (tags) {
        if (tags.isEmpty) return const Text('暂无标签，请先在清单页右上角创建');
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) {
            final selected = _selected.contains(t.id);
            return FilterChip(
              selected: selected,
              label: Text(t.name),
              avatar: CircleAvatar(
                backgroundColor: tagColorFromHex(t.color),
                radius: 8,
              ),
              onSelected: (_) => _toggle(t.id),
            );
          }).toList(),
        );
      },
    );
  }
}
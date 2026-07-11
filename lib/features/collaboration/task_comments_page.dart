import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';

/// 评论状态：加载中 / 错误 / 列表；附实用工具。
@immutable
class TaskCommentsState {
  const TaskCommentsState({
    required this.loading,
    required this.items,
    this.error,
  });

  final bool loading;
  final List<TaskComment> items;
  final String? error;
}

/// 拉取任务评论列表。
final taskCommentsProvider = FutureProvider.family
    .autoDispose<TaskCommentsState, int>((ref, taskServerId) async {
      final api = ref.watch(todoApiProvider).comment;
      try {
        final list = await api.list(taskServerId);
        list.sort((a, b) {
          final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return at.compareTo(bt);
        });
        return TaskCommentsState(loading: false, items: list);
      } catch (e) {
        return TaskCommentsState(
          loading: false,
          items: const [],
          error: e.toString(),
        );
      }
    });

/// 任务评论页：列表 + 新增 + 编辑。
class TaskCommentsPage extends ConsumerStatefulWidget {
  const TaskCommentsPage({
    super.key,
    required this.taskServerId,
    this.taskTitle,
  });

  final int taskServerId;
  final String? taskTitle;

  @override
  ConsumerState<TaskCommentsPage> createState() => _TaskCommentsPageState();
}

class _TaskCommentsPageState extends ConsumerState<TaskCommentsPage> {
  final _addCtrl = TextEditingController();
  final _editCtrl = TextEditingController();
  int? _editingId;
  bool _busy = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    ref.invalidate(taskCommentsProvider(widget.taskServerId));
  }

  Future<void> _add() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    _addCtrl.clear();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(todoApiProvider)
          .comment
          .add(taskId: widget.taskServerId, content: text);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已添加评论')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _addCtrl.text = text;
      messenger.showSnackBar(SnackBar(content: Text('添加失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startEdit(TaskComment c) async {
    setState(() {
      _editingId = c.id;
      _editCtrl.text = c.content;
    });
  }

  Future<void> _cancelEdit() async {
    setState(() {
      _editingId = null;
      _editCtrl.clear();
    });
  }

  Future<void> _saveEdit() async {
    final id = _editingId;
    if (id == null) return;
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(todoApiProvider)
          .comment
          .update(commentId: id, content: text);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已保存修改')));
      setState(() {
        _editingId = null;
        _editCtrl.clear();
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(TaskComment c) async {
    // 提前捕获 messenger，避免 await 后使用过期 context。
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除评论'),
        content: const Text('确认删除这条评论？'),
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
    if (ok != true) return;
    try {
      await ref.read(todoApiProvider).comment.delete(c.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已删除')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskCommentsProvider(widget.taskServerId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '评论${widget.taskTitle != null ? ' · ${widget.taskTitle}' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _list(state)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      decoration: const InputDecoration(
                        labelText: '添加一条评论',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: _busy ? null : _add,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(AsyncValue<TaskCommentsState> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (s) {
        if (s.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: ${s.error}'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          );
        }
        if (s.items.isEmpty) {
          return const Center(child: Text('暂无评论，来说两句吧'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: s.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final c = s.items[i];
            return _CommentTile(
              comment: c,
              isEditing: _editingId == c.id,
              editController: _editCtrl,
              onStartEdit: () => _startEdit(c),
              onCancelEdit: _cancelEdit,
              onSaveEdit: _saveEdit,
              onDelete: () => _delete(c),
            );
          },
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isEditing,
    required this.editController,
    required this.onStartEdit,
    required this.onCancelEdit,
    required this.onSaveEdit,
    required this.onDelete,
  });

  final TaskComment comment;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onStartEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.userId == null ? '自己' : '用户 #${comment.userId}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  comment.createdAt == null
                      ? ''
                      : comment.createdAt!.toLocal().toString().substring(
                          0,
                          16,
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (isEditing) ...[
              TextField(
                controller: editController,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancelEdit, child: const Text('取消')),
                  FilledButton(onPressed: onSaveEdit, child: const Text('保存')),
                ],
              ),
            ] else ...[
              Text(comment.content),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onStartEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// 任务执行人指派状态。
class TaskAssignState {
  const TaskAssignState({
    required this.loading,
    required this.assigneeUserId,
    this.error,
  });

  final bool loading;
  final int? assigneeUserId;
  final String? error;
}

/// 拉取当前任务的执行人（一次异步）。
final taskAssignProvider =
    FutureProvider.family.autoDispose<TaskAssignState, int>((
  ref,
  taskServerId,
) async {
  final api = ref.watch(todoApiProvider).taskAssign;
  try {
    final userId = await api.assignee(taskServerId);
    return TaskAssignState(loading: false, assigneeUserId: userId);
  } catch (e) {
    return TaskAssignState(
      loading: false,
      assigneeUserId: null,
      error: e.toString(),
    );
  }
});

/// 任务执行人指派页：
/// - 显示当前执行人
/// - 指派给指定 userId（PUT /task/{id}/assignee）
/// - 移除执行人（DELETE /task/{id}/assignee）
///
/// 注：按后端契约走 REST，后端负责校验成员是否属于清单；本地不再额外做清单/成员交叉校验。
class TaskAssignPage extends ConsumerStatefulWidget {
  const TaskAssignPage({
    super.key,
    required this.taskServerId,
    this.taskTitle,
  });

  final int taskServerId;
  final String? taskTitle;

  @override
  ConsumerState<TaskAssignPage> createState() => _TaskAssignPageState();
}

class _TaskAssignPageState extends ConsumerState<TaskAssignPage> {
  final _userIdCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _setAssignee(int? userId) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(todoApiProvider)
          .taskAssign
          .setAssignee(taskId: widget.taskServerId, userId: userId);
      if (!mounted) return;
      ref.invalidate(taskAssignProvider(widget.taskServerId));
      messenger.showSnackBar(
        SnackBar(content: Text(userId == null ? '已移除执行人' : '已指派')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('操作失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    // 提前捕获 messenger，避免 await 后使用过期 context。
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除执行人'),
        content: const Text('确认移除该任务的执行人？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      if (!mounted) return;
      await ref
          .read(todoApiProvider)
          .taskAssign
          .removeAssignee(widget.taskServerId);
      if (!mounted) return;
      ref.invalidate(taskAssignProvider(widget.taskServerId));
      messenger.showSnackBar(const SnackBar(content: Text('已移除执行人')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('操作失败: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskAssignProvider(widget.taskServerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '指派执行人${widget.taskTitle != null ? ' · ${widget.taskTitle}' : ''}',
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(taskAssignProvider(widget.taskServerId)),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (s) => _content(s),
      ),
    );
  }

  Widget _content(TaskAssignState s) {
    if (s.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: ${s.error}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(taskAssignProvider(widget.taskServerId)),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(
            s.assigneeUserId == null
                ? '尚未指派'
                : '执行人 #${s.assigneeUserId}',
          ),
          subtitle: Text(s.assigneeUserId == null
              ? '该任务当前没有执行人'
              : '服务端用户 ID：${s.assigneeUserId}'),
        ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '执行人 userId（数字）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final userId = int.tryParse(_userIdCtrl.text.trim());
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('请输入合法的用户 ID（数字）'),
                          ),
                        );
                        return;
                      }
                      _setAssignee(userId);
                    },
              child: const Text('指派'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || s.assigneeUserId == null ? null : _remove,
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('移除执行人'),
        ),
      ],
    );
  }
}

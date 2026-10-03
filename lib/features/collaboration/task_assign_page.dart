import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';
import 'list_member_page.dart';

/// 任务执行人指派状态。
class TaskAssignState {
  const TaskAssignState({required this.assignee, this.error});

  final TaskAssignee? assignee;
  final String? error;
}

/// 拉取当前任务的执行人（一次异步）。
final taskAssignProvider = FutureProvider.family
    .autoDispose<TaskAssignState, int>((ref, taskServerId) async {
      final api = ref.watch(todoApiProvider).taskAssign;
      try {
        final assignee = await api.assignee(taskServerId);
        return TaskAssignState(assignee: assignee);
      } catch (e) {
        return TaskAssignState(assignee: null, error: describeError(e));
      }
    });

/// 任务执行人指派页：
/// - 显示当前执行人的服务端资料
/// - 从清单 active 成员中选择执行人（PUT /task/{id}/assignee）
/// - 移除执行人（DELETE /task/{id}/assignee）
class TaskAssignPage extends ConsumerStatefulWidget {
  const TaskAssignPage({
    super.key,
    required this.taskServerId,
    required this.listServerId,
    this.taskTitle,
  });

  final int taskServerId;
  final int listServerId;
  final String? taskTitle;

  @override
  ConsumerState<TaskAssignPage> createState() => _TaskAssignPageState();
}

class _TaskAssignPageState extends ConsumerState<TaskAssignPage> {
  bool _busy = false;

  Future<void> _setAssignee(int userId) async {
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
      messenger.showSnackBar(const SnackBar(content: Text('已指派')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${describeError(e)}')),
      );
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
    if (!mounted || _busy) return;
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
      messenger.showSnackBar(
        SnackBar(content: Text('操作失败: ${describeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskAssignProvider(widget.taskServerId));
    final members = ref.watch(listMembersProvider(widget.listServerId));
    final currentUserId = ref.watch(sessionProvider)?.userId;

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
        error: (e, _) => Center(child: Text('加载失败: ${describeError(e)}')),
        data: (s) => members.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('成员加载失败: ${describeError(e)}')),
          data: (memberState) => _content(s, memberState, currentUserId),
        ),
      ),
    );
  }

  Widget _content(
    TaskAssignState s,
    ListMembersState memberState,
    int? currentUserId,
  ) {
    if (s.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: ${describeError(s.error)}'),
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
    if (memberState.status == MembersState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('成员加载失败: ${describeError(memberState.error)}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(listMembersProvider(widget.listServerId)),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final activeMembers = memberState.members
        .where((member) => member.status == 'active')
        .toList(growable: false);
    final currentMember = currentUserId == null
        ? null
        : activeMembers
              .where((member) => member.userId == currentUserId)
              .firstOrNull;
    final canEdit =
        currentMember != null &&
        (currentMember.isOwner || currentMember.isEditor);
    final assignee = s.assignee;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(
            assignee == null
                ? '尚未指派'
                : (assignee.displayName ?? '执行人 #${assignee.userId}'),
          ),
          subtitle: Text(
            assignee == null
                ? '该任务当前没有执行人'
                : [
                    if (assignee.email != null && assignee.email!.isNotEmpty)
                      assignee.email!,
                    'ID ${assignee.userId}',
                  ].join(' · '),
          ),
        ),
        const Divider(),
        if (!canEdit)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('当前清单为只读，只有 owner 或 active editor 可以修改执行人'),
          ),
        DropdownButtonFormField<int>(
          key: ValueKey('task-assignee-picker-${assignee?.userId}'),
          decoration: const InputDecoration(
            labelText: '选择清单成员',
            border: OutlineInputBorder(),
          ),
          hint: const Text('选择新的执行人'),
          items: [
            for (final member in activeMembers)
              DropdownMenuItem(
                value: member.userId,
                child: Text(_memberLabel(member)),
              ),
          ],
          onChanged: _busy || activeMembers.isEmpty || !canEdit
              ? null
              : (userId) {
                  if (userId != null && userId != assignee?.userId) {
                    _setAssignee(userId);
                  }
                },
        ),
        if (activeMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('当前清单没有可指派的 active 成员'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || assignee == null || !canEdit ? null : _remove,
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('移除执行人'),
        ),
      ],
    );
  }

  String _memberLabel(ListMember member) {
    final name = member.displayName ?? member.email ?? '成员 #${member.userId}';
    return '$name · ${member.roleLabel}';
  }
}

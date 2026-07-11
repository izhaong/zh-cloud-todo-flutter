import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';

/// `GET /list/{listId}/members` 的返回形态；直接传给下层 provider。
enum MembersState { loading, error, ready }

@immutable
class ListMembersState {
  const ListMembersState({
    required this.status,
    required this.members,
    this.error,
  });

  final MembersState status;
  final List<ListMember> members;
  final String? error;

  /// 当前登录用户是不是 owner（有管理权）。
  bool isOwner(int myUserId) =>
      members.any((m) => m.userId == myUserId && m.isOwner);
}

/// 拉取清单成员流：未登录返回空（UI 层负责提示）。
final listMembersProvider = FutureProvider.family
    .autoDispose<ListMembersState, int>((ref, listServerId) async {
      final api = ref.watch(todoApiProvider).listCollaboration;
      try {
        final members = await api.list(listServerId);
        return ListMembersState(status: MembersState.ready, members: members);
      } catch (e) {
        return ListMembersState(
          status: MembersState.error,
          members: const [],
          error: e.toString(),
        );
      }
    });

/// 列表成员管理页：
/// - 展示成员列表（owner/member 角色标签）
/// - 添加成员（按 userId）/ 移除 / 改角色
/// - 邀请链接（join 端点）/ 自己退出（exit 端点）
class ListMemberPage extends ConsumerStatefulWidget {
  const ListMemberPage({super.key, required this.listServerId, this.title});

  final int listServerId;
  final String? title;

  @override
  ConsumerState<ListMemberPage> createState() => _ListMemberPageState();
}

class _ListMemberPageState extends ConsumerState<ListMemberPage> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  /// 调用 [op] 后 invalidate provider 让 UI 从后端重新拉取。
  Future<void> _act(Future<void> Function() op) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await op();
      if (!mounted) return;
      ref.invalidate(listMembersProvider(widget.listServerId));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  Future<void> _add() async {
    final raw = _addCtrl.text.trim();
    _addCtrl.clear();
    final userId = int.tryParse(raw);
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入合法的用户 ID（数字）')));
      return;
    }
    await _act(
      () => ref
          .read(todoApiProvider)
          .listCollaboration
          .addMember(listId: widget.listServerId, userId: userId),
    );
  }

  Future<void> _remove(ListMember m) async {
    final ok = await _confirm('移除成员', '确认移除成员 #${m.userId}？');
    if (ok != true) return;
    await _act(
      () => ref
          .read(todoApiProvider)
          .listCollaboration
          .removeMember(listId: widget.listServerId, userId: m.userId),
    );
  }

  Future<void> _toggleRole(ListMember m) async {
    // 不能修改自己的角色（避免意外丢失 owner）。
    final session = ref.read(sessionProvider);
    if (session != null && session.userId == m.userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能修改自己的角色')));
      return;
    }
    final next = m.isOwner ? 'member' : 'owner';
    await _act(
      () => ref
          .read(todoApiProvider)
          .listCollaboration
          .updateRole(
            listId: widget.listServerId,
            userId: m.userId,
            role: next,
          ),
    );
  }

  Future<void> _join() async {
    await _act(
      () =>
          ref.read(todoApiProvider).listCollaboration.join(widget.listServerId),
    );
  }

  Future<void> _exit() async {
    final ok = await _confirm('退出协作', '确认退出该清单？');
    if (ok != true) return;
    await _act(
      () =>
          ref.read(todoApiProvider).listCollaboration.exit(widget.listServerId),
    );
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listMembersProvider(widget.listServerId));
    final session = ref.watch(sessionProvider);
    final myUserId = session?.userId;
    final s = state.valueOrNull;

    final iAmOwner = myUserId != null && (s?.isOwner(myUserId) ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text('协作成员${widget.title != null ? ' · ${widget.title}' : ''}'),
        actions: [
          IconButton(
            tooltip: '刷新成员列表',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(listMembersProvider(widget.listServerId)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '按用户 ID 邀请（数字）',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('邀请')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _join,
                  icon: const Icon(Icons.link),
                  label: const Text('通过链接加入'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exit,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('退出协作'),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(child: _content(state, iAmOwner)),
        ],
      ),
    );
  }

  Widget _content(AsyncValue<ListMembersState> state, bool iAmOwner) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (s) {
        if (s.status == MembersState.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: ${s.error}'),
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
        if (s.members.isEmpty) {
          return const Center(child: Text('暂无成员，邀请伙伴加入吧'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: s.members.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = s.members[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  m.isOwner ? Icons.workspace_premium : Icons.person,
                  color: m.isOwner ? Colors.amber : null,
                ),
                title: Text(m.displayName ?? '成员 #${m.userId}'),
                subtitle: Text(
                  '${m.mobile != null && m.mobile!.isNotEmpty ? '${m.mobile} · ' : ''}ID ${m.userId}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(label: Text(m.isOwner ? '所有者' : '成员')),
                    if (iAmOwner && !m.isOwner) ...[
                      IconButton(
                        tooltip: m.isOwner ? '降为成员' : '升为所有者',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _toggleRole(m),
                      ),
                      IconButton(
                        tooltip: '移除',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _remove(m),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

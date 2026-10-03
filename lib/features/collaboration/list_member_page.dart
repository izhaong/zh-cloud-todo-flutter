import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
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
          error: describeError(e),
        );
      }
    });

/// 列表成员管理页：
/// - 展示成员列表（owner/editor/viewer 与邀请状态）
/// - owner 按手机号邀请 editor/viewer、移除成员或修改权限
/// - 受邀成员接受邀请，active 非 owner 成员可退出协作
class ListMemberPage extends ConsumerStatefulWidget {
  const ListMemberPage({super.key, required this.listServerId, this.title});

  final int listServerId;
  final String? title;

  @override
  ConsumerState<ListMemberPage> createState() => _ListMemberPageState();
}

class _ListMemberPageState extends ConsumerState<ListMemberPage> {
  final _addCtrl = TextEditingController();
  String _inviteRole = 'editor';

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  /// 调用 [op] 后 invalidate provider 让 UI 从后端重新拉取。
  Future<bool> _act(Future<void> Function() op) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await op();
      if (!mounted) return true;
      ref.invalidate(listMembersProvider(widget.listServerId));
      return true;
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('操作失败: ${describeError(e)}')),
      );
      return false;
    }
  }

  Future<void> _add() async {
    final mobile = _addCtrl.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 11 位手机号')));
      return;
    }
    final invited = await _act(
      () => ref
          .read(todoApiProvider)
          .listCollaboration
          .addMember(
            listId: widget.listServerId,
            userMobile: mobile,
            role: _inviteRole,
          ),
    );
    if (invited && mounted) _addCtrl.clear();
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

  Future<void> _setRole(ListMember member, String role) async {
    if (member.isOwner || role == member.role) return;
    await _act(
      () => ref
          .read(todoApiProvider)
          .listCollaboration
          .updateRole(
            listId: widget.listServerId,
            userId: member.userId,
            role: role,
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
    final currentMember = myUserId == null
        ? null
        : s?.members.where((member) => member.userId == myUserId).firstOrNull;
    final canAcceptInvitation = currentMember?.status == 'invited';
    final canExit =
        currentMember != null &&
        !currentMember.isOwner &&
        currentMember.status == 'active';

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
          if (iAmOwner)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('collaboration-invite-mobile'),
                    controller: _addCtrl,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: '成员手机号',
                      hintText: '请输入 11 位手机号',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('collaboration-invite-role'),
                          initialValue: _inviteRole,
                          decoration: const InputDecoration(
                            labelText: '邀请权限',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'editor',
                              child: Text('可编辑'),
                            ),
                            DropdownMenuItem(
                              value: 'viewer',
                              child: Text('只读'),
                            ),
                          ],
                          onChanged: (role) {
                            if (role != null) {
                              setState(() => _inviteRole = role);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const Key('collaboration-invite-submit'),
                        onPressed: _add,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('邀请'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (canAcceptInvitation || canExit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  if (canAcceptInvitation)
                    FilledButton.icon(
                      onPressed: _join,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('接受邀请'),
                    ),
                  if (canAcceptInvitation && canExit) const SizedBox(width: 8),
                  if (canExit)
                    OutlinedButton.icon(
                      onPressed: _exit,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('退出协作'),
                    ),
                ],
              ),
            ),
          if (iAmOwner || canAcceptInvitation || canExit)
            const Divider(height: 16),
          Expanded(child: _content(state, iAmOwner)),
        ],
      ),
    );
  }

  Widget _content(AsyncValue<ListMembersState> state, bool iAmOwner) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: ${describeError(e)}')),
      data: (s) {
        if (s.status == MembersState.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: ${describeError(s.error)}'),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_memberContact(m)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(m.roleLabel),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(m.statusLabel),
                        ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: iAmOwner && !m.isOwner
                    ? PopupMenuButton<String>(
                        tooltip: '管理成员',
                        onSelected: (action) {
                          if (action == 'remove') {
                            _remove(m);
                          } else {
                            _setRole(m, action);
                          }
                        },
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'editor',
                            checked: m.isEditor,
                            child: const Text('可编辑'),
                          ),
                          CheckedPopupMenuItem(
                            value: 'viewer',
                            checked: m.isViewer,
                            child: const Text('只读'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('移除成员'),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  String _memberContact(ListMember member) {
    final contact = [
      if (member.mobile != null && member.mobile!.isNotEmpty) member.mobile!,
      if (member.email != null && member.email!.isNotEmpty) member.email!,
      'ID ${member.userId}',
    ];
    return contact.join(' · ');
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import '../task/task_detail_page.dart' show TaskDetailPage;

/// 当前收件箱条目（拉取后回写解析好的任务标题）。
class InboxEntry {
  InboxEntry(this.item, {this.localTitle});

  final ReminderInboxItem item;

  /// 本地解析出的任务标题（按 taskId serverId 查不到时回退 item.taskTitle）。
  final String? localTitle;

  int get id => item.id;
  String get title => (localTitle != null && localTitle!.isNotEmpty)
      ? localTitle!
      : item.taskTitle;
  DateTime get remindAt => item.remindAt;
  String get status => item.status;
  bool get pending => item.pending;
}

/// 收件箱状态：加载中 / 错误 / 数据三类。
@immutable
class InboxState {
  const InboxState.loading() : loading = true, error = null, entries = const [];
  const InboxState.error(this.error) : loading = false, entries = const [];
  const InboxState.data(this.entries) : loading = false, error = null;

  final bool loading;
  final String? error;
  final List<InboxEntry> entries;
}

/// 按任务 serverId 分组视图：聚合每个任务的待处理提醒。
class InboxGroup {
  InboxGroup({required this.taskId, required this.taskTitle});

  final int taskId;

  /// 任务本地/后端标题。
  final String taskTitle;

  final List<InboxEntry> reminders = [];

  int get pendingCount => reminders.where((r) => r.pending).length;
}

/// 把所有条目按 taskId 聚合成 [InboxGroup]，便于页面按任务分组渲染。
/// 组内按首个提醒触发时间升序。
List<InboxGroup> groupByTask(List<InboxEntry> entries) {
  final map = <int, InboxGroup>{};
  for (final e in entries) {
    final g = map.putIfAbsent(
      e.item.taskId,
      () => InboxGroup(taskId: e.item.taskId, taskTitle: e.title),
    );
    g.reminders.add(e);
  }
  final groups = map.values.toList();
  groups.sort(
    (a, b) => a.reminders.first.remindAt.compareTo(b.reminders.first.remindAt),
  );
  return groups;
}

/// 收件箱 Provider：拉取远端 `GET /reminder-action/inbox` → 按 taskId 解析本地标题。
///
/// 未登录（[appDatabaseProvider] 为 null）时跳过标题解析，UI 层单独提示登录。
final inboxProvider = FutureProvider.autoDispose<InboxState>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(todoApiProvider).reminder;
  final items = await api.inbox();
  if (db == null) {
    return InboxState.data([for (final it in items) InboxEntry(it)]);
  }

  final entries = <InboxEntry>[];
  for (final it in items) {
    String? localTitle;
    try {
      final task = await db.taskByServerId(it.taskId);
      localTitle = task?.title;
    } catch (_) {
      // 解析失败时回退后端冗余标题。
    }
    entries.add(InboxEntry(it, localTitle: localTitle));
  }
  return InboxState.data(entries);
});

/// 提醒收件箱页面（P4 / Time Loop）。
///
/// - 拉取 `GET /reminder-action/inbox` 并按任务分组；
/// - 每条可：完成 / 忽略 / 延后 10 分钟（snooze）/ 持续响铃（persistent）；
/// - 每个任务组可：全部完成 / 全部忽略 / 一键跳转到任务详情。
class ReminderInboxPage extends ConsumerWidget {
  const ReminderInboxPage({super.key});

  Future<void> _act(WidgetRef ref, Future<void> Function() op) async {
    // 提前捕获 messenger，避免 await 后使用过期 context。
    final host = ScaffoldMessenger.maybeOf(ref.context);
    try {
      await op();
      ref.invalidate(inboxProvider);
    } catch (e) {
      host?.showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inboxProvider);
    final notLoggedIn = ref.watch(appDatabaseProvider) == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提醒收件箱'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(inboxProvider),
          ),
        ],
      ),
      body: notLoggedIn
          ? const Center(child: Text('请先登录后再查看提醒'))
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败: $e'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(inboxProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (state) {
                final groups = groupByTask(state.entries);
                if (state.entries.isEmpty) {
                  return const Center(child: Text('暂无提醒，棒棒的！'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _InboxGroupCard(
                    group: groups[i],
                    onAct: (op) => _act(ref, op),
                    onOpenTask: (taskId) => _openTask(ref.context, ref, taskId),
                  ),
                );
              },
            ),
    );
  }

  void _openTask(BuildContext context, WidgetRef ref, int taskId) {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return;
    // 提前捕获 navigator / messenger，避免 await 后使用过期 context。
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(
      db.taskByServerId(taskId).then((t) {
        if (t == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('未找到对应任务')));
          return;
        }
        // 直接以 page 模式跳转任务详情（nbavigator 在 await 前捕获，上下文有效）。
        navigator.push(
          MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)),
        );
      }),
    );
  }
}

class _InboxGroupCard extends ConsumerWidget {
  const _InboxGroupCard({
    required this.group,
    required this.onAct,
    required this.onOpenTask,
  });

  final InboxGroup group;
  final Future<void> Function(Future<void> Function() op) onAct;
  final void Function(int taskId) onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(todoApiProvider).reminder;
    final pending = group.reminders.where((e) => e.pending).toList();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.taskTitle.isEmpty
                        ? '任务 #${group.taskId}'
                        : group.taskTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (group.pendingCount > 0)
                  Chip(label: Text('待处理 ${group.pendingCount}')),
                IconButton(
                  tooltip: '打开任务',
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => onOpenTask(group.taskId),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (pending.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () => onAct(() async {
                      for (final r in pending) {
                        await api.complete(r.id);
                      }
                    }),
                    child: const Text('全部完成'),
                  ),
                  OutlinedButton(
                    onPressed: () => onAct(() async {
                      for (final r in pending) {
                        await api.dismiss(r.id);
                      }
                    }),
                    child: const Text('全部忽略'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            for (final r in group.reminders)
              _ReminderTile(api: api, entry: r, onAct: onAct),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.api,
    required this.entry,
    required this.onAct,
  });

  final ReminderActionApi api;
  final InboxEntry entry;
  final Future<void> Function(Future<void> Function() op) onAct;

  String _fmtRemain(DateTime t) {
    final d = t.difference(DateTime.now());
    final prefix = d.isNegative ? '已过 ' : '';
    final a = d.abs();
    final body = a.inMinutes < 60
        ? '${a.inMinutes} 分钟'
        : (a.inHours < 24 ? '${a.inHours} 小时' : '${a.inDays} 天');
    return '$prefix$body';
  }

  @override
  Widget build(BuildContext context) {
    final overdue = entry.remindAt.isBefore(DateTime.now());
    return ListTile(
      dense: true,
      leading: Icon(
        entry.pending ? Icons.notifications_active : Icons.notifications_off,
        color: overdue ? Colors.orange : null,
        size: 20,
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_fmtRemain(entry.remindAt)} · ${entry.remindAt.toLocal().toString().substring(0, 16)}',
      ),
      trailing: entry.pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '延后 10 分钟',
                  icon: const Icon(Icons.snooze, size: 18),
                  onPressed: () => onAct(() => api.snooze(entry.id)),
                ),
                IconButton(
                  tooltip: '持续响铃（信息态）',
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  onPressed: () => onAct(() => api.persistent(entry.id)),
                ),
                IconButton(
                  tooltip: '完成',
                  icon: const Icon(Icons.check, size: 18),
                  onPressed: () => onAct(() => api.complete(entry.id)),
                ),
                IconButton(
                  tooltip: '忽略',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onAct(() => api.dismiss(entry.id)),
                ),
              ],
            )
          : null,
    );
  }
}

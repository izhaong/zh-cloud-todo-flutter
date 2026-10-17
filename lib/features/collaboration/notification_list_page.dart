import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/api/todo_api.dart';
import '../../state/providers.dart';

/// 站内通知列表（FL #358）。
///
/// 判据源：嘀嗒《02-团队如何协作》`:56`「评论成功后，被您评论或 @ 的用户将会在
/// 「通知中心」里收到提醒」。
///
/// **两条纪律**：
/// - 提及那类条目**只展示**，点进评论 —— **不交 OS 调度**（那是提醒专用链路）；
/// - 通知内容服务端**不复述任务标题**（越权保护），所以这里也不去拉任务详情拼回来。
class NotificationListPage extends ConsumerStatefulWidget {
  const NotificationListPage({super.key});

  @override
  ConsumerState<NotificationListPage> createState() =>
      _NotificationListPageState();
}

class _NotificationListPageState extends ConsumerState<NotificationListPage> {
  late final Future<List<TodoNotificationItem>> _future;
  final Set<int> _readLocally = {};

  @override
  void initState() {
    super.initState();
    _future = ref.read(todoApiProvider).notification.unread();
  }

  Future<void> _open(TodoNotificationItem item) async {
    // 标已读（失败不影响跳转）：服务端把"不是自己的"当作不存在。
    ref.read(todoApiProvider).notification.markRead(item.id).then((_) {
      if (mounted) setState(() => _readLocally.add(item.id));
    });
    if (item.isMention && item.taskId != null && mounted) {
      // 提及点进那条评论所在的任务。
      await Navigator.of(context).pushNamed('/tasks/${item.taskId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: FutureBuilder<List<TodoNotificationItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('通知加载失败：${describeError(snapshot.error)}'),
            );
          }
          final items = snapshot.data ?? const <TodoNotificationItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('暂无通知'));
          }
          return ListView(
            children: [
              for (final item in items)
                ListTile(
                  key: Key('todo-notification-${item.id}'),
                  leading: Icon(
                    item.isMention ? Icons.chat_bubble_outline : Icons.alarm,
                    color: _readLocally.contains(item.id) || item.readAt != null
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    item.content ?? (item.isMention ? '有人在评论里提到了你' : '提醒'),
                  ),
                  onTap: () => _open(item),
                ),
            ],
          );
        },
      ),
    );
  }
}

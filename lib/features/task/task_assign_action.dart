import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collaboration/task_assign_page.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// 「分配给」的共用入口（嘀嗒《02-看板视图：分类管理任务》`:175`「在看板视图右键任务，
/// 选择「分配给」即可。」与详情页协作 Sheet 的「指派执行人」是同一条动作）。
///
/// 前置条件不满足时必须**可见**：任务/清单还没同步或本地库未就绪，各给一句提示后返回，
/// 不静默早退、也不改动任务数据。
///
/// [stillCurrent]：详情 Sheet 可以切任务，所以异步反查清单回来之后必须再确认"用户还在看这条任务"，
/// 否则旧任务的指派页会盖到新任务上（原实现里这一句就在 `_openCollaborationHub` 内部）。
Future<void> openTaskAssignAction(
  BuildContext context,
  WidgetRef ref,
  TodoTask task, {
  bool Function()? stillCurrent,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final taskServerId = task.serverId;
  if (taskServerId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('任务尚未同步，无法指派')));
    return;
  }
  final db = ref.read(appDatabaseProvider);
  if (db == null) {
    messenger.showSnackBar(const SnackBar(content: Text('请先登录')));
    return;
  }
  final list = await db.listByLocalId(task.listId);
  if (stillCurrent != null && !stillCurrent()) return;
  final listServerId = list?.serverId;
  if (listServerId == null) {
    messenger.showSnackBar(const SnackBar(content: Text('清单尚未同步，无法选择执行人')));
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TaskAssignPage(
        taskServerId: taskServerId,
        listServerId: listServerId,
        taskTitle: task.title,
      ),
    ),
  );
}

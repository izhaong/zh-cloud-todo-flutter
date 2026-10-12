import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'task_quick_add_sheet.dart';

/// 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》里三句
/// 「添加子任务」的公共入口：`:13`（mobile 详情页「…」）、`:33`（子任务详情再加一层）、
/// `:51`（desktop「右键单击任务，选择「添加子任务」」）。
///
/// 深度守卫只有这一份：详情层原来自己写了一段 `depthOf(t.id) >= 5`，右键那档如果再抄一遍，
/// 两处文案与两处判据就会漂。所以两个调用点都走这里。
Future<void> addSubtaskFlow(
  BuildContext context,
  WidgetRef ref,
  TodoTask parent, {

  /// 详情层用它守住"弹窗还挂在另一个任务上就别弹"（原 `_addSubtask` 的 stale 守卫）。
  /// 右键那一档没有这层身份，不传即可。
  bool Function()? stillCurrent,
}) async {
  final repository = ref.read(taskRepositoryProvider);
  if (repository == null) return;
  // await 之前先取 messenger：await 之后 context 可能已经不在树上了。
  final messenger = ScaffoldMessenger.of(context);
  final depth = await repository.depthOf(parent.id);
  if (stillCurrent != null && !stillCurrent()) return;
  if (depth >= 5) {
    messenger.showSnackBar(
      const SnackBar(content: Text('已达最大嵌套层数（5），无法继续添加子任务')),
    );
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        TaskQuickAddSheet(listId: parent.listId, parentTaskId: parent.id),
  );
}

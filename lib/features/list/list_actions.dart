import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import '../collaboration/list_member_page.dart';
import 'list_editor_sheet.dart';

/// 清单的「编辑 / 共享协作 / 删除」动作（条目命名照抄嘀嗒《01-如何共享清单》）。
///
/// 删除语义（未完成任务拦截 + 二次确认）历史上在 `ListPage` 与 `ListEditorSheet`
/// 各写了一份，后者在「无未完成任务」时甚至不确认就删；侧栏、清单管理页与编辑器
/// 现在都调本文件的同一个函数，只留一份口径。

/// 删除清单：仍有未完成任务时先拦截并给出条数，取消不产生任何写入。
/// 返回是否真的删除，调用方（清单编辑器）据此决定要不要收起自己。
Future<bool> confirmAndDeleteList(
  BuildContext context,
  WidgetRef ref,
  TodoList list,
) async {
  final db = ref.read(appDatabaseProvider);
  if (db == null) return false;
  final open = await db.countOpenTasksByList(list.id);
  if (!context.mounted) return false;
  if (open > 0) {
    final force = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清单有未完成任务'),
        content: Text('"${list.name}" 仍有 $open 项未完成。\n确认删除？'),
        actions: _dialogActions(ctx),
      ),
    );
    if (force != true) return false;
  } else {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除清单'),
        content: Text('"${list.name}" 确认删除？'),
        actions: _dialogActions(ctx),
      ),
    );
    if (ok != true) return false;
  }
  if (!context.mounted) return false;
  final repo = ref.read(listRepositoryProvider);
  if (repo == null) return false;
  await repo.delete(list.id);
  return true;
}

List<Widget> _dialogActions(BuildContext ctx) => [
  TextButton(
    onPressed: () => Navigator.pop(ctx, false),
    child: const Text('取消'),
  ),
  FilledButton(
    onPressed: () => Navigator.pop(ctx, true),
    child: const Text('删除'),
  ),
];

/// 打开该清单的成员页（嘀嗒《01-如何共享清单》:8「共享协作」这一步）。
///
/// 侧栏清单行与任务详情里的「协作」入口共用本函数：成员页、`serverId` 前置校验、
/// 未同步时的提示语只留一份口径。
Future<void> openListCollaboration(
  BuildContext context,
  WidgetRef ref,
  TodoList list,
) async {
  final listServerId = list.serverId;
  if (listServerId == null) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('清单尚未同步，无法打开共享协作')));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ListMemberPage(listServerId: listServerId, title: list.name),
    ),
  );
}

/// 侧栏清单的动作表（长按或左滑唤出），条目命名跟随嘀嗒（「置顶」「编辑」「共享协作」「删除」）。
Future<void> showListActions(
  BuildContext context,
  WidgetRef ref,
  TodoList list,
) async {
  String? pinError;
  final action = await showModalBottomSheet<_ListAction>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pinError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  pinError!,
                  key: const Key('sidebar-list-pin-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ListTile(
              key: const Key('sidebar-list-action-pin'),
              leading: Icon(
                list.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(list.isPinned ? '取消置顶' : '置顶'),
              // 置顶就地处理：失败时表还开着、错误就在眼前，不会像关掉表再弹条
              // 谁也没看见的 SnackBar 那样把失败吞掉。
              onTap: () async {
                final repo = ref.read(listRepositoryProvider);
                if (repo == null) {
                  if (sheetContext.mounted) {
                    setSheetState(() => pinError = '清单数据还没准备好，稍后再试');
                  }
                  return;
                }
                try {
                  await repo.setPinned(list.id, !list.isPinned);
                } on Object catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(
                      () => pinError = '置顶失败：${describeError(e)}，清单列表仍是原来的',
                    );
                  }
                  return;
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              key: const Key('sidebar-list-action-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () => Navigator.pop(sheetContext, _ListAction.edit),
            ),
            ListTile(
              key: const Key('sidebar-list-action-share'),
              leading: const Icon(Icons.people_outline),
              title: const Text('共享协作'),
              onTap: () => Navigator.pop(sheetContext, _ListAction.share),
            ),
            ListTile(
              key: const Key('sidebar-list-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () => Navigator.pop(sheetContext, _ListAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _ListAction.edit:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ListEditorSheet(existing: list),
      );
    case _ListAction.share:
      await openListCollaboration(context, ref, list);
    case _ListAction.delete:
      await confirmAndDeleteList(context, ref, list);
  }
}

enum _ListAction { edit, share, delete }

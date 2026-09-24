import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'list_editor_sheet.dart';

/// 清单的「编辑 / 删除」动作。
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

/// 侧栏长按清单行给出的动作表，条目命名跟随嘀嗒（「编辑」「删除」）。
Future<void> showListActions(
  BuildContext context,
  WidgetRef ref,
  TodoList list,
) async {
  final action = await showModalBottomSheet<_ListAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('sidebar-list-action-edit'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑'),
            onTap: () => Navigator.pop(sheetContext, _ListAction.edit),
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
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _ListAction.edit:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ListEditorSheet(existing: list),
      );
    case _ListAction.delete:
      await confirmAndDeleteList(context, ref, list);
  }
}

enum _ListAction { edit, delete }

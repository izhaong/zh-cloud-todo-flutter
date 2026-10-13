import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// 拖拽载荷：被拖起的清单。
///
/// 与侧栏既有的「任务拖入清单」分型（那边是 `Draggable<TodoTask>`），
/// 这样两条拖拽通道各自只认自己的 `DragTarget`，不会互相接单。
@immutable
class SidebarListMergeDrag {
  const SidebarListMergeDrag(this.listId);

  final String listId;
}

/// 清单行的拖拽手柄（嘀嗒《01-任务/09-如何管理海量任务/01-用文件夹管理任务.md》方式一）。
///
/// 手柄只在「指针设备悬停」或「触屏设备」两种情况下出现：宽屏/平板/手机的黄金基线既不悬停也不是
/// 触屏，默认渲染因此一张都不用重录。手柄不放在 `Dismissible` 的横向滑轨道里，
/// 免得抢掉既有的「左滑唤出置顶/编辑/删除」。
class SidebarListDragHandle extends StatelessWidget {
  const SidebarListDragHandle({
    required this.list,
    required this.visible,
    super.key,
  });

  final TodoList list;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Tooltip(
      message: '拖到另一条清单上可建文件夹',
      child: Semantics(
        // key 挂在带 label 的这个节点上：读屏断言直接量它自己，不被外层节点的合并规则干扰。
        key: ValueKey('todo-sidebar-list-drag-${list.id}'),
        label: '拖到另一条清单上建文件夹',
        button: true,
        child: GestureDetector(
          // 手柄自己吃掉点按，不然落点会顺带把侧栏切到这条清单。
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Draggable<SidebarListMergeDrag>(
            data: SidebarListMergeDrag(list.id),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(list.name, style: const TextStyle(fontSize: 13)),
              ),
            ),
            childWhenDragging: const Opacity(
              opacity: 0.3,
              child: Icon(Icons.drag_indicator, size: 16),
            ),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            child: const Icon(Icons.drag_indicator, size: 16),
          ),
        ),
      ),
    );
  }
}

/// 清单行作为「另一条清单」这一落点。
class SidebarListMergeTarget extends StatelessWidget {
  const SidebarListMergeTarget({
    required this.list,
    required this.ref,
    required this.child,
    super.key,
  });

  final TodoList list;
  final WidgetRef ref;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<SidebarListMergeDrag>(
      key: ValueKey('todo-sidebar-list-merge-target-${list.id}'),
      onWillAcceptWithDetails: (details) => details.data.listId != list.id,
      onAcceptWithDetails: (details) => createFolderByMergingLists(
        context: context,
        ref: ref,
        sourceListId: details.data.listId,
        targetList: list,
      ),
      builder: (context, candidates, _) => child,
    );
  }
}

/// 松手后的命名弹窗 → 建夹 → 两条清单一起搬进去。
///
/// 原文是「松手后，在弹窗内输入名称即可创建文件夹」，所以命名这一步不能省；
/// 取消则一条文件夹都不落。搬清单失败时把刚建的夹删掉（`delete` 会顺带清空归属），
/// 不许留下「夹建了、清单没搬」的半态。
Future<void> createFolderByMergingLists({
  required BuildContext context,
  required WidgetRef ref,
  required String sourceListId,
  required TodoList targetList,
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('新建文件夹'),
      content: TextField(
        key: const Key('sidebar-folder-merge-name'),
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '文件夹名',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('sidebar-folder-merge-cancel'),
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('sidebar-folder-merge-confirm'),
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isEmpty) return;
            Navigator.pop(dialogContext, trimmed);
          },
          child: const Text('创建'),
        ),
      ],
    ),
  );
  if (name == null || !context.mounted) return;

  final folderRepo = ref.read(folderRepositoryProvider);
  final listRepo = ref.read(listRepositoryProvider);
  if (folderRepo == null || listRepo == null) {
    _report(context, '清单数据还没准备好，没能建文件夹');
    return;
  }

  final TodoFolder folder;
  try {
    folder = await folderRepo.create(name);
  } on Object {
    if (context.mounted) _report(context, '建文件夹失败，清单列表仍是原来的');
    return;
  }

  final source = await _loadList(ref, sourceListId);
  try {
    if (source == null) throw StateError('拖起的清单已不存在');
    await listRepo.moveToFolder(source.id, folder.id);
    await listRepo.moveToFolder(targetList.id, folder.id);
  } on Object {
    try {
      await folderRepo.delete(folder.id);
    } on Object {
      // 回滚也失败时不再叠加提示：下面的那句已经说明这次没成。
    }
    if (context.mounted) {
      _report(context, '建文件夹失败：清单没能搬进「$name」，侧栏维持原样');
    }
    return;
  }

  if (context.mounted) {
    _report(
      context,
      '已创建文件夹「${folder.name}」，「${source.name}」与「${targetList.name}」已放入',
    );
  }
}

Future<TodoList?> _loadList(WidgetRef ref, String listId) async {
  final repo = ref.read(listRepositoryProvider);
  if (repo == null) return null;
  final all = await repo.getAll();
  for (final item in all) {
    if (item.id == listId) return item;
  }
  return null;
}

void _report(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

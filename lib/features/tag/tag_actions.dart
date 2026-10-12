import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import '../../state/repositories/tag_repository.dart';
import 'tag_color.dart';

/// 侧栏标签行的动作表（左滑唤出）。
///
/// 嘀嗒《04-用标签管理任务》:79「在侧边栏左滑某个标签，会出现「置顶」「编辑」
/// 和「删除」3个选项。」specs/082 曾裁定本表只放「置顶」——那时「编辑」「删除」
/// 放进来只会跳转。specs/090 把编辑/删除提成共享函数（[promptEditTag] /
/// [confirmAndDeleteTag]）后，两项在表里就地可完成，裁定随之更新为三项。
Future<void> showTagActions(
  BuildContext context,
  WidgetRef ref,
  TodoTag tag,
) async {
  String? pinError;
  await showModalBottomSheet<void>(
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
                  key: const Key('sidebar-tag-pin-error'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ListTile(
              key: const Key('sidebar-tag-action-pin'),
              leading: Icon(
                tag.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(tag.isPinned ? '取消置顶' : '置顶'),
              // 就地处理：失败时表还开着、错误就在眼前，不吞进谁也没看见的 SnackBar。
              onTap: () async {
                final repo = ref.read(tagRepositoryProvider);
                if (repo == null) {
                  if (sheetContext.mounted) {
                    setSheetState(() => pinError = '标签数据还没准备好，稍后再试');
                  }
                  return;
                }
                try {
                  await repo.setPinned(tag.id, !tag.isPinned);
                } on Object catch (e) {
                  if (sheetContext.mounted) {
                    setSheetState(
                      () => pinError = '置顶失败：${describeError(e)}，标签列表仍是原来的',
                    );
                  }
                  return;
                }
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              key: const Key('sidebar-tag-action-edit'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(sheetContext);
                promptEditTag(context, ref, tag);
              },
            ),
            ListTile(
              key: const Key('sidebar-tag-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmAndDeleteTag(context, ref, tag);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// 桌面右键标签行的位置菜单（嘀嗒《04-用标签管理任务》:94「右键单击某个标签，
/// 会出现「置顶」「编辑」和「删除」等选项」）。与 [showTagActions] 同一套动作，
/// 只是载体换成光标处的 [showMenu]；触屏不会发出次键，无需 desktopMode 门
/// （与 kanban_view 的卡片右键同一写法）。
Future<void> showTagContextMenu(
  BuildContext context,
  WidgetRef ref,
  TodoTag tag,
  Offset globalPosition,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final action = await showMenu<_TagContextMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        key: const Key('sidebar-tag-menu-pin'),
        value: _TagContextMenuAction.pin,
        child: Text(tag.isPinned ? '取消置顶' : '置顶'),
      ),
      const PopupMenuItem(
        key: Key('sidebar-tag-menu-edit'),
        value: _TagContextMenuAction.edit,
        child: Text('编辑'),
      ),
      const PopupMenuItem(
        key: Key('sidebar-tag-menu-delete'),
        value: _TagContextMenuAction.delete,
        child: Text('删除'),
      ),
    ],
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _TagContextMenuAction.pin:
      final repo = ref.read(tagRepositoryProvider);
      if (repo == null) return;
      try {
        await repo.setPinned(tag.id, !tag.isPinned);
      } on Object catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('置顶失败：${describeError(e)}，标签列表仍是原来的')),
            );
        }
      }
      return;
    case _TagContextMenuAction.edit:
      await promptEditTag(context, ref, tag);
      return;
    case _TagContextMenuAction.delete:
      await confirmAndDeleteTag(context, ref, tag);
      return;
  }
}

enum _TagContextMenuAction { pin, edit, delete }

/// 与 TagPage 行内「编辑标签」按钮同一份编辑面（名称/颜色/父标签），保存即
/// `TagRepository.update`，取消不写。
Future<void> promptEditTag(
  BuildContext context,
  WidgetRef ref,
  TodoTag tag,
) async {
  final result = await promptTagFields(
    context,
    tags: (ref.read(tagsStreamProvider).valueOrNull ?? const []),
    editingTagId: tag.id,
    initialName: tag.name,
    initialColor: tag.color,
    initialParentId: tag.parentId,
  );
  if (result == null) return;
  final repo = ref.read(tagRepositoryProvider);
  if (repo == null) return;
  await repo.update(
    tag.id,
    name: result.$1,
    color: result.$2,
    parentId: result.$3,
  );
}

/// 与 TagPage 行内「删除标签」按钮同一份确认框；确认后 `TagRepository.delete`
/// （直接子标签由仓储 reparent 到顶层）。
Future<void> confirmAndDeleteTag(
  BuildContext context,
  WidgetRef ref,
  TodoTag tag,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除标签'),
      content: Text('确认删除"${tag.name}"？关联任务将解除；直接子标签会移至顶层。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final repo = ref.read(tagRepositoryProvider);
  if (repo == null) return;
  await repo.delete(tag.id);
}

/// 弹窗：标签名、颜色和本地父标签选择（TagPage 新建/编辑与侧栏动作共用）。
Future<(String, String, String?)?> promptTagFields(
  BuildContext context, {
  required List<TodoTag> tags,
  String? editingTagId,
  String? initialName,
  String? initialColor,
  String? initialParentId,
}) async {
  final nameCtrl = TextEditingController(text: initialName ?? '');
  String? color = initialColor ?? TagRepository.palette.first;
  String? parentId = initialParentId;
  final parentChoices = tags
      .where((tag) => canUseAsParent(tag, editingTagId, tags))
      .toList();
  return showDialog<(String, String, String?)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(initialName == null ? '新建标签' : '编辑标签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标签名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '父标签',
                border: OutlineInputBorder(),
              ),
              child: DropdownButton<String>(
                key: const Key('tag-parent-picker'),
                value: parentId ?? kRootParentValue,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(
                    value: kRootParentValue,
                    child: Text('顶层标签'),
                  ),
                  ...parentChoices.map(
                    (tag) => DropdownMenuItem(
                      value: tag.id,
                      child: Text(tagPath(tag, tags)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => parentId = value == kRootParentValue ? null : value,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TagRepository.palette.map((c) {
                final selected = c == color;
                return GestureDetector(
                  onTap: () => setState(() => color = c),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: parseHexColor(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty || color == null) return;
              Navigator.pop(ctx, (n, color!, parentId));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

const kRootParentValue = '__todo_root_tag__';

bool canUseAsParent(
  TodoTag candidate,
  String? editingTagId,
  List<TodoTag> tags,
) {
  if (editingTagId == null) return true;
  if (candidate.id == editingTagId) return false;
  final visited = <String>{};
  TodoTag? current = candidate;
  while (current?.parentId != null) {
    if (!visited.add(current!.id) || current.parentId == editingTagId) {
      return false;
    }
    current = tags.where((tag) => tag.id == current!.parentId).firstOrNull;
  }
  return true;
}

String tagPath(TodoTag tag, List<TodoTag> tags, {Set<String>? visiting}) {
  final parentId = tag.parentId;
  if (parentId == null) return tag.name;
  final seen = {...?visiting, tag.id};
  if (seen.contains(parentId)) return tag.name;
  final parent = tags
      .where((candidate) => candidate.id == parentId)
      .firstOrNull;
  if (parent == null) return tag.name;
  return '${tagPath(parent, tags, visiting: seen)} / ${tag.name}';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'folder_actions.dart';
import '../shell/sidebar_hierarchy.dart';

/// M11-B2 文件夹管理页（独立页面）。
class FolderPage extends ConsumerWidget {
  const FolderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件夹'),
        actions: [
          IconButton(
            tooltip: '新建文件夹',
            icon: const Icon(Icons.add),
            onPressed: () =>
                _create(context, ref, foldersAsync.valueOrNull ?? const []),
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载文件夹失败: ${describeError(e)}')),
        data: (folders) {
          final entries = flattenSidebarHierarchy(
            folders,
            idOf: (folder) => folder.id,
            parentIdOf: (folder) => folder.parentId,
          );
          return folders.isEmpty
              ? const Center(child: Text('暂无文件夹'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    final f = entry.node;
                    // specs/135（矩阵 #18）：左滑解散 + 桌面右键解散 + 文案统一。
                    return Dismissible(
                      key: ValueKey('folder-row-${f.id}'),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(
                          Icons.delete_sweep,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (_) =>
                          confirmAndDisbandFolder(context, f),
                      child: GestureDetector(
                        onSecondaryTapDown: (details) =>
                            _showContextMenu(context, details, f),
                        child: ListTile(
                          key: ValueKey('folder-row-${f.id}'),
                          contentPadding: EdgeInsets.only(
                            left: 16 + entry.depth * 24,
                            right: 8,
                          ),
                          leading: const Icon(Icons.folder),
                          title: Text(f.name),
                          subtitle: f.parentId == null
                              ? null
                              : Text(_folderPath(f, folders)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '编辑文件夹',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _edit(context, ref, f, folders),
                              ),
                              IconButton(
                                // 嘀嗒 :28「解散文件夹」——文案统一。
                                tooltip: '解散文件夹',
                                icon: const Icon(Icons.delete_sweep_outlined),
                                onPressed: () => _delete(context, ref, f),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    TodoFolder f,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx,
      details.globalPosition.dy,
      overlay.size.width - details.globalPosition.dx,
      0,
    );
    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          key: Key('folder-context-disband'),
          value: 'disband',
          child: Text('解散文件夹'),
        ),
      ],
    ).then((action) {
      if (action == 'disband' && context.mounted) {
        confirmAndDisbandFolder(context, f);
      }
    });
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    List<TodoFolder> folders,
  ) async {
    final result = await _promptFolder(context, folders: folders);
    if (result == null) return;
    final repo = ref.read(folderRepositoryProvider);
    if (repo == null) return;
    await repo.create(result.$1, parentId: result.$2);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    TodoFolder folder,
    List<TodoFolder> folders,
  ) async {
    final result = await _promptFolder(
      context,
      folders: folders,
      editingFolderId: folder.id,
      initialName: folder.name,
      initialParentId: folder.parentId,
    );
    if (result == null) return;
    final repo = ref.read(folderRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.rename(folder.id, result.$1);
      if (result.$2 != folder.parentId) {
        await repo.moveToParent(folder.id, result.$2);
      }
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TodoFolder folder,
  ) async {
    // 口径收进 folder_actions.dart：侧栏长按与这里走同一个确认框、同一个词
    // （嘀嗒 :28「解散文件夹」）。`ref` 保留在签名里，弹层自己按 provider 取仓库。
    await confirmAndDisbandFolder(context, folder);
  }

  Future<(String, String?)?> _promptFolder(
    BuildContext context, {
    required List<TodoFolder> folders,
    String? editingFolderId,
    String? initialName,
    String? initialParentId,
  }) async {
    final ctrl = TextEditingController(text: initialName ?? '');
    String? parentId = initialParentId;
    final parentChoices = folders
        .where((folder) => _canUseAsParent(folder, editingFolderId, folders))
        .toList(growable: false);
    return showDialog<(String, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(editingFolderId == null ? '新建文件夹' : '编辑文件夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '文件夹名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '父文件夹',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButton<String>(
                  key: const Key('folder-parent-picker'),
                  value: parentId ?? _rootParentValue,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                      value: _rootParentValue,
                      child: Text('顶层文件夹'),
                    ),
                    ...parentChoices.map(
                      (folder) => DropdownMenuItem(
                        value: folder.id,
                        child: Text(_folderPath(folder, folders)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => parentId = value == _rootParentValue ? null : value,
                  ),
                ),
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
                final name = ctrl.text.trim();
                if (name.isNotEmpty) Navigator.pop(ctx, (name, parentId));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  bool _canUseAsParent(
    TodoFolder candidate,
    String? editingFolderId,
    List<TodoFolder> folders,
  ) {
    if (editingFolderId == null) return true;
    if (candidate.id == editingFolderId) return false;
    final byId = {for (final folder in folders) folder.id: folder};
    final visited = <String>{};
    TodoFolder? current = candidate;
    while (current != null && visited.add(current.id)) {
      if (current.parentId == editingFolderId) return false;
      current = current.parentId == null ? null : byId[current.parentId!];
    }
    return true;
  }

  String _folderPath(TodoFolder folder, List<TodoFolder> folders) {
    final byId = {for (final item in folders) item.id: item};
    final names = <String>[];
    final visited = <String>{};
    TodoFolder? current = folder;
    while (current != null && visited.add(current.id)) {
      names.add(current.name);
      current = current.parentId == null ? null : byId[current.parentId!];
    }
    return names.reversed.join(' / ');
  }

  static const _rootParentValue = '__root__';
}

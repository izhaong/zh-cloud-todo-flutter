import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';

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
            icon: const Icon(Icons.add),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: foldersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载文件夹失败: $e')),
        data: (folders) => folders.isEmpty
            ? const Center(child: Text('暂无文件夹'))
            : ListView.builder(
                itemCount: folders.length,
                itemBuilder: (_, i) {
                  final f = folders[i];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(f.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(context, ref, f),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, f),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, '新建文件夹');
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).create(name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    TodoFolder folder,
  ) async {
    final name = await _promptName(
      context,
      '重命名文件夹',
      initial: folder.name,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(folderRepositoryProvider).rename(folder.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TodoFolder folder,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件夹'),
        content: Text('确认删除"${folder.name}"？\n其下清单将移至"未分组"。'),
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
    if (ok == true) {
      await ref.read(folderRepositoryProvider).delete(folder.id);
    }
  }

  Future<String?> _promptName(
    BuildContext context,
    String title, {
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
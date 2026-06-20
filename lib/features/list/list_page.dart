import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';
import 'list_editor_sheet.dart';
import '../folder/folder_page.dart';
import '../tag/tag_page.dart';

/// M11-B2 清单列表页。
///
/// - 顶部固定 4 个智能清单：今日 / 全部 / 已完成 / 已过期
/// - 下方按 folderId 分组显示普通清单
/// - 长按弹编辑器（创建/重命名/删除 + 未完成任务拦截）
/// - 拖拽排序：向上/向下按钮（避免引入第三方包）
class ListPage extends ConsumerStatefulWidget {
  const ListPage({super.key});

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  Future<void> _openCreateSheet({int? folderId, TodoList? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ListEditorSheet(
        folderId: folderId,
        existing: existing,
      ),
    );
  }

  Future<void> _deleteList(TodoList list) async {
    final db = ref.read(appDatabaseProvider);
    final open = await db.countOpenTasksByList(list.id);
    if (!mounted) return;
    if (open > 0) {
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('清单有未完成任务'),
          content: Text('"${list.name}" 仍有 $open 项未完成。\n确认删除？'),
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
      if (force != true) return;
    }
    await ref.read(listRepositoryProvider).delete(list.id);
  }

  Future<void> _move(TodoList list, int delta) async {
    final lists = await ref.read(listRepositoryProvider).getAll();
    final inFolder = lists.where((l) => l.folderId == list.folderId).toList();
    inFolder.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      if (c != 0) return c;
      return a.createdAt.compareTo(b.createdAt);
    });
    final idx = inFolder.indexWhere((l) => l.id == list.id);
    if (idx < 0) return;
    final newIdx = idx + delta;
    if (newIdx < 0 || newIdx >= inFolder.length) return;
    final tmp = inFolder[idx];
    inFolder[idx] = inFolder[newIdx];
    inFolder[newIdx] = tmp;
    await ref
        .read(listRepositoryProvider)
        .reorder(inFolder.map((l) => l.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('清单'),
        actions: [
          IconButton(
            tooltip: '文件夹',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FolderPage()),
            ),
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            tooltip: '标签',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TagPage()),
            ),
            icon: const Icon(Icons.label_outline),
          ),
          IconButton(
            tooltip: '新建清单',
            onPressed: () => _openCreateSheet(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载清单失败: $e')),
        data: (lists) {
          final folders = foldersAsync.valueOrNull ?? const <TodoFolder>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SmartListSection(),
              const SizedBox(height: 12),
              _SectionTitle('文件夹'),
              ...folders.map((f) => _FolderGroup(
                    folder: f,
                    lists: lists.where((l) => l.folderId == f.id).toList(),
                    onCreate: () => _openCreateSheet(folderId: f.id),
                    onTap: (l) => _openCreateSheet(existing: l),
                    onDelete: _deleteList,
                    onMove: _move,
                  )),
              const SizedBox(height: 8),
              _SectionTitle('未分组清单'),
              _UngroupedGroup(
                lists: lists.where((l) => l.folderId == null).toList(),
                onTap: (l) => _openCreateSheet(existing: l),
                onDelete: _deleteList,
                onMove: _move,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmartListSection extends ConsumerWidget {
  const _SmartListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const ListTile(
              dense: true,
              title: Text('智能清单'),
              subtitle: Text('今日 / 全部 / 已完成 / 已过期'),
            ),
            const Divider(height: 1),
            ..._defaultSmartItems.map(
              (it) => ListTile(
                leading: Icon(it.$2),
                title: Text(it.$1),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('智能清单：${it.$1}（在"任务"tab 应用过滤）')),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              dense: true,
              title: Text('已保存的智能清单'),
              subtitle: Text('通过任务页"保存为智能清单"创建'),
            ),
            ...(_userSmartLists(ref).map(
              (l) => ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(l.name.substring('smart:'.length)),
                subtitle: Text(l.createdAt.toIso8601String().substring(0, 10)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('智能清单：${l.name}')),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  static const _defaultSmartItems = [
    ('今日', Icons.today_outlined),
    ('全部', Icons.list_alt),
    ('已完成', Icons.check_circle_outline),
    ('已过期', Icons.history_toggle_off),
  ];

  /// 同步拉取用户保存的 smart 清单。
  List<TodoList> _userSmartLists(WidgetRef ref) {
    return ref.watch(smartListsStreamProvider).valueOrNull ??
        const <TodoList>[];
  }
}

class _FolderGroup extends StatelessWidget {
  const _FolderGroup({
    required this.folder,
    required this.lists,
    required this.onCreate,
    required this.onTap,
    required this.onDelete,
    required this.onMove,
  });

  final TodoFolder folder;
  final List<TodoList> lists;
  final VoidCallback onCreate;
  final ValueChanged<TodoList> onTap;
  final ValueChanged<TodoList> onDelete;
  final Future<void> Function(TodoList, int) onMove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(folder.name),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: onCreate,
            ),
          ),
          if (lists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('文件夹下暂无清单'),
              ),
            ),
          ...lists.map(
            (l) => _ListRow(
              list: l,
              onTap: () => onTap(l),
              onDelete: () => onDelete(l),
              onMove: (delta) => onMove(l, delta),
            ),
          ),
        ],
      ),
    );
  }
}

class _UngroupedGroup extends StatelessWidget {
  const _UngroupedGroup({
    required this.lists,
    required this.onTap,
    required this.onDelete,
    required this.onMove,
  });

  final List<TodoList> lists;
  final ValueChanged<TodoList> onTap;
  final ValueChanged<TodoList> onDelete;
  final Future<void> Function(TodoList, int) onMove;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return const Card(
        child: ListTile(title: Text('暂无未分组清单')),
      );
    }
    return Card(
      child: Column(
        children: lists
            .map(
              (l) => _ListRow(
                list: l,
                onTap: () => onTap(l),
                onDelete: () => onDelete(l),
                onMove: (delta) => onMove(l, delta),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.list,
    required this.onTap,
    required this.onDelete,
    required this.onMove,
  });

  final TodoList list;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<void> Function(int) onMove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.list),
      title: Text(list.name),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '上移',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () => onMove(-1),
          ),
          IconButton(
            tooltip: '下移',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => onMove(1),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
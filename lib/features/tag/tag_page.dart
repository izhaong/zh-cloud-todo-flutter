import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import '../../state/repositories/tag_repository.dart';
import 'tag_color.dart';

/// M11-B2 标签管理页（独立页面）。
class TagPage extends ConsumerWidget {
  const TagPage({super.key, this.initialTagId});

  final String? initialTagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _create(context, ref, tagsAsync.valueOrNull ?? []),
          ),
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载标签失败: $e')),
        data: (tags) => tags.isEmpty
            ? const Center(child: Text('暂无标签'))
            : ListView.builder(
                itemCount: tags.length,
                itemBuilder: (_, i) {
                  final t = tags[i];
                  final selected = t.id == initialTagId;
                  return ListTile(
                    key: Key('tag-search-result-${t.id}'),
                    leading: _ColorDot(colorHex: t.color),
                    title: Text(_tagPath(t, tags)),
                    subtitle: selected ? const Text('搜索定位的标签') : null,
                    selected: selected,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, ref, t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, t),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    List<TodoTag> tags,
  ) async {
    final result = await _promptNameColor(context, tags: tags);
    if (result == null) return;
    final repo = ref.read(tagRepositoryProvider);
    if (repo == null) return;
    await repo.create(name: result.$1, color: result.$2, parentId: result.$3);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, TodoTag tag) async {
    final result = await _promptNameColor(
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

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoTag tag) async {
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
    if (ok == true) {
      final repo = ref.read(tagRepositoryProvider);
      if (repo == null) return;
      await repo.delete(tag.id);
    }
  }

  /// 弹窗：标签名、颜色和本地父标签选择。
  Future<(String, String, String?)?> _promptNameColor(
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
        .where((tag) => _canUseAsParent(tag, editingTagId, tags))
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
                  value: parentId ?? _rootParentValue,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(
                      value: _rootParentValue,
                      child: Text('顶层标签'),
                    ),
                    ...parentChoices.map(
                      (tag) => DropdownMenuItem(
                        value: tag.id,
                        child: Text(_tagPath(tag, tags)),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => parentId = value == _rootParentValue ? null : value,
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
}

const _rootParentValue = '__todo_root_tag__';

bool _canUseAsParent(
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

String _tagPath(TodoTag tag, List<TodoTag> tags, {Set<String>? visiting}) {
  final parentId = tag.parentId;
  if (parentId == null) return tag.name;
  final seen = {...?visiting, tag.id};
  if (seen.contains(parentId)) return tag.name;
  final parent = tags
      .where((candidate) => candidate.id == parentId)
      .firstOrNull;
  if (parent == null) return tag.name;
  return '${_tagPath(parent, tags, visiting: seen)} / ${tag.name}';
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({this.colorHex});
  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: parseHexColor(colorHex),
        shape: BoxShape.circle,
      ),
    );
  }
}

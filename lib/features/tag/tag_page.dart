import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'tag_actions.dart';
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
            tooltip: '新建标签',
            icon: const Icon(Icons.add),
            onPressed: () => _create(context, ref, tagsAsync.valueOrNull ?? []),
          ),
        ],
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载标签失败: ${describeError(e)}')),
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
                    title: Text(tagPath(t, tags)),
                    subtitle: selected ? const Text('搜索定位的标签') : null,
                    selected: selected,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '编辑标签',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, ref, t),
                        ),
                        IconButton(
                          tooltip: '删除标签',
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
    final result = await promptTagFields(context, tags: tags);
    if (result == null) return;
    final repo = ref.read(tagRepositoryProvider);
    if (repo == null) return;
    await repo.create(name: result.$1, color: result.$2, parentId: result.$3);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, TodoTag tag) =>
      promptEditTag(context, ref, tag);

  Future<void> _delete(BuildContext context, WidgetRef ref, TodoTag tag) =>
      confirmAndDeleteTag(context, ref, tag);
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

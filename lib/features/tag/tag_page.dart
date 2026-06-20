import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../state/providers.dart';
import '../../state/repositories/tag_repository.dart';
import 'tag_color.dart';

/// M11-B2 标签管理页（独立页面）。
class TagPage extends ConsumerWidget {
  const TagPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _create(context, ref),
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
                  return ListTile(
                    leading: _ColorDot(colorHex: t.color),
                    title: Text(t.name),
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await _promptNameColor(context);
    if (result == null) return;
    await ref.read(tagRepositoryProvider).create(
          name: result.$1,
          color: result.$2,
        );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    TodoTag tag,
  ) async {
    final result = await _promptNameColor(
      context,
      initialName: tag.name,
      initialColor: tag.color,
    );
    if (result == null) return;
    await ref.read(tagRepositoryProvider).update(
          tag.id,
          name: result.$1,
          color: result.$2,
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TodoTag tag,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确认删除"${tag.name}"？关联任务将解除。'),
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
      await ref.read(tagRepositoryProvider).delete(tag.id);
    }
  }

  /// 弹窗：标签名 + 颜色（8 色）选择。
  Future<(String, String)?> _promptNameColor(
    BuildContext context, {
    String? initialName,
    String? initialColor,
  }) async {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    String? color = initialColor ?? TagRepository.palette.first;
    return showDialog<(String, String)>(
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
                Navigator.pop(ctx, (n, color!));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
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
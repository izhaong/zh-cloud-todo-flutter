import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import 'saved_filter_mapping.dart';

/// 侧栏「筛选器」入口的落地页：列出已保存过滤器、一键套用、二次确认删除。
class SavedFiltersPage extends ConsumerWidget {
  const SavedFiltersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(savedFiltersStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('筛选器')),
      body: filters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('过滤器加载失败')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('还没有保存的过滤器'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _row(context, ref, rows[index]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, TodoFilter row) {
    final parsed = parseSavedFilterConditions(row.conditionJson);
    final applicable = parsed == null
        ? null
        : taskFilterFromSaved(
            parsed.conditions,
            unsupportedKeys: parsed.unsupportedKeys,
          );
    final summary = parsed == null
        ? '条件已损坏，无法套用'
        : applicable == null
        ? '${savedFilterSummary(parsed.conditions, unsupportedKeys: parsed.unsupportedKeys)} · 本机暂不支持套用'
        : savedFilterSummary(
            parsed.conditions,
            unsupportedKeys: parsed.unsupportedKeys,
          );
    // 删除按钮放在 ListTile 之外：`trailing` 会被 ListTile 合并进整行语义节点，
    // 读屏只剩一个长标签、点不到独立的删除动作。
    return Row(
      children: [
        Expanded(
          child: ListTile(
            key: ValueKey('saved-filter-${row.id}'),
            title: Text(row.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(summary),
            onTap: applicable == null
                ? null
                : () => Navigator.pop(context, applicable),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          // IconButton 的 tooltip 只给视觉提示，不产出语义标签 —— 图标按钮必须自带 Semantics 名称。
          child: Semantics(
            button: true,
            label: '删除过滤器',
            child: IconButton(
              key: ValueKey('saved-filter-delete-${row.id}'),
              tooltip: '删除过滤器',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, row),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TodoFilter row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除过滤器'),
        content: Text('「${row.name}」确认删除？'),
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
    if (confirmed != true) return;
    final repo = ref.read(filterRepositoryProvider);
    if (repo == null) return;
    await repo.remove(row.id);
  }
}

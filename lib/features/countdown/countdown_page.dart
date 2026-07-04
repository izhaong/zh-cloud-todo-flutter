import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/efficiency_providers.dart';

/// M11-B4 倒数日列表 + 新建
class CountdownPage extends ConsumerWidget {
  const CountdownPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(countdownsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('倒数日'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreate(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('暂无倒数日'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = items[i];
              final daysLeft = c.targetDate
                  .difference(DateTime.now())
                  .inDays;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(c.color),
                  child: Text(
                    c.isCountUp ? '正' : '倒',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(c.title),
                subtitle: Text(
                  c.isCountUp
                      ? '已 ${-daysLeft} 天'
                      : '还有 $daysLeft 天',
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final titleCtl = TextEditingController();
    DateTime target = DateTime.now().add(const Duration(days: 30));
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('新建倒数日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtl, decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('目标日期: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: target,
                        firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) setState(() => target = picked);
                    },
                    child: Text('${target.year}-${target.month}-${target.day}'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty) return;
                await ref.read(countdownApiProvider).create(
                      title: titleCtl.text.trim(),
                      targetDate: target,
                    );
                ref.invalidate(countdownsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.blue;
  try {
    final s = hex.startsWith('#') ? hex : '#$hex';
    return Color(int.parse(s.substring(1), radix: 16) | 0xFF000000);
  } catch (_) {
    return Colors.blue;
  }
}
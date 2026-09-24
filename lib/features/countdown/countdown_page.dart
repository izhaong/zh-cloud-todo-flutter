import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../state/efficiency_providers.dart';

/// 嘀嗒《02-功能指南/06-倒数纪念日/02-打造专属纪念页.md:97》：
/// 点天数就能在**天、年、周**三种单位间快速切换，循环顺序即源页列举顺序。
enum TodoCountdownUnit {
  day('天'),
  year('年'),
  week('周');

  const TodoCountdownUnit(this.suffix);

  final String suffix;

  TodoCountdownUnit get next =>
      TodoCountdownUnit.values[(index + 1) % TodoCountdownUnit.values.length];
}

/// 只给整数档：源页 `:93` 问的是「这是多少年，或是多少周」，带余数要自创格式。
String countdownCountLabel({
  required bool isCountUp,
  required int daysRemaining,
  required TodoCountdownUnit unit,
}) {
  final days = daysRemaining.abs();
  final amount = switch (unit) {
    TodoCountdownUnit.day => days,
    TodoCountdownUnit.year => days ~/ 365,
    TodoCountdownUnit.week => days ~/ 7,
  };
  return '${isCountUp ? '已' : '还有'} $amount ${unit.suffix}';
}

/// 单位切换是**按行**的会话内状态，所以整行搬到有状态组件里。
class _CountdownTile extends StatefulWidget {
  const _CountdownTile({required this.item});

  final CountdownDto item;

  @override
  State<_CountdownTile> createState() => _CountdownTileState();
}

class _CountdownTileState extends State<_CountdownTile> {
  TodoCountdownUnit _unit = TodoCountdownUnit.day;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final label = countdownCountLabel(
      isCountUp: item.isCountUp,
      daysRemaining: item.daysRemaining,
      unit: _unit,
    );
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          item.isCountUp ? '正' : '倒',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(item.title),
      subtitle: Semantics(
        button: true,
        child: InkWell(
          key: Key('todo-countdown-unit-${item.id}'),
          onTap: () => setState(() => _unit = _unit.next),
          child: Text(label),
        ),
      ),
    );
  }
}

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
              return _CountdownTile(item: c);
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
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('目标日期: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: target,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365 * 5),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 10),
                        ),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleCtl.text.trim().isEmpty) return;
                await ref
                    .read(countdownApiProvider)
                    .create(title: titleCtl.text.trim(), targetDate: target);
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

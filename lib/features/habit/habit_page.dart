import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';
import '../../state/providers.dart';
import 'habit_repository.dart';

/// M11-B4 习惯列表 + 打卡
class HabitPage extends ConsumerWidget {
  const HabitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myHabitsProvider);
    final stats = ref.watch(habitStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreate(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          stats.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (s) => Padding(
              padding: const EdgeInsets.all(12),
              child: AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(
                        label: '连续打卡',
                        value: '${s['currentStreak'] ?? 0}',
                        color: brandColors(context).warning),
                    _Stat(
                        label: '本周完成',
                        value: '${s['weeklyDone'] ?? 0}',
                        color: brandColors(context).today),
                    _Stat(
                        label: '总打卡',
                        value: '${s['totalCheckIns'] ?? 0}',
                        color: brandColors(context).success),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (habits) {
                if (habits.isEmpty) {
                  return AppEmptyState(
                    title: '暂无习惯',
                    subtitle: '开启第一个习惯，培养专注力与自律。',
                  );
                }
                return ListView.separated(
                  itemCount: habits.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _HabitTile(habit: habits[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final ctl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建习惯'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '习惯名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = ctl.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(apiClientProvider).raw.post(
                      '/app-api/todo/habit/create',
                      data: {'name': name, 'targetPerWeek': 7},
                    );
                ref.invalidate(myHabitsProvider);
                ref.invalidate(habitStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('创建失败: $e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: brandColors(context).mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit});
  final HabitDto habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _parseColor(habit.color),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  Text(
                    '目标 ${habit.targetPerWeek} 次/周',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              onPressed: () async {
                await ref.read(habitRepositoryProvider).checkIn(habit.id);
                ref.invalidate(myHabitsProvider);
                ref.invalidate(habitStatsProvider);
              },
              child: const Text('打卡'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.green;
  try {
    final s = hex.startsWith('#') ? hex : '#$hex';
    return Color(int.parse(s.substring(1), radix: 16) | 0xFF000000);
  } catch (_) {
    return Colors.green;
  }
}
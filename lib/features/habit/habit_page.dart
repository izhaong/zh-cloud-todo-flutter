import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';
import 'habit_detail_page.dart';
import 'habit_editor.dart';
import 'habit_repository.dart';

/// M11-B4 习惯列表 + 打卡
class HabitPage extends ConsumerWidget {
  const HabitPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myHabitsProvider);
    final stats = ref.watch(habitStatsProvider);
    // 重取失败时 AsyncError 仍带着上一次的 value（由 test/features/habit/habit_page_test.dart 量出），
    // 但 `.when` 按分支判别，会把已加载的数据整块丢掉 ⇒ 判据走 valueOrNull：有值就先渲染值。
    final habits = async.valueOrNull;
    final statsData = stats.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('习惯'),
        actions: [
          IconButton(
            tooltip: '新建习惯',
            icon: const Icon(Icons.add),
            onPressed: () async {
              if (await showHabitEditor(context) && context.mounted) {
                ref.invalidate(myHabitsProvider);
                ref.invalidate(habitStatsProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (stats.hasError && statsData != null)
            AppRefreshFailedHint(
              message: '统计刷新失败，显示的是上一次数据',
              onRetry: () => ref.invalidate(habitStatsProvider),
            ),
          if (statsData != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(
                      label: '连续打卡',
                      value: '${statsData['currentStreak'] ?? 0}',
                      color: brandColors(context).warning,
                    ),
                    _Stat(
                      label: '本周完成',
                      value: '${statsData['weeklyDone'] ?? 0}',
                      color: brandColors(context).today,
                    ),
                    _Stat(
                      label: '总打卡',
                      value: '${statsData['totalCheckIns'] ?? 0}',
                      color: brandColors(context).success,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: habits == null
                ? (async.hasError
                      ? _ListLoadFailed(
                          message: '加载失败: ${describeError(async.error)}',
                          onRetry: () => ref.invalidate(myHabitsProvider),
                        )
                      : const Center(child: CircularProgressIndicator()))
                : (async.hasError
                      ? Column(
                          children: [
                            AppRefreshFailedHint(
                              message: '列表刷新失败，仍显示上一次的数据',
                              onRetry: () => ref.invalidate(myHabitsProvider),
                            ),
                            Expanded(child: _HabitList(habits: habits)),
                          ],
                        )
                      : _HabitList(habits: habits)),
          ),
        ],
      ),
    );
  }
}

class _HabitList extends StatelessWidget {
  const _HabitList({required this.habits});

  final List<HabitDto> habits;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return const AppEmptyState(title: '暂无习惯', subtitle: '开启第一个习惯，培养专注力与自律。');
    }
    return ListView.separated(
      itemCount: habits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _HabitTile(habit: habits[i]),
    );
  }
}

/// 首值就没读到才走这里。
class _ListLoadFailed extends StatelessWidget {
  const _ListLoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
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
    // 嘀嗒：点习惯先进详情页，管理动作在详情页的「...」里，不在列表行上做菜单。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AppCard(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  HabitDetailPage(habitId: habit.id, initial: habit),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: habitColor(habit.color, colors.success),
                child: Icon(
                  habitIconChoices[habit.icon] ?? Icons.check,
                  color: Colors.white,
                  size: 18,
                ),
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
                      _targetLabel(habit),
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
      ),
    );
  }
}

String _targetLabel(HabitDto habit) {
  return '${habitPeriodLabel(habit.period)} ${habit.targetCount} 次';
}

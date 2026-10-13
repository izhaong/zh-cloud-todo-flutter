import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';
import 'habit_detail_page.dart';
import 'habit_editor.dart';
import 'habit_repository.dart';
import 'habit_smart_list_visibility.dart';
import 'habit_week_stats.dart';

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
          // 嘀嗒《03-习惯数据统计》:29「点击习惯页面中的统计图标，就能够
          // 查看到所有习惯的打卡情况」——入口进周视图统计页（FL #542）。
          // 嘀嗒《02-更好地完成习惯》:66「可在习惯页面右上角点击管理图标，
          // 选择『在“今天”、“最近7天”中显示』」（specs/130，矩阵 #45 面 ⑤）。
          const HabitSmartListVisibilityAction(),
          Semantics(
            label: '打卡统计',
            button: true,
            child: IconButton(
              key: const Key('habit-stats-entry'),
              tooltip: '打卡统计',
              icon: const Icon(Icons.insert_chart_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HabitWeekStatsPage(),
                ),
              ),
            ),
          ),
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

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(habitRepositoryProvider);
    if (habit.recordType == 2) {
      // 手动记录档：嘀嗒打卡时可输入「本次完成的量」，不输入就是没打。
      final amount = await showHabitAmountSheet(context);
      if (amount == null) return;
      await repo.checkIn(habit.id, amount: amount);
    } else {
      await repo.checkIn(habit.id);
    }
    ref.invalidate(myHabitsProvider);
    ref.invalidate(habitStatsProvider);
  }

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
                onPressed: () => _checkIn(context, ref),
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
  final base = '${habitPeriodLabel(habit.period)} ${habit.targetCount} 次';
  // 打卡方式只在非默认档（自动记录）时补一句，读得出来这行的计数口径。
  final type = habitRecordTypeChoices[habit.recordType];
  return habit.recordType == 1 || type == null ? base : '$base · $type';
}

/// 手动记录档的「本次完成量」输入弹层；取消或关掉返回 null（不打卡）。
Future<int?> showHabitAmountSheet(BuildContext context) async {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const _HabitAmountSheet(),
  );
}

class _HabitAmountSheet extends StatefulWidget {
  const _HabitAmountSheet();

  @override
  State<_HabitAmountSheet> createState() => _HabitAmountSheetState();
}

class _HabitAmountSheetState extends State<_HabitAmountSheet> {
  final _amount = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _confirm() {
    final value = int.tryParse(_amount.text.trim());
    if (value == null || value < 1) {
      setState(() => _error = '完成量至少为 1');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本次完成量', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('habit-checkin-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '完成量', errorText: _error),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                key: const Key('habit-checkin-confirm'),
                onPressed: _confirm,
                child: const Text('打卡'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

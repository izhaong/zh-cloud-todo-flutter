import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';
import '../shell/app_dialog.dart';
import 'habit_editor.dart';
import 'habit_repository.dart';

/// 嘀嗒《01-开始坚持一个习惯》:58「点击习惯进入详情页，点击右上角「...」，
/// 可进行编辑、开始专注、分享、归档或删除等操作」——本文件只做「编辑」「删除」：
/// 归档的 `PUT /habit/{id}/archived` 只在未合并的 zh-cloud-service!276 里，
/// 「开始专注」「分享」属其它功能，均不在 specs/037 范围。
class HabitDetailPage extends ConsumerWidget {
  const HabitDetailPage({
    super.key,
    required this.habitId,
    required this.initial,
  });

  final int habitId;
  final HabitDto initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fresh = ref.watch(myHabitsProvider).valueOrNull;
    final habit = _findById(fresh, habitId) ?? initial;
    return Scaffold(
      key: const Key('habit-detail-page'),
      appBar: AppBar(
        title: Text(habit.name, overflow: TextOverflow.ellipsis),
        actions: [
          // PopupMenuButton 自带的 tooltip 在测试里拿不到语义节点（实测 0 命中），
          // 所以显式补一个标签，读屏才念得出这是「更多操作」。
          Semantics(
            label: '更多操作',
            button: true,
            child: PopupMenuButton<String>(
              key: const Key('habit-detail-menu'),
              tooltip: '更多操作',
              onSelected: (action) => switch (action) {
                'edit' => _edit(context, ref, habit),
                'delete' => _confirmDelete(context, ref, habit),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _HabitHeader(habit: habit),
          const SizedBox(height: 12),
          AppCard(
            child: Text(
              _subtitle(habit),
              style: TextStyle(
                fontSize: 13,
                color: brandColors(context).mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(HabitDto habit) {
    final reminder = habit.reminderAt == null
        ? ''
        : ' · '
              '${habit.reminderAt!.hour.toString().padLeft(2, '0')}:'
              '${habit.reminderAt!.minute.toString().padLeft(2, '0')} 提示';
    return '${habitPeriodLabel(habit.period)} ${habit.targetCount} 次$reminder';
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    HabitDto habit,
  ) async {
    if (await showHabitEditor(context, habit: habit) && context.mounted) {
      ref.invalidate(myHabitsProvider);
      ref.invalidate(habitStatsProvider);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HabitDto habit,
  ) async {
    // 措辞取嘀嗒《02-更好地完成习惯》:122，与「归档」区分开。
    // 注意：后端 /habit/delete 目前不级联打卡记录，该承诺由 Service 侧补齐（specs/037 tasks.md 契约缺口）。
    final confirmed = await AppDialog.confirm(
      context,
      title: '删除习惯',
      content: '删除后，该习惯将被永久移除，所有打卡记录也会被清空，无法恢复。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(habitRepositoryProvider).delete(habit.id);
      ref.invalidate(myHabitsProvider);
      ref.invalidate(habitStatsProvider);
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('删除失败: $error')));
    }
  }
}

HabitDto? _findById(List<HabitDto>? list, int id) {
  if (list == null) return null;
  for (final habit in list) {
    if (habit.id == id) return habit;
  }
  return null;
}

class _HabitHeader extends StatelessWidget {
  const _HabitHeader({required this.habit});

  final HabitDto habit;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: habitColor(habit.color, colors.accent),
            child: Icon(
              habitIconChoices[habit.icon] ?? Icons.check,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

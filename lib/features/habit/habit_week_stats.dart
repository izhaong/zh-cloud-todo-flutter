import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';
import 'habit_repository.dart';

/// 嘀嗒《05-习惯打卡/03-习惯数据统计》:28/:29/:33/:34（FL #542，矩阵 #46 ④）：
/// 「点击习惯页面中的统计图标，就能够查看到所有习惯的打卡情况」。
/// 本单做周视图（行=习惯、列=周一…周日）；整月视图按 2026-09-23 范围裁定
/// 属商业化不做；「记录回顾」时间轴依赖打卡日志（#45 ④），不在本单。
/// 窗口与「今天」全部从服务端 dailyCounts 读（WEEK 窗口＝自然周周一，
/// 覆盖起点到今天），不拿本地时钟猜——时区漂移时两边会差一天。

class HabitWeekRow {
  HabitWeekRow({required this.habit, required this.counts});

  final HabitDto habit;
  final Map<DateTime, int> counts;
}

class HabitWeekResult {
  HabitWeekResult({required this.rows, required this.failedIds});

  final List<HabitWeekRow> rows;
  final Set<int> failedIds;

  bool get hasFailure => failedIds.isNotEmpty;
}

final habitWeekStatsProvider = FutureProvider.autoDispose<HabitWeekResult>((
  ref,
) async {
  final repo = ref.watch(habitRepositoryProvider);
  final habits = await ref.watch(myHabitsProvider.future);
  final rows = <HabitWeekRow>[];
  final failed = <int>{};
  // 逐习惯拉 WEEK；单个失败不拖垮整页——已加载的行照常画，
  // 失败的 habitId 收进 failedIds 给可见提示（specs/045 同形）。
  for (final habit in habits) {
    try {
      final stats = await repo.stats(habit.id, period: 'WEEK');
      final counts = <DateTime, int>{};
      for (final entry in (stats['dailyCounts'] as List? ?? const [])) {
        if (entry is! Map) continue;
        final date = DateTime.tryParse('${entry['date']}');
        if (date == null) continue;
        counts[DateTime(date.year, date.month, date.day)] =
            (entry['count'] as num?)?.toInt() ?? 0;
      }
      rows.add(HabitWeekRow(habit: habit, counts: counts));
    } catch (_) {
      failed.add(habit.id);
    }
  }
  return HabitWeekResult(rows: rows, failedIds: failed);
});

String _cellDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _headerDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class HabitWeekStatsPage extends ConsumerWidget {
  const HabitWeekStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = brandColors(context);
    final async = ref.watch(habitWeekStatsProvider);
    final result = async.valueOrNull;

    Widget body;
    if (result == null) {
      body = async.hasError
          ? Center(
              child: AppRefreshFailedHint(
                key: const Key('habit-week-retry'),
                message: '打卡统计加载失败',
                onRetry: () => ref.invalidate(habitWeekStatsProvider),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else if (result.rows.isEmpty) {
      body = const Center(
        child: AppEmptyState(title: '暂无习惯', subtitle: '先创建习惯，再来看打卡统计。'),
      );
    } else {
      final window = _windowOf(result.rows);
      body = ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _WeekHeader(start: window.$1, colors: colors),
          const SizedBox(height: 8),
          for (final row in result.rows) ...[
            _WeekRow(
              habit: row.habit,
              counts: row.counts,
              window: window,
              colors: colors,
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return Scaffold(
      key: const Key('habit-week-stats-page'),
      appBar: AppBar(title: const Text('打卡统计')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: colors.accent,
              onRefresh: () async {
                ref.invalidate(habitWeekStatsProvider);
                try {
                  await ref.read(habitWeekStatsProvider.future);
                } catch (_) {}
              },
              child: body,
            ),
          ),
          if (result != null && result.hasFailure)
            AppRefreshFailedHint(
              key: const Key('habit-week-retry'),
              message: '部分习惯统计刷新失败，已加载的照常显示',
              onRetry: () => ref.invalidate(habitWeekStatsProvider),
            ),
        ],
      ),
    );
  }

  /// 窗口起点 = 各行最早日期；今天 = 各行最晚日期（服务端 WEEK 从周一发到今天）。
  /// 7 列补齐到周日，今天之后的格子按「还没到」画。
  (DateTime, DateTime) _windowOf(List<HabitWeekRow> rows) {
    DateTime? start;
    DateTime? today;
    for (final row in rows) {
      for (final day in row.counts.keys) {
        if (start == null || day.isBefore(start)) start = day;
        if (today == null || day.isAfter(today)) today = day;
      }
    }
    start ??= DateTime.now();
    today ??= start;
    return (start, today);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.start, required this.colors});

  final DateTime start;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 84),
        for (var i = 0; i < 7; i++)
          SizedBox(
            width: 30,
            child: Text(
              _headerDate(start.add(Duration(days: i))),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.mutedForeground),
            ),
          ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.habit,
    required this.counts,
    required this.window,
    required this.colors,
  });

  final HabitDto habit;
  final Map<DateTime, int> counts;
  final (DateTime, DateTime) window;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final (start, today) = window;
    return Row(
      key: ValueKey('habit-week-row-${habit.id}'),
      children: [
        SizedBox(
          width: 84,
          child: Text(
            habit.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _cell(start.add(Duration(days: i)), today),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(DateTime day, DateTime today) {
    final isFuture = day.isAfter(today);
    final count = counts[day];
    final label = isFuture
        ? '${day.month}月${day.day}日 还没到'
        : (count ?? 0) > 0
        ? '${day.month}月${day.day}日 打卡$count次'
        : '${day.month}月${day.day}日 没有打卡';
    final filled = !isFuture && (count ?? 0) > 0;
    return Semantics(
      label: label,
      child: Container(
        key: Key('habit-week-cell-${habit.id}-${_cellDate(day)}'),
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? colors.accent
              : (isFuture ? Colors.transparent : colors.muted),
          borderRadius: BorderRadius.circular(6),
          border: isFuture ? Border.all(color: colors.mutedForeground) : null,
        ),
        child: filled
            ? ExcludeSemantics(
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

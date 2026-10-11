import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/efficiency_providers.dart';

/// 嘀嗒《05-习惯打卡/03-习惯数据统计.md》:6/:10/:24（FL #377）：
/// 详情页滚动区给「打卡数据」三项，卡片「更多」进「年度热力统计页」。
/// 数字只取服务端已给且窗口内可复算的三项；不造「完成率」——
/// 服务端 !283 已把写死的 0.85 摘成 null（zh-cloud-service #281）。
/// 窗口钉 YEAR（本年 1 月 1 号起，service #303 的日历规则），标签「本年」与之对齐。
final habitYearStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, habitId) {
      final repo = ref.watch(habitRepositoryProvider);
      return repo.stats(habitId, period: 'YEAR');
    });

/// 「刷新失败保留已加载数据」（specs/045 同形）：FutureProvider 失败后
/// valueOrNull 归零，靠 widget 自己的状态把上一份数据留在屏上。
Map<String, dynamic>? _retain(
  Map<String, dynamic>? incoming,
  Map<String, dynamic>? cached,
) {
  if (incoming != null) return incoming;
  return cached;
}

class HabitStatsCard extends ConsumerStatefulWidget {
  const HabitStatsCard({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<HabitStatsCard> createState() => _HabitStatsCardState();
}

class _HabitStatsCardState extends ConsumerState<HabitStatsCard> {
  Map<String, dynamic>? _seen;

  @override
  Widget build(BuildContext context) {
    final provider = habitYearStatsProvider(widget.habitId);
    final async = ref.watch(provider);
    if (async.hasValue) _seen = async.value;
    final data = _retain(async.valueOrNull, _seen);
    final colors = brandColors(context);

    final children = <Widget>[
      Row(
        children: [
          Text(
            '打卡数据',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          const Spacer(),
          Text(
            '本年',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ],
      ),
      const SizedBox(height: 10),
      data == null
          // 失败态不放转圈：placeholder 会永久动画，页面既不报错也不可用。
          ? (async.hasError ? const SizedBox.shrink() : _placeholder(colors))
          : Row(
              children: [
                _stat(
                  colors,
                  'habit-stats-total',
                  '${data['totalCheckIns'] ?? 0}',
                  '累计打卡',
                ),
                _stat(
                  colors,
                  'habit-stats-streak',
                  '${data['continuousDays'] ?? 0}',
                  '连续天数',
                ),
                _stat(
                  colors,
                  'habit-stats-longest',
                  '${data['longestContinuous'] ?? 0}',
                  '最长连续',
                ),
              ],
            ),
      if (data != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('habit-stats-more'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HabitYearHeatmapPage(habitId: widget.habitId),
              ),
            ),
            child: const Text('更多'),
          ),
        ),
      ],
    ];

    return AppCard(
      key: const Key('habit-stats-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          if (async.hasError)
            AppRefreshFailedHint(
              key: const Key('habit-stats-retry'),
              message: '打卡数据刷新失败',
              onRetry: () => ref.invalidate(provider),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.accent,
          ),
        ),
      ),
    );
  }

  Widget _stat(AppColors colors, String key, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            key: Key(key),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// 年度热力统计页（:24「年度热力统计页，方便你回顾这一年的完成情况」）。
/// 格子逐日渲染服务端 YEAR 窗口给的 dailyCounts（一天一格、首格 01-01）；
/// 53 周横向滚动承载，不缩字号。
class HabitYearHeatmapPage extends ConsumerStatefulWidget {
  const HabitYearHeatmapPage({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<HabitYearHeatmapPage> createState() =>
      _HabitYearHeatmapPageState();
}

class _HabitYearHeatmapPageState extends ConsumerState<HabitYearHeatmapPage> {
  Map<String, dynamic>? _seen;

  @override
  Widget build(BuildContext context) {
    final provider = habitYearStatsProvider(widget.habitId);
    final async = ref.watch(provider);
    if (async.hasValue) _seen = async.value;
    final data = _retain(async.valueOrNull, _seen);
    final colors = brandColors(context);

    final body = data == null
        ? (async.hasError
              ? Center(
                  child: Text(
                    '年度热力加载失败',
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
        : _buildGrid(context, data);

    return Scaffold(
      key: const Key('habit-year-heatmap-page'),
      appBar: AppBar(title: const Text('年度热力统计')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: colors.accent,
              onRefresh: () async {
                ref.invalidate(provider);
                // 失败要让 onRefresh 正常收尾（异常抛进 RefreshIndicator
                // 会成未处理错误），失败态交给下方 AppRefreshFailedHint 呈现。
                try {
                  await ref.read(provider.future);
                } catch (_) {}
              },
              child: body,
            ),
          ),
          if (async.hasError)
            AppRefreshFailedHint(
              key: const Key('habit-year-retry'),
              message: '年度热力刷新失败',
              onRetry: () => ref.invalidate(provider),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, Map<String, dynamic> data) {
    final colors = brandColors(context);
    final counts = <DateTime, int>{};
    final order = <DateTime>[];
    for (final entry in (data['dailyCounts'] as List? ?? const [])) {
      if (entry is! Map) continue;
      final date = DateTime.tryParse('${entry['date']}');
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (!counts.containsKey(day)) order.add(day);
      counts[day] = (entry['count'] as num?)?.toInt() ?? 0;
    }
    if (order.isEmpty) {
      return Center(
        child: Text(
          '本年还没有打卡记录',
          style: TextStyle(color: colors.mutedForeground),
        ),
      );
    }
    const cell = 13.0;
    const gap = 2.0;
    // 第一天按周一为首列对齐（与仓内 timeline/calendar 视图同一口径）；
    // 优点：周一 = 0 时首列顶格。首列空格不带语义，避免念出假日期。
    final leading = (order.first.weekday - 1) % 7;
    final rows = 7;
    final columns = (leading + order.length + rows - 1) ~/ rows;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++)
        const SizedBox(width: cell, height: cell),
      for (final day in order) _cell(colors, day, counts[day] ?? 0),
    ];
    final columnsWidgets = <Widget>[
      for (var c = 0; c < columns; c++)
        Column(
          children: [
            for (var r = 0; r < rows; r++)
              (c * rows + r) < cells.length
                  ? cells[c * rows + r]
                  : const SizedBox(width: cell, height: cell),
          ],
        ),
    ];
    // 外层必须有一根纵向可滚轴：RefreshIndicator 只认纵向 ScrollNotification，
    // 只有横向滚轴时下拉刷新永远不触发（真机同样中招，不只是测试问题）。
    return SingleChildScrollView(
      // 整年格子高约百来 px，小于视口 ⇒ 默认 Clamping 物理会拒绝拖动，
      // 不加 AlwaysScrollable 连下拉手势都进不来（真机同样中招）。
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in columnsWidgets)
              Padding(
                padding: const EdgeInsets.only(right: gap),
                child: column,
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(AppColors colors, DateTime day, int count) {
    final key =
        'habit-heat-cell-'
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        label: '${day.month}月${day.day}日 打卡$count次',
        child: Container(
          key: Key(key),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: count > 0 ? colors.accent : colors.muted,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

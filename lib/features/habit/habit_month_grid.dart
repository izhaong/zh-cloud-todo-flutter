import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../state/efficiency_providers.dart';
import 'habit_repository.dart';

/// 嘀嗒《02-功能指南/05-习惯打卡/02-更好地完成习惯.md》的两面：
/// `:72`-`:88`「月度打卡表」（`:77` 原文「点击习惯进入打卡页面，向上滑动即可查看当月打卡情况」——
/// 本端点一下就出表、不等向上滑动，这一处与源页不一致已记在 spec 的取舍里）与
/// `:94`「在「月度打卡表」中点击任意日期，即可补记打卡」。
Future<void> showHabitMonthSheet(BuildContext context, HabitDto habit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => HabitMonthSheet(habit: habit),
  );
}

/// 与 `HabitRepository.checkIn` 发给后端的 `checkedAt` 同一套日期串，
/// 也和 `AppTodoHabitStatsRespVO.DailyCountVO.date` 对齐。
String habitDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// 当月每一天，按日期顺序。源页只说「点击任意日期」，没规定首日要按周几对齐，
/// 所以不插空格子、也不加周一/周日表头（那都是发明）。
List<DateTime> habitMonthDays(DateTime month) {
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  return List.generate(
    dayCount,
    (i) => DateTime(month.year, month.month, i + 1),
  );
}

/// 这一格的日子到了没有。嘀嗒《02-更好地完成习惯》`:94`「在「月度打卡表」中点击任意日期，
/// 即可补记打卡」补的是**已经发生而漏记**的日子；后端 `TodoHabitServiceImpl.getStats`
/// 的窗口写死 `to = LocalDateTime.now()`（`:125`）而 `checkIn`（`:105`）不校验未来时间 ⇒
/// 补到未来的记录能落库，却永远进不了 `dailyCounts` 与 `total`：用户点了、存了、看不见。
bool habitIsFutureDay(DateTime day, DateTime today) {
  final startOfToday = DateTime(today.year, today.month, today.day);
  // 两边都削到「当天零点」再比：只比时间戳的话，今天 23:59 会被判成未来日（用例钉着）。
  return DateTime(day.year, day.month, day.day).isAfter(startOfToday);
}

class HabitMonthSheet extends ConsumerStatefulWidget {
  const HabitMonthSheet({required this.habit, super.key});

  final HabitDto habit;

  @override
  ConsumerState<HabitMonthSheet> createState() => _HabitMonthSheetState();
}

class _HabitMonthSheetState extends ConsumerState<HabitMonthSheet> {
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late final DateTime _month = DateTime(_today.year, _today.month);
  Map<String, int> _counts = const {};
  bool _loading = true;
  String? _error;

  /// 「这一天还没到」的提示：不是错误，所以不借用错误条（错误条一说「失败」就等于
  /// 承认刚才那一下本该成功）。
  String? _notice;

  /// 连点两格会先后发两次 `stats`：只有最后一次的回包能写进 state，
  /// 先发后到的旧包直接丢弃（否则旧次数会盖掉刚补记回来的新次数）。
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(habitRepositoryProvider);
    final seq = ++_loadSeq;
    try {
      final stats = await repo.stats(widget.habit.id, period: 'MONTH');
      final counts = <String, int>{};
      final dailyCounts = stats['dailyCounts'];
      if (dailyCounts is List) {
        for (final entry in dailyCounts) {
          if (entry is! Map) continue;
          final date = entry['date']?.toString();
          if (date == null || date.isEmpty) continue;
          counts[date] = (entry['count'] as num?)?.toInt() ?? 0;
        }
      }
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _counts = counts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = '当月打卡情况加载失败：${describeError(e)}';
      });
    }
  }

  Future<void> _backfill(DateTime day) async {
    if (habitIsFutureDay(day, _today)) {
      // 静默早退是不行的（同 Issue #292 的口径）：这一格看着和别的格子一模一样，
      // 点了没反应只会让人以为「补记没生效」，然后去重试或者怪 App。
      setState(() {
        _error = null;
        _notice = '这个日期还没到，不能补记';
      });
      return;
    }
    setState(() => _notice = null);
    final repo = ref.read(habitRepositoryProvider);
    try {
      await repo.checkIn(widget.habit.id, date: day);
    } catch (e) {
      // 失败只换错误条，_counts 原样留着 ⇒ 已渲染的当月格子不丢
      if (!mounted) return;
      setState(() => _error = '补记失败：${describeError(e)}');
      return;
    }
    await _load();
    if (!mounted) return;
    // 补记会改变「打卡概览」那一排统计的累计值，所以刷的是概览 provider；
    // 月表自己的次数走上面那次 _load，两者不是同一条通道。
    ref.invalidate(habitStatsProvider);
  }

  int _countOf(DateTime day) => _counts[habitDayKey(day)] ?? 0;

  String _cellLabel(DateTime day) {
    if (habitIsFutureDay(day, _today)) {
      // 「未打卡」是一句关于过去的断言，安在还没到的日子上是假话（读屏会念「26 日，未打卡」）。
      return '${day.day} 日，还没到';
    }
    final count = _countOf(day);
    return count > 0 ? '${day.day} 日，打卡 $count 次' : '${day.day} 日，未打卡';
  }

  @override
  Widget build(BuildContext context) {
    final days = habitMonthDays(_month);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度打卡表',
              key: const ValueKey('todo-habit-month-title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${_month.year} 年 ${_month.month} 月'),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('todo-habit-month-error'),
                style: TextStyle(color: colors.error),
              ),
            if (_notice != null)
              Text(
                _notice!,
                key: const ValueKey('todo-habit-month-notice'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.count(
                key: const ValueKey('todo-habit-month-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (final day in days)
                    Semantics(
                      button: true,
                      label: _cellLabel(day),
                      child: InkWell(
                        key: ValueKey('todo-habit-day-${habitDayKey(day)}'),
                        onTap: () => _backfill(day),
                        child: ColoredBox(
                          color: _countOf(day) > 0
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          child: Center(
                            // 这一格的 Semantics(label:) 会把子 Text 并进同一个节点
                            // （实测 label = 「N 日，打卡 M 次\nM」），读屏会重复播报。
                            child: ExcludeSemantics(
                              child: Text(
                                _countOf(day) > 0
                                    ? '${_countOf(day)}'
                                    : '${day.day}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

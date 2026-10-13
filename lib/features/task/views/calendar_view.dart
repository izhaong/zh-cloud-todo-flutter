import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/time/task_time_mode.dart';
import '../../../core/time/week_start.dart';
import '../../../core/api/todo_api.dart';
import '../../../core/widgets/app_widgets.dart';
import 'timeline_color.dart';
import '../../../state/providers.dart';
import '../task_detail_page.dart';
import '../task_view_mutation_feedback.dart';

/// M11-B3 日历视图：周 / 月 / 年 / 列表 / 日程 5 模式。
///
/// 任务落点优先级：dueAt > endAt > startAt。
/// - 月模式：7x6 网格，列顺序与行起点由「设置-日期与时间-星期开始于」决定
///   （默认周一）；行 = 自然周；点日期格进入日程模式
/// - 周模式：7 列横排，取哪 7 天同样由该偏好决定；每列内是该天的任务列表
/// - 年模式：12 月聚合（每月任务计数 + 切换月份）
/// - 列表模式：所有任务按日期排序的扁平列表
/// - 日程模式：所有有时间的任务按日期升序排成一条跨日时间轴（日内按时间）
///
/// 纯函数：
///   - [resolveTaskDate] 取单个任务落点日期
///   - [buildMonthGrid] 生成月模式网格
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({
    super.key,
    required this.tasks,
    DateTime? now,
    this.onTaskSelected,
    this.onTaskDateChanged,
    this.filterCompleted = true,
  }) : _now = now;

  final DateTime? _now;
  final List<TodoTask> tasks;
  final ValueChanged<String>? onTaskSelected;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  /// 日历自身的「显示已完成」设置是否参与过滤。清单页的日历由清单筛选决定，
  /// 传 false —— 否则用户筛「只看已完成」再切到日历会被叠成空列表；
  /// 此时「显示设置」入口一并隐藏，因为这个开关在这里没有可见效果。
  final bool filterCompleted;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late DateTime _anchor;
  CalendarMode _mode = CalendarMode.month;
  bool _showCompleted = false;

  /// 列表档「显示时间轴」（嘀嗒《04-列表视图：按天查看任务》:16/:18/:23）。
  /// 会话内状态、默认关，理由见 specs/052 FR-4/FR-5。
  bool _showListTimeline = false;

  /// 年视图热力图（嘀嗒《03-年视图》:76 默认关闭）。
  bool _showHeatmap = false;

  /// 任务块着色轴（specs/124，矩阵 #31）：默认按优先级（现状锁）。
  TimelineColorBy _colorBy = TimelineColorBy.priority;

  /// 列表档「日历全景」展开态（嘀嗒《08-常见问题》:168）。同屏瞬时展开/收起，
  /// 不进偏好 —— 嘀嗒没写跨启动保留。
  bool _panoramaExpanded = false;

  /// 用户是否已经动过显示设置。恢复偏好是异步的，若期间用户已切了视图或拨了开关，
  /// 迟到的旧值必须作废 —— 否则表现为「刚点的档位被弹回上一次的选择」。
  bool _displayTouched = false;

  /// 嘀嗒默认隐藏已完成任务，由「显示设置」里的开关控制。
  List<TodoTask> get _visibleTasks {
    if (!widget.filterCompleted || _showCompleted) return widget.tasks;
    return [
      for (final t in widget.tasks)
        if (!t.completed) t,
    ];
  }

  @override
  void initState() {
    super.initState();
    _anchor = widget._now ?? DateTime.now();
    // 锚点归零到当天 00:00
    _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day);
    Future<void>.microtask(_restoreDisplay);
  }

  @override
  Widget build(BuildContext context) {
    // FR-7：首值未到达或读失败都退回默认档（周一 = develop 既有行为）。
    // 这里不能用 when(error:)，那条分支会丢掉 AsyncError 里留存的旧值。
    final firstDay = resolveWeekStartFirstDay(ref.watch(weekStartProvider));
    // 农历/节假日（specs/125）：开关读偏好仓；数据按锚点月/年拉取（autoDispose
    // 缓存，月内重复进不出网）。拉取失败按无数据渲染（日历主体不受影响）。
    final infoFlags = ref.watch(calendarInfoFlagsProvider).valueOrNull;
    final showLunar = infoFlags?.showLunar ?? false;
    final showHolidays = infoFlags?.showHolidays ?? false;
    final lunarByDay = showLunar
        ? ref
                  .watch(
                    calendarLunarMonthProvider(
                      DateTime(_anchor.year, _anchor.month, 1),
                    ),
                  )
                  .valueOrNull ??
              const <DateTime, CalendarLunarDate>{}
        : const <DateTime, CalendarLunarDate>{};
    final holidaysByDay = showHolidays
        ? {
            for (final holiday
                in ref
                        .watch(calendarHolidaysProvider(_anchor.year))
                        .valueOrNull ??
                    const <CalendarHoliday>[])
              DateTime(holiday.date.year, holiday.date.month, holiday.date.day):
                  holiday,
          }
        : const <DateTime, CalendarHoliday>{};
    return Column(
      children: [
        _Toolbar(
          mode: _mode,
          anchor: _anchor,
          onModeChanged: _changeMode,
          onPrev: () => setState(() => _shift(-1)),
          onNext: () => setState(() => _shift(1)),
          // 「显示设置」现在含颜色轴（specs/124），在任何模式都有可见效果；
          // 不再按 filterCompleted 隐藏入口（那是「显示已完成」一格的旧口径）。
          onOpenSettings: _showDisplaySettings,
          showTimelineToggle: _mode == CalendarMode.list,
          timelineOn: _showListTimeline,
          onToggleTimeline: () =>
              setState(() => _showListTimeline = !_showListTimeline),
        ),
        const Divider(height: 1),
        Expanded(
          child: switch (_mode) {
            CalendarMode.month => _MonthGrid(
              anchor: _anchor,
              firstDay: firstDay,
              tasks: _visibleTasks,
              colorBy: _colorBy,
              showLunar: showLunar,
              showHolidays: showHolidays,
              lunarByDay: lunarByDay,
              holidaysByDay: holidaysByDay,
              listColorHexOf: (task) => ref
                  .watch(listsStreamProvider)
                  .valueOrNull
                  ?.where((list) => list.id == task.listId)
                  .firstOrNull
                  ?.color,
              tagColorHexOf: (task) {
                final ids = ref
                    .watch(taskTagIndexProvider)
                    .valueOrNull?[task.id];
                if (ids == null || ids.isEmpty) return null;
                final tags = ref.watch(tagsStreamProvider).valueOrNull;
                if (tags == null) return null;
                // 多标签取位次最高的标签色（与「按标签排序」同口径）。
                String? best;
                var bestRank = 1 << 30;
                for (final (index, tag) in tags.indexed) {
                  if (!ids.contains(tag.id)) continue;
                  if (tag.color == null || tag.color!.isEmpty) continue;
                  if (index < bestRank) {
                    bestRank = index;
                    best = tag.color;
                  }
                }
                return best;
              },
              onTaskDateChanged: widget.onTaskDateChanged,
              onDayTap: (day) {
                setState(() => _anchor = day);
                _changeMode(CalendarMode.agenda);
              },
            ),
            CalendarMode.week => _WeekView(
              anchor: _anchor,
              firstDay: firstDay,
              selectedDay: _yearSelectedDay,
              tasks: _visibleTasks,
              onTaskTap: (t) => _openDetail(context, t),
            ),
            CalendarMode.year => _YearView(
              anchor: _anchor,
              onDayTap: (d) {
                setState(() {
                  _anchor = d;
                  _yearSelectedDay = d;
                });
                _changeMode(CalendarMode.week);
              },
              tasks: _visibleTasks,
              allTasks: widget.tasks,
              showHeatmap: _showHeatmap,
              onMonthTap: (m) {
                setState(() => _anchor = DateTime(_anchor.year, m, 1));
                _changeMode(CalendarMode.month);
              },
            ),
            CalendarMode.list => Column(
              children: [
                _ListCalendarStrip(
                  anchor: _anchor,
                  firstDay: firstDay,
                  expanded: _panoramaExpanded,
                  onToggle: () =>
                      setState(() => _panoramaExpanded = !_panoramaExpanded),
                  onDayTap: (day) => setState(() {
                    _anchor = day;
                    _panoramaExpanded = false;
                  }),
                ),
                Expanded(
                  child: _showListTimeline
                      ? _DayTimeline(
                          tasks: tasksOnDayByTime(_visibleTasks, _anchor),
                          onTaskTap: (t) => _openDetail(context, t),
                        )
                      : _ListView(
                          tasks: _visibleTasks,
                          onTaskTap: (t) => _openDetail(context, t),
                        ),
                ),
              ],
            ),
            CalendarMode.agenda => _AgendaView(
              anchor: _anchor,
              today: widget._now ?? DateTime.now(),
              tasks: _visibleTasks,
              onTaskTap: (t) => _openDetail(context, t),
            ),
          },
        ),
      ],
    );
  }

  void _shift(int direction) {
    switch (_mode) {
      case CalendarMode.month:
        _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
        break;
      case CalendarMode.week:
        _anchor = _anchor.add(Duration(days: 7 * direction));
        break;
      case CalendarMode.year:
        _anchor = DateTime(_anchor.year + direction, _anchor.month, 1);
        break;
      case CalendarMode.list:
        // 未开启时间轴时列表档不看锚点（现状）；开启后内容按选中日取数，
        // 不按天移动就把用户钉在进入列表档那一刻的那一天。
        if (_showListTimeline) {
          _anchor = _anchor.add(Duration(days: direction));
        }
        break;
      case CalendarMode.agenda:
        _anchor = _anchor.add(Duration(days: direction));
        break;
    }
  }

  Future<void> _restoreDisplay() async {
    final repository = ref.read(taskViewActionRepositoryProvider);
    final saved = await repository?.getCalendarDisplay();
    if (!mounted || saved == null || _displayTouched) return;
    setState(() {
      if (saved.viewType != null) {
        for (final mode in CalendarMode.values) {
          if (mode.name == saved.viewType) _mode = mode;
        }
      }
      _showCompleted = saved.showCompletedTasks ?? false;
      _showHeatmap = saved.showHeatmap ?? false;
      _colorBy = timelineColorByFromWire(saved.calendarColorBy);
    });
  }

  /// 年视图日格点出来的那一天；只有它非空时周视图才高亮，其余情况下周视图
  /// 外观不变（嘀嗒《03-年视图》:64 只说「高亮显示所选日期」）。
  DateTime? _yearSelectedDay;

  Future<void> _changeMode(CalendarMode mode) async {
    _displayTouched = true;
    if (mounted) setState(() => _mode = mode);
    await _persistDisplay();
  }

  Future<void> _showDisplaySettings() async {
    _displayTouched = true;
    final next = await showModalBottomSheet<CalendarDisplaySettings>(
      context: context,
      builder: (sheetContext) => _DisplaySettingsSheet(
        showCompleted: _showCompleted,
        showHeatmap: _showHeatmap,
        colorBy: _colorBy,
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      _showCompleted = next.showCompleted;
      _showHeatmap = next.showHeatmap;
      _colorBy = next.colorBy;
    });
    await _persistDisplay();
  }

  /// 模式与开关必须成对写：单写开关会让偏好层的 viewType 兜底成 list。
  Future<void> _persistDisplay() async {
    try {
      await ref
          .read(taskViewActionRepositoryProvider)
          ?.saveCalendarDisplay(
            viewMode: _mode.name,
            showCompletedTasks: _showCompleted,
            showHeatmap: _showHeatmap,
            colorBy: _colorBy.name,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('日历显示设置保存失败，当前修改仅本次生效')));
    }
  }

  void _openDetail(BuildContext context, TodoTask t) {
    if (isExternalCalendarTask(t)) {
      showExternalCalendarEventDialog(context, t);
      return;
    }
    final callback = widget.onTaskSelected;
    if (callback != null) {
      callback(t.id);
      return;
    }
    showTaskDetailSheet(context, t.id);
  }
}

enum CalendarMode { month, week, year, list, agenda }

extension CalendarModeX on CalendarMode {
  String get label {
    switch (this) {
      case CalendarMode.month:
        return '月';
      case CalendarMode.week:
        return '周';
      case CalendarMode.year:
        return '年';
      case CalendarMode.list:
        return '列表';
      case CalendarMode.agenda:
        return '日程';
    }
  }
}

DateTime? resolveTaskDate(TodoTask t) {
  final d = t.dueAt ?? t.endAt ?? t.startAt;
  if (d == null) return null;
  final display = t.allDay
      ? d
      : taskDisplayDateTime(
          d,
          mode: TaskTimeMode.fromWire(t.timeMode),
          timeZone: t.timeZone,
        );
  return DateTime(display.year, display.month, display.day);
}

DateTime calendarDueAtForDay(TodoTask task, DateTime day) {
  if (task.allDay) {
    return DateTime(day.year, day.month, day.day);
  }
  final source = task.dueAt ?? task.endAt ?? task.startAt;
  if (source == null) {
    return DateTime(day.year, day.month, day.day);
  }
  return taskDateTimeForDisplayDay(
    source,
    day,
    mode: TaskTimeMode.fromWire(task.timeMode),
    timeZone: task.timeZone,
  );
}

bool isExternalCalendarTask(TodoTask task) {
  return task.id.startsWith('external:');
}

Future<void> showExternalCalendarEventDialog(
  BuildContext context,
  TodoTask task,
) {
  final source = task.listId.startsWith('external:')
      ? task.listId.substring('external:'.length)
      : '订阅日历';
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(task.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来源：$source'),
          const SizedBox(height: 8),
          const Text('只读订阅事件'),
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(task.description!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 日历「显示设置」抽屉一次弹层要交回的整组值（分开交回会丢掉另一格的当前值；
/// specs/124 加第三样：任务块着色轴）。
class CalendarDisplaySettings {
  const CalendarDisplaySettings({
    required this.showCompleted,
    required this.showHeatmap,
    required this.colorBy,
  });

  final bool showCompleted;
  final bool showHeatmap;
  final TimelineColorBy colorBy;
}

class _DisplaySettingsSheet extends StatelessWidget {
  const _DisplaySettingsSheet({
    required this.showCompleted,
    required this.showHeatmap,
    required this.colorBy,
  });

  final bool showCompleted;
  final bool showHeatmap;

  /// 任务块着色轴（specs/124，矩阵 #31）：嘀嗒《08-常见问题》:58
  /// 「颜色-显示方式：按清单、优先级或标签显示」。
  final TimelineColorBy colorBy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // 颜色轴进抽屉后总高超过一屏（-60px 溢出是 22 条存量用例一起红的根因）：
      // 内容可滚动，开关/单选交互不受影响。
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('显示设置', style: TextStyle(fontSize: 16)),
              ),
            ),
            SwitchListTile(
              key: const Key('calendar-show-completed'),
              title: const Text('显示已完成'),
              value: showCompleted,
              onChanged: (value) => Navigator.pop(
                context,
                CalendarDisplaySettings(
                  showCompleted: value,
                  showHeatmap: showHeatmap,
                  colorBy: colorBy,
                ),
              ),
            ),
            // 嘀嗒《03-年视图》:80/:87「显示设置 → 样式 → 热力图」，分组名照抄。
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('样式', style: TextStyle(fontSize: 13)),
              ),
            ),
            SwitchListTile(
              key: const Key('calendar-show-heatmap'),
              title: const Text('热力图'),
              value: showHeatmap,
              onChanged: (value) => Navigator.pop(
                context,
                CalendarDisplaySettings(
                  showCompleted: showCompleted,
                  showHeatmap: value,
                  colorBy: colorBy,
                ),
              ),
            ),
            // 嘀嗒《08-常见问题》:58「颜色-显示方式」；specs/124，矩阵 #31。
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('颜色', style: TextStyle(fontSize: 13)),
              ),
            ),
            RadioGroup<TimelineColorBy>(
              groupValue: colorBy,
              onChanged: (value) => Navigator.pop(
                context,
                CalendarDisplaySettings(
                  showCompleted: showCompleted,
                  showHeatmap: showHeatmap,
                  colorBy: value ?? TimelineColorBy.priority,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mode in TimelineColorBy.values)
                    RadioListTile<TimelineColorBy>(
                      key: Key('calendar-color-by-${mode.name}'),
                      title: Text(switch (mode) {
                        TimelineColorBy.priority => '按优先级',
                        TimelineColorBy.list => '按清单',
                        TimelineColorBy.tag => '按标签',
                      }),
                      value: mode,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 月模式网格：6 行 × 7 列，列顺序与起点由 [firstDay] 决定（默认周一，
/// 即 develop 改造前的行为）；包含 anchor 月的所有日期及上下月填充。
List<List<DateTime>> buildMonthGrid(
  DateTime anchor, {
  int firstDay = WeekStart.defaultFirstDay,
}) {
  final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
  // weekDay: 1(Mon)..7(Sun)
  final leadingBlanks = WeekStart.offsetOf(
    firstOfMonth.weekday,
    firstDay: firstDay,
  );
  final start = firstOfMonth.subtract(Duration(days: leadingBlanks));
  final rows = <List<DateTime>>[];
  for (var r = 0; r < 6; r++) {
    final row = <DateTime>[];
    for (var c = 0; c < 7; c++) {
      row.add(start.add(Duration(days: r * 7 + c)));
    }
    rows.add(row);
  }
  return rows;
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.mode,
    required this.anchor,
    required this.onModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onOpenSettings,
    required this.showTimelineToggle,
    required this.timelineOn,
    required this.onToggleTimeline,
  });

  final CalendarMode mode;
  final DateTime anchor;
  final ValueChanged<CalendarMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onOpenSettings;

  /// 「显示时间轴」只在列表档出现（嘀嗒 :23 的打开方式就是列表档里的一个图标）。
  final bool showTimelineToggle;
  final bool timelineOn;
  final VoidCallback onToggleTimeline;

  @override
  Widget build(BuildContext context) {
    final ym = DateFormat('yyyy 年 M 月').format(anchor);
    final y = DateFormat('yyyy 年').format(anchor);
    final label = switch (mode) {
      CalendarMode.month => ym,
      CalendarMode.week => ym,
      CalendarMode.year => y,
      CalendarMode.list =>
        timelineOn ? DateFormat('yyyy 年 M 月 d 日').format(anchor) : '全部任务',
      CalendarMode.agenda => DateFormat('yyyy 年 M 月 d 日').format(anchor),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final modeSelector = SegmentedButton<CalendarMode>(
          segments: [
            for (final m in CalendarMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        );
        final previousButton = IconButton(
          tooltip: '上一个',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        );
        final nextButton = IconButton(
          tooltip: '下一个',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        );
        final settingsButton = onOpenSettings == null
            ? const SizedBox.shrink()
            : Semantics(
                container: true,
                button: true,
                enabled: true,
                label: '显示设置',
                onTap: onOpenSettings,
                child: ExcludeSemantics(
                  child: IconButton(
                    key: const Key('calendar-display-settings'),
                    tooltip: '显示设置',
                    icon: const Icon(Icons.tune),
                    onPressed: onOpenSettings,
                  ),
                ),
              );
        final timelineButton = !showTimelineToggle
            ? const SizedBox.shrink()
            : Semantics(
                key: const Key('calendar-list-timeline'),
                container: true,
                button: true,
                enabled: true,
                selected: timelineOn,
                label: '显示时间轴',
                onTap: onToggleTimeline,
                child: ExcludeSemantics(
                  child: IconButton(
                    tooltip: '显示时间轴',
                    icon: Icon(
                      timelineOn ? Icons.timeline : Icons.timeline_outlined,
                    ),
                    onPressed: onToggleTimeline,
                  ),
                ),
              );
        final labelText = Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: constraints.maxWidth < 600
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: modeSelector,
                    ),
                    Row(
                      children: [
                        previousButton,
                        Expanded(child: labelText),
                        nextButton,
                        settingsButton,
                        timelineButton,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    modeSelector,
                    const Spacer(),
                    previousButton,
                    labelText,
                    nextButton,
                    settingsButton,
                    timelineButton,
                  ],
                ),
        );
      },
    );
  }
}

/// 月视图表头的单字（一…日）。嘀嗒表头用单字，档位名用「周X」，
/// 两者同源：去掉"周"前缀即表头字形，避免出现第二份星期表。
String weekdayGlyph(int weekday) =>
    WeekStart.labelOf(weekday).replaceFirst('周', '');

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.anchor,
    required this.firstDay,
    required this.tasks,
    required this.onDayTap,
    this.onTaskDateChanged,
    this.colorBy = TimelineColorBy.priority,
    this.listColorHexOf,
    this.tagColorHexOf,
    this.showLunar = false,
    this.showHolidays = false,
    this.lunarByDay = const {},
    this.holidaysByDay = const {},
  });

  final DateTime anchor;
  final int firstDay;
  final List<TodoTask> tasks;

  /// 农历/节假日（specs/125，矩阵 #31 面 ①）：开关在「设置-日期与时间」，
  /// 数据由页面按可见月/年拉取后传入。
  final bool showLunar;
  final bool showHolidays;
  final Map<DateTime, CalendarLunarDate> lunarByDay;
  final Map<DateTime, CalendarHoliday> holidaysByDay;
  final ValueChanged<DateTime> onDayTap;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  /// 任务块着色轴（specs/124，矩阵 #31）：与时间线同一套解析
  /// （[timelineTaskColor]），无色回退优先级轴。
  final TimelineColorBy colorBy;
  final String? Function(TodoTask task)? listColorHexOf;
  final String? Function(TodoTask task)? tagColorHexOf;

  @override
  Widget build(BuildContext context) {
    final grid = buildMonthGrid(anchor, firstDay: firstDay);
    final tasksByDay = <String, List<TodoTask>>{};
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      final key = '${d.year}-${d.month}-${d.day}';
      tasksByDay.putIfAbsent(key, () => []).add(t);
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Row(
            // 表头与网格必须读同一个 firstDay，否则「格子里是周六、
            // 头上写着周一」这类错位没有任何测试能替你发现。
            children: [
              for (final weekday in WeekStart.columnOrder(firstDay: firstDay))
                _DayHeader(weekdayGlyph(weekday)),
            ],
          ),
          for (final row in grid)
            Expanded(
              child: Row(
                children: [
                  for (final d in row)
                    Expanded(
                      child: _DayCell(
                        day: d,
                        anchor: anchor,
                        tasks:
                            tasksByDay['${d.year}-${d.month}-${d.day}'] ??
                            const [],
                        onTap: () => onDayTap(d),
                        onTaskDateChanged: onTaskDateChanged,
                        colorBy: colorBy,
                        listColorHexOf: listColorHexOf,
                        tagColorHexOf: tagColorHexOf,
                        showLunar: showLunar,
                        showHolidays: showHolidays,
                        lunar: lunarByDay[DateTime(d.year, d.month, d.day)],
                        holiday:
                            holidaysByDay[DateTime(d.year, d.month, d.day)],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.anchor,
    required this.tasks,
    required this.onTap,
    this.onTaskDateChanged,
    this.colorBy = TimelineColorBy.priority,
    this.listColorHexOf,
    this.tagColorHexOf,
    this.showLunar = false,
    this.showHolidays = false,
    this.lunar,
    this.holiday,
  });
  final DateTime day;
  final DateTime anchor;
  final List<TodoTask> tasks;
  final VoidCallback onTap;

  /// 农历/节假日当日数据（specs/125）。
  final bool showLunar;
  final bool showHolidays;
  final CalendarLunarDate? lunar;
  final CalendarHoliday? holiday;
  final Future<void> Function(TodoTask task, DateTime dueAt)? onTaskDateChanged;

  /// 着色轴与两条 hex 解析闭包（specs/124）；null 取色回退优先级轴。
  final TimelineColorBy colorBy;
  final String? Function(TodoTask task)? listColorHexOf;
  final String? Function(TodoTask task)? tagColorHexOf;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final isCurrentMonth = day.month == anchor.month;
    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return DragTarget<TodoTask>(
      key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
      onWillAcceptWithDetails: (details) =>
          onTaskDateChanged != null &&
          !isExternalCalendarTask(details.data) &&
          resolveTaskDate(details.data) != day,
      onAcceptWithDetails: (details) => _moveTask(context, details.data),
      builder: (context, candidates, _) => Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? colors.accent.withValues(alpha: 0.2)
                  : isToday
                  ? colors.accent.withValues(alpha: 0.12)
                  : (isCurrentMonth ? colors.surface : colors.background),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: candidates.isNotEmpty || isToday
                    ? colors.accent
                    : colors.border,
                width: candidates.isNotEmpty || isToday ? 1.5 : 0.5,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday
                            ? colors.accent
                            : isCurrentMonth
                            ? colors.foreground
                            : colors.mutedForeground,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (showHolidays && holiday != null)
                      Text(
                        // 嘀嗒口径：休/班角标。holiday.name 已是「国庆节」等
                        // 名称，格内空间小，取一字或「班」。
                        holiday!.isHoliday ? '休' : '班',
                        key: ValueKey(
                          'calendar-holiday-${day.month}-${day.day}',
                        ),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: holiday!.isHoliday
                              ? colors.destructive
                              : colors.info,
                        ),
                      ),
                  ],
                ),
                if (showLunar)
                  Text(
                    // 农历行：lunarDate 形如「六月初三」；节气优先展示。
                    (lunar?.solarTerm?.isNotEmpty ?? false)
                        ? lunar!.solarTerm!
                        : (lunar?.lunarDate ?? ''),
                    key: ValueKey('calendar-lunar-${day.month}-${day.day}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      color: colors.mutedForeground,
                    ),
                  ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _CalendarTaskChip(
                          task: task,
                          color:
                              timelineTaskColor(
                                task,
                                colorBy: colorBy,
                                listColorHexOf: listColorHexOf,
                                tagColorHexOf: tagColorHexOf,
                              ) ??
                              _priorityColor(task.priority, colors),
                          draggable:
                              onTaskDateChanged != null &&
                              !isExternalCalendarTask(task),
                        );
                      },
                    ),
                  ),
                  Text(
                    '${tasks.length} 项',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveTask(BuildContext context, TodoTask task) async {
    final callback = onTaskDateChanged;
    if (callback == null) return;
    try {
      await callback(task, calendarDueAtForDay(task, day));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '日历改期失败，请重试')),
        ),
      );
    }
  }

  /// 任务优先级色点，沿用 Todo 产品的语义色层级。
  Color _priorityColor(int priority, AppColors colors) {
    switch (priority) {
      case 3:
        return colors.destructive;
      case 2:
        return colors.warning;
      case 1:
        return colors.info;
      default:
        return colors.accent;
    }
  }
}

class _CalendarTaskChip extends StatelessWidget {
  const _CalendarTaskChip({
    required this.task,
    required this.color,
    required this.draggable,
  });

  final TodoTask task;
  final Color color;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: brandColors(context).foreground, fontSize: 9),
      ),
    );
    if (!draggable) return chip;
    return Draggable<TodoTask>(
      key: ValueKey('calendar-task-drag-${task.id}'),
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: chip,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

/// 周视图列头。嘀嗒《02-功能指南/02-日历/03-年视图：查看年度任务完成情况.md》
/// `:64`「点击日期 → 跳转至周视图，并高亮显示所选日期」⇒ 高亮与「已选中」读屏
/// 语义必须挂在同一个带 key 的节点上，点进来的那天既能看见也能被念出来。
class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    return Semantics(
      key: selected ? const Key('calendar-week-selected-day') : null,
      selected: selected,
      label: selected ? '已选中 $label' : label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: selected
            ? BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              )
            : null,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.firstDay,
    required this.tasks,
    required this.onTaskTap,
    this.selectedDay,
  });
  final DateTime anchor;
  final int firstDay;
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  /// 从年视图点进来的那一天；为空表示不是「所选」，列头不做高亮。
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final weekStart = WeekStart.startOf(anchor, firstDay: firstDay);
    final days = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );
    final tasksByDay = <String, List<TodoTask>>{};
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      tasksByDay.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(t);
    }
    final df = DateFormat('M/d');
    final colors = brandColors(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WeekDayHeader(
                      label: df.format(d),
                      selected:
                          selectedDay != null && _isSameDay(d, selectedDay!),
                    ),
                    const Divider(height: 4),
                    Expanded(
                      child: () {
                        final list =
                            tasksByDay['${d.year}-${d.month}-${d.day}'] ??
                            const <TodoTask>[];
                        if (list.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final t = list[i];
                            return InkWell(
                              onTap: () => onTaskTap(t),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  t.title,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          },
                        );
                      }(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.anchor,
    required this.tasks,
    required this.allTasks,
    required this.onMonthTap,
    required this.onDayTap,
    required this.showHeatmap,
  });
  final DateTime anchor;

  /// 判据源《03-年视图》:64「点击日期 → 跳转至周视图，并高亮显示所选日期」
  /// ⇒ 日格把选中的那天交给外层：锚点改到那天并切周视图，高亮由 `_WeekView` 负责。
  final ValueChanged<DateTime> onDayTap;
  final List<TodoTask> tasks;

  /// 热力图数的是「当天完成数」，必须绕过「显示已完成」的过滤 ——
  /// 否则默认（不显示已完成）下全年都是最浅档，这个功能看着就是坏的。
  final List<TodoTask> allTasks;
  final ValueChanged<int> onMonthTap;
  final bool showHeatmap;

  @override
  Widget build(BuildContext context) {
    if (showHeatmap) return _buildHeatmap(context);
    final countByMonth = List<int>.filled(12, 0);
    for (final t in tasks) {
      final d = resolveTaskDate(t);
      if (d == null) continue;
      if (d.year != anchor.year) continue;
      countByMonth[d.month - 1] += 1;
    }
    final df = DateFormat('M 月');
    final colors = brandColors(context);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = i + 1;
        return InkWell(
          onTap: () => onMonthTap(m),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  df.format(DateTime(anchor.year, m, 1)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${countByMonth[i]} 项任务',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 热力图整年一次构建，不走懒加载 —— 否则滚出视口的月份在语义树/测试里根本不存在。
  Widget _buildHeatmap(BuildContext context) {
    final countByDay = <DateTime, int>{};
    for (final t in allTasks) {
      if (!t.completed) continue;
      final completedAt = t.completedAt;
      if (completedAt == null) continue;
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      if (day.year != anchor.year) continue;
      countByDay[day] = (countByDay[day] ?? 0) + 1;
    }
    var maxPerDay = 0;
    for (final count in countByDay.values) {
      if (count > maxPerDay) maxPerDay = count;
    }
    final df = DateFormat('M 月');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var m = 1; m <= 12; m++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onMonthTap(m),
                    child: Text(
                      df.format(DateTime(anchor.year, m, 1)),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MonthHeatmap(
                    year: anchor.year,
                    month: m,
                    countByDay: countByDay,
                    maxPerDay: maxPerDay,
                    onDayTap: onDayTap,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 单月热力格：周一起排，日格只着色不放文字（字号放大不该把格子撑破）。
class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.year,
    required this.month,
    required this.countByDay,
    required this.maxPerDay,
    required this.onDayTap,
  });

  final int year;
  final int month;
  final Map<DateTime, int> countByDay;
  final int maxPerDay;
  final ValueChanged<DateTime> onDayTap;

  static const _cellSize = 14.0;
  static const _cellGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final leadingBlanks = firstDay.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox(width: _cellSize, height: _cellSize));
    }
    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final count = countByDay[date] ?? 0;
      final level = calendarHeatmapLevel(count, maxPerDay);
      cells.add(
        Padding(
          padding: const EdgeInsets.only(right: _cellGap, bottom: _cellGap),
          // :64「点击日期 → 跳转至周视图」⇒ 日格必须真的可点；着色与读屏语义
          // 仍同属一个节点，所以 key 留在 Semantics 上。
          child: InkWell(
            onTap: () => onDayTap(date),
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            child: Semantics(
              key: Key('calendar-year-day-${_isoDay(date)}'),
              label: '$month 月 $day 日 完成 $count 项',
              child: Container(
                width: _cellSize,
                height: _cellSize,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: _heatmapAlpha[level]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Wrap(children: cells);
  }
}

/// 日格 key 与语义 label 用的日期串。
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const int _heatmapLevels = 4;

/// 分母下限：全年只完成 1 项时，那一项不该被画成「最忙的一天」。
const int _heatmapMinDenominator = 4;

/// 档位 0..4 对应的着色浓度；`0` 档只留一点底色，让「没完成」也看得见格子。
const List<double> _heatmapAlpha = [0.06, 0.26, 0.46, 0.68, 0.9];

/// 年视图热力图档位（嘀嗒《03-年视图》:98「颜色越深，代表当天完成的任务越多」）。
///
/// 源页只给了相对口径、没给绝对阈值，所以按当年单日最大值归一成 4 档，
/// 并给分母垫一个下限，避免稀疏年份把唯一一次完成显示成满格热度；
/// 数据全在本地库里，最大值就在传进来的列表里算，不需要服务端聚合。
int calendarHeatmapLevel(int completedOnDay, int maxCompletedPerDay) {
  if (completedOnDay <= 0) return 0;
  final denominator = maxCompletedPerDay < _heatmapMinDenominator
      ? _heatmapMinDenominator
      : maxCompletedPerDay;
  final level =
      (completedOnDay * _heatmapLevels + denominator - 1) ~/ denominator;
  return level.clamp(1, _heatmapLevels);
}

class _AgendaView extends StatefulWidget {
  const _AgendaView({
    required this.anchor,
    required this.today,
    required this.tasks,
    required this.onTaskTap,
  });

  final DateTime anchor;
  final DateTime today;
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  State<_AgendaView> createState() => _AgendaViewState();
}

/// 日程视图 = 一条**跨日**的时间轴。
///
/// 源页 `:5`「你所有安排好时间的任务会显示在一个时间轴中以线性的方式展示」、
/// `:7`「同时看到过去已完成的任务、当前的进度和未来的计划」；
/// 上一版按 anchor 单日过滤，两句话都不成立 ⇒ 这里改成按日期升序分组。
/// 原文没有给窗口上下界，所以**不设「最近 N 天」之类的截断**。
class _AgendaViewState extends State<_AgendaView> {
  /// 统一行高：锚点偏移于是可以算出来（`行号 × 行高`），不用等布局再校正。
  static const double _rowExtent = 88;

  ScrollController? _controller;
  DateTime? _seededAnchor;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _timelineRows(widget.tasks);
    if (rows.isEmpty) {
      return const AppEmptyState(
        title: '暂无日程',
        subtitle: '为任务设置开始和截止时间，它们会按日期排进这条时间轴。',
      );
    }

    final anchorIndex = _anchorRowIndex(rows, widget.anchor);
    final controller = _controller ??= ScrollController(
      initialScrollOffset: anchorIndex * _rowExtent,
    );
    if (_seededAnchor != widget.anchor) {
      _seededAnchor = widget.anchor;
      if (controller.hasClients) {
        final offset = (anchorIndex * _rowExtent).clamp(
          0.0,
          controller.position.maxScrollExtent,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.jumpTo(offset);
        });
      }
    }

    return ListView.builder(
      key: const Key('calendar-agenda-timeline'),
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemExtent: _rowExtent,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return row.task == null
            ? _dayHeader(context, row.day)
            : _taskRow(context, row.task!, row.day);
      },
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day) {
    final colors = brandColors(context);
    final isToday = _isSameDay(day, widget.today);
    return Semantics(
      header: true,
      child: Container(
        key: ValueKey(
          'calendar-agenda-day-${day.year}-${day.month}-${day.day}',
        ),
        color: colors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.centerLeft,
        child: DefaultTextStyle(
          style:
              Theme.of(context).textTheme.labelLarge ??
              const TextStyle(fontSize: 13),
          child: Row(
            children: [
              Text('${day.month}月${day.day}日'),
              if (isToday) ...[const SizedBox(width: 6), const Text('今天')],
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskRow(BuildContext context, TodoTask task, DateTime day) {
    final clock = task.allDay
        ? '全天'
        : _formatClock(task, task.startAt ?? task.dueAt ?? task.endAt!);
    return ListTile(
      key: ValueKey('calendar-agenda-task-${task.id}'),
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: SizedBox(
        width: 48,
        child: Text(
          clock,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _formatTime(task),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isExternalCalendarTask(task)
          ? const Icon(Icons.lock_outline, size: 18)
          : null,
      onTap: () => widget.onTaskTap(task),
    );
  }
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

/// 把任务摊成「日头 + 该日任务」的行序列，日期升序；日内沿用原有的时间排序。
List<_AgendaRow> _timelineRows(List<TodoTask> tasks) {
  final byDay = <DateTime, List<TodoTask>>{};
  for (final task in tasks) {
    final date = resolveTaskDate(task);
    if (date == null) continue;
    byDay.putIfAbsent(date, () => <TodoTask>[]).add(task);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days) ...[
      _AgendaRow(day: day),
      for (final task in (byDay[day]!..sort(_compareByTime)))
        _AgendaRow(day: day, task: task),
    ],
  ];
}

/// 锚点那天必须在视口里：该日有任务就从它的日头开始；没有就从下一个日头开始。
int _anchorRowIndex(List<_AgendaRow> rows, DateTime anchor) {
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    if (row.task != null) continue;
    if (!row.day.isBefore(anchor)) return index;
  }
  return rows.length - 1;
}

class _AgendaRow {
  const _AgendaRow({required this.day, this.task});

  final DateTime day;
  final TodoTask? task;
}

/// 日程行的时间区间：全天在前，未定时点有专门文案。
String _formatTime(TodoTask task) {
  if (task.allDay) return '全天';
  final start = task.startAt ?? task.dueAt ?? task.endAt;
  if (start == null) return '未设置时间';
  final startLabel = _formatClock(task, start);
  final end = task.endAt;
  if (end == null || !end.isAfter(start)) return startLabel;
  return '$startLabel–${_formatClock(task, end)}';
}

/// 选中日当天的任务，全天在前、有时点的按墙钟时刻升序。
///
/// 议程档与列表档「显示时间轴」共用这一个取数口：嘀嗒的「日程」与
/// 「列表视图-显示时间轴」渲染的是同一批"按天 + 按时间"的内容，
/// 各自抄一份就会长出两个事实源（specs/051 第 76 轮 PH 探针就是这么抓出来的）。
List<TodoTask> tasksOnDayByTime(List<TodoTask> tasks, DateTime day) {
  return [
    for (final task in tasks)
      if (_isOnDay(task, day)) task,
  ]..sort(_compareByTime);
}

bool _isOnDay(TodoTask task, DateTime day) {
  final date = resolveTaskDate(task);
  return date != null &&
      date.year == day.year &&
      date.month == day.month &&
      date.day == day.day;
}

int _compareByTime(TodoTask left, TodoTask right) {
  if (left.allDay != right.allDay) return left.allDay ? -1 : 1;
  final leftTime = left.startAt ?? left.dueAt ?? left.endAt;
  final rightTime = right.startAt ?? right.dueAt ?? right.endAt;
  if (leftTime == null && rightTime == null) return 0;
  if (leftTime == null) return 1;
  if (rightTime == null) return -1;
  return _compareWallClock(
    _displayTime(left, leftTime),
    _displayTime(right, rightTime),
  );
}

String _formatClock(TodoTask task, DateTime instant) {
  return DateFormat('HH:mm').format(_displayTime(task, instant));
}

DateTime _displayTime(TodoTask task, DateTime instant) {
  return taskDisplayDateTime(
    instant,
    mode: TaskTimeMode.fromWire(task.timeMode),
    timeZone: task.timeZone,
  );
}

int _compareWallClock(DateTime left, DateTime right) {
  for (final pair in [
    (left.hour, right.hour),
    (left.minute, right.minute),
    (left.second, right.second),
    (left.millisecond, right.millisecond),
    (left.microsecond, right.microsecond),
  ]) {
    final compared = pair.$1.compareTo(pair.$2);
    if (compared != 0) return compared;
  }
  return 0;
}

/// 列表档「第一排日历」与「日历全景」（嘀嗒《08-常见问题》:168
/// 「在列表视图，手指按住第一排日历，向下拉，即可展开一个小的日历全景。」）。
/// 周条常驻（就是"第一排日历"），向下拉在其下方展开同屏的小月网格、上滑收起，
/// 展开/收起也可走读屏按钮；不是新页面也不是弹层。全景是纯日期网格，
/// 不渲染任务点（嘀嗒未写全景带任务标记，specs/099 明确不做）。
class _ListCalendarStrip extends StatelessWidget {
  const _ListCalendarStrip({
    required this.anchor,
    required this.firstDay,
    required this.expanded,
    required this.onToggle,
    required this.onDayTap,
  });

  final DateTime anchor;
  final int firstDay;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final weekStart = WeekStart.startOf(anchor, firstDay: firstDay);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (!expanded && velocity > 120) onToggle();
        if (expanded && velocity < -120) onToggle();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                _ListStripDay(
                  day: weekStart.add(Duration(days: i)),
                  anchor: anchor,
                  onDayTap: onDayTap,
                ),
              Semantics(
                key: const Key('calendar-list-panorama-toggle'),
                container: true,
                button: true,
                enabled: true,
                label: expanded ? '收起日历全景' : '展开日历全景',
                onTap: onToggle,
                child: ExcludeSemantics(
                  child: IconButton(
                    tooltip: expanded ? '收起日历全景' : '展开日历全景',
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    onPressed: onToggle,
                  ),
                ),
              ),
            ],
          ),
          if (expanded)
            ExcludeSemantics(
              child: SizedBox(
                key: const Key('calendar-list-panorama'),
                height: 280,
                child: _MonthGrid(
                  anchor: anchor,
                  firstDay: firstDay,
                  tasks: const [],
                  onDayTap: onDayTap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 周条上的一个日期格：点选即把锚点切到那一天；读屏念「M月d日」与选中态。
class _ListStripDay extends StatelessWidget {
  const _ListStripDay({
    required this.day,
    required this.anchor,
    required this.onDayTap,
  });

  final DateTime day;
  final DateTime anchor;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final isAnchor =
        day.year == anchor.year &&
        day.month == anchor.month &&
        day.day == anchor.day;
    final isCurrentMonth = day.month == anchor.month;
    return Expanded(
      child: Semantics(
        key: ValueKey('calendar-strip-day-${day.year}-${day.month}-${day.day}'),
        label: '${day.month}月${day.day}日',
        selected: isAnchor,
        child: InkWell(
          onTap: () => onDayTap(day),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isAnchor
                  ? colors.accent.withValues(alpha: 0.15)
                  : colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isAnchor ? colors.accent : colors.border,
                width: isAnchor ? 1.5 : 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ExcludeSemantics(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: isAnchor
                      ? colors.accent
                      : isCurrentMonth
                      ? colors.foreground
                      : colors.mutedForeground,
                  fontWeight: isAnchor ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.tasks, required this.onTaskTap});
  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      final ad = resolveTaskDate(a);
      final bd = resolveTaskDate(b);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    if (sorted.isEmpty) {
      // 时间轴关闭时本列表展示的是「全部任务」而非某一天（matrix #29 第 274 轮订正），
      // 空态文案不能再说「该日无任务」——那是 _DayTimeline（按天口径）的句子。
      return AppEmptyState(title: '暂无任务', subtitle: '在日历上选择日期，点击即可添加任务。');
    }
    final df = DateFormat('yyyy-MM-dd');
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = sorted[i];
        final d = resolveTaskDate(t);
        return ListTile(
          leading: const Icon(Icons.event_note),
          title: Text(t.title),
          subtitle: d == null ? const Text('无日期') : Text(df.format(d)),
          onTap: () => onTaskTap(t),
        );
      },
    );
  }
}

/// 列表档「显示时间轴」：以时间为线，串起选中日一天的日程（嘀嗒《04-列表视图》:18）。
///
/// 全天任务落在轴**之外**的上方「全天」栏，有时点的任务落在轴上并在左侧标出 HH:mm：
/// 《08-常见问题》:32 原文是「将全天任务栏里的任务拖拽至时间轴上的对应时间点」——
/// 拖拽的两个端点是**两个区域**，所以 `:32` 只证嘀嗒另有一根「全天任务栏」，
/// 不证它是这条轴的一部分（第 77 轮复核 F2）。全天行因此不画轴线。
/// 拖拽改时间、隐藏时段、长按落点建任务都不在本面（specs/052「明确不做」）。
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.tasks, required this.onTaskTap});

  static const double _gutterWidth = 46;

  final List<TodoTask> tasks;
  final ValueChanged<TodoTask> onTaskTap;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const AppEmptyState(title: '该日无任务', subtitle: '切换日期，或为任务设置时间。');
    }
    final allDay = [
      for (final t in tasks)
        if (t.allDay) t,
    ];
    final timed = [
      for (final t in tasks)
        if (!t.allDay) t,
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: [
        if (allDay.isNotEmpty)
          Column(
            key: const Key('calendar-timeline-allday'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '全天',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              for (final t in allDay) _row(context, t, null),
            ],
          ),
        if (timed.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: allDay.isEmpty ? 0 : 8),
            child: Column(
              key: const Key('calendar-timeline-timed'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in timed)
                  _row(
                    context,
                    t,
                    _formatClock(t, t.startAt ?? t.dueAt ?? t.endAt!),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, TodoTask task, String? clock) {
    final colors = brandColors(context);
    return Semantics(
      key: ValueKey('calendar-timeline-row-${task.id}'),
      container: true,
      button: true,
      enabled: true,
      label: '${clock ?? '全天'} ${task.title}',
      onTap: () => onTaskTap(task),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onTaskTap(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: _gutterWidth,
                  child: Text(
                    clock ?? '',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                // 轴：每行自己画一段左边线，相邻行拼成一条连续的线。
                Container(
                  width: 16,
                  decoration: clock == null
                      ? null
                      : BoxDecoration(
                          border: Border(
                            left: BorderSide(width: 2, color: colors.border),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'efficiency_dashboard.dart';

void main() {
  runApp(const TodoFlutterApp());
}

class TodoFlutterApp extends StatelessWidget {
  const TodoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'zh-cloud todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  static const _cacheKey = 'zh_cloud_todo_flutter_state_v2';
  static const _quadrantNames = <String>['紧急且重要', '重要不紧急', '紧急不重要', '不紧急不重要'];
  static const _pomodoroDurationSeconds = 25 * 60;

  bool _isLoading = true;
  bool _isSignedIn = false;
  String _activeTab = '日历';
  String _calendarView = '周';
  late List<_TodoListItem> _lists;
  late List<_TodoTaskItem> _tasks;
  late List<_CalendarEventItem> _calendarEvents;
  late List<_SyncQueueItem> _syncQueue;
  late List<EfficiencyQuadrantItem> _quadrantItems;
  late List<EfficiencyHabitItem> _habits;
  late List<EfficiencyCountdownItem> _countdowns;
  int _pomodoroSecondsRemaining = _pomodoroDurationSeconds;
  int _pomodoroCompletedRounds = 0;
  bool _pomodoroRunning = false;
  Timer? _pomodoroTimer;

  @override
  void initState() {
    super.initState();
    _seedState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    super.dispose();
  }

  void _seedState() {
    _lists = [
      _TodoListItem('工作', 12, 3),
      _TodoListItem('个人', 8, 1),
      _TodoListItem('共享清单', 5, 2),
    ];
    _tasks = [
      _TodoTaskItem('补齐 Flutter 主壳路由', '工作', '进行中'),
      _TodoTaskItem('接入任务列表和快速添加', '工作', '待办'),
      _TodoTaskItem('同步队列与本地缓存回显', '共享清单', '待办'),
    ];
    _calendarEvents = [
      _CalendarEventItem('09:30', '任务评审', '工作', '今天'),
      _CalendarEventItem('14:00', '同步回放检查', '共享清单', '今天'),
      _CalendarEventItem('18:30', '明日计划', '个人', '明天'),
      _CalendarEventItem('全天', '月度目标回顾', '工作', '本周'),
    ];
    _syncQueue = [
      _SyncQueueItem('create task', '待重试'),
      _SyncQueueItem('update list', '已排队'),
    ];
    _quadrantItems = [
      EfficiencyQuadrantItem(title: '今晚完成日报', quadrant: '紧急且重要', done: false),
      EfficiencyQuadrantItem(title: '整理下周目标', quadrant: '重要不紧急', done: false),
      EfficiencyQuadrantItem(title: '回复同步提醒', quadrant: '紧急不重要', done: true),
      EfficiencyQuadrantItem(title: '清理重复标签', quadrant: '不紧急不重要', done: false),
    ];
    final today = DateTime.now();
    _habits = [
      EfficiencyHabitItem(
        title: '番茄后记录 1 条复盘',
        target: '每天一次',
        doneToday: false,
        streak: 4,
      ),
      EfficiencyHabitItem(
        title: '上午先处理高优任务',
        target: '工作日',
        doneToday: true,
        streak: 11,
      ),
      EfficiencyHabitItem(
        title: '晚间整理待办',
        target: '每天一次',
        doneToday: false,
        streak: 2,
      ),
    ];
    _countdowns = [
      EfficiencyCountdownItem(
        title: 'M3-B3 演示里程碑',
        targetDateIso: DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 14)).toIso8601String(),
      ),
      EfficiencyCountdownItem(
        title: '周末纪念日',
        targetDateIso: DateTime(
          today.year,
          today.month,
          today.day,
        ).add(const Duration(days: 6)).toIso8601String(),
      ),
    ];
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _isSignedIn = data['signedIn'] as bool? ?? false;
      _activeTab = data['activeTab'] as String? ?? '日历';
      _calendarView = data['calendarView'] as String? ?? '周';
      _lists = _decodeLists(data['lists'] as List<dynamic>?);
      _tasks = _decodeTasks(data['tasks'] as List<dynamic>?);
      _calendarEvents = _decodeCalendarEvents(
        data['calendarEvents'] as List<dynamic>?,
      );
      _syncQueue = _decodeSyncQueue(data['syncQueue'] as List<dynamic>?);
      _quadrantItems = _decodeQuadrantItems(
        data['quadrantItems'] as List<dynamic>?,
      );
      _habits = _decodeHabits(data['habits'] as List<dynamic>?);
      _countdowns = _decodeCountdowns(data['countdowns'] as List<dynamic>?);
      _pomodoroSecondsRemaining =
          data['pomodoroSecondsRemaining'] as int? ?? _pomodoroDurationSeconds;
      _pomodoroCompletedRounds = data['pomodoroCompletedRounds'] as int? ?? 0;
      _pomodoroRunning = data['pomodoroRunning'] as bool? ?? false;
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    if (_pomodoroRunning) {
      _resumePomodoroTimer();
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'signedIn': _isSignedIn,
        'activeTab': _activeTab,
        'calendarView': _calendarView,
        'lists': _lists.map((item) => item.toJson()).toList(),
        'tasks': _tasks.map((item) => item.toJson()).toList(),
        'calendarEvents': _calendarEvents.map((item) => item.toJson()).toList(),
        'syncQueue': _syncQueue.map((item) => item.toJson()).toList(),
        'quadrantItems': _quadrantItems.map((item) => item.toJson()).toList(),
        'habits': _habits.map((item) => item.toJson()).toList(),
        'countdowns': _countdowns.map((item) => item.toJson()).toList(),
        'pomodoroSecondsRemaining': _pomodoroSecondsRemaining,
        'pomodoroCompletedRounds': _pomodoroCompletedRounds,
        'pomodoroRunning': _pomodoroRunning,
      }),
    );
  }

  List<_TodoListItem> _decodeLists(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) => _TodoListItem(
            json['name'] as String? ?? '',
            json['taskCount'] as int? ?? 0,
            json['completedCount'] as int? ?? 0,
          ),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _lists;
  }

  List<_TodoTaskItem> _decodeTasks(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) => _TodoTaskItem(
            json['title'] as String? ?? '',
            json['listName'] as String? ?? '',
            json['status'] as String? ?? '',
          ),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _tasks;
  }

  List<_CalendarEventItem> _decodeCalendarEvents(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) => _CalendarEventItem(
            json['time'] as String? ?? '',
            json['title'] as String? ?? '',
            json['listName'] as String? ?? '',
            json['bucket'] as String? ?? '',
          ),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _calendarEvents;
  }

  List<_SyncQueueItem> _decodeSyncQueue(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) => _SyncQueueItem(
            json['action'] as String? ?? '',
            json['state'] as String? ?? '',
          ),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _syncQueue;
  }

  List<EfficiencyQuadrantItem> _decodeQuadrantItems(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) =>
              EfficiencyQuadrantItem.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _quadrantItems;
  }

  List<EfficiencyHabitItem> _decodeHabits(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) => EfficiencyHabitItem.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _habits;
  }

  List<EfficiencyCountdownItem> _decodeCountdowns(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) =>
              EfficiencyCountdownItem.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _countdowns;
  }

  void _goToTab(String tab) {
    setState(() {
      _activeTab = tab;
    });
    _persistState();
  }

  Future<void> _toggleSignIn() async {
    setState(() {
      _isSignedIn = !_isSignedIn;
      _syncQueue.insert(
        0,
        _SyncQueueItem(_isSignedIn ? 'login' : 'logout', '已同步'),
      );
    });
    await _persistState();
  }

  Future<void> _addTask() async {
    setState(() {
      _tasks = [const _TodoTaskItem('新的快速添加任务', '工作', '待办'), ..._tasks];
      _calendarEvents = [
        const _CalendarEventItem('10:30', '新增任务安排', '工作', '今天'),
        ..._calendarEvents,
      ];
      _syncQueue.insert(0, const _SyncQueueItem('create task', '待重试'));
    });
    await _persistState();
  }

  Future<void> _markFirstTaskDone() async {
    setState(() {
      if (_tasks.isEmpty) {
        return;
      }
      final first = _tasks.first;
      _tasks = [
        _TodoTaskItem(first.title, first.listName, '已完成'),
        ..._tasks.skip(1),
      ];
      _calendarEvents = [
        const _CalendarEventItem('09:30', '任务状态已更新', '工作', '今天'),
        ..._calendarEvents,
      ];
      _syncQueue.insert(0, const _SyncQueueItem('complete task', '已排队'));
    });
    await _persistState();
  }

  Future<void> _handleQuadrantAction(int index) async {
    setState(() {
      final quadrantName = _quadrantNames[index];
      final pendingIndex = _quadrantItems.indexWhere(
        (item) => item.quadrant == quadrantName && !item.done,
      );
      if (pendingIndex >= 0) {
        _quadrantItems[pendingIndex] = _quadrantItems[pendingIndex].copyWith(
          done: true,
        );
      } else {
        _quadrantItems = [
          EfficiencyQuadrantItem(
            title: '$quadrantName 新示例',
            quadrant: quadrantName,
            done: false,
          ),
          ..._quadrantItems,
        ];
      }
      _syncQueue.insert(
        0,
        _SyncQueueItem('quadrant ${_quadrantNames[index]}', '已写入本地'),
      );
    });
    await _persistState();
  }

  Future<void> _toggleHabit(int index) async {
    setState(() {
      final habit = _habits[index];
      final updated = habit.doneToday
          ? habit.copyWith(doneToday: false)
          : habit.copyWith(doneToday: true, streak: habit.streak + 1);
      _habits[index] = updated;
      _syncQueue.insert(
        0,
        _SyncQueueItem(
          'habit ${updated.title}',
          updated.doneToday ? '已打卡' : '已撤销',
        ),
      );
    });
    await _persistState();
  }

  Future<void> _shiftCountdown(int index, int daysDelta) async {
    setState(() {
      final shifted = _countdowns[index].targetDate.add(
        Duration(days: daysDelta),
      );
      _countdowns[index] = _countdowns[index].copyWith(
        targetDateIso: shifted.toIso8601String(),
      );
      _syncQueue.insert(
        0,
        _SyncQueueItem('countdown ${_countdowns[index].title}', '已调整'),
      );
    });
    await _persistState();
  }

  void _resumePomodoroTimer() {
    _pomodoroTimer?.cancel();
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_pomodoroRunning) {
        _pomodoroTimer?.cancel();
        return;
      }
      setState(() {
        if (_pomodoroSecondsRemaining <= 1) {
          _pomodoroSecondsRemaining = _pomodoroDurationSeconds;
          _pomodoroCompletedRounds += 1;
          _pomodoroRunning = false;
          _pomodoroTimer?.cancel();
        } else {
          _pomodoroSecondsRemaining -= 1;
        }
      });
      _persistState();
    });
  }

  Future<void> _togglePomodoro() async {
    if (_pomodoroRunning) {
      _pomodoroTimer?.cancel();
      setState(() {
        _pomodoroRunning = false;
      });
      await _persistState();
      return;
    }
    setState(() {
      _pomodoroRunning = true;
    });
    _resumePomodoroTimer();
    await _persistState();
  }

  Future<void> _resetPomodoro() async {
    _pomodoroTimer?.cancel();
    setState(() {
      _pomodoroSecondsRemaining = _pomodoroDurationSeconds;
      _pomodoroRunning = false;
    });
    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('zh-cloud todo'),
        actions: [
          IconButton(
            tooltip: '效率',
            onPressed: () => _goToTab('效率'),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: '同步',
            onPressed: () {
              setState(() {
                _syncQueue.insert(
                  0,
                  const _SyncQueueItem('manual sync', '已触发'),
                );
              });
              _persistState();
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: _isSignedIn ? '退出登录' : '登录',
            onPressed: _toggleSignIn,
            icon: Icon(_isSignedIn ? Icons.logout : Icons.login),
          ),
        ],
      ),
      body: _activeTab == '日历'
          ? _CalendarTabView(
              isSignedIn: _isSignedIn,
              calendarView: _calendarView,
              tasks: _tasks,
              events: _calendarEvents,
              onCalendarViewChanged: (view) {
                setState(() {
                  _calendarView = view;
                });
                _persistState();
              },
              onOpenEfficiency: () => _goToTab('效率'),
            )
          : _activeTab == '效率'
          ? EfficiencyTabView(
              isSignedIn: _isSignedIn,
              taskCount: _tasks.length,
              completedTaskCount: _tasks
                  .where((item) => item.status == '已完成')
                  .length,
              calendarEventCount: _calendarEvents.length,
              syncQueueCount: _syncQueue.length,
              quadrantItems: _quadrantItems,
              pomodoroSecondsRemaining: _pomodoroSecondsRemaining,
              pomodoroCompletedRounds: _pomodoroCompletedRounds,
              pomodoroRunning: _pomodoroRunning,
              habits: _habits,
              countdowns: _countdowns,
              onQuadrantAction: _handleQuadrantAction,
              onPomodoroStart: _togglePomodoro,
              onPomodoroPause: _togglePomodoro,
              onPomodoroReset: _resetPomodoro,
              onHabitToggle: _toggleHabit,
              onCountdownShift: _shiftCountdown,
            )
          : _DashboardTabView(
              isSignedIn: _isSignedIn,
              lists: _lists,
              tasks: _tasks,
              syncQueue: _syncQueue,
              onAddTask: _addTask,
              onMarkFirstTaskDone: _markFirstTaskDone,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex(_activeTab),
        onDestinationSelected: (index) {
          setState(() {
            _activeTab = _tabName(index);
          });
          _persistState();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: '任务'),
          NavigationDestination(icon: Icon(Icons.event), label: '日历'),
          NavigationDestination(icon: Icon(Icons.flash_on), label: '效率'),
          NavigationDestination(icon: Icon(Icons.view_list), label: '清单'),
          NavigationDestination(icon: Icon(Icons.sync), label: '同步'),
        ],
      ),
    );
  }

  int _navIndex(String value) {
    switch (value) {
      case '日历':
        return 1;
      case '效率':
        return 2;
      case '清单':
        return 3;
      case '同步':
        return 4;
      default:
        return 0;
    }
  }

  String _tabName(int index) {
    switch (index) {
      case 1:
        return '日历';
      case 2:
        return '效率';
      case 3:
        return '清单';
      case 4:
        return '同步';
      default:
        return '任务';
    }
  }
}

class _DashboardTabView extends StatelessWidget {
  const _DashboardTabView({
    required this.isSignedIn,
    required this.lists,
    required this.tasks,
    required this.syncQueue,
    required this.onAddTask,
    required this.onMarkFirstTaskDone,
  });

  final bool isSignedIn;
  final List<_TodoListItem> lists;
  final List<_TodoTaskItem> tasks;
  final List<_SyncQueueItem> syncQueue;
  final Future<void> Function() onAddTask;
  final Future<void> Function() onMarkFirstTaskDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('移动端核心闭环', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(isSignedIn ? '已登录，状态已恢复' : '未登录，等待接入 todo-member'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: '我的任务', value: '${tasks.length}'),
            _MetricCard(label: '今日完成', value: '6'),
            _MetricCard(label: '同步队列', value: '${syncQueue.length}'),
            const _MetricCard(label: '离线缓存', value: '已启用'),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('清单'),
        const SizedBox(height: 8),
        ...lists.map((item) => _ListTileCard(item: item)),
        const SizedBox(height: 20),
        const _SectionTitle('任务'),
        const SizedBox(height: 8),
        ...tasks.map((item) => _TaskTileCard(item: item)),
        const SizedBox(height: 20),
        const _SectionTitle('同步队列'),
        const SizedBox(height: 8),
        ...syncQueue.map((item) => _QueueTileCard(item: item)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAddTask,
          icon: const Icon(Icons.playlist_add),
          label: const Text('快速添加任务'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onMarkFirstTaskDone,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('完成首个任务'),
        ),
      ],
    );
  }
}

class _CalendarTabView extends StatelessWidget {
  const _CalendarTabView({
    required this.isSignedIn,
    required this.calendarView,
    required this.tasks,
    required this.events,
    required this.onCalendarViewChanged,
    required this.onOpenEfficiency,
  });

  final bool isSignedIn;
  final String calendarView;
  final List<_TodoTaskItem> tasks;
  final List<_CalendarEventItem> events;
  final ValueChanged<String> onCalendarViewChanged;
  final VoidCallback onOpenEfficiency;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '日历 / 日程入口',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton.icon(
              onPressed: onOpenEfficiency,
              icon: const Icon(Icons.flash_on),
              label: const Text('打开效率工具'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(isSignedIn ? '已登录，可复用本地任务生成安排' : '未登录，先展示本地任务映射'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: '待排任务', value: '${tasks.length}'),
            _MetricCard(label: '日历事件', value: '${events.length}'),
            const _MetricCard(label: '同步来源', value: '本地'),
            _MetricCard(label: '当前视图', value: calendarView),
          ],
        ),
        const SizedBox(height: 16),
        _CalendarPreviewCard(
          activeView: calendarView,
          events: events,
          onViewChanged: onCalendarViewChanged,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _CalendarPreviewCard extends StatelessWidget {
  const _CalendarPreviewCard({
    required this.activeView,
    required this.events,
    required this.onViewChanged,
  });

  final String activeView;
  final List<_CalendarEventItem> events;
  final ValueChanged<String> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final filteredEvents = events.where((event) {
      if (activeView == '年') {
        return true;
      }
      if (activeView == '月') {
        return event.bucket == '今天' || event.bucket == '本周';
      }
      if (activeView == '日程') {
        return event.time != '全天';
      }
      if (activeView == '列表') {
        return true;
      }
      return event.bucket == '今天' || event.bucket == '本周';
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '视图切换',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onViewChanged('周'),
                  icon: const Icon(Icons.view_week),
                  label: const Text('周'),
                ),
                TextButton.icon(
                  onPressed: () => onViewChanged('月'),
                  icon: const Icon(Icons.calendar_view_month),
                  label: const Text('月'),
                ),
                TextButton.icon(
                  onPressed: () => onViewChanged('年'),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('年'),
                ),
                TextButton.icon(
                  onPressed: () => onViewChanged('列表'),
                  icon: const Icon(Icons.view_list),
                  label: const Text('列表'),
                ),
                TextButton.icon(
                  onPressed: () => onViewChanged('日程'),
                  icon: const Icon(Icons.schedule),
                  label: const Text('日程'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CalendarViewChip(label: '当前视图', value: activeView),
                _CalendarViewChip(label: '事件总数', value: '${events.length}'),
                _CalendarViewChip(
                  label: '过滤结果',
                  value: '${filteredEvents.length}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (activeView == '年')
              _YearView(events: filteredEvents)
            else if (activeView == '月')
              _MonthView(events: filteredEvents)
            else if (activeView == '日程')
              _ScheduleView(events: filteredEvents)
            else if (activeView == '列表')
              _ListAgendaView(events: filteredEvents)
            else
              _WeekView(events: filteredEvents),
          ],
        ),
      ),
    );
  }
}

class _CalendarViewChip extends StatelessWidget {
  const _CalendarViewChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label：$value'));
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.events});

  final List<_CalendarEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarSummaryRow('本周概览', '3 个任务相关事件', Icons.view_week),
        const SizedBox(height: 12),
        ...events
            .take(3)
            .map(
              (event) => _CalendarEventTile(
                title: event.title,
                subtitle: '${event.time} · ${event.listName}',
                trailing: event.bucket,
              ),
            ),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.events});

  final List<_CalendarEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarSummaryRow('月视图', '聚合今天、本周和待办安排', Icons.calendar_view_month),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: events
              .map(
                (event) =>
                    _SmallEventPill(label: event.bucket, value: event.title),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({required this.events});

  final List<_CalendarEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarSummaryRow('年视图', '展示当前任务的年度布局入口', Icons.calendar_today),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _YearCell(title: 'Q1', count: 1),
            _YearCell(title: 'Q2', count: events.length),
            _YearCell(title: 'Q3', count: 0),
            _YearCell(title: 'Q4', count: 0),
          ],
        ),
      ],
    );
  }
}

class _ListAgendaView extends StatelessWidget {
  const _ListAgendaView({required this.events});

  final List<_CalendarEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events
          .map(
            (event) => _CalendarEventTile(
              title: event.title,
              subtitle: '${event.bucket} · ${event.listName}',
              trailing: event.time,
            ),
          )
          .toList(),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({required this.events});

  final List<_CalendarEventItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CalendarSummaryRow('日程', '按时间排序的轻量安排', Icons.schedule),
        const SizedBox(height: 12),
        ...events
            .where((event) => event.time != '全天')
            .map(
              (event) => _CalendarEventTile(
                title: event.title,
                subtitle: '${event.time} · ${event.bucket}',
                trailing: event.listName,
              ),
            ),
      ],
    );
  }
}

class _CalendarSummaryRow extends StatelessWidget {
  const _CalendarSummaryRow(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_note),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(trailing),
      ),
    );
  }
}

class _SmallEventPill extends StatelessWidget {
  const _SmallEventPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label · $value'));
  }
}

class _YearCell extends StatelessWidget {
  const _YearCell({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('$count 个事件'),
          ],
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({required this.item});

  final _TodoListItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: Text(item.name),
        subtitle: Text('${item.taskCount} 个任务 · ${item.completedCount} 已完成'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TaskTileCard extends StatelessWidget {
  const _TaskTileCard({required this.item});

  final _TodoTaskItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(item.title),
        subtitle: Text('${item.listName} · ${item.status}'),
        trailing: const Icon(Icons.more_horiz),
      ),
    );
  }
}

class _QueueTileCard extends StatelessWidget {
  const _QueueTileCard({required this.item});

  final _SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: Text(item.action),
        subtitle: Text(item.state),
      ),
    );
  }
}

class _TodoListItem {
  const _TodoListItem(this.name, this.taskCount, this.completedCount);

  final String name;
  final int taskCount;
  final int completedCount;

  Map<String, dynamic> toJson() => {
    'name': name,
    'taskCount': taskCount,
    'completedCount': completedCount,
  };
}

class _TodoTaskItem {
  const _TodoTaskItem(this.title, this.listName, this.status);

  final String title;
  final String listName;
  final String status;

  Map<String, dynamic> toJson() => {
    'title': title,
    'listName': listName,
    'status': status,
  };
}

class _CalendarEventItem {
  const _CalendarEventItem(this.time, this.title, this.listName, this.bucket);

  final String time;
  final String title;
  final String listName;
  final String bucket;

  Map<String, dynamic> toJson() => {
    'time': time,
    'title': title,
    'listName': listName,
    'bucket': bucket,
  };
}

class _SyncQueueItem {
  const _SyncQueueItem(this.action, this.state);

  final String action;
  final String state;

  Map<String, dynamic> toJson() => {'action': action, 'state': state};
}

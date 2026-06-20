import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'efficiency_dashboard.dart';
import 'system_entry_dashboard.dart';
import 'todo_member_auth_client.dart';
import 'features/list/list_page.dart';
import 'features/task/tasks_by_list_page.dart';

void main() {
  runApp(const TodoFlutterApp());
}

class TodoFlutterApp extends StatelessWidget {
  const TodoFlutterApp({super.key, this.authClient});

  final TodoMemberAuthGateway? authClient;

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
      home: TodoHomePage(authClient: authClient),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, this.authClient});

  final TodoMemberAuthGateway? authClient;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  static const _cacheKey = 'zh_cloud_todo_flutter_state_v2';
  static const _quadrantNames = <String>['紧急且重要', '重要不紧急', '紧急不重要', '不紧急不重要'];
  static const _pomodoroDurationSeconds = 25 * 60;

  bool _isLoading = true;
  bool _isSignedIn = false;
  TodoAuthSession? _authSession;
  late final TodoMemberAuthGateway _authClient;
  String _activeTab = '日历';
  String _calendarView = '周';
  late List<_TodoListItem> _lists;
  late List<_TodoTaskItem> _tasks;
  late List<_CalendarEventItem> _calendarEvents;
  late List<_SyncQueueItem> _syncQueue;
  late List<EfficiencyQuadrantItem> _quadrantItems;
  late List<EfficiencyHabitItem> _habits;
  late List<EfficiencyCountdownItem> _countdowns;
  late List<SystemEntryNote> _systemNotes;
  late List<SystemEntryImportItem> _systemImports;
  String _systemShareStatus = '等待系统分享内容';
  int _pomodoroSecondsRemaining = _pomodoroDurationSeconds;
  int _pomodoroCompletedRounds = 0;
  bool _pomodoroRunning = false;
  Timer? _pomodoroTimer;

  @override
  void initState() {
    super.initState();
    _authClient = widget.authClient ?? TodoMemberAuthClient();
    _seedState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    if (widget.authClient == null) {
      _authClient.close();
    }
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
    _systemNotes = [
      const SystemEntryNote(title: '今日便签', content: '检查桌面入口和导入队列。'),
      const SystemEntryNote(title: '同步提醒', content: 'B4 收口前同步 Web 与 Flutter。'),
    ];
    _systemImports = [
      const SystemEntryImportItem(source: 'CSV 任务文件', status: '待确认'),
      const SystemEntryImportItem(source: '日历订阅 URL', status: '可预览'),
    ];
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final authSession = data['authSession'];
      if (authSession is Map) {
        _authSession = TodoAuthSession.fromJson(
          authSession.cast<String, dynamic>(),
        );
      }
      _isSignedIn = _authSession?.isValid == true;
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
      _systemNotes = _decodeSystemNotes(data['systemNotes'] as List<dynamic>?);
      _systemImports = _decodeSystemImports(
        data['systemImports'] as List<dynamic>?,
      );
      _systemShareStatus =
          data['systemShareStatus'] as String? ?? _systemShareStatus;
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
        'authSession': _authSession?.toJson(),
        'activeTab': _activeTab,
        'calendarView': _calendarView,
        'lists': _lists.map((item) => item.toJson()).toList(),
        'tasks': _tasks.map((item) => item.toJson()).toList(),
        'calendarEvents': _calendarEvents.map((item) => item.toJson()).toList(),
        'syncQueue': _syncQueue.map((item) => item.toJson()).toList(),
        'quadrantItems': _quadrantItems.map((item) => item.toJson()).toList(),
        'habits': _habits.map((item) => item.toJson()).toList(),
        'countdowns': _countdowns.map((item) => item.toJson()).toList(),
        'systemNotes': _systemNotes.map((item) => item.toJson()).toList(),
        'systemImports': _systemImports.map((item) => item.toJson()).toList(),
        'systemShareStatus': _systemShareStatus,
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

  List<SystemEntryNote> _decodeSystemNotes(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map((json) => SystemEntryNote.fromJson(json.cast<String, dynamic>()))
        .toList();
    return items?.isNotEmpty == true ? items! : _systemNotes;
  }

  List<SystemEntryImportItem> _decodeSystemImports(List<dynamic>? raw) {
    final items = raw
        ?.whereType<Map>()
        .map(
          (json) =>
              SystemEntryImportItem.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
    return items?.isNotEmpty == true ? items! : _systemImports;
  }

  void _goToTab(String tab) {
    setState(() {
      _activeTab = tab;
    });
    _persistState();
  }

  Future<void> _handleAuthenticated(
    TodoAuthSession session,
    String action,
  ) async {
    setState(() {
      _authSession = session;
      _isSignedIn = true;
      _activeTab = '日历';
      _syncQueue.insert(0, _SyncQueueItem(action, '已同步'));
    });
    await _persistState();
  }

  Future<void> _logout() async {
    final accessToken = _authSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await _authClient.logout(accessToken);
      } on Object {
        // 本地退出不能被网络失败阻塞。
      }
    }
    setState(() {
      _authSession = null;
      _isSignedIn = false;
      _syncQueue.insert(0, const _SyncQueueItem('logout', '已同步'));
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

  Future<void> _addSystemNote() async {
    setState(() {
      _systemNotes = [
        SystemEntryNote(
          title: '桌面便签 ${_systemNotes.length + 1}',
          content: '来自系统入口的本地便签。',
        ),
        ..._systemNotes,
      ];
      _syncQueue.insert(0, const _SyncQueueItem('desktop note', '已写入本地'));
    });
    await _persistState();
  }

  Future<void> _simulateSystemShare() async {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    setState(() {
      _systemShareStatus = '已接收系统分享：$hour:$minute';
      _syncQueue.insert(0, const _SyncQueueItem('system share', '已接收'));
    });
    await _persistState();
  }

  Future<void> _addImportRecord() async {
    setState(() {
      _systemImports = [
        SystemEntryImportItem(
          source: '导入入口 ${_systemImports.length + 1}',
          status: '已加入队列',
        ),
        ..._systemImports,
      ];
      _syncQueue.insert(0, const _SyncQueueItem('import entry', '已排队'));
    });
    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('zh-cloud todo')),
        body: _TodoAuthPage(
          authClient: _authClient,
          onAuthenticated: _handleAuthenticated,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('zh-cloud todo'),
        actions: [
          IconButton(
            tooltip: '系统入口',
            onPressed: () => _goToTab('系统'),
            icon: const Icon(Icons.widgets_outlined),
          ),
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
            tooltip: '退出登录',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
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
          : _activeTab == '系统'
          ? SystemEntryTabView(
              taskCount: _tasks.length,
              syncQueueCount: _syncQueue.length,
              notes: _systemNotes,
              imports: _systemImports,
              shareStatus: _systemShareStatus,
              onAddNote: _addSystemNote,
              onSimulateShare: _simulateSystemShare,
              onAddImport: _addImportRecord,
            )
          : _activeTab == '清单'
          ? const ListPage()
          : _activeTab == '任务'
          ? const TasksByListPage()
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
          NavigationDestination(icon: Icon(Icons.widgets), label: '系统'),
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
      case '系统':
        return 3;
      case '清单':
        return 4;
      case '同步':
        return 5;
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
        return '系统';
      case 4:
        return '清单';
      case 5:
        return '同步';
      default:
        return '任务';
    }
  }
}

enum _AuthMode { password, sms, register, forgotPassword }

class _TodoAuthPage extends StatefulWidget {
  const _TodoAuthPage({
    required this.authClient,
    required this.onAuthenticated,
  });

  final TodoMemberAuthGateway authClient;
  final Future<void> Function(TodoAuthSession session, String action)
  onAuthenticated;

  @override
  State<_TodoAuthPage> createState() => _TodoAuthPageState();
}

class _TodoAuthPageState extends State<_TodoAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthMode _mode = _AuthMode.password;
  bool _submitting = false;
  bool _sendingCode = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPasswordMode = _mode == _AuthMode.password;
    final isForgotMode = _mode == _AuthMode.forgotPassword;
    final title = switch (_mode) {
      _AuthMode.password => '密码登录',
      _AuthMode.sms => '短信验证码登录',
      _AuthMode.register => '注册 Todo 账号',
      _AuthMode.forgotPassword => '找回密码',
    };
    final subtitle = switch (_mode) {
      _AuthMode.password => '使用 todo-member 手机号和密码进入任务空间',
      _AuthMode.sms => '验证码登录会复用 todo-member token',
      _AuthMode.register => '手机号验证码登录即注册，不创建独立用户池',
      _AuthMode.forgotPassword => '验证码校验后重置密码，再返回登录页',
    };

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            key: const ValueKey('todo-auth-list'),
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Icon(Icons.task_alt, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Todo 账号入口', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 20),
              SegmentedButton<_AuthMode>(
                segments: const [
                  ButtonSegment(
                    value: _AuthMode.password,
                    icon: Icon(Icons.lock_outline),
                    label: Text('密码'),
                  ),
                  ButtonSegment(
                    value: _AuthMode.sms,
                    icon: Icon(Icons.sms_outlined),
                    label: Text('验证码'),
                  ),
                ],
                selected: {
                  isPasswordMode || isForgotMode
                      ? _AuthMode.password
                      : _AuthMode.sms,
                },
                onSelectionChanged: (selection) {
                  final next = selection.first;
                  _switchMode(next);
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '手机号',
                            prefixIcon: Icon(Icons.phone_iphone),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateMobile,
                        ),
                        const SizedBox(height: 12),
                        if (isPasswordMode || isForgotMode) ...[
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: isForgotMode ? '新密码' : '密码',
                              prefixIcon: const Icon(Icons.password),
                              border: const OutlineInputBorder(),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!isPasswordMode) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '短信验证码',
                                    prefixIcon: Icon(Icons.verified_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _validateCode,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 56,
                                child: OutlinedButton.icon(
                                  onPressed: _isBusy ? null : _sendCode,
                                  icon: _sendingCode
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_to_mobile),
                                  label: const Text('发送'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_message != null) ...[
                          _AuthMessage(
                            text: _message!,
                            isError: _messageIsError,
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          key: const ValueKey('todo-auth-submit'),
                          onPressed: _isBusy ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isForgotMode
                                      ? Icons.restart_alt
                                      : Icons.login,
                                ),
                          label: Text(_submitLabel),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _switchMode(_AuthMode.register),
                              child: const Text('注册'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _switchMode(_AuthMode.forgotPassword),
                              child: const Text('忘记密码'),
                            ),
                            if (_mode != _AuthMode.password)
                              TextButton(
                                onPressed: () =>
                                    _switchMode(_AuthMode.password),
                                child: const Text('返回密码登录'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isBusy => _submitting || _sendingCode;

  String get _submitLabel {
    return switch (_mode) {
      _AuthMode.password => '登录',
      _AuthMode.sms => '验证码登录',
      _AuthMode.register => '注册并登录',
      _AuthMode.forgotPassword => '重置密码',
    };
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
      _messageIsError = false;
      if (mode != _AuthMode.forgotPassword) {
        _passwordController.clear();
      }
      _codeController.clear();
    });
  }

  Future<void> _sendCode() async {
    final mobileError = _validateMobile(_mobileController.text);
    if (mobileError != null) {
      setState(() {
        _message = mobileError;
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _sendingCode = true;
      _message = null;
    });
    try {
      await widget.authClient.sendSmsCode(
        mobile: _mobileController.text.trim(),
        scene: _mode == _AuthMode.forgotPassword ? 4 : 1,
      );
      setState(() {
        _message = _mode == _AuthMode.forgotPassword
            ? '重置密码验证码已发送'
            : '登录验证码已发送';
        _messageIsError = false;
      });
    } on TodoMemberAuthException catch (error) {
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } on Object catch (error) {
      setState(() {
        _message = '验证码发送失败：$error';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingCode = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      if (_mode == _AuthMode.password) {
        final session = await widget.authClient.passwordLogin(
          mobile: _mobileController.text.trim(),
          password: _passwordController.text,
        );
        await widget.onAuthenticated(session, 'password login');
        return;
      }
      if (_mode == _AuthMode.forgotPassword) {
        await widget.authClient.resetPassword(
          mobile: _mobileController.text.trim(),
          code: _codeController.text.trim(),
          password: _passwordController.text,
        );
        setState(() {
          _mode = _AuthMode.password;
          _passwordController.clear();
          _codeController.clear();
          _message = '密码已重置，请使用新密码登录';
          _messageIsError = false;
        });
        return;
      }
      final session = await widget.authClient.smsLogin(
        mobile: _mobileController.text.trim(),
        code: _codeController.text.trim(),
      );
      await widget.onAuthenticated(
        session,
        _mode == _AuthMode.register ? 'sms register' : 'sms login',
      );
    } on TodoMemberAuthException catch (error) {
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } on Object catch (error) {
      setState(() {
        _message = '账号请求失败：$error';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String? _validateMobile(String? value) {
    final mobile = value?.trim() ?? '';
    if (mobile.isEmpty) {
      return '请输入手机号';
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(mobile)) {
      return '请输入 11 位手机号';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return _mode == _AuthMode.forgotPassword ? '请输入新密码' : '请输入密码';
    }
    if (password.length < 4 || password.length > 16) {
      return '密码长度为 4-16 位';
    }
    return null;
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return '请输入短信验证码';
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(code)) {
      return '验证码为 4-6 位数字';
    }
    return null;
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
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

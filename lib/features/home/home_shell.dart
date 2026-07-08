import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/session_state.dart';
import '../../core/notification/local_notification_service.dart';
import '../efficiency/efficiency_hub_page.dart';
import '../list/list_page.dart';
import '../native/native_entry_page.dart';
import '../quadrant/quadrant_rules_page.dart';
import '../reminder/reminder_inbox_page.dart';
import '../settings/settings_route.dart';
import '../calendar_sub/calendar_subscription_page.dart';
import '../task/tasks_by_list_page.dart';

/// 登录后的主导航壳：任务 / 清单 / 效率 / 系统，四个底部 tab。
///
/// 应用启动、恢复前台、任一 tab 手动触发时调用 [SyncCoordinator.syncOnce]。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _syncing = false;
  Timer? _periodicSync;

  static const _pages = [
    TasksByListPage(),
    ListPage(),
    EfficiencyHubPage(),
    NativeEntryPage(),
  ];

  static const _labels = ['任务', '清单', '效率', '系统'];
  static const _icons = [
    Icons.check_circle_outline,
    Icons.list_alt,
    Icons.bolt_outlined,
    Icons.widgets_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerSync();
    // 初始化本地通知（测试环境无平台实现，内部已短路不抛异常）。
    _initNotifications();
    // 测试环境跳过周期性同步 / 提醒轮询（避免 pumpAndSettle 永远等不到空闲）。
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      _periodicSync = Timer.periodic(const Duration(seconds: 30), (_) {
        _triggerSync();
        _pollUpcomingReminders();
      });
    }
  }

  /// 初始化本地通知并申请权限（测试环境安全短路）。
  Future<void> _initNotifications() async {
    final svc = ref.read(localNotificationServiceProvider);
    try {
      await svc.init();
      await svc.requestPermissions();
    } catch (_) {
      // 由 service 内部 catch，此处再兜底一层：不允许通知异常影响主壳。
    }
  }

  /// 拉取即将到期的提醒，以本地通知提示用户（仅在即将到期窗口内触发）。
  Future<void> _pollUpcomingReminders() async {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return;
    final svc = ref.read(localNotificationServiceProvider);
    final api = ref.read(todoApiProvider).reminder;
    final db = ref.read(appDatabaseProvider);
    if (db == null) return;
    try {
      final items = await api.inbox();
      final now = DateTime.now();
      for (final it in items.where((e) => e.pending)) {
        final diff = it.remindAt.difference(now);
        // 窗口：已过期 或 30 秒内到期。
        if (diff.inSeconds <= 30) {
          final task = await db.taskByServerId(it.taskId);
          final taskTitle =
              (task != null && task.title.isNotEmpty) ? task.title : it.taskTitle;
          await svc.show(
            id: it.id,
            title: taskTitle.isEmpty ? '提醒' : taskTitle,
            body: '到期提醒',
            payload: 'reminder:${it.id}',
          );
        }
      }
    } catch (_) {
      // 轮询失败静默，下一次定时器再试。
    }
  }

  @override
  void dispose() {
    _periodicSync?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
    }
  }

  Future<void> _triggerSync() async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null || _syncing) return;
    _syncing = true;
    try {
      await coordinator.syncOnce();
    } catch (_) {
      // 同步失败静默重试（下一次定时器 / 手动触发再试）。
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_labels[_tabIndex]),
        actions: [
          IconButton(
            tooltip: '提醒收件箱',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReminderInboxPage()),
            ),
          ),
          IconButton(
            tooltip: '四象限规则',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuadrantRulesPage()),
            ),
          ),
          IconButton(
            tooltip: '日历订阅',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CalendarSubscriptionPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsRoute(signedInMobile: session?.mobile),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
        ],
      ),
    );
  }
}

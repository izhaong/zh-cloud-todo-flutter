import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/session_state.dart';
import '../efficiency/efficiency_hub_page.dart';
import '../list/list_page.dart';
import '../native/native_entry_page.dart';
import '../quadrant/quadrant_rules_page.dart';
import '../settings/settings_route.dart';
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
    // 测试环境跳过周期性同步（避免 pumpAndSettle 永远等不到空闲）。
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      _periodicSync = Timer.periodic(const Duration(seconds: 30), (_) {
        _triggerSync();
      });
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
            tooltip: '立即同步',
            icon: const Icon(Icons.sync),
            onPressed: _triggerSync,
          ),
          IconButton(
            tooltip: '四象限规则',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuadrantRulesPage()),
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

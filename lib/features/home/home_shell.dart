import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification/local_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';
import '../habit/habit_page.dart';
import '../settings/settings_route.dart';
import '../tag/tag_page.dart';
import '../task/tasks_by_list_page.dart';
import '../task/views/calendar_view.dart';
import '../../core/db/app_database.dart';
import '../shell/section.dart';
import '../shell/sidebar.dart';
import '../shell/quick_add_bar.dart';

/// 自适应主壳：依据视口宽度在三套布局间切换。
///
/// - 桌面 (≥1024px)：左侧常驻 [Sidebar] + 右侧内容区（顶部 QuickAddBar + 视图）。
/// - 平板 (600–1023px)：可收起 Sidebar（汉堡 + 抽屉）+ 右侧内容区。
/// - 移动 (<600px)：底部 TabBar（任务/日历/习惯/我的）+ 抽屉展开 Sidebar + FAB。
///
/// 状态（选中的分区 / 智能清单 / 清单）集中在此，Sidebar 与底部 TabBar 共用。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  Section _section = Section.tasks;
  SmartList _smart = SmartList.inbox;
  String? _listId;

  bool _syncing = false;
  Timer? _periodicSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerSync();
    _initNotifications();
    if (!const bool.fromEnvironment('FLUTTER_TEST')) {
      _periodicSync = Timer.periodic(const Duration(seconds: 30), (_) {
        _triggerSync();
        _pollUpcomingReminders();
      });
    }
  }

  Future<void> _initNotifications() async {
    final svc = ref.read(localNotificationServiceProvider);
    try {
      await svc.init();
      await svc.requestPermissions();
    } catch (_) {}
  }

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _periodicSync?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _triggerSync();
  }

  Future<void> _triggerSync() async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null || _syncing) return;
    _syncing = true;
    try {
      await coordinator.syncOnce();
    } catch (_) {
      // 同步失败静默重试。
    } finally {
      _syncing = false;
    }
  }

  // --- 导航回调 ---
  void _selectSection(Section s) => setState(() => _section = s);
  void _selectSmart(SmartList s) => setState(() => _smart = s);
  void _selectList(String? id) => setState(() => _listId = id);

  void _openTags() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TagPage()));
  }

  void _openFilters() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const _FiltersPage()));
  }

  void _openSettings() {
    final session = ref.read(sessionProvider);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsRoute(signedInMobile: session?.mobile),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width >= 1024) {
        return _desktopShell(width: width);
      } else if (width >= 600) {
        return _tabletShell();
      }
      return _mobileShell();
    });
  }

  /// 当前任务页的 dueRange（由智能清单映射）。
  String? get _dueRange {
    switch (_smart) {
      case SmartList.today:
        return 'today';
      case SmartList.upcoming:
        return 'last7days';
      default:
        return null;
    }
  }

  /// 任务分区当前选中的清单 id。
  String? get _effectiveListId {
    if (_smart == SmartList.inbox) return 'inbox';
    return _listId;
  }

  Widget _buildContent() {
    switch (_section) {
      case Section.tasks:
        return _TasksPane(
          dueRange: _dueRange,
          listId: _effectiveListId,
          onQuickAdd: _quickAdd,
        );
      case Section.calendar:
        return const _CalendarHost();
      case Section.habit:
        return const HabitPage();
      case Section.mine:
        return const _MinePane();
    }
  }

  Future<void> _quickAdd(String title) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final listId = _effectiveListId ?? 'inbox';
    await repo.create(listId: listId, title: title);
  }

  // === 桌面：Sidebar 常驻 ===
  Widget _desktopShell({required double width}) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedSection: _section,
            selectedSmart: _smart,
            selectedListId: _listId,
            onSelectSection: _selectSection,
            onSelectSmart: _selectSmart,
            onSelectList: _selectList,
            onOpenTags: _openTags,
            onOpenFilters: _openFilters,
            onOpenSettings: _openSettings,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _ContentTopBar(
                  title: '任务',
                  onSearch: () {},
                  onAvatar: () {},
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === 平板：Sidebar 可收起（抽屉）===
  Widget _tabletShell() {
    return Scaffold(
      appBar: _shellAppBar(),
      drawer: Drawer(
        child: Sidebar(
          selectedSection: _section,
          selectedSmart: _smart,
          selectedListId: _listId,
          onSelectSection: (s) {
            _selectSection(s);
            Navigator.pop(context);
          },
          onSelectSmart: (s) {
            _selectSmart(s);
            Navigator.pop(context);
          },
          onSelectList: (id) {
            _selectList(id);
            Navigator.pop(context);
          },
          onOpenTags: _openTags,
          onOpenFilters: _openFilters,
          onOpenSettings: () {
            Navigator.pop(context);
            _openSettings();
          },
        ),
      ),
      body: Column(
        children: [
          _ContentTopBar(
            title: '任务',
            onSearch: () {},
            onAvatar: () {},
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // === 移动：底部 TabBar + 抽屉 + FAB ===
  Widget _mobileShell() {
    return Scaffold(
      appBar: _shellAppBar(),
      drawer: Drawer(
        child: Sidebar(
          selectedSection: _section,
          selectedSmart: _smart,
          selectedListId: _listId,
          onSelectSection: (s) {
            _selectSection(s);
            Navigator.pop(context);
          },
          onSelectSmart: (s) {
            _selectSmart(s);
            Navigator.pop(context);
          },
          onSelectList: (id) {
            _selectList(id);
            Navigator.pop(context);
          },
          onOpenTags: _openTags,
          onOpenFilters: _openFilters,
          onOpenSettings: () {
            Navigator.pop(context);
            _openSettings();
          },
        ),
      ),
      body: _buildContent(),
      floatingActionButton: _section == Section.tasks
          ? FloatingActionButton(
              onPressed: () => _showQuickAddSheet(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: Section.values.indexOf(_section),
        onDestinationSelected: (i) =>
            setState(() => _section = Section.values[i]),
        destinations: [
          for (final s in Section.values)
            NavigationDestination(icon: Icon(s.icon), label: s.label),
        ],
      ),
    );
  }

  PreferredSizeWidget _shellAppBar() {
    return AppBar(
      title: Text(_section.label),
      actions: [
        IconButton(
          tooltip: '搜索',
          icon: const Icon(Icons.search),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {},
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 15,
              backgroundColor:
                  AppColors.light.mutedForeground.withValues(alpha: 0.2),
              child: Icon(Icons.person,
                  size: 18, color: AppColors.light.foreground),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showQuickAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: '新任务'),
        ),
      ),
    );
  }
}

/// 内容区顶栏：标题 + 搜索 + 头像菜单。
class _ContentTopBar extends StatelessWidget {
  const _ContentTopBar({
    required this.title,
    required this.onSearch,
    required this.onAvatar,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '搜索',
            icon: Icon(Icons.search, color: colors.mutedForeground),
            onPressed: onSearch,
          ),
          InkWell(
            onTap: onAvatar,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colors.accent.withValues(alpha: 0.12),
              child: Icon(Icons.person, size: 18, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务分区：顶部 QuickAddBar + 任务视图。
class _TasksPane extends StatelessWidget {
  const _TasksPane({
    required this.dueRange,
    required this.listId,
    required this.onQuickAdd,
  });

  final String? dueRange;
  final String? listId;
  final ValueChanged<String> onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuickAddBar(onSubmit: onQuickAdd),
        Expanded(
          child: TasksByListPage(
            hideAppBar: true,
            lockedListId: true,
            initialListId: listId,
            initialDueRange: dueRange,
          ),
        ),
      ],
    );
  }
}

/// 日历分区：复用 CalendarView，包顶层 AppBar-less 容器。
class _CalendarHost extends ConsumerWidget {
  const _CalendarHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(taskRepositoryProvider);
    if (repo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<List<TodoTask>>(
      stream: repo.watchAll(),
      builder: (ctx, snap) {
        final tasks = snap.data ?? const <TodoTask>[];
        return CalendarView(tasks: tasks);
      },
    );
  }
}

/// "我的"分区：账户 + 设置 + 退出登录。
class _MinePane extends ConsumerWidget {
  const _MinePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final colors = Theme.of(context).extension<AppThemeExtension>()!.colors;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colors.accent.withValues(alpha: 0.12),
            child: Icon(Icons.person, color: colors.accent),
          ),
          title: Text(session?.mobile ?? '已登录',
              style: TextStyle(color: colors.foreground)),
          subtitle: Text('zh-cloud todo',
              style: TextStyle(color: colors.mutedForeground)),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.settings_outlined, color: colors.mutedForeground),
          title: const Text('设置'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SettingsRoute(signedInMobile: session?.mobile),
          )),
        ),
        ListTile(
          leading: Icon(Icons.logout, color: colors.destructive),
          title: const Text('退出登录'),
          onTap: () => ref.read(sessionProvider.notifier).signOut(),
        ),
      ],
    );
  }
}

/// 简易筛选器页（占位整合入口）。
class _FiltersPage extends StatelessWidget {
  const _FiltersPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('筛选器')),
      body: ListView(
        children: const [
          ListTile(title: Text('今日任务')),
          ListTile(title: Text('已完成')),
          ListTile(title: Text('已过期')),
        ],
      ),
    );
  }
}

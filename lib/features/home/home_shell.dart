import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/notification/local_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../../state/session_state.dart';
import '../habit/habit_page.dart';
import '../settings/settings_route.dart';
import '../shell/section.dart';
import '../task/tasks_by_list_page.dart';
import '../task/views/calendar_view.dart';
import '../tag/tag_page.dart';
import 'ticktick_workspace.dart';

/// TickTick 风格主壳：只负责状态与内容分发，布局交给 [TickTickWorkspace]。
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
          final taskTitle = (task != null && task.title.isNotEmpty)
              ? task.title
              : it.taskTitle;
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

  void _selectSection(Section s) => setState(() => _section = s);
  void _selectSmart(SmartList s) => setState(() {
    _smart = s;
    _listId = null;
  });
  void _selectList(String? id) => setState(() {
    _smart = SmartList.all;
    _listId = id;
  });

  void _openTags() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TagPage()));
  }

  void _openFilters() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _FiltersPage()));
  }

  void _openSettings() {
    final session = ref.read(sessionProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsRoute(signedInMobile: session?.mobile),
      ),
    );
  }

  Future<void> _quickAdd(String title) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final listId = _effectiveListId ?? 'inbox';
    await repo.create(listId: listId, title: title);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TickTickWorkspace(
          width: width,
          section: _section,
          smart: _smart,
          listId: _listId,
          content: _buildContent(),
          onSelectSection: _selectSection,
          onSelectSmart: _selectSmart,
          onSelectList: _selectList,
          onOpenTags: _openTags,
          onOpenFilters: _openFilters,
          onOpenSettings: _openSettings,
          onQuickAdd: _quickAdd,
        );
      },
    );
  }

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

  String? get _effectiveListId {
    switch (_smart) {
      case SmartList.inbox:
        return 'inbox';
      case SmartList.all:
        return _listId;
      case SmartList.today:
      case SmartList.upcoming:
      case SmartList.completed:
      case SmartList.trash:
        return null;
    }
  }

  Widget _buildContent() {
    switch (_section) {
      case Section.tasks:
        return _buildTaskPane();
      case Section.calendar:
        return const _CalendarHost();
      case Section.habit:
        return const HabitPage();
      case Section.mine:
        return const _MinePane();
    }
  }

  Widget _buildTaskPane() {
    if (_smart == SmartList.trash) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppEmptyState(title: '垃圾桶', subtitle: '回收站内容将显示在这里。'),
      );
    }
    return TasksByListPage(
      hideAppBar: true,
      lockedListId: true,
      initialListId: _effectiveListId,
      initialDueRange: _dueRange,
      initialCompleted: _smart == SmartList.completed ? true : null,
    );
  }
}

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
          title: Text(
            session?.mobile ?? '已登录',
            style: TextStyle(color: colors.foreground),
          ),
          subtitle: Text(
            'zh-cloud todo',
            style: TextStyle(color: colors.mutedForeground),
          ),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.settings_outlined, color: colors.mutedForeground),
          title: const Text('设置'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SettingsRoute(signedInMobile: session?.mobile),
            ),
          ),
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

class _FiltersPage extends StatelessWidget {
  const _FiltersPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('筛选器')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          ListTile(title: Text('今日任务')),
          ListTile(title: Text('已完成')),
          ListTile(title: Text('已过期')),
        ],
      ),
    );
  }
}

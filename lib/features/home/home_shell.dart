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
import '../task/task_detail_page.dart';
import '../task/task_detail_pane.dart';
import '../task/tasks_by_list_page.dart';
import '../task/views/calendar_view.dart';
import '../tag/tag_page.dart';
import 'sync_recovery_banner.dart';
import 'todo_workspace.dart';

/// Todo 主壳：只负责状态与内容分发，布局交给 [TodoWorkspace]。
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
  String? _selectedTaskId;
  final _workspaceScaffoldKey = GlobalKey<ScaffoldState>();
  TodoWorkspaceProfile? _layoutProfile;
  int _detailPresentationGeneration = 0;
  Route<void>? _mobileDetailRoute;
  bool _mobileDetailDismissInProgress = false;
  bool _preserveSelectionWhenMobileRouteCloses = false;

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

  Future<void> _retryFailedSyncChanges(List<TodoSyncChange> changes) async {
    final queue = ref.read(syncChangeQueueProvider);
    if (queue == null) return;
    for (final change in changes) {
      await queue.retryNow(change.id);
    }
    await _triggerSync();
  }

  void _selectSection(Section section) {
    if (section == _section) return;
    final hadTaskSelection = _selectedTaskId != null;
    setState(() {
      _section = section;
      _selectedTaskId = null;
    });
    if (hadTaskSelection) _dismissDetailPresentation();
  }

  void _selectSmart(SmartList smart) {
    if (smart == _smart && _listId == null) return;
    final hadTaskSelection = _selectedTaskId != null;
    setState(() {
      _smart = smart;
      _listId = null;
      _selectedTaskId = null;
    });
    if (hadTaskSelection) _dismissDetailPresentation();
  }

  void _selectList(String? id) {
    final smart = id == 'inbox' ? SmartList.inbox : SmartList.all;
    if (smart == _smart && id == _listId) return;
    final hadTaskSelection = _selectedTaskId != null;
    setState(() {
      _smart = smart;
      _listId = id;
      _selectedTaskId = null;
    });
    if (hadTaskSelection) _dismissDetailPresentation();
  }

  void _selectTask(String taskId) {
    final profile = todoWorkspaceProfileForWidth(
      MediaQuery.sizeOf(context).width,
    );
    if (taskId == _selectedTaskId) {
      _presentTask(taskId, profile);
      return;
    }
    setState(() => _selectedTaskId = taskId);
    _presentTask(taskId, profile);
  }

  void _invalidateTaskSelection(String taskId) {
    if (taskId != _selectedTaskId) return;
    setState(() => _selectedTaskId = null);
    _dismissDetailPresentation();
  }

  void _clearTaskSelection() {
    if (_selectedTaskId == null) return;
    setState(() => _selectedTaskId = null);
    _dismissDetailPresentation();
  }

  void _handleDetailDrawerChanged(TodoWorkspaceProfile profile, bool isOpen) {
    if (isOpen || profile != _layoutProfile || _selectedTaskId == null) return;
    _detailPresentationGeneration++;
    setState(() => _selectedTaskId = null);
  }

  void _syncLayoutProfile(TodoWorkspaceProfile profile) {
    final previous = _layoutProfile;
    if (previous == profile) return;
    _layoutProfile = profile;
    final selectedTaskId = _selectedTaskId;
    if (selectedTaskId == null) {
      if (profile != TodoWorkspaceProfile.mobile) {
        _dismissMobileDetail(preserveSelection: true);
      }
      return;
    }
    _presentTask(selectedTaskId, profile);
  }

  void _presentTask(String taskId, TodoWorkspaceProfile profile) {
    final generation = ++_detailPresentationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _detailPresentationGeneration ||
          _selectedTaskId != taskId ||
          _layoutProfile != profile) {
        return;
      }
      switch (profile) {
        case TodoWorkspaceProfile.wide:
          _dismissMobileDetail(preserveSelection: true);
          return;
        case TodoWorkspaceProfile.compact:
        case TodoWorkspaceProfile.tablet:
          _dismissMobileDetail(preserveSelection: true);
          final scaffold = _workspaceScaffoldKey.currentState;
          if (scaffold != null && !scaffold.isEndDrawerOpen) {
            scaffold.openEndDrawer();
          }
          return;
        case TodoWorkspaceProfile.mobile:
          unawaited(_openMobileDetail(taskId));
          return;
      }
    });
  }

  Future<void> _openMobileDetail(String taskId) async {
    if (_mobileDetailRoute != null) return;
    final route = MaterialPageRoute<void>(
      settings: RouteSettings(name: 'todo-task-detail-$taskId'),
      builder: (_) => _MobileTaskDetailRoute(
        taskId: taskId,
        onLeaveMobile: () => _dismissMobileDetail(preserveSelection: true),
      ),
    );
    _mobileDetailRoute = route;
    await Navigator.of(context).push(route);
    if (!identical(_mobileDetailRoute, route)) return;
    final preserveSelection = _preserveSelectionWhenMobileRouteCloses;
    _mobileDetailRoute = null;
    _mobileDetailDismissInProgress = false;
    _preserveSelectionWhenMobileRouteCloses = false;
    if (!mounted || preserveSelection || _selectedTaskId != taskId) return;
    setState(() => _selectedTaskId = null);
  }

  void _dismissDetailPresentation() {
    _detailPresentationGeneration++;
    final scaffold = _workspaceScaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) scaffold!.closeEndDrawer();
    _dismissMobileDetail(preserveSelection: false);
  }

  void _dismissMobileDetail({required bool preserveSelection}) {
    final route = _mobileDetailRoute;
    if (route == null || _mobileDetailDismissInProgress) return;
    _mobileDetailDismissInProgress = true;
    _preserveSelectionWhenMobileRouteCloses = preserveSelection;
    Navigator.of(context).removeRoute(route);
  }

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
    final failedChanges =
        ref.watch(failedSyncChangesProvider).valueOrNull ??
        const <TodoSyncChange>[];
    final conflictCount = failedChanges
        .where((change) => change.failureReason != null)
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final profile = todoWorkspaceProfileForWidth(width);
        _syncLayoutProfile(profile);
        return TodoWorkspace(
          width: width,
          section: _section,
          smart: _smart,
          listId: _listId,
          content: Stack(
            children: [
              _buildContent(),
              if (failedChanges.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  left: 12,
                  child: SyncRecoveryBanner(
                    failedCount: failedChanges.length,
                    conflictCount: conflictCount,
                    onRetry: () => _retryFailedSyncChanges(failedChanges),
                  ),
                ),
            ],
          ),
          detail: TaskDetailPane(
            taskId: _selectedTaskId,
            embedded: true,
            onClose: _clearTaskSelection,
            onUnavailable: _invalidateTaskSelection,
          ),
          onSelectSection: _selectSection,
          onSelectSmart: _selectSmart,
          onSelectList: _selectList,
          onOpenTags: _openTags,
          onOpenFilters: _openFilters,
          onOpenSettings: _openSettings,
          scaffoldKey: _workspaceScaffoldKey,
          onDetailDrawerChanged: _handleDetailDrawerChanged,
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
      title: _taskPaneTitle,
      hideAppBar: true,
      lockedListId: true,
      initialListId: _effectiveListId,
      initialDueRange: _dueRange,
      initialCompleted: _smart == SmartList.completed ? true : null,
      selectedTaskId: _selectedTaskId,
      onTaskSelected: _selectTask,
      onSelectionInvalidated: _invalidateTaskSelection,
      onQuickAdd: _quickAdd,
    );
  }

  String get _taskPaneTitle {
    final listId = _effectiveListId;
    if (listId == 'inbox') return SmartList.inbox.label;
    if (listId != null) return '清单';
    return _smart.label;
  }
}

class _MobileTaskDetailRoute extends StatefulWidget {
  const _MobileTaskDetailRoute({
    required this.taskId,
    required this.onLeaveMobile,
  });

  final String taskId;
  final VoidCallback onLeaveMobile;

  @override
  State<_MobileTaskDetailRoute> createState() => _MobileTaskDetailRouteState();
}

class _MobileTaskDetailRouteState extends State<_MobileTaskDetailRoute> {
  bool _exitScheduled = false;

  @override
  Widget build(BuildContext context) {
    final profile = todoWorkspaceProfileForWidth(
      MediaQuery.sizeOf(context).width,
    );
    if (profile != TodoWorkspaceProfile.mobile && !_exitScheduled) {
      _exitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentProfile = todoWorkspaceProfileForWidth(
          MediaQuery.sizeOf(context).width,
        );
        if (currentProfile == TodoWorkspaceProfile.mobile) {
          _exitScheduled = false;
          return;
        }
        widget.onLeaveMobile();
      });
    }
    return TaskDetailPage(taskId: widget.taskId);
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

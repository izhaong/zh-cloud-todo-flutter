import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../native/native_intents.dart';
import '../../state/providers.dart';
import '../../state/repositories/reminder_repository.dart';
import '../shell/app_dialog.dart';
import 'task_quick_add_sheet.dart';
import '../collaboration/task_comments_page.dart';
import '../collaboration/task_assign_page.dart';
import '../collaboration/list_member_page.dart';

/// 收集箱的本地清单 id（synthetic inbox）：listId 为该值的任务视为"未归清单"。
const String kInboxListId = 'inbox';

enum _TaskDetailAction {
  previewMarkdown,
  togglePin,
  moveToInbox,
  copy,
  share,
  abandon,
  collaboration,
  delete,
}

class _RepeatRuleDraft {
  const _RepeatRuleDraft({
    required this.frequency,
    required this.interval,
    required this.weekdays,
    required this.repeatMode,
  });

  final String frequency;
  final int interval;
  final Set<int> weekdays;
  final String repeatMode;
}

class _TaskReminderSection extends ConsumerWidget {
  const _TaskReminderSection({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final repository = ref.read(reminderRepositoryProvider);
    if (db == null) return const SizedBox.shrink();
    final reminders = db.select(db.todoReminders)
      ..where((reminder) => reminder.taskId.equals(taskId))
      ..orderBy([(reminder) => OrderingTerm.asc(reminder.remindAt)]);
    return StreamBuilder<List<TodoReminder>>(
      stream: reminders.watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <TodoReminder>[];
        return Column(
          key: const Key('task-reminders'),
          children: [
            if (rows.isEmpty)
              const Align(alignment: Alignment.centerLeft, child: Text('尚无提醒')),
            for (final reminder in rows)
              _TaskReminderTile(reminder: reminder, repository: repository),
          ],
        );
      },
    );
  }
}

class _TaskReminderTile extends ConsumerWidget {
  const _TaskReminderTile({required this.reminder, required this.repository});

  final TodoReminder reminder;
  final ReminderRepository? repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    if (db == null) return const SizedBox.shrink();
    final changes = db.select(db.todoSyncChanges)
      ..where((change) => change.entity.equals('reminder'))
      ..where((change) => change.entityLocalId.equals(reminder.id))
      ..orderBy([(change) => OrderingTerm.desc(change.id)])
      ..limit(1);
    return StreamBuilder<List<TodoSyncChange>>(
      stream: changes.watch(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <TodoSyncChange>[];
        final change = rows.isEmpty ? null : rows.first;
        final syncMessage = _reminderSyncMessage(change);
        return ListTile(
          key: ValueKey('task-reminder-${reminder.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm_outlined),
          title: Text(reminder.remindAt.toLocal().toString().substring(0, 16)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.persistent
                    ? '持续提醒，每 ${reminder.intervalMinutes ?? 0} 分钟'
                    : (reminder.anchorType == 'END' ? '截止时提醒' : '单次提醒'),
              ),
              if (syncMessage != null)
                Text(
                  syncMessage,
                  key: ValueKey('task-reminder-sync-${reminder.id}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (change?.status == 'retryable')
                IconButton(
                  key: ValueKey('task-reminder-retry-${reminder.id}'),
                  tooltip: '立即重试同步',
                  onPressed: ref.read(syncCoordinatorProvider) == null
                      ? null
                      : () => _retrySync(context, ref),
                  icon: const Icon(Icons.refresh),
                ),
              IconButton(
                key: ValueKey('task-reminder-remove-${reminder.id}'),
                tooltip: '删除提醒',
                onPressed: repository == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await repository!.remove(reminder.id);
                        if (context.mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('已删除提醒')),
                          );
                        }
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _retrySync(BuildContext context, WidgetRef ref) async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await coordinator.syncOnce();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('已同步 ${outcome.pushed} 项本地变更')),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('同步暂时不可用，请稍后重试')));
    }
  }

  String? _reminderSyncMessage(TodoSyncChange? change) {
    if (change == null || change.status == 'synced') return null;
    if (change.status == 'queued') return '等待同步';
    if (change.status == 'retryable') {
      return '同步失败，等待重试（已尝试 ${change.attemptCount} 次）';
    }
    if (change.status == 'failed') return '同步冲突，保留本地版本待处理';
    return null;
  }
}

/// 可复用的真实任务详情内容：
/// - 标题 / 描述 / 优先级 / 起止 / due / list / folder / 标签 chips
/// - 子任务（多级，通过 parentTaskId）
/// - 勾选 / 取消勾选（乐观更新 + sync_queue）
///
/// [embedded] 为 true 时直接渲染在固定详情区或 Sheet 中；为 false 时保留
/// 原有全屏详情页容器。所有容器共享同一份表单与业务能力。
class TaskDetailPane extends ConsumerStatefulWidget {
  const TaskDetailPane({
    super.key,
    required this.taskId,
    this.embedded = false,
    this.onClose,
    this.onUnavailable,
  });

  final String? taskId;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<String>? onUnavailable;

  @override
  ConsumerState<TaskDetailPane> createState() => _TaskDetailPaneState();
}

class _TaskDetailPaneState extends ConsumerState<TaskDetailPane> {
  TodoTask? _task;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  int _priority = 0;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _loading = true;
  bool _clearStartAt = false;
  bool _clearEndAt = false;
  DateTime? _dueAt;
  bool _allDay = false;
  String? _timeZone;
  bool _fixedTimezone = false;
  TodoRepeatRule? _repeatRule;
  bool _repeatOccurrenceSkipped = false;
  String? _selectedListId;
  String? _listName;
  StreamSubscription<TodoTask?>? _taskSubscription;
  int _loadGeneration = 0;
  int _liveSnapshotGeneration = 0;
  String? _unavailableNotifiedFor;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _desc = TextEditingController();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(covariant TaskDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.taskId != oldWidget.taskId) {
      unawaited(_bootstrap());
    }
  }

  Future<void> _bootstrap() async {
    final generation = ++_loadGeneration;
    _liveSnapshotGeneration++;
    final taskId = widget.taskId;
    final previousSubscription = _taskSubscription;
    _taskSubscription = null;
    unawaited(previousSubscription?.cancel());
    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _task = null;
      _title.clear();
      _desc.clear();
      _priority = 0;
      _startAt = null;
      _endAt = null;
      _clearStartAt = false;
      _clearEndAt = false;
      _dueAt = null;
      _allDay = false;
      _timeZone = null;
      _fixedTimezone = false;
      _repeatRule = null;
      _repeatOccurrenceSkipped = false;
      _selectedListId = null;
      _listName = null;
      _loading = taskId != null;
      _unavailableNotifiedFor = null;
    });
    if (taskId == null) return;

    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
      return;
    }

    final t = await repo.getById(taskId);
    final listName = t == null ? null : await _resolveListName(t.listId);
    final repeatRule = t == null ? null : await _repeatRuleForTask(t);
    final repeatSkipped = t == null || repeatRule == null
        ? false
        : await _repeatSkipExists(
            repeatRule.id,
            repeatRule.taskId,
            _repeatOccurrenceAt(t),
          );
    if (!mounted || generation != _loadGeneration || widget.taskId != taskId) {
      return;
    }
    setState(() {
      _task = t;
      _title.text = t?.title ?? '';
      _desc.text = t?.description ?? '';
      _priority = t?.priority ?? 0;
      _startAt = t?.startAt;
      _endAt = t?.endAt;
      _dueAt = t?.dueAt;
      _allDay = t?.allDay ?? false;
      _timeZone = t?.timeZone;
      _fixedTimezone = t?.fixedTimezone ?? false;
      _repeatRule = repeatRule;
      _repeatOccurrenceSkipped = repeatSkipped;
      _selectedListId = t?.listId;
      _listName = listName;
      _loading = false;
    });
    if (t == null) {
      _markUnavailable(taskId);
      return;
    }

    _taskSubscription = repo.watchById(taskId).listen((latest) {
      if (latest == null) {
        _markUnavailable(taskId);
        return;
      }
      unawaited(_mergeLiveTaskSnapshot(latest, taskId));
    });
  }

  Future<void> _mergeLiveTaskSnapshot(TodoTask latest, String taskId) async {
    if (!mounted || widget.taskId != taskId) return;
    final snapshotGeneration = ++_liveSnapshotGeneration;
    final listName = _task?.listId == latest.listId
        ? _listName
        : await _resolveListName(latest.listId);
    if (!mounted ||
        widget.taskId != taskId ||
        snapshotGeneration != _liveSnapshotGeneration) {
      return;
    }

    final previous = _task;
    final titleDirty = previous != null && _title.text != previous.title;
    final descriptionDirty =
        previous != null && _desc.text != (previous.description ?? '');
    final priorityDirty = previous != null && _priority != previous.priority;
    final startDirty =
        previous != null && (_clearStartAt || _startAt != previous.startAt);
    final endDirty =
        previous != null && (_clearEndAt || _endAt != previous.endAt);
    final dueDirty = previous != null && _dueAt != previous.dueAt;
    final allDayDirty = previous != null && _allDay != previous.allDay;
    final timeZoneDirty = previous != null && _timeZone != previous.timeZone;
    final fixedTimezoneDirty =
        previous != null && _fixedTimezone != previous.fixedTimezone;
    final listDirty = previous != null && _selectedListId != previous.listId;
    setState(() {
      _task = latest;
      if (!titleDirty) _title.text = latest.title;
      if (!descriptionDirty) _desc.text = latest.description ?? '';
      if (!priorityDirty) _priority = latest.priority;
      if (!startDirty) _startAt = latest.startAt;
      if (!endDirty) _endAt = latest.endAt;
      if (!dueDirty) _dueAt = latest.dueAt;
      if (!allDayDirty) _allDay = latest.allDay;
      if (!timeZoneDirty) _timeZone = latest.timeZone;
      if (!fixedTimezoneDirty) _fixedTimezone = latest.fixedTimezone;
      if (!listDirty) {
        _selectedListId = latest.listId;
        _listName = listName;
      }
      _loading = false;
      _unavailableNotifiedFor = null;
    });
  }

  Future<String> _resolveListName(String listId) async {
    if (listId == kInboxListId) return '收集箱';
    final repository = ref.read(listRepositoryProvider);
    final lists = await repository?.getAll() ?? const <TodoList>[];
    for (final list in lists) {
      if (list.id == listId) return list.name;
    }
    return '未知清单';
  }

  void _markUnavailable(String taskId) {
    if (!mounted || widget.taskId != taskId) return;
    _liveSnapshotGeneration++;
    if (_task != null || _loading) {
      setState(() {
        _task = null;
        _loading = false;
      });
    }
    if (_unavailableNotifiedFor == taskId) return;
    _unavailableNotifiedFor = taskId;
    widget.onUnavailable?.call(taskId);
  }

  void _close() {
    final callback = widget.onClose;
    if (callback != null) {
      callback();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) navigator!.pop();
  }

  bool _isCurrentTask(String taskId) {
    return mounted && widget.taskId == taskId;
  }

  @override
  void dispose() {
    unawaited(_taskSubscription?.cancel());
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _task;
    if (t == null) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    TodoTask updated;
    try {
      updated = await repo.update(
        t.id,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        priority: _priority,
        startAt: _startAt,
        endAt: _endAt,
        clearStartAt: _clearStartAt || (_startAt == null && t.startAt != null),
        clearEndAt: _clearEndAt || (_endAt == null && t.endAt != null),
        dueAt: _dueAt,
        clearDueAt: _dueAt == null && t.dueAt != null,
        allDay: _allDay,
        timeZone: _fixedTimezone ? (_timeZone ?? 'Asia/Shanghai') : _timeZone,
        fixedTimezone: _fixedTimezone,
        listId: _selectedListId == t.listId ? null : _selectedListId,
      );
    } on ArgumentError catch (error) {
      if (_isCurrentTask(t.id)) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? '任务时间无效')),
        );
      }
      return;
    }
    if (mounted && widget.taskId == updated.id) {
      setState(() {
        _task = updated;
        _clearStartAt = false;
        _clearEndAt = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  Future<void> _toggleComplete(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final updated = await repo.toggleComplete(t.id);
    if (mounted && widget.taskId == updated.id) {
      setState(() => _task = updated);
    }
  }

  Future<void> _togglePin(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final next = await repo.togglePin(t.id);
    if (!mounted || widget.taskId != t.id) return;
    setState(() => _task = next);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(next.isPinned ? '已置顶' : '已取消置顶')));
  }

  Future<void> _delete(TodoTask t) async {
    final ok = await AppDialog.confirm(
      context,
      title: '删除任务',
      content: '确认删除"${t.title}"？子任务也会被一并删除。',
      confirmLabel: '删除',
      danger: true,
    );
    if (ok != true || !_isCurrentTask(t.id)) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.delete(t.id);
    if (!_isCurrentTask(t.id)) return;
    _markUnavailable(t.id);
    _close();
  }

  Future<void> _addSubtask(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final depth = await repo.depthOf(t.id);
    if (!mounted || widget.taskId != t.id) return;
    // §2.2 子任务深度 ≤5 守卫：仅允许在深度 <5 的任务下继续添加子任务。
    if (depth >= 5) {
      messenger.showSnackBar(
        const SnackBar(content: Text('已达最大嵌套层数（5），无法继续添加子任务')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskQuickAddSheet(listId: t.listId, parentTaskId: t.id),
    );
  }

  /// §2.3 收集箱迁移：把任务挪入 synthetic inbox (listId = 'inbox')。
  Future<void> _moveToInbox(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await repo.update(t.id, listId: kInboxListId);
    if (!_isCurrentTask(t.id)) return;
    messenger.showSnackBar(const SnackBar(content: Text('已移至收集箱')));
  }

  Future<void> _moveToInboxAndClose(TodoTask t) async {
    await _moveToInbox(t);
    if (_isCurrentTask(t.id)) _close();
  }

  Future<void> _copy(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final copied = await repo.copy(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已创建“${copied.title}”')));
  }

  Future<void> _share(TodoTask t) async {
    final body = [
      t.title,
      if ((t.description ?? '').trim().isNotEmpty) t.description!.trim(),
      if (t.dueAt != null)
        '截止：${t.dueAt!.toLocal().toString().substring(0, 16)}',
    ].join('\n');
    final shared = await NativeIntents.shareText(body, subject: t.title);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(shared ? '已打开系统分享' : '当前设备不支持系统分享')));
  }

  Future<void> _previewMarkdown(TodoTask t) async {
    final description = t.description?.trim();
    if (description == null || description.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: MarkdownBody(
            data: description,
            selectable: true,
            softLineBreak: true,
          ),
        ),
      ),
    );
  }

  Future<void> _abandon(TodoTask t) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '放弃任务',
      content: '放弃后会保留记录，但不会再计入待办。',
      confirmLabel: '放弃',
      danger: true,
    );
    if (confirmed != true || !_isCurrentTask(t.id)) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.abandon(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('任务已放弃')));
  }

  /// P6 协作任务：底部 Sheet 选择（指派 / 评论 / 协作成员）。
  Future<void> _openCollaborationHub(TodoTask t) async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('指派执行人'),
              onTap: () => Navigator.pop(ctx, 'assign'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('查看/添加评论'),
              onTap: () => Navigator.pop(ctx, 'comments'),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('协作成员'),
              subtitle: const Text('邀请 / 移除 / 调整成员角色'),
              onTap: () => Navigator.pop(ctx, 'members'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted || widget.taskId != t.id) return;
    final taskServerId = t.serverId;
    if (choice == 'assign') {
      if (taskServerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务尚未同步，无法指派')));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TaskAssignPage(taskServerId: taskServerId, taskTitle: t.title),
        ),
      );
      return;
    }
    if (choice == 'comments') {
      if (taskServerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务尚未同步，暂无评论')));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TaskCommentsPage(taskServerId: taskServerId, taskTitle: t.title),
        ),
      );
      return;
    }
    if (choice == 'members') {
      final db = ref.read(appDatabaseProvider);
      if (db == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先登录')));
        return;
      }
      final list = await _resolveList(db, t.listId);
      if (!mounted || widget.taskId != t.id) return;
      final listServerId = list?.serverId;
      if (listServerId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('清单尚未同步，无法打开协作成员')));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListMemberPage(
            listServerId: listServerId,
            title: list?.name ?? t.title,
          ),
        ),
      );
    }
  }

  Future<TodoList?> _resolveList(AppDatabase db, String localListId) async {
    // listId 本地 UUID：从本地 drift 反查对应的 list serverId。
    return db.listByLocalId(localListId);
  }

  Future<TodoRepeatRule?> _repeatRuleForTask(TodoTask task) {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return Future.value(null);
    if (task.repeatRuleId != null) {
      return (db.select(
        db.todoRepeatRules,
      )..where((rule) => rule.id.equals(task.repeatRuleId!))).getSingleOrNull();
    }
    return (db.select(
      db.todoRepeatRules,
    )..where((rule) => rule.taskId.equals(task.id))).getSingleOrNull();
  }

  DateTime _repeatOccurrenceAt(TodoTask task) =>
      task.repeatOccurrenceAt ??
      _dueAt ??
      _startAt ??
      task.dueAt ??
      task.startAt ??
      DateTime.now();

  Future<bool> _repeatSkipExists(
    String repeatRuleId,
    String taskId,
    DateTime occurrenceAt,
  ) async {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return false;
    return (await (db.select(db.todoRepeatSkips)
              ..where((entry) => entry.repeatRuleId.equals(repeatRuleId))
              ..where((entry) => entry.taskId.equals(taskId))
              ..where((entry) => entry.occurrenceDate.equals(occurrenceAt)))
            .getSingleOrNull()) !=
        null;
  }

  Future<void> _pickDue(TodoTask t) async {
    final now = _dueAt ?? t.dueAt ?? DateTime.now();
    final picked = await _pickDateTime(t, now);
    if (picked == null) return;
    setState(() => _dueAt = picked);
  }

  Future<void> _showScheduleSheet(TodoTask t) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          Widget heading(String value) => Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(value, style: Theme.of(context).textTheme.labelLarge),
          );

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('日期、提醒与重复'),
                    subtitle: const Text('保存任务提交时间语义；提醒和重复会离线排队同步'),
                    trailing: IconButton(
                      key: const Key('task-schedule-close'),
                      tooltip: '关闭时间设置',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        heading('截止时间'),
                        OutlinedButton.icon(
                          key: const Key('task-due-at'),
                          onPressed: () async {
                            await _pickDue(t);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _dueAt == null
                                ? '未设置'
                                : '${_dueAt!.toLocal().toString().substring(0, 16)} (本地时区)',
                          ),
                        ),
                        if (_dueAt != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => update(() => _dueAt = null),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('清除截止时间'),
                            ),
                          ),
                        const Divider(height: 32),
                        heading('时间语义'),
                        OutlinedButton.icon(
                          key: const Key('task-start-at'),
                          onPressed: () async {
                            await _pickStartAt(t);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: Text(
                            _startAt == null
                                ? '开始时间未设置'
                                : '开始：${_startAt!.toLocal().toString().substring(0, 16)}',
                          ),
                        ),
                        if (_startAt != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key('task-clear-start-at'),
                              onPressed: () => update(() {
                                _startAt = null;
                                _clearStartAt = true;
                              }),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('清除开始时间'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-end-at'),
                          onPressed: () async {
                            await _pickEndAt(t);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                          icon: const Icon(Icons.stop_outlined),
                          label: Text(
                            _endAt == null
                                ? '结束时间未设置'
                                : '结束：${_endAt!.toLocal().toString().substring(0, 16)}',
                          ),
                        ),
                        if (_endAt != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key('task-clear-end-at'),
                              onPressed: () => update(() {
                                _endAt = null;
                                _clearEndAt = true;
                              }),
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('清除结束时间'),
                            ),
                          ),
                        SwitchListTile(
                          key: const Key('task-all-day'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('全天'),
                          subtitle: const Text('全天任务按日期范围保存，不绑定具体时分'),
                          value: _allDay,
                          onChanged: (value) => update(() => _allDay = value),
                        ),
                        SwitchListTile(
                          key: const Key('task-fixed-timezone'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('固定时区'),
                          subtitle: const Text('固定后按所选时区保留墙上时间'),
                          value: _fixedTimezone,
                          onChanged: (value) => update(() {
                            _fixedTimezone = value;
                            if (value) _timeZone ??= 'Asia/Shanghai';
                          }),
                        ),
                        if (_fixedTimezone)
                          DropdownButtonFormField<String>(
                            key: const Key('task-timezone'),
                            initialValue: _timeZone ?? 'Asia/Shanghai',
                            decoration: const InputDecoration(
                              labelText: '时区',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Asia/Shanghai',
                                child: Text('中国标准时间'),
                              ),
                              DropdownMenuItem(
                                value: 'America/Los_Angeles',
                                child: Text('美国太平洋时间'),
                              ),
                              DropdownMenuItem(
                                value: 'UTC',
                                child: Text('协调世界时'),
                              ),
                            ],
                            onChanged: (value) =>
                                update(() => _timeZone = value),
                          ),
                        const Divider(height: 32),
                        heading('提醒'),
                        OutlinedButton.icon(
                          key: const Key('task-add-absolute-reminder'),
                          onPressed: () => _addAbsoluteReminder(t),
                          icon: const Icon(Icons.add_alarm_outlined),
                          label: const Text('添加指定时间提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-end-reminder'),
                          onPressed: () => _addEndReminder(t),
                          icon: const Icon(Icons.alarm_add_outlined),
                          label: const Text('在截止时提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-before-due-reminder'),
                          onPressed: () =>
                              _addEndReminder(t, offsetMinutes: 10),
                          icon: const Icon(Icons.alarm_on_outlined),
                          label: const Text('截止前 10 分钟提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-persistent-end-reminder'),
                          onPressed: () => _addEndReminder(
                            t,
                            persistent: true,
                            intervalMinutes: 30,
                          ),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('截止时持续提醒（每 30 分钟）'),
                        ),
                        const SizedBox(height: 8),
                        _TaskReminderSection(taskId: t.id),
                        const Divider(height: 32),
                        heading('重复'),
                        OutlinedButton.icon(
                          key: const Key('task-repeat-rule'),
                          onPressed: () async {
                            await _editRepeatRule(t);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                          icon: const Icon(Icons.repeat_outlined),
                          label: Text(
                            _repeatRule == null
                                ? '不重复'
                                : _repeatRuleLabel(_repeatRule!),
                          ),
                        ),
                        if (_repeatRule?.enabled == true)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 4,
                              children: [
                                if (_repeatOccurrenceSkipped)
                                  TextButton.icon(
                                    key: const Key('task-repeat-catchup'),
                                    onPressed: () async {
                                      await _catchupRepeatOccurrence(t);
                                      if (sheetContext.mounted) {
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.playlist_add_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('补做本次'),
                                  )
                                else
                                  TextButton.icon(
                                    key: const Key('task-repeat-skip'),
                                    onPressed: () async {
                                      await _skipRepeatOccurrence(t);
                                      if (sheetContext.mounted) {
                                        setSheetState(() {});
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.skip_next_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('跳过本次'),
                                  ),
                                TextButton.icon(
                                  key: const Key('task-repeat-disable'),
                                  onPressed: () async {
                                    await _disableRepeatRule(t);
                                    if (sheetContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.pause_circle_outline,
                                    size: 16,
                                  ),
                                  label: const Text('停止重复'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickStartAt(TodoTask t) async {
    final now = _startAt ?? _dueAt ?? t.startAt ?? t.dueAt ?? DateTime.now();
    final picked = await _pickDateTime(t, now);
    if (picked == null) return;
    setState(() {
      _startAt = picked;
      _clearStartAt = false;
    });
  }

  Future<void> _pickEndAt(TodoTask t) async {
    final fallback =
        _startAt ?? t.startAt ?? _dueAt ?? t.dueAt ?? DateTime.now();
    final now = _endAt ?? t.endAt ?? fallback.add(const Duration(hours: 1));
    final picked = await _pickDateTime(t, now);
    if (picked == null) return;
    setState(() {
      _endAt = picked;
      _clearEndAt = false;
    });
  }

  Future<DateTime?> _pickDateTime(TodoTask t, DateTime now) async {
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted || widget.taskId != t.id) return null;
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!_isCurrentTask(t.id)) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay?.hour ?? now.hour,
      timeOfDay?.minute ?? now.minute,
    );
  }

  Future<void> _addEndReminder(
    TodoTask t, {
    int? offsetMinutes,
    bool persistent = false,
    int? intervalMinutes,
  }) async {
    final dueAt = _dueAt ?? t.dueAt;
    final messenger = ScaffoldMessenger.of(context);
    if (dueAt == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请先设置截止时间')));
      return;
    }
    final reminders = ref.read(reminderRepositoryProvider);
    if (reminders == null) {
      messenger.showSnackBar(const SnackBar(content: Text('提醒存储未就绪')));
      return;
    }
    await reminders.create(
      taskId: t.id,
      fireAt: dueAt.subtract(Duration(minutes: offsetMinutes ?? 0)),
      anchorType: 'END',
      offsetMinutes: offsetMinutes,
      persistent: persistent,
      intervalMinutes: intervalMinutes,
      timeZone: _timeZone,
      fixedTimezone: _fixedTimezone,
    );
    if (!_isCurrentTask(t.id)) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          persistent
              ? '已添加截止时持续提醒'
              : offsetMinutes == null
              ? '已添加截止时提醒'
              : '已添加截止前 $offsetMinutes 分钟提醒',
        ),
      ),
    );
  }

  Future<void> _addAbsoluteReminder(TodoTask t) async {
    final initial =
        _dueAt ?? t.dueAt ?? DateTime.now().add(const Duration(hours: 1));
    final fireAt = await _pickDateTime(t, initial);
    if (fireAt == null || !mounted || !_isCurrentTask(t.id)) return;

    final messenger = ScaffoldMessenger.of(context);
    final reminders = ref.read(reminderRepositoryProvider);
    if (reminders == null) {
      messenger.showSnackBar(const SnackBar(content: Text('提醒存储未就绪')));
      return;
    }
    await reminders.create(
      taskId: t.id,
      fireAt: fireAt,
      timeZone: _timeZone,
      fixedTimezone: _fixedTimezone,
    );
    if (!_isCurrentTask(t.id)) return;
    messenger.showSnackBar(const SnackBar(content: Text('已添加指定时间提醒')));
  }

  Future<void> _editRepeatRule(TodoTask t) async {
    final repository = ref.read(repeatRuleRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (repository == null) {
      messenger.showSnackBar(const SnackBar(content: Text('重复规则存储未就绪')));
      return;
    }

    final existing = _repeatRule;
    final draft = await _showRepeatRuleEditor(existing);
    if (draft == null || !_isCurrentTask(t.id)) return;
    try {
      final rule = await repository.save(
        taskId: t.id,
        frequency: draft.frequency,
        intervalValue: draft.interval,
        weekdays: draft.frequency == 'CUSTOM' ? draft.weekdays : null,
        startAt: existing?.startAt ?? _startAt ?? _dueAt ?? DateTime.now(),
        repeatMode: draft.repeatMode,
        timeZone: _timeZone,
        enabled: true,
      );
      if (!_isCurrentTask(t.id)) return;
      setState(() => _repeatRule = rule);
      messenger.showSnackBar(const SnackBar(content: Text('重复规则已保存')));
    } on ArgumentError catch (error) {
      if (_isCurrentTask(t.id)) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
      }
    }
  }

  Future<void> _disableRepeatRule(TodoTask t) async {
    final existing = _repeatRule;
    final repository = ref.read(repeatRuleRepositoryProvider);
    if (existing == null || repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final weekdays = _weekdaysFromText(existing.byDay);
    final rule = await repository.save(
      taskId: t.id,
      frequency: existing.freq,
      intervalValue: existing.interval,
      weekdays: existing.freq == 'CUSTOM' ? weekdays : null,
      monthDay: existing.monthDay,
      startAt: existing.startAt ?? _startAt ?? _dueAt ?? DateTime.now(),
      untilAt: existing.until,
      countLimit: existing.countLimit,
      repeatMode: existing.repeatMode,
      timeZone: existing.timeZone,
      enabled: false,
    );
    if (!_isCurrentTask(t.id)) return;
    setState(() => _repeatRule = rule);
    messenger.showSnackBar(const SnackBar(content: Text('已停止重复')));
  }

  Future<void> _skipRepeatOccurrence(TodoTask t) async {
    final rule = _repeatRule;
    final repository = ref.read(repeatRuleRepositoryProvider);
    if (rule == null || !rule.enabled || repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.skip(
        repeatRuleId: rule.id,
        taskId: rule.taskId,
        occurrenceAt: _repeatOccurrenceAt(t),
      );
      if (_isCurrentTask(t.id)) {
        setState(() => _repeatOccurrenceSkipped = true);
        messenger.showSnackBar(const SnackBar(content: Text('已跳过本次重复')));
      }
    } on ArgumentError catch (error) {
      if (_isCurrentTask(t.id)) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
      }
    }
  }

  Future<void> _catchupRepeatOccurrence(TodoTask t) async {
    final rule = _repeatRule;
    final repository = ref.read(repeatRuleRepositoryProvider);
    if (rule == null || !rule.enabled || repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.catchup(
        repeatRuleId: rule.id,
        taskId: rule.taskId,
        occurrenceAt: _repeatOccurrenceAt(t),
      );
      if (_isCurrentTask(t.id)) {
        setState(() => _repeatOccurrenceSkipped = false);
        messenger.showSnackBar(const SnackBar(content: Text('已安排补做本次重复')));
      }
    } on ArgumentError catch (error) {
      if (_isCurrentTask(t.id)) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.message.toString())),
        );
      }
    }
  }

  Future<_RepeatRuleDraft?> _showRepeatRuleEditor(TodoRepeatRule? existing) {
    var frequency = existing?.freq ?? 'DAILY';
    var repeatMode = existing?.repeatMode ?? 'ON_DUE';
    final intervalController = TextEditingController(
      text: '${existing?.interval ?? 1}',
    );
    final weekdays = _weekdaysFromText(existing?.byDay);
    if (frequency == 'CUSTOM' && weekdays.isEmpty) {
      weekdays.add(DateTime.now().weekday);
    }
    return showDialog<_RepeatRuleDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('重复规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('频率'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      const [
                            ('DAILY', '每天'),
                            ('WEEKLY', '每周'),
                            ('MONTHLY', '每月'),
                            ('YEARLY', '每年'),
                            ('WEEKDAY', '工作日'),
                            ('CUSTOM', '自定义'),
                          ]
                          .map(
                            (option) => ChoiceChip(
                              key: Key(
                                'task-repeat-frequency-${option.$1.toLowerCase()}',
                              ),
                              label: Text(option.$2),
                              selected: frequency == option.$1,
                              onSelected: (_) => setDialogState(() {
                                frequency = option.$1;
                                if (frequency == 'CUSTOM' && weekdays.isEmpty) {
                                  weekdays.add(DateTime.now().weekday);
                                }
                              }),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('task-repeat-interval'),
                  controller: intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '每隔几次',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('触发方式'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children:
                      const [('ON_DUE', '到期后重复'), ('ON_COMPLETE', '完成后重复')]
                          .map(
                            (option) => ChoiceChip(
                              key: Key(
                                'task-repeat-mode-${option.$1.toLowerCase()}',
                              ),
                              label: Text(option.$2),
                              selected: repeatMode == option.$1,
                              onSelected: (_) =>
                                  setDialogState(() => repeatMode = option.$1),
                            ),
                          )
                          .toList(),
                ),
                if (frequency == 'CUSTOM') ...[
                  const SizedBox(height: 16),
                  const Text('重复星期'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (index) {
                      final weekday = index + 1;
                      const labels = ['一', '二', '三', '四', '五', '六', '日'];
                      return FilterChip(
                        key: Key('task-repeat-weekday-$weekday'),
                        label: Text(labels[index]),
                        selected: weekdays.contains(weekday),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            weekdays.add(weekday);
                          } else {
                            weekdays.remove(weekday);
                          }
                        }),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('task-repeat-save'),
              onPressed: () {
                final interval = int.tryParse(intervalController.text.trim());
                if (interval == null || interval < 1) return;
                Navigator.pop(
                  dialogContext,
                  _RepeatRuleDraft(
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays,
                    repeatMode: repeatMode,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ).whenComplete(intervalController.dispose);
  }

  Set<int> _weekdaysFromText(String? value) => (value ?? '')
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((weekday) => weekday >= 1 && weekday <= 7)
      .toSet();

  String _repeatRuleLabel(TodoRepeatRule rule) {
    const labels = {
      'DAILY': '每天',
      'WEEKLY': '每周',
      'MONTHLY': '每月',
      'YEARLY': '每年',
      'WEEKDAY': '工作日',
      'CUSTOM': '自定义',
    };
    final label = labels[rule.freq] ?? rule.freq;
    return rule.enabled ? '$label（每隔 ${rule.interval} 次）' : '已停止：$label';
  }

  Future<void> _pickSchedule(TodoTask t, {required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    final now = current ?? (isStart ? t.startAt : t.endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted || widget.taskId != t.id) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!_isCurrentTask(t.id)) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? now.hour,
      time?.minute ?? now.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = selected;
      } else {
        _endAt = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.taskId == null) {
      return _buildNoSelection();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = _task;
    if (t == null) {
      return _buildNotFound();
    }

    final colors = brandColors(context);
    Widget sh(String s) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.mutedForeground,
          letterSpacing: 0.3,
        ),
      ),
    );

    final body = ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Semantics(
          identifier: 'todo_task_detail_title',
          child: TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          identifier: 'todo_task_detail_description',
          child: TextField(
            key: const Key('todo-task-detail-description-input'),
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '描述',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey('task-priority-${t.id}-$_priority'),
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: '优先级',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('无')),
            DropdownMenuItem(value: 1, child: Text('低')),
            DropdownMenuItem(value: 2, child: Text('中')),
            DropdownMenuItem(value: 3, child: Text('高')),
          ],
          onChanged: (v) => setState(() => _priority = v ?? 0),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              identifier: 'todo_task_detail_save',
              button: true,
              child: AppButton(
                key: const Key('todo_task_detail_save_button'),
                onPressed: _save,
                icon: Icons.save_outlined,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        sh('截止时间'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('task-schedule-options'),
          onPressed: () => _showScheduleSheet(t),
          icon: const Icon(Icons.event_outlined),
          label: Text(
            _dueAt == null
                ? '未设置'
                : '${_dueAt!.toLocal().toString().substring(0, 16)} (本地时区)',
          ),
        ),
        if (_dueAt != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _dueAt = null),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('清除'),
            ),
          ),
        ],
        const Divider(height: 32),
        sh('清单'),
        const SizedBox(height: 8),
        _TaskListPicker(
          taskId: t.id,
          selectedListId: _selectedListId ?? t.listId,
          selectedListName: _listName,
          onChanged: (listId, listName) => setState(() {
            _selectedListId = listId;
            _listName = listName;
          }),
        ),
        const Divider(height: 32),
        sh('标签'),
        const SizedBox(height: 8),
        _TagChips(key: ValueKey('task-tags-${t.id}'), taskId: t.id),
        const Divider(height: 32),
        sh('检查事项'),
        const SizedBox(height: 8),
        _ChecklistSection(
          key: ValueKey('task-checklist-${t.id}'),
          taskId: t.id,
        ),
        const Divider(height: 32),
        sh('附件'),
        const SizedBox(height: 8),
        _AttachmentSection(
          key: ValueKey('task-attachments-${t.id}'),
          taskId: t.id,
        ),
        const Divider(height: 32),
        sh('任务动态'),
        const SizedBox(height: 8),
        if (t.serverId == null)
          const Text('任务同步后可查看动态')
        else
          _ActivitySection(
            key: ValueKey('task-activities-${t.id}'),
            taskServerId: t.serverId!,
          ),
        const Divider(height: 32),
        sh('模板'),
        const SizedBox(height: 8),
        _TemplateSection(key: ValueKey('task-templates-${t.id}'), task: t),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: sh('子任务')),
            IconButton(
              tooltip: '添加子任务',
              onPressed: () => _addSubtask(t),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        _SubtaskList(taskId: t.id, onAdd: () => _addSubtask(t)),
        const Divider(height: 32),
        sh('时间段（可选）'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickSchedule(t, isStart: true),
          icon: const Icon(Icons.play_circle_outline),
          label: Text(
            _startAt == null
                ? '设置开始时间'
                : '开始：${_startAt!.toLocal().toString().substring(0, 16)}',
          ),
        ),
        if (_startAt != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _startAt = null),
              child: const Text('清除开始时间'),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _pickSchedule(t, isStart: false),
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(
            _endAt == null
                ? '设置结束时间'
                : '结束：${_endAt!.toLocal().toString().substring(0, 16)}',
          ),
        ),
        if (_endAt != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _endAt = null),
              child: const Text('清除结束时间'),
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return _buildEmbedded(context, t, body);
    }
    return _buildPage(context, t, body);
  }

  Widget _buildNoSelection() {
    final colors = brandColors(context);
    final content = ColoredBox(
      key: const Key('todo-detail-no-selection'),
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notes_outlined, color: colors.mutedForeground),
              const SizedBox(height: 12),
              Text(
                '选择任务以查看详情',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedForeground, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情')),
      body: content,
    );
  }

  /// 嵌入模式：自带标题与详情操作，不创建新的 Scaffold 或导航栈。
  Widget _buildEmbedded(BuildContext context, TodoTask t, Widget body) {
    return Column(
      key: const Key('todo-task-detail-pane'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: '关闭详情',
                onPressed: _close,
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '任务详情',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t.isPinned ? '取消置顶' : '置顶',
                onPressed: () => _togglePin(t),
                icon: Icon(
                  t.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
              ),
              IconButton(
                tooltip: t.completed ? '取消勾选' : '勾选完成',
                onPressed: () => _toggleComplete(t),
                icon: Icon(
                  t.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
              ),
              IconButton(
                tooltip: '移至收集箱',
                onPressed: () => _moveToInboxAndClose(t),
                icon: const Icon(Icons.move_to_inbox_outlined),
              ),
              IconButton(
                tooltip: '协作（指派/评论/成员）',
                onPressed: () => _openCollaborationHub(t),
                icon: const Icon(Icons.people_outline),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () => _delete(t),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: body),
      ],
    );
  }

  /// 传统全屏页面模式（保留向后兼容）
  Widget _buildPage(BuildContext context, TodoTask t, Widget body) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      key: const Key('todo_task_detail_page'),
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: narrow
            ? [
                IconButton(
                  tooltip: t.completed ? '取消勾选' : '勾选完成',
                  onPressed: () => _toggleComplete(t),
                  icon: Icon(
                    t.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                ),
                PopupMenuButton<_TaskDetailAction>(
                  tooltip: '更多任务操作',
                  onSelected: (action) {
                    switch (action) {
                      case _TaskDetailAction.previewMarkdown:
                        unawaited(_previewMarkdown(t));
                        return;
                      case _TaskDetailAction.togglePin:
                        unawaited(_togglePin(t));
                        return;
                      case _TaskDetailAction.moveToInbox:
                        unawaited(_moveToInboxAndClose(t));
                        return;
                      case _TaskDetailAction.copy:
                        unawaited(_copy(t));
                        return;
                      case _TaskDetailAction.share:
                        unawaited(_share(t));
                        return;
                      case _TaskDetailAction.abandon:
                        unawaited(_abandon(t));
                        return;
                      case _TaskDetailAction.collaboration:
                        unawaited(_openCollaborationHub(t));
                        return;
                      case _TaskDetailAction.delete:
                        unawaited(_delete(t));
                        return;
                    }
                  },
                  itemBuilder: (context) => [
                    if ((t.description ?? '').trim().isNotEmpty)
                      const PopupMenuItem(
                        value: _TaskDetailAction.previewMarkdown,
                        child: Text('Markdown 预览'),
                      ),
                    PopupMenuItem(
                      value: _TaskDetailAction.togglePin,
                      child: Text(t.isPinned ? '取消置顶' : '置顶'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.moveToInbox,
                      child: Text('移至收集箱'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.copy,
                      child: Text('复制任务'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.share,
                      child: Text('分享任务'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.abandon,
                      child: Text('放弃任务'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.collaboration,
                      child: Text('协作'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.delete,
                      child: Text('删除'),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  tooltip: t.isPinned ? '取消置顶' : '置顶',
                  onPressed: () => _togglePin(t),
                  icon: Icon(
                    t.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  ),
                ),
                IconButton(
                  tooltip: t.completed ? '取消勾选' : '勾选完成',
                  onPressed: () => _toggleComplete(t),
                  icon: Icon(
                    t.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                ),
                IconButton(
                  tooltip: '移至收集箱',
                  onPressed: () => _moveToInboxAndClose(t),
                  icon: const Icon(Icons.move_to_inbox_outlined),
                ),
                IconButton(
                  tooltip: '复制任务',
                  onPressed: () => _copy(t),
                  icon: const Icon(Icons.copy_outlined),
                ),
                IconButton(
                  tooltip: '分享任务',
                  onPressed: () => _share(t),
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  tooltip: '放弃任务',
                  onPressed: t.cancelled ? null : () => _abandon(t),
                  icon: const Icon(Icons.block_outlined),
                ),
                IconButton(
                  tooltip: '协作',
                  onPressed: () => _openCollaborationHub(t),
                  icon: const Icon(Icons.people_outline),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: () => _delete(t),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
      ),
      body: body,
    );
  }

  Widget _buildNotFound() {
    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  tooltip: '关闭详情',
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
                const Text('任务不存在'),
              ],
            ),
          ),
          const Expanded(child: Center(child: Text('任务不存在或已删除'))),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('任务不存在')),
      body: const Center(child: Text('任务不存在或已删除')),
    );
  }
}

class _TaskListPicker extends ConsumerWidget {
  const _TaskListPicker({
    required this.taskId,
    required this.selectedListId,
    required this.selectedListName,
    required this.onChanged,
  });

  final String taskId;
  final String selectedListId;
  final String? selectedListName;
  final void Function(String listId, String listName) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsStreamProvider).valueOrNull ?? const [];
    final colors = brandColors(context);
    return InkWell(
      key: Key('task-list-$taskId'),
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final nextListId = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.inbox_outlined),
                  title: const Text('收集箱'),
                  trailing: selectedListId == kInboxListId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, kInboxListId),
                ),
                for (final list in lists)
                  if (list.id != kInboxListId)
                    ListTile(
                      leading: const Icon(Icons.list_alt_outlined),
                      title: Text(list.name),
                      trailing: selectedListId == list.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, list.id),
                    ),
              ],
            ),
          ),
        );
        if (nextListId == null) return;
        final nextListName = nextListId == kInboxListId
            ? '收集箱'
            : lists
                      .where((list) => list.id == nextListId)
                      .map((list) => list.name)
                      .firstOrNull ??
                  selectedListName ??
                  '未知清单';
        onChanged(nextListId, nextListName);
      },
      child: Row(
        children: [
          Icon(Icons.list_alt_outlined, color: colors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedListName ?? '未知清单',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskList extends ConsumerWidget {
  const _SubtaskList({required this.taskId, required this.onAdd});

  final String taskId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(taskRepositoryProvider);
    if (repo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<List<TodoTask>>(
      stream: repo.watchChildrenOf(taskId),
      builder: (ctx, snap) {
        final items = snap.data ?? const <TodoTask>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加子任务'),
            ),
          );
        }
        return Column(
          children: items
              .map(
                (st) => CheckboxListTile(
                  value: st.completed,
                  title: Text(
                    st.title,
                    style: TextStyle(
                      decoration: st.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  onChanged: (_) async {
                    final repo = ref.read(taskRepositoryProvider);
                    if (repo == null) return;
                    await repo.toggleComplete(st.id);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _TagChips extends ConsumerStatefulWidget {
  const _TagChips({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<_TagChips> createState() => _TagChipsState();
}

class _TagChipsState extends ConsumerState<_TagChips> {
  Set<String> _selected = {};
  bool _loaded = false;

  Future<void> _bootstrap() async {
    final repo = ref.read(tagRepositoryProvider);
    if (repo == null) return;
    final ids = await repo.tagIdsOf(widget.taskId);
    if (!mounted) return;
    setState(() {
      _selected = ids.toSet();
      _loaded = true;
    });
  }

  Future<void> _toggle(String tagId) async {
    setState(() {
      if (_selected.contains(tagId)) {
        _selected.remove(tagId);
      } else {
        _selected.add(tagId);
      }
    });
    final repo = ref.read(tagRepositoryProvider);
    if (repo == null) return;
    await repo.setTaskTags(widget.taskId, _selected.toList());
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 32);
    final tagsAsync = ref.watch(tagsStreamProvider);
    return tagsAsync.when(
      loading: () => const SizedBox(height: 32),
      error: (e, _) => Text('标签加载失败: $e'),
      data: (tags) {
        if (tags.isEmpty) return const Text('暂无标签，请先在清单页右上角创建');
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) {
            final selected = _selected.contains(t.id);
            return FilterChip(
              selected: selected,
              label: Text(t.name),
              avatar: CircleAvatar(
                backgroundColor: tagColorFromHex(t.color),
                radius: 8,
              ),
              onSelected: (_) => _toggle(t.id),
            );
          }).toList(),
        );
      },
    );
  }
}

/// §2.1 内嵌检查事项：通过本地 Repository 与 outbox 离线优先同步。
class _ChecklistSection extends ConsumerStatefulWidget {
  const _ChecklistSection({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<_ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<_ChecklistSection> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.createChecklistItem(taskId: widget.taskId, title: text);
    if (mounted) _addCtrl.clear();
  }

  Future<void> _toggle(TodoChecklistItem item) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.toggleChecklistItem(item.id);
  }

  Future<void> _delete(TodoChecklistItem item) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.deleteChecklistItem(item.id);
  }

  Future<void> _edit(TodoChecklistItem item) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _ChecklistEditDialog(initialTitle: item.title),
    );
    final normalized = title?.trim();
    if (normalized == null || normalized.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.updateChecklistItem(item.id, title: normalized);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(taskRepositoryProvider);
    if (repo == null) return const SizedBox(height: 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addCtrl,
                decoration: const InputDecoration(
                  labelText: '新增检查事项',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: '添加',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<TodoChecklistItem>>(
          stream: repo.watchChecklistItems(widget.taskId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            final items = snapshot.data!;
            if (items.isEmpty) return const Text('暂无检查事项');
            return Column(
              children: items
                  .map(
                    (item) => GestureDetector(
                      onLongPress: () => _edit(item),
                      child: CheckboxListTile(
                        value: item.completed,
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration: item.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        onChanged: (_) => _toggle(item),
                        secondary: IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.close),
                          onPressed: () => _delete(item),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ChecklistEditDialog extends StatefulWidget {
  const _ChecklistEditDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_ChecklistEditDialog> createState() => _ChecklistEditDialogState();
}

class _ChecklistEditDialogState extends State<_ChecklistEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('编辑检查事项'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: '检查事项',
        border: OutlineInputBorder(),
      ),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('保存'),
      ),
    ],
  );
}

/// 任务附件始终先进入 Drift + outbox；这里不直接调用后端。
class _AttachmentSection extends ConsumerStatefulWidget {
  const _AttachmentSection({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<_AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends ConsumerState<_AttachmentSection> {
  Future<void> _pickAndQueue() async {
    final result = await FilePicker.pickFiles(allowMultiple: true);
    if (result == null) return;
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    var queued = 0;
    for (final file in result.files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      await repo.queueAttachment(
        taskId: widget.taskId,
        name: file.name,
        localPath: path,
        mimeType: _mimeTypeFor(file.name),
        size: file.size,
      );
      queued++;
    }
    if (!mounted || queued == 0) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已加入 $queued 个附件上传队列')));
  }

  Future<void> _retry(TodoAttachment attachment) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.retryAttachment(attachment.id);
  }

  Future<void> _delete(TodoAttachment attachment) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    await repo.deleteAttachment(attachment.id);
  }

  String _mimeTypeFor(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.pdf')) return 'application/pdf';
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.txt') || normalized.endsWith('.md')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }

  ({String label, IconData icon, Color color}) _status(
    BuildContext context,
    TodoAttachment attachment,
  ) {
    final colors = brandColors(context);
    return switch (attachment.status) {
      'uploading' => (
        label: '正在上传',
        icon: Icons.cloud_upload_outlined,
        color: colors.mutedForeground,
      ),
      'failed' => (
        label: '上传失败',
        icon: Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      'uploaded' => (
        label: '已完成',
        icon: Icons.cloud_done_outlined,
        color: colors.success,
      ),
      _ => (
        label: '等待上传',
        icon: Icons.schedule_outlined,
        color: colors.mutedForeground,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(taskRepositoryProvider);
    if (repo == null) return const SizedBox(height: 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _pickAndQueue,
          icon: const Icon(Icons.attach_file),
          label: const Text('添加附件'),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<TodoAttachment>>(
          stream: repo.watchAttachments(widget.taskId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final attachments = snapshot.data!;
            if (attachments.isEmpty) return const Text('暂无附件');
            return Column(
              children: attachments.map((attachment) {
                final status = _status(context, attachment);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(status.icon, color: status.color),
                  title: Text(attachment.name),
                  subtitle: Text(
                    attachment.status == 'failed' && attachment.error != null
                        ? '${status.label}：${attachment.error}'
                        : status.label,
                    style: TextStyle(color: status.color),
                  ),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      if (attachment.status == 'failed')
                        IconButton(
                          tooltip: '重试上传',
                          onPressed: () => _retry(attachment),
                          icon: const Icon(Icons.refresh),
                        ),
                      IconButton(
                        tooltip: '删除附件',
                        onPressed: () => _delete(attachment),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActivitySection extends ConsumerStatefulWidget {
  const _ActivitySection({super.key, required this.taskServerId});

  final int taskServerId;

  @override
  ConsumerState<_ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<_ActivitySection> {
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final repo = ref.read(activityRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.refreshTask(widget.taskServerId);
      if (mounted) setState(() => _refreshError = null);
    } catch (_) {
      if (mounted) setState(() => _refreshError = '离线显示已缓存的动态');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(activityRepositoryProvider);
    if (repo == null) return const SizedBox(height: 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_refreshError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_refreshError!),
          ),
        StreamBuilder<List<TodoActivity>>(
          stream: repo.watchTask(widget.taskServerId),
          builder: (context, snapshot) {
            final activities = snapshot.data ?? const <TodoActivity>[];
            if (activities.isEmpty) return const Text('暂无任务动态');
            return Column(
              children: activities
                  .map(
                    (activity) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_outlined),
                      title: Text(_activityLabel(activity.action)),
                      subtitle: Text(
                        '${activity.actorUserName ?? '成员'} · ${activity.occurredAt.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新动态'),
          ),
        ),
      ],
    );
  }

  String _activityLabel(String action) => switch (action) {
    'task_created' => '创建了任务',
    'task_updated' => '更新了任务',
    'task_completed' => '完成了任务',
    'task_uncompleted' => '取消完成任务',
    'comment_created' => '添加了评论',
    _ => action,
  };
}

class _TemplateSection extends ConsumerWidget {
  const _TemplateSection({super.key, required this.task});

  final TodoTask task;

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final templates = ref.read(templateRepositoryProvider);
    if (templates == null) return;
    await templates.saveTask(task: task, name: '${task.title} 模板');
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已保存为模板，等待同步')));
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    TodoTemplate template,
  ) async {
    final templates = ref.read(templateRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    if (templates == null || tasks == null) return;
    final seed = templates.taskSeed(template);
    await tasks.create(
      listId: task.listId,
      title: seed.title,
      description: seed.description,
      priority: seed.priority,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已应用模板“${template.name}”')));
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator == null) return;
    try {
      final outcome = await coordinator.syncOnce();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步完成：推送 ${outcome.pushed} 项，拉取 ${outcome.pulled} 项'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模板同步失败，将继续显示本地缓存')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(templateRepositoryProvider);
    if (repo == null) return const SizedBox(height: 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _saveCurrent(context, ref),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存当前任务为模板'),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '刷新模板',
              onPressed: () => _refresh(context, ref),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        StreamBuilder<List<TodoTemplate>>(
          stream: repo.watchAll(),
          builder: (context, snapshot) {
            final templates = snapshot.data ?? const <TodoTemplate>[];
            if (templates.isEmpty) return const Text('暂无本地模板');
            return Column(
              children: templates
                  .map(
                    (template) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(template.name),
                      subtitle: Text(
                        template.status == 'synced' ? '已同步' : '等待同步',
                      ),
                      trailing: TextButton(
                        onPressed: () => _apply(context, ref, template),
                        child: const Text('应用'),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

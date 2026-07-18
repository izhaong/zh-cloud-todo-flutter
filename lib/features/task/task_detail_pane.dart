import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/api/todo_api.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/providers.dart';
import '../shell/app_dialog.dart';
import 'task_quick_add_sheet.dart';
import '../collaboration/task_comments_page.dart';
import '../collaboration/task_assign_page.dart';
import '../collaboration/list_member_page.dart';

/// 收件箱的本地清单 id（synthetic inbox）：listId 为该值的任务视为"未归清单"。
const String kInboxListId = 'inbox';

enum _TaskDetailAction { togglePin, moveToInbox, collaboration, delete }

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
              ListTile(
                key: ValueKey('task-reminder-${reminder.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm_outlined),
                title: Text(
                  reminder.remindAt.toLocal().toString().substring(0, 16),
                ),
                subtitle: Text(
                  reminder.persistent
                      ? '持续提醒，每 ${reminder.intervalMinutes ?? 0} 分钟'
                      : (reminder.anchorType == 'END' ? '截止时提醒' : '单次提醒'),
                ),
                trailing: IconButton(
                  key: ValueKey('task-reminder-remove-${reminder.id}'),
                  tooltip: '删除提醒',
                  onPressed: repository == null
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await repository.remove(reminder.id);
                          if (context.mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已删除提醒')),
                            );
                          }
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        );
      },
    );
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
  bool _loading = true;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _clearStartAt = false;
  bool _clearEndAt = false;
  DateTime? _dueAt;
  bool _allDay = false;
  String? _timeZone;
  bool _fixedTimezone = false;
  TodoRepeatRule? _repeatRule;
  bool _repeatOccurrenceSkipped = false;
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
    final repeatRule = t == null ? null : await _repeatRuleForTask(t.id);
    final repeatSkipped = t == null || repeatRule == null
        ? false
        : await _repeatSkipExists(repeatRule.id, t.id, _repeatOccurrenceAt(t));
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
      _listName = listName;
      _loading = false;
      _unavailableNotifiedFor = null;
    });
  }

  Future<String> _resolveListName(String listId) async {
    if (listId == kInboxListId) return '收件箱';
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
        clearStartAt: _clearStartAt,
        clearEndAt: _clearEndAt,
        dueAt: _dueAt,
        allDay: _allDay,
        timeZone: _fixedTimezone ? (_timeZone ?? 'Asia/Shanghai') : _timeZone,
        fixedTimezone: _fixedTimezone,
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

  /// §2.3 收件箱迁移：把任务挪入 synthetic inbox (listId = 'inbox')。
  Future<void> _moveToInbox(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await repo.update(t.id, listId: kInboxListId);
    if (!_isCurrentTask(t.id)) return;
    messenger.showSnackBar(const SnackBar(content: Text('已移至收件箱')));
  }

  Future<void> _moveToInboxAndClose(TodoTask t) async {
    await _moveToInbox(t);
    if (_isCurrentTask(t.id)) _close();
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

  Future<TodoRepeatRule?> _repeatRuleForTask(String taskId) {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return Future.value(null);
    return (db.select(
      db.todoRepeatRules,
    )..where((rule) => rule.taskId.equals(taskId))).getSingleOrNull();
  }

  DateTime _repeatOccurrenceAt(TodoTask task) =>
      _dueAt ?? _startAt ?? task.dueAt ?? task.startAt ?? DateTime.now();

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
        taskId: t.id,
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
        taskId: t.id,
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
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: '标题',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '描述',
            border: OutlineInputBorder(),
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
            AppButton(
              onPressed: _save,
              icon: Icons.save_outlined,
              child: const Text('保存'),
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
        Row(
          children: [
            Icon(Icons.list_alt_outlined, color: colors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _listName ?? '未知清单',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.foreground),
              ),
            ),
          ],
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
                tooltip: '移至收件箱',
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
                      case _TaskDetailAction.togglePin:
                        unawaited(_togglePin(t));
                        return;
                      case _TaskDetailAction.moveToInbox:
                        unawaited(_moveToInboxAndClose(t));
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
                    PopupMenuItem(
                      value: _TaskDetailAction.togglePin,
                      child: Text(t.isPinned ? '取消置顶' : '置顶'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.moveToInbox,
                      child: Text('移至收件箱'),
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
                  tooltip: '移至收件箱',
                  onPressed: () => _moveToInboxAndClose(t),
                  icon: const Icon(Icons.move_to_inbox_outlined),
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

/// §2.1 内嵌检查事项（checklist）：直接走 [ChecklistApi] REST，实时与后端同步。
class _ChecklistSection extends ConsumerStatefulWidget {
  const _ChecklistSection({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<_ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<_ChecklistSection> {
  List<ChecklistItem> _items = const [];
  bool _loading = true;
  String? _error;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(todoApiProvider).checklist;
      final items = await api.list(widget.taskId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _error = '检查事项暂不可用';
      });
    }
  }

  Future<void> _add() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    _addCtrl.clear();
    final api = ref.read(todoApiProvider).checklist;
    await api.create(taskId: widget.taskId, title: text);
    await _load();
  }

  Future<void> _toggle(ChecklistItem it) async {
    final api = ref.read(todoApiProvider).checklist;
    await api.update(it.id, completed: !it.completed);
    await _load();
  }

  Future<void> _delete(ChecklistItem it) async {
    final api = ref.read(todoApiProvider).checklist;
    await api.delete(it.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
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
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_error != null)
          Text('加载失败: $_error')
        else if (_items.isEmpty)
          const Text('暂无检查事项')
        else
          ..._items.map(
            (it) => CheckboxListTile(
              value: it.completed,
              title: Text(
                it.title,
                style: TextStyle(
                  decoration: it.completed ? TextDecoration.lineThrough : null,
                ),
              ),
              onChanged: (_) => _toggle(it),
              secondary: IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.close),
                onPressed: () => _delete(it),
              ),
            ),
          ),
      ],
    );
  }
}

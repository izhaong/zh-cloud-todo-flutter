import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_text.dart';
import '../../core/api/todo_api.dart';
import '../../core/db/app_database.dart';
import '../../core/sync/repeat_frequency_wire.dart';
import '../../core/time/task_time_formatter.dart';
import '../../core/time/task_time_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/todo_layout_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../../native/native_intents.dart';
import '../../state/providers.dart';
import '../tag/hash_tag_input.dart';
import '../../state/repositories/reminder_repository.dart';
import '../../state/repositories/task_query_repository.dart';
import '../shell/app_dialog.dart';
import 'task_detail_page.dart';
import 'subtask_flow.dart';
// tagColorFromHex 是个定义在快速添加表文件里的顶层辅助（:370），详情层的标签色块用它。
// 本轮不动这个摆放（挪进 tag_color.dart 属另一件事），只把这条依赖显式留住。
import 'task_quick_add_sheet.dart';
import '../collaboration/task_comments_page.dart';
import 'task_assign_action.dart';
import '../list/list_actions.dart';
import '../note/note_page.dart';
import '../pomodoro/pomodoro_page.dart';
import 'task_view_mutation_feedback.dart';

/// 收集箱的本地清单 id（synthetic inbox）：listId 为该值的任务视为"未归清单"。
const String kInboxListId = 'inbox';

/// 嵌入态操作头放得下 7 枚图标所需的**内容宽度**（不含包裹层左右各 8 的内边距）：7×48 + 4 间距 = 340。
///
/// 48 = `kMinInteractiveDimension`。**这个数不跟随主题密度**：本仓主题是
/// `useMaterial3: true`（`lib/app.dart:109`、`:150`），而 M3 的 `IconButton` 把样式里的
/// `visualDensity` 硬编成 `VisualDensity.standard`（SDK `material/icon_button.dart:1152`
/// 等四处 getter），所以 `ThemeData.visualDensity` 改不动这几枚图标的占位。
/// 实测两条读数（都不折叠时的溢出量）：`VisualDensity.compact` 下面板 320dp（内容 304）溢 **36px**、
/// 面板 300dp（内容 284）溢 **56px**（= 340 − 284）—— 两个数都指向"图标仍是 48dp"，
/// 即主题密度改不动这几枚按钮。随 PR 提交的那条 compact 用例钉的是 320dp 那一档
/// （`headerIconExtent('关闭详情') == 48.0`）；56px 那档是我按复核建议把阈值改成"随密度算"时
/// 拿到的读数，留在这里当"为什么不跟密度"的证据，用例里没有它。
///
/// 调用点比的是 `LayoutBuilder` 给的 `constraints.maxWidth`，那个值已经扣掉了左右各 8 的内边距，
/// 所以 340 对应面板 356：实测面板 355 溢 1px、356 刚好（再加一次 16 就是把同一份 padding 数两遍，
/// 会把折叠线错推到面板 372）。
const double _embeddedActionRowContentMinWidth = 340;

enum _TaskDetailAction {
  startPomodoro,
  previewMarkdown,
  togglePin,
  moveToInbox,
  copy,
  share,
  convertToNote,
  linkParent,
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
    required this.selectedDates,
    required this.untilAt,
    required this.countLimit,
  });

  final String frequency;
  final int interval;
  final Set<int> weekdays;
  final String repeatMode;
  final Set<DateTime> selectedDates;
  final DateTime? untilAt;
  final int? countLimit;
}

class _ReminderDraft {
  const _ReminderDraft({
    required this.fireAt,
    required this.anchorType,
    required this.offsetMinutes,
    required this.persistent,
    required this.intervalMinutes,
    required this.timeZone,
    required this.fixedTimezone,
    required this.timeMode,
  });

  final DateTime fireAt;
  final String anchorType;
  final int? offsetMinutes;
  final bool persistent;
  final int? intervalMinutes;
  final String? timeZone;
  final bool fixedTimezone;
  final TaskTimeMode timeMode;
}

String _reminderTimeModeSubtitle(TaskTimeMode mode) {
  // 措辞照抄嘀嗒《01-任务/07-固定时间与固定时区》，与任务侧同一口径。
  return switch (mode) {
    TaskTimeMode.fixedTimezone => '任务的时间会随着所在时区的不同而改变',
    TaskTimeMode.fixedTime => '不论所处时区如何变化，任务的时间都会保持一致',
    TaskTimeMode.floating => '',
  };
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
          title: Text(
            formatTaskDateTime(
              reminder.remindAt,
              allDay: false,
              mode: TaskTimeMode.fromWire(reminder.timeMode),
              timeZone: reminder.timeZone,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_reminderAnchorDescription(reminder)),
              if (reminder.persistent)
                Text('持续提醒，每 ${reminder.intervalMinutes ?? 0} 分钟'),
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
                key: ValueKey('task-reminder-edit-${reminder.id}'),
                tooltip: '编辑提醒',
                onPressed: repository == null
                    ? null
                    : () => _editReminder(context, ref),
                icon: const Icon(Icons.edit_outlined),
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

  String _reminderAnchorDescription(TodoReminder reminder) {
    final offset = reminder.offsetMinutes ?? 0;
    final prefix = switch (reminder.anchorType) {
      'START' => '开始',
      'DUE' => '截止',
      'END' => '结束',
      _ => null,
    };
    if (prefix == null) return '指定时间提醒';
    return offset > 0 ? '$prefix前 $offset 分钟' : '$prefix时提醒';
  }

  Future<void> _editReminder(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final reminderRepository = repository;
    if (db == null || reminderRepository == null) return;
    final task = await (db.select(
      db.todoTasks,
    )..where((task) => task.id.equals(reminder.taskId))).getSingleOrNull();
    if (!context.mounted) return;
    if (task == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提醒所属任务不存在')));
      return;
    }

    final draft = await _showReminderEditor(context, ref, task);
    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await reminderRepository.update(
        id: reminder.id,
        fireAt: draft.fireAt,
        anchorType: draft.anchorType,
        offsetMinutes: draft.offsetMinutes,
        persistent: draft.persistent,
        intervalMinutes: draft.intervalMinutes,
        timeZone: draft.timeZone,
        fixedTimezone: draft.fixedTimezone,
        timeMode: draft.timeMode,
      );
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('提醒已更新')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('提醒更新失败：${_reminderErrorMessage(error)}')),
        );
      }
    }
  }

  Future<_ReminderDraft?> _showReminderEditor(
    BuildContext context,
    WidgetRef ref,
    TodoTask task,
  ) async {
    const supportedAnchors = {'ABSOLUTE', 'START', 'DUE', 'END'};
    var anchorType = supportedAnchors.contains(reminder.anchorType)
        ? reminder.anchorType
        : 'ABSOLUTE';
    var fireAt = reminder.remindAt;
    var persistent = reminder.persistent;
    var timeMode = TaskTimeMode.fromWire(reminder.timeMode);
    var fixedTimezone = TaskTimeMode.legacyFlagOf(timeMode);
    var offsetText = reminder.offsetMinutes?.toString() ?? '';
    var intervalText = reminder.intervalMinutes?.toString() ?? '30';
    var timeZoneText = reminder.timeZone ?? '';
    String? validationMessage;
    // 嘀嗒《01-任务/07-固定时间与固定时区》:11「开启后…即可选择「固定时区」或「固定时间」」
    // ⇒ 「设置 → 日期与时间 → 时区」关掉时这一档不出现。取的是**打开这一刻**的持久值：
    // `ref.read(...).valueOrNull` 在 provider 首帧还没收到流数据时恒为 null，会退成「开」，
    // 于是"关掉到底有没有效"取决于用户手速 —— 红测（specs/055 的 FR-2 那条）就是先红在这里。
    // 只显隐，**不动** fixedTimezone 初值（关掉开关不得把已设的时区改掉，FR-3）。
    var timezoneCapabilityEnabled = true;
    try {
      timezoneCapabilityEnabled = await ref.read(
        timezoneEnabledProvider.future,
      );
    } on Object {
      // 偏好读不到时按「开」：不因偏好子系统抖动而把既有能力藏掉（与仓储"无记录即开"同口径）。
    }
    if (!context.mounted) return null;
    return showDialog<_ReminderDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final anchorAt = _reminderAnchorAt(task, anchorType);
          return AlertDialog(
            title: const Text('编辑提醒'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('task-reminder-anchor'),
                      initialValue: anchorType,
                      decoration: const InputDecoration(
                        labelText: '提醒时间',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          key: Key('task-reminder-anchor-absolute'),
                          value: 'ABSOLUTE',
                          child: Text('指定时间'),
                        ),
                        DropdownMenuItem(
                          key: Key('task-reminder-anchor-start'),
                          value: 'START',
                          child: Text('开始时'),
                        ),
                        DropdownMenuItem(
                          key: Key('task-reminder-anchor-due'),
                          value: 'DUE',
                          child: Text('截止时'),
                        ),
                        DropdownMenuItem(
                          key: Key('task-reminder-anchor-end'),
                          value: 'END',
                          child: Text('结束时'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          anchorType = value;
                          validationMessage = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (anchorType == 'ABSOLUTE')
                      OutlinedButton.icon(
                        key: const Key('task-reminder-fire-at'),
                        onPressed: () async {
                          final picked = await _pickReminderDateTime(
                            dialogContext,
                            fireAt,
                          );
                          if (picked != null && dialogContext.mounted) {
                            setDialogState(() {
                              fireAt = picked;
                              validationMessage = null;
                            });
                          }
                        },
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(
                          formatTaskDateTime(
                            fireAt,
                            allDay: false,
                            mode: timeMode,
                            timeZone: timeZoneText.trim(),
                          ),
                        ),
                      )
                    else ...[
                      TextFormField(
                        key: const Key('task-reminder-offset-minutes'),
                        initialValue: offsetText,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '提前分钟数',
                          hintText: '0',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setDialogState(() {
                          offsetText = value;
                          validationMessage = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        anchorAt == null
                            ? '当前任务尚未设置所选时间'
                            : '所选锚点：${formatTaskDateTime(anchorAt, allDay: false, mode: TaskTimeMode.fromWire(task.timeMode), timeZone: task.timeZone)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('task-reminder-persistent'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('持续提醒'),
                      subtitle: const Text('保持提醒，直到你处理任务'),
                      value: persistent,
                      onChanged: (value) => setDialogState(() {
                        persistent = value;
                        validationMessage = null;
                      }),
                    ),
                    if (persistent)
                      TextFormField(
                        key: const Key('task-reminder-interval-minutes'),
                        initialValue: intervalText,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '提醒间隔（分钟）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setDialogState(() {
                          intervalText = value;
                          validationMessage = null;
                        }),
                      ),
                    const SizedBox(height: 8),
                    if (timezoneCapabilityEnabled)
                      RadioGroup<TaskTimeMode>(
                        groupValue: timeMode,
                        onChanged: (picked) => setDialogState(() {
                          timeMode = picked ?? TaskTimeMode.floating;
                          fixedTimezone = TaskTimeMode.legacyFlagOf(timeMode);
                          validationMessage = null;
                        }),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final option in const [
                              TaskTimeMode.fixedTimezone,
                              TaskTimeMode.fixedTime,
                            ])
                              Semantics(
                                key: Key(
                                  'task-reminder-time-mode-${option.wire}',
                                ),
                                selected: timeMode == option,
                                label:
                                    '${option.label!}\n${_reminderTimeModeSubtitle(option)}',
                                child: RadioListTile<TaskTimeMode>(
                                  contentPadding: EdgeInsets.zero,
                                  value: option,
                                  toggleable: true,
                                  title: Text(option.label!),
                                  subtitle: Text(
                                    _reminderTimeModeSubtitle(option),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    TextFormField(
                      key: const Key('task-reminder-timezone'),
                      initialValue: timeZoneText,
                      decoration: InputDecoration(
                        labelText: fixedTimezone ? '固定时区（IANA）' : '创建时区（IANA）',
                        hintText: 'Asia/Shanghai',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        timeZoneText = value;
                        validationMessage = null;
                      },
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        key: const Key('task-reminder-validation-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const Key('task-reminder-save'),
                onPressed: () {
                  final normalizedOffset = offsetText.trim();
                  final offsetMinutes = normalizedOffset.isEmpty
                      ? 0
                      : int.tryParse(normalizedOffset);
                  final normalizedInterval = intervalText.trim();
                  final intervalMinutes = persistent
                      ? int.tryParse(normalizedInterval)
                      : null;
                  final timeZone = timeZoneText.trim();
                  String? error;
                  DateTime resolvedFireAt = fireAt;
                  if (anchorType != 'ABSOLUTE') {
                    if (anchorAt == null) {
                      error = '请先为任务设置所选时间';
                    } else if (offsetMinutes == null || offsetMinutes < 0) {
                      error = '提前分钟数必须是非负整数';
                    } else {
                      resolvedFireAt = anchorAt.subtract(
                        Duration(minutes: offsetMinutes),
                      );
                    }
                  }
                  if (error == null &&
                      persistent &&
                      (intervalMinutes == null || intervalMinutes <= 0)) {
                    error = '持续提醒间隔必须是正整数';
                  }
                  if (error == null && fixedTimezone && timeZone.isEmpty) {
                    error = '固定时区不能为空';
                  }
                  if (error != null) {
                    setDialogState(() => validationMessage = error);
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    _ReminderDraft(
                      fireAt: resolvedFireAt,
                      anchorType: anchorType,
                      offsetMinutes: anchorType == 'ABSOLUTE'
                          ? null
                          : offsetMinutes,
                      persistent: persistent,
                      intervalMinutes: intervalMinutes,
                      timeZone: timeZone.isEmpty ? null : timeZone,
                      fixedTimezone: fixedTimezone,
                      timeMode: timeMode,
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? _reminderAnchorAt(TodoTask task, String anchorType) {
    return switch (anchorType) {
      'START' => task.startAt,
      'DUE' => task.dueAt,
      'END' => task.endAt,
      _ => reminder.remindAt,
    };
  }

  Future<DateTime?> _pickReminderDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _reminderErrorMessage(Object error) {
    if (error is ArgumentError) return error.message?.toString() ?? '参数无效';
    if (error is StateError) return error.message;
    return '请稍后重试';
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
  var _linkParentOpen = false;
  bool _clearStartAt = false;
  bool _clearEndAt = false;
  DateTime? _dueAt;
  bool _allDay = false;
  String? _timeZone;
  TaskTimeMode _timeMode = TaskTimeMode.floating;

  /// 副标题只用嘀嗒原句（`:48` / `:60`），不改写成交互说明。
  static String _timeModeSubtitle(TaskTimeMode mode) {
    return switch (mode) {
      TaskTimeMode.fixedTimezone => '任务的时间会随着所在时区的不同而改变',
      TaskTimeMode.fixedTime => '不论所处时区如何变化，任务的时间都会保持一致',
      TaskTimeMode.floating => '',
    };
  }

  String _formatScheduleTime(DateTime value) => formatTaskDateTime(
    value,
    allDay: _allDay,
    mode: _timeMode,
    timeZone: _timeZone,
  );
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
      _timeMode = TaskTimeMode.floating;
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
      _timeMode = TaskTimeMode.fromWire(t?.timeMode ?? 0);
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
    final timeModeDirty =
        previous != null && _timeMode.wire != previous.timeMode;
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
      if (!timeModeDirty) _timeMode = TaskTimeMode.fromWire(latest.timeMode);
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

  bool _canStartPomodoro(TodoTask task) {
    return task.serverId != null && !task.completed && !task.cancelled;
  }

  void _startPomodoro(TodoTask task) {
    final serverId = task.serverId;
    if (!_canStartPomodoro(task) || serverId == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PomodoroPage(taskId: serverId)));
  }

  List<PopupMenuEntry<_TaskDetailAction>> _compactMoreActions(TodoTask task) {
    return [
      if (_canStartPomodoro(task))
        const PopupMenuItem(
          value: _TaskDetailAction.startPomodoro,
          child: Text('开始专注'),
        ),
      const PopupMenuItem(
        value: _TaskDetailAction.convertToNote,
        child: Text('转为笔记'),
      ),
      const PopupMenuItem(
        value: _TaskDetailAction.linkParent,
        child: Text('关联主任务'),
      ),
    ];
  }

  /// 窄面板（内容宽放不下 7 枚图标，即面板 < 356dp）才折进「...」：
  /// 7 枚固定 48dp 图标 + 4dp 间距 + 左右 8dp 内边距要 356dp，320px 屏上实测溢出 36px
  /// （Issue #279；与字号无关，1.0 与 1.3 溢出量相同）。宽面板保持原样，
  /// 免得折叠把已有的图标形状改掉。
  List<PopupMenuEntry<_TaskDetailAction>> _embeddedMoreActions(
    TodoTask task, {
    required bool foldedActions,
  }) {
    return [
      ..._compactMoreActions(task),
      if (foldedActions)
        const PopupMenuItem(
          value: _TaskDetailAction.moveToInbox,
          child: Text('移至收集箱'),
        ),
      if (foldedActions)
        const PopupMenuItem(value: _TaskDetailAction.delete, child: Text('删除')),
    ];
  }

  void _onCompactMoreAction(TodoTask task, _TaskDetailAction action) {
    switch (action) {
      case _TaskDetailAction.startPomodoro:
        _startPomodoro(task);
        return;
      case _TaskDetailAction.convertToNote:
        unawaited(_convertToNote(task));
        return;
      case _TaskDetailAction.linkParent:
        unawaited(_linkParentTask(task));
        return;
      case _TaskDetailAction.moveToInbox:
        unawaited(_moveToInboxAndClose(task));
        return;
      case _TaskDetailAction.delete:
        unawaited(_delete(task));
        return;
      default:
        return;
    }
  }

  /// 嘀嗒《多级任务》「关联主任务」：详情「...」里选一个同清单任务当主任务，
  /// 已关联时显示当前主任务并可取消关联。成环、五级上限与只读清单由
  /// [TaskRepository.reparent] 兜底，这里只负责把失败说清楚。
  Future<void> _linkParentTask(TodoTask task) async {
    if (_linkParentOpen) return;
    _linkParentOpen = true;
    try {
      await _prepareAndShowParentSheet(task);
    } finally {
      _linkParentOpen = false;
    }
  }

  /// 候选要先等三次 await，加载期间再点一次「...」→「关联主任务」会叠两层弹层：
  /// 「取消关联」只退一层，看起来像按钮失灵。一次打开只允许一个在飞的加载。
  Future<void> _prepareAndShowParentSheet(TodoTask task) async {
    final taskRepository = ref.read(taskRepositoryProvider);
    final queryRepository = ref.read(taskQueryRepositoryProvider);
    if (taskRepository == null || queryRepository == null) {
      _showTaskDetailFeedback('任务暂不可用，请稍后重试');
      return;
    }
    final excluded = {task.id, ...await taskRepository.descendantIds(task.id)};
    final candidates = (await queryRepository.filter(
      TaskQueryFilter(listId: task.listId),
    )).where((item) => !excluded.contains(item.id)).toList(growable: false);
    final currentParent = task.parentTaskId == null
        ? null
        : await taskRepository.getById(task.parentTaskId!);
    if (!mounted || _task?.id != task.id) return;
    if (candidates.isEmpty && currentParent == null) {
      _showTaskDetailFeedback('暂无可关联的主任务');
      return;
    }
    // 弹层离场动画期间 sheetContext 仍然 mounted，连点两个候选会把下层路由一起弹掉，
    // 所以一次打开只允许提交一次。
    var handled = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        Future<void> apply(String? parentTaskId) async {
          if (handled) return;
          handled = true;
          await _applyReparent(task.id, parentTaskId, sheetContext);
        }

        return _ParentTaskSheet(
          currentParentTitle: currentParent?.title,
          candidates: candidates,
          onSelect: (parentTaskId) => unawaited(apply(parentTaskId)),
          onUnlink: () => unawaited(apply(null)),
        );
      },
    );
  }

  Future<void> _applyReparent(
    String taskId,
    String? newParentId,
    BuildContext sheetContext,
  ) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.reparent(taskId, newParentId);
    } catch (error) {
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (!mounted) return;
      _showTaskDetailFeedback(_reparentFailureMessage(error));
      return;
    }
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  /// 仓储的规则裁决（只读清单、五级上限、成环）都是确定性失败，
  /// 不能对用户说「请重试」，直接把它的原因转成提示。
  String _reparentFailureMessage(Object error) {
    if (error is StateError) return error.message;
    // `ArgumentError.message` 是 `Object?`，`'${...}'` 会渲染出字面量 "null"。
    if (error is ArgumentError) {
      return error.message?.toString() ?? '关联主任务失败，请重试';
    }
    return taskViewMutationFailureMessage(error, '关联主任务失败，请重试');
  }

  void _showTaskDetailFeedback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 标题上方的主任务行：点击跳转到主任务详情（嘀嗒「点主任务标题跳主任务详情」）。
  Widget _buildParentTaskRow(TodoTask task) {
    final parentTaskId = task.parentTaskId;
    if (parentTaskId == null) return const SizedBox.shrink();
    final repo = ref.watch(taskRepositoryProvider);
    if (repo == null) return const SizedBox.shrink();
    return StreamBuilder<TodoTask?>(
      stream: repo.watchById(parentTaskId),
      builder: (context, snapshot) {
        final parent = snapshot.data;
        if (parent == null) return const SizedBox.shrink();
        final colors = brandColors(context);
        return InkWell(
          key: const Key('task-detail-parent-row'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => unawaited(showTaskDetailSheet(context, parent.id)),
          child: Semantics(
            container: true,
            button: true,
            // 嘀嗒可见文案就是裸的主任务标题；「主任务：」只给读屏，避免读出来不知道是什么。
            label: '主任务：${parent.title}',
            onTap: () => unawaited(showTaskDetailSheet(context, parent.id)),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        parent.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
    // 嘀嗒《01-任务/09-如何管理海量任务/04-用标签管理任务.md》:61（desktop 方式二）
    // 「创建任务时输入「#」或在任务详情中输入「#」快速创建标签」：
    // 标题里的「#名称」剥成标签，落库的标题不留井号原文。
    final hashDraft = parseHashTagInput(_title.text);
    // FL #603：换清单**不在这笔 `update` 里带** `listId` —— 带上它会让
    // `_requireSectionInList` 拿**旧清单的 `sectionId`** 去校验新清单，直接抛错
    // （用户看到的是"改不动"，而不是"要先移分组"）。换清单交给下面第二笔 `moveToList`：
    // 它清分组、子树跟着走、目标清单必须可写（三条 `update(listId:)` 都没有）。
    final targetListId = _selectedListId == t.listId ? null : _selectedListId;
    TodoTask updated;
    try {
      updated = await repo.update(
        t.id,
        title: hashDraft.title,
        description: _desc.text.trim(),
        priority: _priority,
        startAt: _startAt,
        endAt: _endAt,
        clearStartAt: _clearStartAt || (_startAt == null && t.startAt != null),
        clearEndAt: _clearEndAt || (_endAt == null && t.endAt != null),
        dueAt: _dueAt,
        clearDueAt: _dueAt == null && t.dueAt != null,
        allDay: _allDay,
        timeZone: _timeMode.requiresAnchorZone
            ? (_timeZone ?? 'Asia/Shanghai')
            : _timeZone,
        timeMode: _timeMode.wire,
      );
    } on ArgumentError catch (error) {
      if (_isCurrentTask(t.id)) {
        messenger.showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? '任务时间无效')),
        );
      }
      return;
    }
    // 换清单是**第二次写**（与下面的标签同形）：失败不能带走已保存的主体，也不能静默早退。
    // 走 `moveToList` 而不是 `update(listId:)`，见本函数开头那条注释。
    if (targetListId != null) {
      try {
        final moved = await repo.moveToList(t.id, targetListId);
        updated = moved.firstWhere(
          (row) => row.id == t.id,
          orElse: () => updated,
        );
      } on Object catch (error) {
        if (mounted && widget.taskId == t.id) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                // 只读清单是**可解释的拒绝**，说成"失败"会让用户以为重试就好。
                taskViewMutationFailureMessage(error, '任务已保存，但没能移到目标清单，请重试'),
              ),
            ),
          );
        }
        return;
      }
    }
    if (mounted && widget.taskId == updated.id) {
      setState(() {
        _task = updated;
        _clearStartAt = false;
        _clearEndAt = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('已保存')));
    }
    if (hashDraft.tagNames.isEmpty) return;
    // 标签是第二次写：失败不能带走已经保存的任务，也不能静默早退。
    try {
      final tagRepo = ref.read(tagRepositoryProvider);
      if (tagRepo == null) throw StateError('标签仓储不可用');
      final ids = await resolveTagIdsByName(
        repo: tagRepo,
        names: hashDraft.tagNames,
      );
      if (ids.isEmpty) return;
      final existing = (await tagRepo.tagIdsOf(updated.id)).toSet();
      await tagRepo.setTaskTags(
        updated.id,
        existing.union(ids.toSet()).toList(),
      );
    } on Object {
      if (mounted && widget.taskId == updated.id) {
        messenger.showSnackBar(const SnackBar(content: Text('标签保存失败，任务已保存')));
      }
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
    final detailTaskId = widget.taskId;
    await addSubtaskFlow(
      context,
      ref,
      t,
      // 详情面板可以切到别的任务：await 之后身份变了就不该再弹这张表。
      stillCurrent: () => mounted && widget.taskId == detailTaskId,
    );
  }

  /// §2.3 收集箱迁移：把任务挪入 synthetic inbox (listId = 'inbox')。
  Future<void> _moveToInbox(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    // FL #603：与详情面板保存那条同口径 —— 走 `moveToList` 而不是 `update(listId:)`。
    // `update(listId:)` 不清分组（搬进收集箱后 `sectionId` 还是原清单的 ⇒ 违规数据），
    // 子树也不会跟着走。收集箱是合成的可写落点，`moveToList` 自己会补出来。
    try {
      await repo.moveToList(t.id, kInboxListId);
    } on Object catch (error) {
      if (!_isCurrentTask(t.id)) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '移到收集箱失败，请重试')),
        ),
      );
      return;
    }
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
        '截止：${formatTaskDateTime(t.dueAt!, allDay: t.allDay, mode: TaskTimeMode.fromWire(t.timeMode), timeZone: t.timeZone)}',
    ].join('\n');
    final shared = await NativeIntents.shareText(body, subject: t.title);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(shared ? '已打开系统分享' : '当前设备不支持系统分享')));
  }

  Future<void> _convertToNote(TodoTask task) async {
    final serverId = task.serverId;
    if (serverId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务同步后才能转换为笔记')));
      return;
    }
    try {
      await ref.read(noteRepositoryProvider).convertFromTask(serverId);
      if (!mounted || widget.taskId != task.id) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已转换为笔记'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NotePage())),
          ),
        ),
      );
    } catch (error) {
      if (!mounted || widget.taskId != task.id) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('转换失败：${describeError(error)}')));
    }
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
      await openTaskAssignAction(
        context,
        ref,
        t,
        stillCurrent: () => mounted && widget.taskId == t.id,
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
        ).showSnackBar(const SnackBar(content: Text('清单尚未同步，无法查看评论权限')));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaskCommentsPage(
            taskServerId: taskServerId,
            listServerId: listServerId,
            taskTitle: t.title,
          ),
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
      if (list == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('清单尚未同步，无法打开共享协作')));
        return;
      }
      // 与侧栏清单动作表走同一个函数：serverId 前置校验、提示语、成员页开法只留一份。
      await openListCollaboration(context, ref, list);
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
                                : _formatScheduleTime(_dueAt!),
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
                                : '开始：${_formatScheduleTime(_startAt!)}',
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
                                : '结束：${_formatScheduleTime(_endAt!)}',
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
                        // 嘀嗒《01-任务/07-固定时间与固定时区》:31「选择「固定时区」或者「固定时间」」
                        // ⇒ 两档互斥、可以都不选（都不选＝浮动）。用词逐字照抄，
                        // 不给"未选"这一档发明界面名字（spec 056 决定 1）。
                        RadioGroup<TaskTimeMode>(
                          groupValue: _timeMode,
                          onChanged: (picked) => update(() {
                            _timeMode = picked ?? TaskTimeMode.floating;
                            if (_timeMode.requiresAnchorZone) {
                              _timeZone ??= 'Asia/Shanghai';
                            }
                          }),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final option in const [
                                TaskTimeMode.fixedTimezone,
                                TaskTimeMode.fixedTime,
                              ])
                                RadioListTile<TaskTimeMode>(
                                  key: Key('task-time-mode-${option.wire}'),
                                  contentPadding: EdgeInsets.zero,
                                  value: option,
                                  // Material 的 toggleable：再点已选中的那一档时 onChanged 收到
                                  // null ⇒ 回到"两档都不选"。嘀嗒原文只命名两档、没给默认态取名，
                                  // 所以既不发明第三档名字也不加"取消固定"按钮（spec 056 决定 1）。
                                  toggleable: true,
                                  title: Text(option.label!),
                                  subtitle: Text(_timeModeSubtitle(option)),
                                ),
                            ],
                          ),
                        ),
                        if (_timeMode.requiresAnchorZone)
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
                          key: const Key('task-add-due-reminder'),
                          onPressed: () => _addDueReminder(t),
                          icon: const Icon(Icons.alarm_add_outlined),
                          label: const Text('在截止时提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-before-due-reminder'),
                          onPressed: () =>
                              _addDueReminder(t, offsetMinutes: 10),
                          icon: const Icon(Icons.alarm_on_outlined),
                          label: const Text('截止前 10 分钟提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-end-reminder'),
                          onPressed: () => _addEndTimeReminder(t),
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('在结束时提醒'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('task-add-persistent-end-reminder'),
                          onPressed: () => _addDueReminder(
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
    final initialWallClock = taskWallClockDateTime(
      now,
      allDay: _allDay,
      mode: _timeMode,
      timeZone: _timeZone,
    );
    final date = await showDatePicker(
      context: context,
      initialDate: initialWallClock,
      firstDate: DateTime(initialWallClock.year - 1),
      lastDate: DateTime(initialWallClock.year + 5),
    );
    if (date == null || !mounted || widget.taskId != t.id) return null;
    if (_allDay) {
      return DateTime(date.year, date.month, date.day);
    }
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialWallClock),
    );
    if (!_isCurrentTask(t.id)) return null;
    final wallClock = DateTime(
      date.year,
      date.month,
      date.day,
      timeOfDay?.hour ?? initialWallClock.hour,
      timeOfDay?.minute ?? initialWallClock.minute,
    );
    return taskDateTimeFromWallClock(
      wallClock,
      mode: _timeMode,
      timeZone: _timeZone,
    );
  }

  Future<void> _addDueReminder(
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
      anchorType: 'DUE',
      offsetMinutes: offsetMinutes,
      persistent: persistent,
      intervalMinutes: intervalMinutes,
      timeZone: _timeZone,
      fixedTimezone: TaskTimeMode.legacyFlagOf(_timeMode),
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

  Future<void> _addEndTimeReminder(TodoTask t) async {
    final endAt = _endAt ?? t.endAt;
    final messenger = ScaffoldMessenger.of(context);
    if (endAt == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请先设置结束时间')));
      return;
    }
    final reminders = ref.read(reminderRepositoryProvider);
    if (reminders == null) {
      messenger.showSnackBar(const SnackBar(content: Text('提醒存储未就绪')));
      return;
    }
    await reminders.create(
      taskId: t.id,
      fireAt: endAt,
      anchorType: 'END',
      timeZone: _timeZone,
      fixedTimezone: TaskTimeMode.legacyFlagOf(_timeMode),
    );
    if (!_isCurrentTask(t.id)) return;
    messenger.showSnackBar(const SnackBar(content: Text('已添加结束时提醒')));
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
      fixedTimezone: TaskTimeMode.legacyFlagOf(_timeMode),
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
        weekdays:
            draft.frequency == 'CUSTOM' &&
                draft.repeatMode != 'ON_SELECTED_DATES'
            ? draft.weekdays
            : null,
        startAt: existing?.startAt ?? _startAt ?? _dueAt ?? DateTime.now(),
        untilAt: draft.untilAt,
        countLimit: draft.countLimit,
        repeatMode: draft.repeatMode,
        selectedDates: draft.selectedDates,
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
    final selectedDates = _selectedDatesFromJson(existing.selectedDatesJson);
    final rule = await repository.save(
      taskId: t.id,
      frequency: existing.freq,
      intervalValue: existing.interval,
      weekdays:
          existing.freq == 'CUSTOM' &&
              existing.repeatMode != 'ON_SELECTED_DATES'
          ? weekdays
          : null,
      monthDay: existing.monthDay,
      startAt: existing.startAt ?? _startAt ?? _dueAt ?? DateTime.now(),
      untilAt: existing.until,
      countLimit: existing.countLimit,
      repeatMode: existing.repeatMode,
      selectedDates: selectedDates,
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
    var intervalText = '${existing?.interval ?? 1}';
    var endMode = existing?.until != null
        ? 'until'
        : (existing?.countLimit != null ? 'count' : 'never');
    var untilAt = existing?.until;
    var countText = '${existing?.countLimit ?? 1}';
    final repeatStart =
        existing?.startAt ?? _startAt ?? _dueAt ?? DateTime.now();
    final weekdays = _weekdaysFromText(existing?.byDay);
    final selectedDates = _selectedDatesFromJson(existing?.selectedDatesJson);
    if (frequency == 'CUSTOM' &&
        repeatMode != 'ON_SELECTED_DATES' &&
        weekdays.isEmpty) {
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
                            // 顺序照嘀嗒《10-设置重复任务》：法定工作日紧跟在工作日后、
                            // 法定节假日紧跟在每周末后（文档按「工作日」「节假日」两组分节）。
                            ('LEGAL_WORKDAY', '法定工作日'),
                            ('WEEKEND', '每周末'),
                            ('LEGAL_HOLIDAY', '法定节假日'),
                            ('CUSTOM', '自定义'),
                          ]
                          .map(
                            (option) => ChoiceChip(
                              key: Key(
                                'task-repeat-frequency-${repeatFrequencyToWire(option.$1)}',
                              ),
                              label: Text(option.$2),
                              selected: frequency == option.$1,
                              onSelected: (_) => setDialogState(() {
                                frequency = option.$1;
                                if (repeatMode == 'ON_SELECTED_DATES' &&
                                    frequency != 'CUSTOM') {
                                  repeatMode = 'ON_DUE';
                                  selectedDates.clear();
                                }
                                if (frequency == 'CUSTOM' &&
                                    repeatMode != 'ON_SELECTED_DATES' &&
                                    weekdays.isEmpty) {
                                  weekdays.add(DateTime.now().weekday);
                                }
                              }),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('task-repeat-interval'),
                  initialValue: intervalText,
                  onChanged: (value) => intervalText = value,
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
                      const [
                            ('ON_DUE', '到期后重复'),
                            ('ON_COMPLETE', '完成后重复'),
                            ('ON_SELECTED_DATES', '自选日期'),
                          ]
                          .map(
                            (option) => ChoiceChip(
                              key: Key(
                                'task-repeat-mode-${option.$1.toLowerCase()}',
                              ),
                              label: Text(option.$2),
                              selected: repeatMode == option.$1,
                              onSelected: (_) => setDialogState(() {
                                repeatMode = option.$1;
                                if (repeatMode == 'ON_SELECTED_DATES') {
                                  frequency = 'CUSTOM';
                                  weekdays.clear();
                                  endMode = 'never';
                                  untilAt = null;
                                } else if (frequency == 'CUSTOM' &&
                                    weekdays.isEmpty) {
                                  selectedDates.clear();
                                  weekdays.add(DateTime.now().weekday);
                                } else {
                                  selectedDates.clear();
                                }
                              }),
                            ),
                          )
                          .toList(),
                ),
                if (frequency == 'CUSTOM' &&
                    repeatMode != 'ON_SELECTED_DATES') ...[
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
                if (repeatMode == 'ON_SELECTED_DATES') ...[
                  const SizedBox(height: 16),
                  const Text('自选日期'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('task-repeat-selected-date-add'),
                    onPressed: () async {
                      final firstDate = DateTime(
                        repeatStart.year,
                        repeatStart.month,
                        repeatStart.day,
                      );
                      final lastDate = DateTime(firstDate.year + 20, 12, 31);
                      final ordered = selectedDates.toList()..sort();
                      final candidate = ordered.isEmpty
                          ? firstDate
                          : ordered.last;
                      final initialDate = candidate.isBefore(firstDate)
                          ? firstDate
                          : (candidate.isAfter(lastDate)
                                ? lastDate
                                : candidate);
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: initialDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (picked == null || !dialogContext.mounted) return;
                      setDialogState(() {
                        selectedDates.add(
                          DateTime(picked.year, picked.month, picked.day),
                        );
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('添加日期'),
                  ),
                  if (selectedDates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (selectedDates.toList()..sort())
                          .map(
                            (date) => InputChip(
                              key: Key(
                                'task-repeat-selected-date-${_formatDateOnly(date)}',
                              ),
                              label: Text(_formatDateOnly(date)),
                              deleteIcon: Icon(
                                Icons.cancel,
                                key: Key(
                                  'task-repeat-selected-date-delete-${_formatDateOnly(date)}',
                                ),
                              ),
                              deleteButtonTooltipMessage:
                                  '删除 ${_formatDateOnly(date)}',
                              onDeleted: () => setDialogState(
                                () => selectedDates.remove(date),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('结束重复'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        const [
                              ('never', '永不'),
                              ('until', '按日期'),
                              ('count', '按次数'),
                            ]
                            .map(
                              (option) => ChoiceChip(
                                key: Key('task-repeat-end-${option.$1}'),
                                label: Text(option.$2),
                                selected: endMode == option.$1,
                                onSelected: (_) =>
                                    setDialogState(() => endMode = option.$1),
                              ),
                            )
                            .toList(),
                  ),
                  if (endMode == 'until') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('task-repeat-until-date'),
                      onPressed: () async {
                        final firstDate = DateTime(
                          repeatStart.year,
                          repeatStart.month,
                          repeatStart.day,
                        );
                        final lastDate = DateTime(firstDate.year + 20, 12, 31);
                        final candidate = untilAt ?? firstDate;
                        final initialDate = candidate.isBefore(firstDate)
                            ? firstDate
                            : (candidate.isAfter(lastDate)
                                  ? lastDate
                                  : candidate);
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: initialDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );
                        if (picked == null || !dialogContext.mounted) return;
                        setDialogState(() {
                          untilAt = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            23,
                            59,
                            59,
                          );
                        });
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        untilAt == null
                            ? '选择结束日期'
                            : '结束于 ${_formatDateOnly(untilAt!)}',
                      ),
                    ),
                  ],
                  if (endMode == 'count') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('task-repeat-count'),
                      initialValue: countText,
                      onChanged: (value) => countText = value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '重复次数',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
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
                final interval = int.tryParse(intervalText.trim());
                if (interval == null || interval < 1) return;
                final countLimit = endMode == 'count'
                    ? int.tryParse(countText.trim())
                    : null;
                if (endMode == 'count' &&
                    (countLimit == null || countLimit < 1)) {
                  return;
                }
                if (endMode == 'until' && untilAt == null) return;
                if (repeatMode == 'ON_SELECTED_DATES' &&
                    selectedDates.isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _RepeatRuleDraft(
                    frequency: frequency,
                    interval: interval,
                    weekdays: weekdays,
                    repeatMode: repeatMode,
                    selectedDates: selectedDates,
                    untilAt:
                        repeatMode != 'ON_SELECTED_DATES' && endMode == 'until'
                        ? untilAt
                        : null,
                    countLimit: repeatMode == 'ON_SELECTED_DATES'
                        ? null
                        : countLimit,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Set<int> _weekdaysFromText(String? value) => (value ?? '')
      .split(',')
      .map(int.tryParse)
      .whereType<int>()
      .where((weekday) => weekday >= 1 && weekday <= 7)
      .toSet();

  Set<DateTime> _selectedDatesFromJson(String? value) {
    if (value == null || value.isEmpty) return <DateTime>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List<dynamic>) return <DateTime>{};
      return decoded
          .map((item) => DateTime.tryParse(item.toString()))
          .whereType<DateTime>()
          .map((date) => DateTime(date.year, date.month, date.day))
          .toSet();
    } on FormatException {
      return <DateTime>{};
    }
  }

  String _formatDateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _repeatRuleLabel(TodoRepeatRule rule) {
    const labels = {
      'DAILY': '每天',
      'WEEKLY': '每周',
      'MONTHLY': '每月',
      'YEARLY': '每年',
      'WEEKDAY': '工作日',
      'LEGAL_WORKDAY': '法定工作日',
      'WEEKEND': '每周末',
      'LEGAL_HOLIDAY': '法定节假日',
      'CUSTOM': '自定义',
    };
    final label = labels[rule.freq] ?? rule.freq;
    if (rule.repeatMode == 'ON_SELECTED_DATES') {
      final count = _selectedDatesFromJson(rule.selectedDatesJson).length;
      return rule.enabled ? '自选 $count 个日期' : '已停止：自选 $count 个日期';
    }
    final ending = rule.until != null
        ? '，至 ${_formatDateOnly(rule.until!)}'
        : (rule.countLimit != null ? '，共 ${rule.countLimit} 次' : '');
    return rule.enabled ? '$label（每隔 ${rule.interval} 次$ending）' : '已停止：$label';
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
    // 分区标题：加一枚品牌色小圆点做视觉锚，让「截止时间 / 清单 / 标签」
    // 这些分区在长面板里一眼可分（原来只有一行 12px 灰字，几乎融进背景）。
    Widget sh(String s) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            s,
            style: AppTextStyles.sectionTitle.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );

    final body = ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _buildParentTaskRow(t),
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
          label: Text(_dueAt == null ? '未设置' : _formatScheduleTime(_dueAt!)),
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
        _SubtaskList(
          taskId: t.id,
          onAdd: () => _addSubtask(t),
          onAddSubtask: _addSubtask,
        ),
        const Divider(height: 32),
        sh('时间段（可选）'),
        const SizedBox(height: 8),
        // 两个入口并排而不是上下紧贴：上下堆叠时两个描边按钮会连成一块，
        // 看起来像一个被劈开的控件。并排后各自独立，也更省纵向空间。
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickSchedule(t, isStart: true),
                icon: const Icon(Icons.play_circle_outline),
                // 图标已经表达了「开始 / 结束」，文案里不再重复前缀，
                // 把宽度留给时间本身（窄屏靠省略号兜底，完整值在弹层里）。
                label: Text(
                  _startAt == null ? '设置开始时间' : _formatScheduleTime(_startAt!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickSchedule(t, isStart: false),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _endAt == null ? '设置结束时间' : _formatScheduleTime(_endAt!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (_startAt != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _startAt = null),
              child: const Text('清除开始时间'),
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
                style: AppTextStyles.body.copyWith(
                  color: colors.mutedForeground,
                ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final folded =
                  constraints.maxWidth < _embeddedActionRowContentMinWidth;
              return Row(
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
                  if (!folded)
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
                  PopupMenuButton<_TaskDetailAction>(
                    tooltip: '更多任务操作',
                    onSelected: (action) => _onCompactMoreAction(t, action),
                    itemBuilder: (context) =>
                        _embeddedMoreActions(t, foldedActions: folded),
                  ),
                  if (!folded)
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => _delete(t),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              );
            },
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
                      case _TaskDetailAction.startPomodoro:
                        _startPomodoro(t);
                        return;
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
                      case _TaskDetailAction.convertToNote:
                        unawaited(_convertToNote(t));
                        return;
                      case _TaskDetailAction.linkParent:
                        unawaited(_linkParentTask(t));
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
                    if (_canStartPomodoro(t))
                      const PopupMenuItem(
                        value: _TaskDetailAction.startPomodoro,
                        child: Text('开始专注'),
                      ),
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
                      value: _TaskDetailAction.convertToNote,
                      child: Text('转为笔记'),
                    ),
                    const PopupMenuItem(
                      value: _TaskDetailAction.linkParent,
                      child: Text('关联主任务'),
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
                PopupMenuButton<_TaskDetailAction>(
                  tooltip: '更多任务操作',
                  onSelected: (action) => _onCompactMoreAction(t, action),
                  itemBuilder: (context) => _compactMoreActions(t),
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

/// 「关联主任务」弹层：已关联时显示当前主任务与 ✖️ 取消关联，下面列同清单内
/// 可作为主任务的候选（自己与自己的后代已在调用侧排除）。
class _ParentTaskSheet extends StatelessWidget {
  const _ParentTaskSheet({
    required this.currentParentTitle,
    required this.candidates,
    required this.onSelect,
    required this.onUnlink,
  });

  final String? currentParentTitle;
  final List<TodoTask> candidates;
  final void Function(String parentTaskId) onSelect;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final currentParent = currentParentTitle;
    return SafeArea(
      key: const ValueKey('task-parent-sheet'),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('关联主任务', style: AppTextStyles.panelTitle),
              ),
            ),
            if (currentParent != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当前主任务：$currentParent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // M3 IconButton 只把 tooltip 交给 Tooltip，语义节点本身没有
                    // label（tooltip 文案只在气泡出现时存在），所以「取消关联」这个
                    // 动作必须由外层显式给读屏节点。
                    Semantics(
                      container: true,
                      button: true,
                      label: '取消关联',
                      onTap: onUnlink,
                      child: ExcludeSemantics(
                        child: IconButton(
                          key: const Key('task-parent-unlink'),
                          tooltip: '取消关联',
                          onPressed: onUnlink,
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 无候选又无当前主任务时调用侧已早退（「暂无可关联的主任务」），
            // 有主任务则主任务本身必在候选内，故这里不再摆空态分支。
            Expanded(
              child: ListView(
                children: [
                  for (final task in candidates)
                    ListTile(
                      key: ValueKey('task-parent-candidate-${task.id}'),
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text(task.title),
                      onTap: () => onSelect(task.id),
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
  const _SubtaskList({
    required this.taskId,
    required this.onAdd,
    required this.onAddSubtask,
    this.depth = 0,
    this.showEmptyAdd = true,
  });

  final String taskId;
  final VoidCallback onAdd;
  final ValueChanged<TodoTask> onAddSubtask;
  final int depth;
  final bool showEmptyAdd;

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
          if (!showEmptyAdd) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加子任务'),
            ),
          );
        }
        return ReorderableListView.builder(
          key: Key('subtask-list-$taskId'),
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          // Flutter 3.41 本地基线尚未提供 onReorderItem；升级基线前保留旧回调。
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) async {
            final ids = items.map((task) => task.id).toList();
            final moved = ids.removeAt(oldIndex);
            if (newIndex > oldIndex) newIndex -= 1;
            ids.insert(newIndex.clamp(0, ids.length), moved);
            try {
              await repo.reorderSiblings(
                listId: items.first.listId,
                parentTaskId: taskId,
                orderedTaskIds: ids,
              );
            } catch (error) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    taskViewMutationFailureMessage(error, '子任务排序保存失败，请重试'),
                  ),
                ),
              );
            }
          },
          itemBuilder: (context, index) {
            final task = items[index];
            return _SubtaskTreeItem(
              key: ValueKey('subtask-tree-${task.id}'),
              task: task,
              previousSiblingId: index == 0 ? null : items[index - 1].id,
              reorderIndex: index,
              depth: depth,
              onAddSubtask: onAddSubtask,
            );
          },
        );
      },
    );
  }
}

enum _SubtaskHierarchyAction { indent, outdent, detach, addChild }

class _SubtaskTreeItem extends ConsumerStatefulWidget {
  const _SubtaskTreeItem({
    super.key,
    required this.task,
    required this.previousSiblingId,
    required this.reorderIndex,
    required this.depth,
    required this.onAddSubtask,
  });

  final TodoTask task;
  final String? previousSiblingId;
  final int reorderIndex;
  final int depth;
  final ValueChanged<TodoTask> onAddSubtask;

  @override
  ConsumerState<_SubtaskTreeItem> createState() => _SubtaskTreeItemState();
}

class _SubtaskTreeItemState extends ConsumerState<_SubtaskTreeItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final showActions =
        MediaQuery.sizeOf(context).width < TodoLayoutTokens.compactMinWidth ||
        _hovered ||
        _focused;
    final actionWidgets = showActions
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                key: Key('subtask-reorder-${task.id}'),
                index: widget.reorderIndex,
                child: const Tooltip(
                  message: '拖动排序',
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator, size: 18),
                  ),
                ),
              ),
              PopupMenuButton<_SubtaskHierarchyAction>(
                key: Key('subtask-more-${task.id}'),
                tooltip: '子任务层级操作',
                onSelected: _applyAction,
                itemBuilder: (context) => [
                  if (widget.previousSiblingId != null)
                    PopupMenuItem(
                      key: Key('subtask-indent-${task.id}'),
                      value: _SubtaskHierarchyAction.indent,
                      child: const Text('缩进为上一项子任务'),
                    ),
                  PopupMenuItem(
                    key: Key('subtask-outdent-${task.id}'),
                    value: _SubtaskHierarchyAction.outdent,
                    child: const Text('反缩进一级'),
                  ),
                  PopupMenuItem(
                    key: Key('subtask-detach-${task.id}'),
                    value: _SubtaskHierarchyAction.detach,
                    child: const Text('解除父任务'),
                  ),
                  PopupMenuItem(
                    key: Key('subtask-add-child-${task.id}'),
                    value: _SubtaskHierarchyAction.addChild,
                    child: const Text('添加子任务'),
                  ),
                ],
              ),
            ],
          )
        : null;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: widget.depth * 16.0),
              child: CheckboxListTile(
                key: Key('subtask-row-${task.id}'),
                value: task.completed,
                title: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                secondary: actionWidgets,
                onChanged: (_) async {
                  final repo = ref.read(taskRepositoryProvider);
                  if (repo == null) return;
                  await repo.toggleComplete(task.id);
                },
              ),
            ),
            if (widget.depth < 4)
              _SubtaskList(
                taskId: task.id,
                onAdd: () => widget.onAddSubtask(task),
                onAddSubtask: widget.onAddSubtask,
                depth: widget.depth + 1,
                showEmptyAdd: false,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyAction(_SubtaskHierarchyAction action) async {
    final task = widget.task;
    if (action == _SubtaskHierarchyAction.addChild) {
      widget.onAddSubtask(task);
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    try {
      switch (action) {
        case _SubtaskHierarchyAction.indent:
          await repo.indent(task.id, widget.previousSiblingId!);
        case _SubtaskHierarchyAction.outdent:
          await repo.outdent(task.id);
        case _SubtaskHierarchyAction.detach:
          await repo.detach(task.id);
        case _SubtaskHierarchyAction.addChild:
          return;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, '子任务层级调整失败，请重试')),
        ),
      );
    }
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
      error: (e, _) => Text('标签加载失败: ${describeError(e)}'),
      data: (tags) {
        if (tags.isEmpty) return const Text('暂无标签，可先在侧栏「标签」里创建');
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

  Future<void> _moveChecklistItem(
    List<TodoChecklistItem> items,
    String sourceItemId,
    String targetItemId,
  ) async {
    final oldIndex = items.indexWhere((item) => item.id == sourceItemId);
    final newIndex = items.indexWhere((item) => item.id == targetItemId);
    if (oldIndex < 0 || newIndex < 0 || oldIndex == newIndex) return;
    final orderedIds = items.map((item) => item.id).toList();
    final movedId = orderedIds.removeAt(oldIndex);
    orderedIds.insert(newIndex, movedId);
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.reorderChecklistItems(widget.taskId, orderedIds);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_checklistErrorMessage(error))));
    }
  }

  String _checklistErrorMessage(Object error) {
    if (error is ArgumentError) return error.message?.toString() ?? '检查事项顺序无效';
    if (error is StateError) return error.message;
    return '检查事项排序失败，请稍后重试';
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
              children: items.map((item) {
                return DragTarget<String>(
                  key: Key('checklist-item-${item.id}'),
                  onWillAcceptWithDetails: (details) => details.data != item.id,
                  onAcceptWithDetails: (details) =>
                      _moveChecklistItem(items, details.data, item.id),
                  builder: (context, candidateData, rejectedData) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: candidateData.isEmpty
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
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
                          ),
                          Draggable<String>(
                            data: item.id,
                            feedback: Material(
                              key: Key('checklist-drag-feedback-${item.id}'),
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(item.title),
                              ),
                            ),
                            childWhenDragging: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                            ),
                            child: Tooltip(
                              message: '拖动检查事项',
                              child: Padding(
                                key: Key('checklist-reorder-${item.id}'),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
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
                        ? '${status.label}：${describeError(attachment.error)}'
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
                      title: Text(
                        TaskActivityRecord.actionLabelFor(activity.action),
                      ),
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

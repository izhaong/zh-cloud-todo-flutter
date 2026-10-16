import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_text.dart';
import '../../../core/db/app_database.dart';
import '../../../core/task/task_swipe_preferences.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/time/task_time_mode.dart';
import '../../../state/providers.dart';
import '../../../state/repositories/task_repository.dart';
import '../../pomodoro/pomodoro_page.dart';
import '../../tag/batch_tag_picker_sheet.dart';
import '../subtask_flow.dart';
import '../task_view_mutation_feedback.dart';
import 'task_row.dart';
import 'task_swipe_reveal.dart';

enum _TaskRowContextAction { startPomodoro, tags, addChild, more }

/// Provider-aware adapter that assembles row data and reports task actions.
class TaskRowHost extends ConsumerStatefulWidget {
  const TaskRowHost({
    super.key,
    required this.task,
    this.listColor,
    this.enableSwipeGestures = true,
    this.desktopMode = false,
    this.reorderIndex,
    this.selected = false,
    this.onTap,
    this.batchSelectionActive = false,
    this.batchSelected = false,
    this.onBatchSelectionChanged,
    this.taskSections = const [],
    this.subtaskExpander,
    this.indentLevel = 0,
  });

  final TodoTask task;
  final Color? listColor;
  final bool enableSwipeGestures;
  final bool desktopMode;
  final int? reorderIndex;
  final bool selected;
  final ValueChanged<String>? onTap;
  final bool batchSelectionActive;
  final bool batchSelected;
  final ValueChanged<bool>? onBatchSelectionChanged;
  final List<TodoTaskSection> taskSections;

  /// 展开/收起子任务那颗箭头（只有"真会展开出子行"的那一行才给）。
  /// 由清单页构造、经 `TaskRow` 挂在这一行的某一头：desktop 右、mobile 左
  /// （嘀嗒《…06-多级任务.md》:78 与 :86 给的位置不是一个方位）。
  final Widget? subtaskExpander;

  /// 这一行在树里的层级（顶层 0）。
  final int indentLevel;

  @override
  ConsumerState<TaskRowHost> createState() => _TaskRowHostState();
}

class _TaskRowHostState extends ConsumerState<TaskRowHost> {
  /// 收集箱的 id 与 `tasks_by_list_page.dart` 的 `kInboxListId` 同值。
  /// 这里不 import 那份常量：清单页本来就 import 这一行的宿主组件，反向再 import 一次
  /// 是个循环引用；仓里其余几处（`task_repository.dart` 的 `_inboxListId`、
  /// `sync_coordinator.dart` 的 `_inboxListName`）也都是各自私有常量这个既有形状。
  static const _inboxListId = 'inbox';

  late final FocusNode _focusNode;
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'task-row-${widget.task.id}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = brandColors(context);
    final tagRepo = ref.watch(tagRepositoryProvider);
    final taskRepo = ref.watch(taskRepositoryProvider);
    final now = ref.watch(currentDateTimeProvider)();
    final showContextActions =
        widget.desktopMode && (_hovered || _focused || widget.selected);

    return Focus(
      key: Key('task-row-focus-${widget.task.id}'),
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: widget.desktopMode
            ? (_) => setState(() => _hovered = true)
            : null,
        onExit: widget.desktopMode
            ? (_) => setState(() => _hovered = false)
            : null,
        cursor: widget.desktopMode
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: StreamBuilder<List<TodoTag>>(
          stream:
              tagRepo?.watchTagsOfTask(widget.task.id) ?? const Stream.empty(),
          builder: (context, tagSnapshot) {
            final tagNames = (tagSnapshot.data ?? const <TodoTag>[])
                .map((tag) => tag.name)
                .toList();

            return StreamBuilder<List<TodoTask>>(
              stream:
                  taskRepo?.watchChildrenOf(widget.task.id) ??
                  const Stream.empty(),
              builder: (context, childSnapshot) {
                final dragHandle =
                    showContextActions && widget.reorderIndex != null
                    ? ReorderableDragStartListener(
                        index: widget.reorderIndex!,
                        child: Tooltip(
                          message: '拖动排序',
                          child: Icon(
                            Icons.drag_indicator,
                            size: 18,
                            color: colors.mutedForeground,
                          ),
                        ),
                      )
                    : null;
                final data = TaskRowData(
                  id: widget.task.id,
                  title: widget.task.title,
                  completed: widget.task.completed,
                  isPinned: widget.task.isPinned,
                  priority: widget.task.priority,
                  dueAt: widget.task.dueAt == null
                      ? null
                      : taskWallClockDateTime(
                          widget.task.dueAt!,
                          allDay: widget.task.allDay,
                          mode: TaskTimeMode.fromWire(widget.task.timeMode),
                          timeZone: widget.task.timeZone,
                        ),
                  subtaskCount: childSnapshot.data?.length ?? 0,
                  tagNames: tagNames,
                  listColor: widget.listColor,
                );

                final row = TaskRow(
                  data: data,
                  desktopMode: widget.desktopMode,
                  hovered: _hovered,
                  focused: _focused,
                  selected: widget.selected,
                  batchSelectionActive: widget.batchSelectionActive,
                  batchSelected: widget.batchSelected,
                  onBatchSelectionChanged: widget.onBatchSelectionChanged,
                  now: now,
                  expander: widget.subtaskExpander,
                  indentLevel: widget.indentLevel,
                  dragHandle: dragHandle,
                  onMore: widget.desktopMode
                      ? () => _showMoreMenu(context)
                      : null,
                  onToggleComplete: () {
                    taskRepo?.toggleComplete(widget.task.id);
                  },
                  onPin: () {
                    taskRepo?.togglePin(widget.task.id);
                  },
                  onTap: () => widget.onTap?.call(widget.task.id),
                );

                Widget taskRow = row;
                if (widget.enableSwipeGestures) {
                  final swipe = resolveTaskSwipePreferences(
                    ref.watch(taskSwipePreferencesProvider),
                  );
                  taskRow = TaskSwipeRevealRow(
                    key: ValueKey('task-swipe-${widget.task.id}'),
                    // 「向右滑动分别为「完成」、「置顶」」⇒ 手指向右那一侧的档位
                    startToEndActions: _swipeSpecs(
                      context,
                      swipe.swipeRight,
                      taskRepo,
                    ),
                    // 「将任务向左短滑，可以看到任务右侧出现了三个选项」
                    endToStartActions: _swipeSpecs(
                      context,
                      swipe.swipeLeft,
                      taskRepo,
                    ),
                    child: row,
                  );
                }
                if (!widget.desktopMode) return taskRow;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onSecondaryTapDown: (details) {
                    _showDesktopContextMenu(context, details.globalPosition);
                  },
                  child: taskRow,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 把档位列表翻成钮。`taskRepo == null`（库没就绪）时钮禁用而不是消失：
  /// 露出宽度是按档位数量算的，钮消失了位移就对不上，落点会落在一个不存在的格子上。
  List<TaskSwipeActionSpec> _swipeSpecs(
    BuildContext context,
    List<TaskSwipeAction> actions,
    TaskRepository? taskRepo,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      for (final action in actions)
        TaskSwipeActionSpec(
          action: action,
          key: taskSwipeActionKey(action, widget.task.id),
          background: _swipeBackgroundFor(action, scheme),
          foreground: _swipeForegroundFor(action, scheme),
          label: _swipeLabel(action),
          onTap: taskRepo == null
              ? null
              : () => _runSwipeAction(action, taskRepo),
        ),
    ];
  }

  /// 成对取 `*Container` / `on*Container`：主题里这两色是保证对比度的组合，
  /// 与倒数纪念日左滑那一面同一套取色。
  Color _swipeBackgroundFor(TaskSwipeAction action, ColorScheme scheme) =>
      switch (action) {
        TaskSwipeAction.complete => scheme.primaryContainer,
        TaskSwipeAction.pin => scheme.secondaryContainer,
        TaskSwipeAction.moveTo => scheme.secondaryContainer,
        TaskSwipeAction.changeDueDate => scheme.secondaryContainer,
        TaskSwipeAction.delete => scheme.errorContainer,
      };

  Color _swipeForegroundFor(TaskSwipeAction action, ColorScheme scheme) =>
      switch (action) {
        TaskSwipeAction.complete => scheme.onPrimaryContainer,
        TaskSwipeAction.pin => scheme.onSecondaryContainer,
        TaskSwipeAction.moveTo => scheme.onSecondaryContainer,
        TaskSwipeAction.changeDueDate => scheme.onSecondaryContainer,
        TaskSwipeAction.delete => scheme.onErrorContainer,
      };

  /// 文案跟着状态说真话：勾掉之后那颗钮再叫「完成」就是骗人（嘀嗒原文把这一档
  /// 写成「完成」，是描述未完成行的动作）。
  String _swipeLabel(TaskSwipeAction action) => switch (action) {
    TaskSwipeAction.complete => widget.task.completed ? '取消完成' : '完成',
    TaskSwipeAction.pin => widget.task.isPinned ? '取消置顶' : '置顶',
    _ => action.label,
  };

  Future<void> _runSwipeAction(
    TaskSwipeAction action,
    TaskRepository taskRepo,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case TaskSwipeAction.complete:
        await _guardSwipeWrite(
          () => taskRepo.toggleComplete(widget.task.id),
          '操作失败，请重试',
          messenger,
        );
      case TaskSwipeAction.pin:
        await _guardSwipeWrite(
          () => taskRepo.togglePin(widget.task.id),
          '置顶失败，请重试',
          messenger,
        );
      case TaskSwipeAction.delete:
        await _confirmSwipeDelete(taskRepo, messenger);
      case TaskSwipeAction.moveTo:
        await _pickSwipeTargetList(taskRepo, messenger);
      case TaskSwipeAction.changeDueDate:
        await _pickSwipeDueDate(messenger);
    }
  }

  /// 写入包一层：失败时给可见提示，并把"成没成"返回给调用方。
  /// 不返回的话，调用方只能无条件弹成功条 —— 那样失败时会先看到失败条再看到
  /// 一条"已移动到「X」"，而清单根本没变（交叉验证点名的就是这一处）。
  Future<bool> _guardSwipeWrite(
    Future<Object?> Function() write,
    String fallback,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await write();
      return true;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, fallback)),
        ),
      );
      return false;
    }
  }

  /// 「删除任务」是这一面上唯一不可逆的动作，先确认再删（与倒数纪念日左滑同一形状）。
  Future<void> _confirmSwipeDelete(
    TaskRepository taskRepo,
    ScaffoldMessengerState messenger,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (sheetContext) => AlertDialog(
        title: Text('删除「${widget.task.title}」？'),
        content: const Text('删除后无法恢复，子任务会一起删除。'),
        actions: [
          TextButton(
            key: const Key('todo-task-swipe-delete-cancel'),
            onPressed: () => Navigator.pop(sheetContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('todo-task-swipe-delete-confirm'),
            onPressed: () => Navigator.pop(sheetContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _guardSwipeWrite(
      () => taskRepo.delete(widget.task.id),
      '删除失败，请重试',
      messenger,
    );
  }

  /// 「移动任务」：目标只有可写清单（收集箱是合成的可写落点，`listsStreamProvider`
  /// 按 `ListRepository.watchAll` 的口径不含它，所以单独补一行）。
  /// 只读清单不在表里出现，仓储里那条 `_requireWritableList` 仍是兜底 —— 这里不复制判定。
  Future<void> _pickSwipeTargetList(
    TaskRepository taskRepo,
    ScaffoldMessengerState messenger,
  ) async {
    if (widget.task.parentTaskId != null) {
      // 子任务与父任务必须同清单（`task_repository.dart` 的
      // `_assertParentChainDoesNotContain` 抛的就是「父任务必须属于同一清单」）。
      // 单独挪一行子任务会当场造出那种状态，所以在开表之前就拒掉并说清该怎么做。
      messenger.showSnackBar(const SnackBar(content: Text('子任务请随主任务一起移动')));
      return;
    }
    final lists =
        ref.read(listsStreamProvider).valueOrNull ?? const <TodoList>[];
    final writable = lists.where((list) => list.writable).toList();
    final targets = <(String, String)>[
      if (widget.task.listId != _inboxListId) (_inboxListId, '收集箱'),
      for (final list in writable)
        if (list.id != _inboxListId && list.id != widget.task.listId)
          (list.id, list.name),
    ];
    if (targets.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('没有可移动到的清单，请先新建清单')));
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (id, name) in targets)
              ListTile(
                key: Key('todo-task-swipe-move-target-$id'),
                leading: Icon(
                  id == _inboxListId
                      ? Icons.inbox_outlined
                      : Icons.list_alt_outlined,
                ),
                title: Text(name),
                onTap: () => Navigator.pop(sheetContext, id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final nameOf = targets
        .where((target) => target.$1 == picked)
        .map((target) => target.$2)
        .firstOrNull;
    final moved = await _guardSwipeWrite(
      () => taskRepo.moveToList(widget.task.id, picked),
      '移动失败，请重试',
      messenger,
    );
    if (!moved || nameOf == null) return;
    messenger.showSnackBar(SnackBar(content: Text('已移动到「$nameOf」')));
  }

  /// 「修改日期」走「把截止日挪到某一天」那条既有通道（时刻/全天语义都不变），
  /// 不在这里自己拼 dueAt —— 拼一份就会和日历拖动、「今天」清单落点漂开。
  Future<void> _pickSwipeDueDate(ScaffoldMessengerState messenger) async {
    final now = ref.read(currentDateTimeProvider)();
    final dueAt = widget.task.dueAt;
    final initial = dueAt == null
        ? DateTime(now.year, now.month, now.day)
        : taskWallClockDateTime(
            dueAt,
            allDay: widget.task.allDay,
            mode: TaskTimeMode.fromWire(widget.task.timeMode),
            timeZone: widget.task.timeZone,
          );
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '设置截止日期',
    );
    if (picked == null) return;
    final actions = ref.read(taskViewActionRepositoryProvider);
    if (actions == null) {
      messenger.showSnackBar(const SnackBar(content: Text('任务暂不可修改，请稍后重试')));
      return;
    }
    await _guardSwipeWrite(
      () => actions.scheduleTaskToDay(widget.task.id, targetDay: picked),
      '日期修改失败，请重试',
      messenger,
    );
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    final colors = brandColors(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canStartPomodoro)
              ListTile(
                key: Key('todo-task-start-focus-${widget.task.id}'),
                leading: Icon(Icons.timer_outlined, color: colors.accent),
                title: const Text('开始专注'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startPomodoro(context);
                },
              ),
            ListTile(
              key: Key('todo-task-more-delete-${widget.task.id}'),
              leading: Icon(Icons.delete_outline, color: colors.destructive),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runMoreMenuAction(
                  (repo, messenger) => _confirmSwipeDelete(repo, messenger),
                );
              },
            ),
            ListTile(
              key: Key('todo-task-more-move-list-${widget.task.id}'),
              leading: Icon(
                Icons.drive_file_move_outline,
                color: colors.accent,
              ),
              title: const Text('移动到清单'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runMoreMenuAction(
                  (repo, messenger) => _pickSwipeTargetList(repo, messenger),
                );
              },
            ),
            if (widget.taskSections.isNotEmpty)
              ListTile(
                key: Key('todo-task-move-section-${widget.task.id}'),
                leading: Icon(Icons.view_agenda_outlined, color: colors.accent),
                title: const Text('移动到分组'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSectionMenu();
                },
              ),
            ListTile(
              key: Key('todo-task-more-reminder-${widget.task.id}'),
              leading: Icon(Icons.alarm_add_outlined, color: colors.accent),
              title: const Text('设置提醒'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addReminderForTask();
              },
            ),
            ListTile(
              key: Key('todo-task-more-tags-${widget.task.id}'),
              leading: Icon(Icons.label_outline, color: colors.accent),
              title: const Text('编辑标签'),
              onTap: () {
                Navigator.pop(sheetContext);
                _runMoreMenuAction((_, _) => _pickTags(context));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 右键/底部表那条「更多操作」的落库入口。
  ///
  /// 这张表原先有四颗只 `Navigator.pop`、不写库的死钮（FL #604）：
  /// 「删除」「移动到清单」「设置提醒」「编辑标签」。它们要的行为在左滑动作表里
  /// **已经各自实现过一遍**，所以这里只做「取仓储 + 取 messenger + 转调」，
  /// 不再重造第二份口径 —— 删除的确认框文案、换清单的父子同清单校验、
  /// 改日期的墙钟换算三处都只有一份实现。
  ///
  /// `taskRepo == null`（库未就绪）时给出可见反馈：死钮的原始症状正是「点了没反应」，
  /// 静默 return 会复刻同一个症状。
  Future<void> _runMoreMenuAction(
    Future<void> Function(TaskRepository repo, ScaffoldMessengerState messenger)
    action,
  ) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地数据还没准备好，请稍后再试')));
      return;
    }
    if (!mounted) return;
    await action(repo, ScaffoldMessenger.of(context));
  }

  /// 「设置提醒」：**新建一条提醒**，不是改截止时间。
  ///
  /// 详情页那份提醒编辑器是 `_TaskDetailPaneState` 的私有方法（还有 allDay /
  /// timeMode / timeZone 三个表单态要读），在行卡片里重造一份就等于把「提醒」
  /// 的口径分叉成两份。这里走仓储的最小写路径：选一个时间点 → 建 ABSOLUTE 提醒，
  /// 与详情页「指定时间（ABSOLUTE）」档同语义。
  Future<void> _addReminderForTask() async {
    final reminders = ref.read(reminderRepositoryProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (reminders == null) {
      messenger.showSnackBar(const SnackBar(content: Text('提醒存储未就绪')));
      return;
    }
    final now = ref.read(currentDateTimeProvider)();
    final initial = widget.task.dueAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final fireAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await reminders.create(taskId: widget.task.id, fireAt: fireAt);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('已添加提醒')));
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('提醒添加失败：${describeError(error)}')),
      );
    }
  }

  bool get _canStartPomodoro {
    final task = widget.task;
    return task.serverId != null && !task.completed && !task.cancelled;
  }

  void _startPomodoro(BuildContext context) {
    final serverId = widget.task.serverId;
    if (!_canStartPomodoro || serverId == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PomodoroPage(taskId: serverId)));
  }

  Future<void> _showDesktopContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_TaskRowContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        if (_canStartPomodoro)
          const PopupMenuItem(
            value: _TaskRowContextAction.startPomodoro,
            child: Text('开始专注'),
          ),
        const PopupMenuItem(
          value: _TaskRowContextAction.tags,
          key: Key('todo-task-context-tags'),
          child: Text('标签'),
        ),
        // 嘀嗒《02-功能指南/01-任务/09-如何管理海量任务/06-多级任务.md》:51
        // 「右键单击任务，选择「添加子任务」。」
        const PopupMenuItem(
          value: _TaskRowContextAction.addChild,
          key: Key('todo-task-context-add-child'),
          child: Text('添加子任务'),
        ),
        const PopupMenuItem(
          value: _TaskRowContextAction.more,
          child: Text('更多操作'),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _TaskRowContextAction.startPomodoro:
        _startPomodoro(context);
        return;
      case _TaskRowContextAction.tags:
        await _pickTags(context);
        return;
      case _TaskRowContextAction.addChild:
        await addSubtaskFlow(context, ref, widget.task);
        return;
      case _TaskRowContextAction.more:
        await _showMoreMenu(context);
        return;
    }
  }

  /// 嘀嗒 :57「右键单击任务，选择「标签」添加已有标签或创建新标签」：
  /// 复用批量「设置标签」那张表（表内有新建一行），应用 = `setTaskTags`
  /// 全量替换，与详情 `_TagChips` 同语义，所以要预选当前已挂标签。
  Future<void> _pickTags(BuildContext context) async {
    final tagRepo = ref.read(tagRepositoryProvider);
    if (tagRepo == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签暂不可用，请稍后重试')));
      return;
    }
    final tags = await tagRepo.getAll();
    if (!context.mounted) return;
    final currentIds = await tagRepo.tagIdsOf(widget.task.id);
    if (!context.mounted) return;
    final selected = await BatchTagPickerSheet.show(
      context,
      tags: tags,
      initialSelected: currentIds.toSet(),
      onCreate: (name) => tagRepo.create(name: name),
    );
    if (selected == null || !context.mounted) return;
    try {
      await tagRepo.setTaskTags(widget.task.id, selected);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签保存失败，请重试')));
    }
  }

  Future<void> _showSectionMenu() async {
    final selectedSectionId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '移动到分组',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              key: const Key('todo-task-section-ungrouped'),
              leading: Icon(
                widget.task.sectionId == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('未分组'),
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
            for (final section in widget.taskSections)
              ListTile(
                key: Key('todo-task-section-${section.id}'),
                leading: Icon(
                  widget.task.sectionId == section.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(section.name),
                onTap: () => Navigator.of(sheetContext).pop(section.id),
              ),
          ],
        ),
      ),
    );
    if (selectedSectionId == null || !mounted) return;
    try {
      await ref
          .read(taskRepositoryProvider)
          ?.update(
            widget.task.id,
            sectionId: selectedSectionId.isEmpty ? null : selectedSectionId,
            clearSectionId: selectedSectionId.isEmpty,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务移动分组失败，请重试')));
    }
  }
}

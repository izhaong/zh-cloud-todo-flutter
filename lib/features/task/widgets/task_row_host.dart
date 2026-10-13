import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _guardSwipeWrite(
    Future<Object?> Function() write,
    String fallback,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await write();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(taskViewMutationFailureMessage(error, fallback)),
        ),
      );
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
    await _guardSwipeWrite(
      () => taskRepo.moveToList(widget.task.id, picked),
      '移动失败，请重试',
      messenger,
    );
    if (nameOf == null) return;
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
              leading: Icon(Icons.delete_outline, color: colors.destructive),
              title: const Text('删除'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: Icon(
                Icons.drive_file_move_outline,
                color: colors.accent,
              ),
              title: const Text('移动到清单'),
              onTap: () => Navigator.pop(sheetContext),
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
              leading: Icon(Icons.alarm_add_outlined, color: colors.accent),
              title: const Text('设置提醒'),
              onTap: () => Navigator.pop(sheetContext),
            ),
            ListTile(
              leading: Icon(Icons.label_outline, color: colors.accent),
              title: const Text('编辑标签'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
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

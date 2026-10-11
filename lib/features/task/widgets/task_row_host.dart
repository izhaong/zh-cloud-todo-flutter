import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/time/task_time_formatter.dart';
import '../../../core/time/task_time_mode.dart';
import '../../../state/providers.dart';
import '../../pomodoro/pomodoro_page.dart';
import '../../tag/batch_tag_picker_sheet.dart';
import 'task_row.dart';

enum _TaskRowContextAction { startPomodoro, tags, more }

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

  @override
  ConsumerState<TaskRowHost> createState() => _TaskRowHostState();
}

class _TaskRowHostState extends ConsumerState<TaskRowHost> {
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
                  taskRow = Dismissible(
                    key: ValueKey('task-${widget.task.id}'),
                    direction: DismissDirection.horizontal,
                    background: _SwipeBackground(
                      alignment: Alignment.centerLeft,
                      icon: widget.task.completed
                          ? Icons.undo
                          : Icons.check_circle,
                      label: widget.task.completed ? '取消完成' : '完成',
                      color: colors.success,
                    ),
                    secondaryBackground: _SwipeBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.more_horiz,
                      label: '更多',
                      color: colors.accent,
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        if (taskRepo == null) return false;
                        await taskRepo.toggleComplete(widget.task.id);
                        return false;
                      }
                      await _showMoreMenu(context);
                      return false;
                    },
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

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final alignLeft = alignment == Alignment.centerLeft;
    return Container(
      color: color,
      padding: EdgeInsets.only(
        left: alignLeft ? 20 : 0,
        right: alignLeft ? 0 : 20,
      ),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignLeft) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            _labelWidget(),
          ] else ...[
            _labelWidget(),
            const SizedBox(width: 6),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }

  Widget _labelWidget() => Text(
    label,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
  );
}

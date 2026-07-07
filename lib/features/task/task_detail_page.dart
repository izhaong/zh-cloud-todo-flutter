import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/api/todo_api.dart';
import '../../state/providers.dart';
import 'task_quick_add_sheet.dart';

/// 收件箱的本地清单 id（synthetic inbox）：listId 为该值的任务视为"未归清单"。
const String kInboxListId = 'inbox';

/// M11-B2 任务详情页 / Sheet（#31 改造为右侧抽屉 + Deep Link）：
/// - 标题 / 描述 / 优先级 / 起止 / due / list / folder / 标签 chips
/// - 子任务（多级，通过 parentTaskId）
/// - 勾选 / 取消勾选（乐观更新 + sync_queue）
///
/// 支持两种展示模式：
/// 1. **Sheet 模式**（默认）：通过 [showTaskDetailSheet] 以右侧抽屉/底部 Sheet 弹出
/// 2. **Page 模式**：传统全屏页面（保留向后兼容，Deep Link 场景使用）
class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({super.key, required this.taskId, this.asSheet = false});

  final String taskId;

  /// 是否以 Sheet 模式渲染（无 Scaffold/AppBar，自带拖拽手柄 + 关闭按钮）
  final bool asSheet;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  TodoTask? _task;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  int _priority = 0;
  bool _loading = true;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _desc = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final t = await ref.read(taskRepositoryProvider)!.getById(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = t;
      _title.text = t?.title ?? '';
      _desc.text = t?.description ?? '';
      _priority = t?.priority ?? 0;
      _dueAt = t?.dueAt;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _task;
    if (t == null) return;
    await ref.read(taskRepositoryProvider)!.update(
          t.id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          priority: _priority,
          dueAt: _dueAt,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _toggleComplete(TodoTask t) async {
    await ref.read(taskRepositoryProvider)!.toggleComplete(t.id);
  }

  Future<void> _togglePin(TodoTask t) async {
    final next = await ref.read(taskRepositoryProvider)!.togglePin(t.id);
    if (!mounted) return;
    setState(() => _task = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next.isPinned ? '已置顶' : '已取消置顶')),
    );
  }

  Future<void> _delete(TodoTask t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确认删除"${t.title}"？子任务也会被一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskRepositoryProvider)!.delete(t.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addSubtask(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final depth = await repo.depthOf(t.id);
    if (!mounted) return;
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
      builder: (_) => TaskQuickAddSheet(
        listId: t.listId,
        parentTaskId: t.id,
      ),
    );
  }

  /// §2.3 收件箱迁移：把任务挪入 synthetic inbox (listId = 'inbox')。
  Future<void> _moveToInbox(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await repo.update(t.id, listId: kInboxListId);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('已移至收件箱')),
    );
  }

  Future<void> _pickDue(TodoTask t) async {
    final repo = ref.read(taskRepositoryProvider);
    if (repo == null) return;
    final now = _dueAt ?? t.dueAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        timeOfDay?.hour ?? now.hour,
        timeOfDay?.minute ?? now.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = _task;
    if (t == null) {
      return _buildNotFound();
    }

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
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存'),
            ),
          ],
        ),
        const Divider(height: 32),
        Text('截止时间', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickDue(t),
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
        Text('标签', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _TagChips(taskId: t.id),
        const Divider(height: 32),
        Text('检查事项', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ChecklistSection(taskId: t.id),
        const Divider(height: 32),
        Row(
          children: [
            Text('子任务', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: () => _addSubtask(t),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        _SubtaskList(taskId: t.id, onAdd: () => _addSubtask(t)),
      ],
    );

    if (widget.asSheet) {
      return _buildSheet(context, t, body);
    }
    return _buildPage(context, t, body);
  }

  /// Sheet 模式：自带头部（拖拽手柄 + 标题 + 操作按钮 + 关闭）
  Widget _buildSheet(BuildContext context, TodoTask t, Widget body) {
    return Column(
      children: [
        // 拖拽手柄
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // 自定义头部
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
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
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _moveToInbox(t);
                  if (mounted) navigator.pop();
                },
                icon: const Icon(Icons.move_to_inbox_outlined),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
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
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _moveToInbox(t);
                  if (mounted) navigator.pop();
                },
                icon: const Icon(Icons.move_to_inbox_outlined),
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
    if (widget.asSheet) {
      return Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                const Text('任务不存在'),
              ],
            ),
          ),
          const Expanded(
            child: Center(child: Text('任务不存在或已删除')),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('任务不存在')),
      body: const Center(child: Text('任务不存在或已删除')),
    );
  }
}

/// 弹出任务详情 Sheet（#31）。
///
/// - **宽屏（≥600dp）**：右侧抽屉，宽度 420dp，从右向左滑出
/// - **窄屏（<600dp）**：底部 Sheet，高度约 90%，向上滑出
///
/// 用法：
/// ```dart
/// showTaskDetailSheet(context, task.id);
/// ```
Future<void> showTaskDetailSheet(
  BuildContext context,
  String taskId, {
  bool useRootNavigator = true,
}) async {
  final isWide = MediaQuery.sizeOf(context).width >= 600;

  if (isWide) {
    // ── 右侧抽屉模式 ──
    await showDialog<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return _RightSideSheet(
          width: 420,
          child: TaskDetailPage(taskId: taskId, asSheet: true),
        );
      },
    );
  } else {
    // ── 底部 Sheet 模式 ──
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.9,
          child: TaskDetailPage(taskId: taskId, asSheet: true),
        );
      },
    );
  }
}

/// 右侧抽屉容器：从右侧滑入的固定宽度面板。
class _RightSideSheet extends StatelessWidget {
  const _RightSideSheet({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 16,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          child: SafeArea(child: child),
        ),
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
    return StreamBuilder<List<TodoTask>>(
      stream: ref.watch(taskRepositoryProvider)!.watchChildrenOf(taskId),
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
                      decoration:
                          st.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (_) async {
                    await ref                        .read(taskRepositoryProvider)!
                        .toggleComplete(st.id);
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
  const _TagChips({required this.taskId});

  final String taskId;

  @override
  ConsumerState<_TagChips> createState() => _TagChipsState();
}

class _TagChipsState extends ConsumerState<_TagChips> {
  Set<String> _selected = {};
  bool _loaded = false;

  Future<void> _bootstrap() async {
    final ids = await ref.read(tagRepositoryProvider)!.tagIdsOf(widget.taskId);
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
    await ref        .read(tagRepositoryProvider)!
        .setTaskTags(widget.taskId, _selected.toList());
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
  const _ChecklistSection({required this.taskId});

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
    final api = ref.read(todoApiProvider).checklist;
    final items = await api.list(widget.taskId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
      _error = null;
    });
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
          ..._items.map((it) => CheckboxListTile(
                value: it.completed,
                title: Text(
                  it.title,
                  style: TextStyle(
                    decoration:
                        it.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                onChanged: (_) => _toggle(it),
                secondary: IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.close),
                  onPressed: () => _delete(it),
                ),
              )),
      ],
    );
  }
}

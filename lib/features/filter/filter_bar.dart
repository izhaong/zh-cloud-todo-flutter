import 'package:flutter/material.dart';

import '../../core/db/app_database.dart' show TodoTag, TodoTask;
import '../../state/providers.dart';
import 'saved_filter_mapping.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskAssigneeOption {
  const TaskAssigneeOption({required this.userId, required this.name});

  final int userId;
  final String name;
}

/// M11-B2 过滤条：list / folder / tag / priority / due 范围 / completed 状态。
class TaskFilter {
  const TaskFilter({
    this.listId,
    this.folderId,
    this.tagIds = const [],
    this.priority,
    this.dueRange,
    this.completed,
    this.assigneeUserId,
    this.keyword,
    this.dueAtFrom,
    this.dueAtTo,
  });

  final String? listId;
  final int? folderId;
  final List<String> tagIds;
  final int? priority;
  final String? dueRange; // today / overdue / future
  final bool? completed;
  final int? assigneeUserId;
  final String? keyword;

  /// Local calendar-day lower bound chosen in the advanced filter.
  final DateTime? dueAtFrom;

  /// Local calendar-day upper bound chosen in the advanced filter.
  final DateTime? dueAtTo;

  TaskFilter copyWith({
    String? listId,
    int? folderId,
    List<String>? tagIds,
    int? priority,
    String? dueRange,
    bool? completed,
    int? assigneeUserId,
    bool clearAssigneeUserId = false,
    String? keyword,
    bool clearKeyword = false,
    DateTime? dueAtFrom,
    bool clearDueAtFrom = false,
    DateTime? dueAtTo,
    bool clearDueAtTo = false,
  }) {
    return TaskFilter(
      listId: listId ?? this.listId,
      folderId: folderId ?? this.folderId,
      tagIds: tagIds ?? this.tagIds,
      priority: priority ?? this.priority,
      dueRange: dueRange ?? this.dueRange,
      completed: completed ?? this.completed,
      assigneeUserId: clearAssigneeUserId
          ? null
          : assigneeUserId ?? this.assigneeUserId,
      keyword: clearKeyword ? null : keyword ?? this.keyword,
      dueAtFrom: clearDueAtFrom ? null : dueAtFrom ?? this.dueAtFrom,
      dueAtTo: clearDueAtTo ? null : dueAtTo ?? this.dueAtTo,
    );
  }

  bool get isEmpty =>
      listId == null &&
      folderId == null &&
      tagIds.isEmpty &&
      priority == null &&
      dueRange == null &&
      completed == null &&
      assigneeUserId == null &&
      (keyword == null || keyword!.trim().isEmpty) &&
      dueAtFrom == null &&
      dueAtTo == null;

  /// 把当前 filter 物化为智能清单的入参 map。
  Map<String, dynamic> toJson() => {
    'listId': listId,
    'folderId': folderId,
    'tagIds': tagIds,
    'priority': priority,
    'dueRange': dueRange,
    'completed': completed,
    'assigneeUserId': assigneeUserId,
    'keyword': keyword,
    'dueAtFrom': dueAtFrom?.toIso8601String(),
    'dueAtTo': dueAtTo?.toIso8601String(),
  };
}

/// M11-B2 顶部过滤条 + "保存为智能清单" 按钮。
class FilterBar extends ConsumerWidget {
  const FilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.assigneeOptions = const [],
    this.previewResolver,
  });

  final TaskFilter filter;
  final ValueChanged<TaskFilter> onChanged;
  final List<TaskAssigneeOption> assigneeOptions;

  /// 「预览模式」的算法入口：给一套草稿条件，返回命中的任务。
  /// 由持有原始列表的页面注入（页面已经 import 本文件，反向 import 会成环）。
  final List<TodoTask> Function(TaskFilter draft)? previewResolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueRange = filter.dueRange;
    final completed = filter.completed;
    final tagsAsync = ref.watch(tagsStreamProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: filter.isEmpty,
            onSelected: (_) => onChanged(TaskFilter()),
          ),
          _Choice(
            label: dueRangeChipLabel(dueRange),
            selected: dueRange != null,
            onTap: () async {
              final next = await _pickDueRange(context, dueRange);
              if (next != null) onChanged(filter.copyWith(dueRange: next));
            },
          ),
          _Choice(
            label: completedChipLabel(completed),
            selected: completed != null,
            onTap: () async {
              final next = await _pickCompleted(context, completed);
              onChanged(filter.copyWith(completed: next));
            },
          ),
          _Choice(
            label: priorityChipLabel(filter.priority),
            selected: filter.priority != null,
            onTap: () async {
              final next = await _pickPriority(context, filter.priority);
              if (next != filter.priority) {
                onChanged(filter.copyWith(priority: next));
              }
            },
          ),
          _Choice(
            key: const Key('todo-filter-advanced'),
            label: _advancedFilterLabel(filter),
            selected: _hasAdvancedFilter(filter),
            onTap: () async {
              final next = await _pickAdvancedFilter(
                context,
                filter,
                assigneeOptions,
                tagsAsync.valueOrNull ?? const <TodoTag>[],
                tagsAsync.hasError,
                previewResolver,
              );
              if (next == null) return;
              onChanged(
                _draftFilter(
                  base: filter,
                  keyword: next.keyword ?? '',
                  dueAtFrom: next.dueAtFrom,
                  dueAtTo: next.dueAtTo,
                  assigneeUserId: next.assigneeUserId,
                  tagIds: next.tagIds,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          if (!filter.isEmpty)
            TextButton.icon(
              onPressed: () => _saveAsFilter(context, ref, filter),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('保存为过滤器'),
            ),
        ],
      ),
    );
  }

  static Future<String?> _pickDueRange(
    BuildContext context,
    String? cur,
  ) async {
    return showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('今日'),
              trailing: cur == 'today' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('已过期'),
              trailing: cur == 'overdue' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'overdue'),
            ),
            ListTile(
              leading: const Icon(Icons.upcoming),
              title: const Text('将来'),
              trailing: cur == 'future' ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'future'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
      ),
    ).then((v) => (v == null || v.isEmpty) ? null : v);
  }

  static Future<bool?> _pickCompleted(BuildContext context, bool? cur) async {
    return showModalBottomSheet<bool?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('已完成'),
              trailing: cur == true
                  ? const Icon(Icons.radio_button_checked)
                  : null,
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('未完成'),
              trailing: cur == false
                  ? const Icon(Icons.radio_button_checked)
                  : null,
              onTap: () => Navigator.pop(ctx, false),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  static Future<int?> _pickPriority(BuildContext context, int? cur) async {
    return showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in const [1, 2, 3])
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text('优先级 $p'),
                trailing: cur == p ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('清除'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
          ],
        ),
      ),
    ).then((v) => v == -1 ? null : v);
  }

  /// 高级筛选对话框里的草稿 → 完整生效条件。
  /// 预览与「应用高级筛选」共用这一份：两处各写一遍 copyWith，
  /// 迟早会变成"预览说的是一套、套出来是另一套"。
  static TaskFilter _draftFilter({
    required TaskFilter base,
    required String keyword,
    required DateTime? dueAtFrom,
    required DateTime? dueAtTo,
    required int? assigneeUserId,
    required List<String> tagIds,
  }) {
    return base.copyWith(
      keyword: keyword.isEmpty ? null : keyword,
      clearKeyword: keyword.isEmpty,
      dueAtFrom: dueAtFrom,
      clearDueAtFrom: dueAtFrom == null,
      dueAtTo: dueAtTo,
      clearDueAtTo: dueAtTo == null,
      assigneeUserId: assigneeUserId,
      clearAssigneeUserId: assigneeUserId == null,
      // 空列表 = 清空标签条件：copyWith 的 `tagIds ?? this.tagIds` 里 [] 是非 null，会覆盖旧值。
      tagIds: tagIds,
    );
  }

  static Future<_AdvancedFilter?> _pickAdvancedFilter(
    BuildContext context,
    TaskFilter current,
    List<TaskAssigneeOption> assigneeOptions,
    List<TodoTag> tags,
    bool tagsUnavailable,
    List<TodoTask> Function(TaskFilter draft)? previewResolver,
  ) async {
    final keywordController = TextEditingController(
      text: current.keyword ?? '',
    );
    int? selectedAssigneeUserId = current.assigneeUserId;
    final selectedTagIds = current.tagIds.toSet();
    final dueAtFromController = TextEditingController(
      text: _formatDate(current.dueAtFrom),
    );
    final dueAtToController = TextEditingController(
      text: _formatDate(current.dueAtTo),
    );
    var previewEnabled = false;
    String? validationMessage;
    return showDialog<_AdvancedFilter?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final draftKeyword = keywordController.text.trim();
          final draftDueAtFrom = _parseLocalDate(dueAtFromController.text);
          final draftDueAtTo = _parseLocalDate(dueAtToController.text);
          final draftDatesUsable =
              (dueAtFromController.text.trim().isEmpty ||
                  draftDueAtFrom != null) &&
              (dueAtToController.text.trim().isEmpty || draftDueAtTo != null);
          final previewMatches =
              previewEnabled && previewResolver != null && draftDatesUsable
              ? previewResolver(
                  _draftFilter(
                    base: current,
                    keyword: draftKeyword,
                    dueAtFrom: draftDueAtFrom,
                    dueAtTo: draftDueAtTo,
                    assigneeUserId: selectedAssigneeUserId,
                    tagIds: selectedTagIds.toList(),
                  ),
                )
              : null;
          return AlertDialog(
            title: const Text('高级筛选'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('task-filter-keyword'),
                    controller: keywordController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: '关键词（标题或正文）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: const Key('task-filter-assignee'),
                    initialValue: selectedAssigneeUserId,
                    decoration: const InputDecoration(
                      labelText: '负责人',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('全部负责人'),
                      ),
                      for (final option in assigneeOptions)
                        DropdownMenuItem<int?>(
                          value: option.userId,
                          child: Text(option.name),
                        ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedAssigneeUserId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('task-filter-due-at-from'),
                    controller: dueAtFromController,
                    keyboardType: TextInputType.datetime,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: '截止日期起（YYYY-MM-DD）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('task-filter-due-at-to'),
                    controller: dueAtToController,
                    keyboardType: TextInputType.datetime,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: '截止日期止（YYYY-MM-DD）',
                      border: const OutlineInputBorder(),
                      errorText: validationMessage,
                    ),
                  ),
                  _TagConditionSection(
                    tags: tags,
                    unavailable: tagsUnavailable,
                    selected: selectedTagIds,
                    onToggle: (tagId, selected) {
                      setDialogState(() {
                        if (selected) {
                          selectedTagIds.add(tagId);
                        } else {
                          selectedTagIds.remove(tagId);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('预览模式')),
                      // 旁边那句 Text 不会自动变成开关的读屏名：裸 Switch 的节点是"未命名开关"。
                      // 包一层带 key 的 Semantics，测试才钉得住"开关自身念得出「预览模式」"。
                      Semantics(
                        key: const Key(
                          'task-filter-advanced-preview-semantics',
                        ),
                        label: '预览模式',
                        child: Switch(
                          key: const Key('task-filter-advanced-preview'),
                          value: previewEnabled,
                          onChanged: previewResolver == null
                              ? null
                              : (next) =>
                                    setDialogState(() => previewEnabled = next),
                        ),
                      ),
                    ],
                  ),
                  if (previewMatches != null)
                    Container(
                      key: const Key('task-filter-advanced-preview-panel'),
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x33000000)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('命中 ${previewMatches.length} 项'),
                          if (previewMatches.isEmpty) const Text('无匹配任务'),
                          for (final task in previewMatches.take(3))
                            Text(task.title),
                          if (previewMatches.length > 3)
                            Text('其余 ${previewMatches.length - 3} 项未列出'),
                        ],
                      ),
                    )
                  else if (previewEnabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('日期无效，未预览'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final dueAtFrom = _parseLocalDate(dueAtFromController.text);
                  final dueAtTo = _parseLocalDate(dueAtToController.text);
                  final fromInvalid =
                      dueAtFromController.text.trim().isNotEmpty &&
                      dueAtFrom == null;
                  final toInvalid =
                      dueAtToController.text.trim().isNotEmpty &&
                      dueAtTo == null;
                  if (fromInvalid || toInvalid) {
                    setDialogState(
                      () => validationMessage = '请输入有效日期，例如 2026-07-12',
                    );
                    return;
                  }
                  if (dueAtFrom != null &&
                      dueAtTo != null &&
                      dueAtFrom.isAfter(dueAtTo)) {
                    setDialogState(() => validationMessage = '截止日期起不能晚于截止日期止');
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    _AdvancedFilter(
                      keyword: keywordController.text.trim().isEmpty
                          ? null
                          : keywordController.text.trim(),
                      dueAtFrom: dueAtFrom,
                      dueAtTo: dueAtTo,
                      assigneeUserId: selectedAssigneeUserId,
                      tagIds: (selectedTagIds.toList()..sort()),
                    ),
                  );
                },
                child: const Text('应用高级筛选'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 保存成「已保存过滤器」（真表 `todoFilters` + outbox）。
  /// 服务端 `conditions` 契约放不下的维度（文件夹、负责人、已过期/将来）在对话框里点名，
  /// 不静默存成半个过滤器。
  static Future<void> _saveAsFilter(
    BuildContext context,
    WidgetRef ref,
    TaskFilter filter,
  ) async {
    final mapped = savedFilterOf(filter);
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('保存为过滤器'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('saved-filter-name'),
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '过滤器名称',
                  border: OutlineInputBorder(),
                ),
              ),
              if (mapped.skipped.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('本过滤器不保存：${mapped.skipped.join('、')}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    if (mapped.conditions.toJson().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前条件本机还存不住，未保存')));
      }
      return;
    }
    final repo = ref.read(filterRepositoryProvider);
    if (repo == null) return;
    await repo.save(name: name, conditions: mapped.conditions);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已保存过滤器：$name')));
    }
  }
}

class _AdvancedFilter {
  const _AdvancedFilter({
    required this.keyword,
    required this.dueAtFrom,
    required this.dueAtTo,
    required this.assigneeUserId,
    this.tagIds = const [],
  });

  final String? keyword;
  final DateTime? dueAtFrom;
  final DateTime? dueAtTo;
  final int? assigneeUserId;
  final List<String> tagIds;
}

bool _hasAdvancedFilter(TaskFilter filter) =>
    filter.keyword?.trim().isNotEmpty == true ||
    filter.dueAtFrom != null ||
    filter.dueAtTo != null ||
    filter.assigneeUserId != null ||
    filter.tagIds.isNotEmpty;

String _advancedFilterLabel(TaskFilter filter) {
  if (filter.tagIds.isNotEmpty) return '标签';
  if (filter.assigneeUserId != null) return '负责人';
  if (filter.keyword?.trim().isNotEmpty == true) return '关键词';
  if (filter.dueAtFrom != null || filter.dueAtTo != null) return '日期';
  return '高级';
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _parseLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

String dueRangeChipLabel(String? v) {
  switch (v) {
    case 'today':
      return '今日';
    case 'tomorrow':
      return '明天';
    case 'last7days':
      return '近 7 天';
    case 'next7days':
      return '未来 7 天';
    case 'overdue':
      return '已过期';
    case 'future':
      return '将来';
    default:
      return '日期';
  }
}

String completedChipLabel(bool? v) {
  if (v == null) return '完成';
  return v ? '已完成' : '未完成';
}

String priorityChipLabel(int? v) {
  if (v == null) return '优先级';
  return '优先级 $v';
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// 「标签」这一条筛选条件：多选，缺省按「且」（与 `applyTaskFilter` 的 `containsAll` 同口径）。
/// 读不出标签时不静默退化成"没有标签条件"，要给可见提示（四件套③）。
class _TagConditionSection extends StatelessWidget {
  const _TagConditionSection({
    required this.tags,
    required this.unavailable,
    required this.selected,
    required this.onToggle,
  });

  final List<TodoTag> tags;
  final bool unavailable;
  final Set<String> selected;
  final void Function(String tagId, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('task-filter-tag-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('标签', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (unavailable)
          const Text('标签暂不可用，其余条件仍可继续筛选')
        else if (tags.isEmpty)
          const Text('暂无可选择的标签')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                Semantics(
                  key: Key('task-filter-tag-semantics-${tag.id}'),
                  label:
                      '标签 ${tag.name}，${selected.contains(tag.id) ? '已选中' : '未选中'}',
                  selected: selected.contains(tag.id),
                  button: true,
                  excludeSemantics: true,
                  child: FilterChip(
                    key: Key('task-filter-tag-${tag.id}'),
                    label: Text(tag.name),
                    selected: selected.contains(tag.id),
                    onSelected: (next) => onToggle(tag.id, next),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

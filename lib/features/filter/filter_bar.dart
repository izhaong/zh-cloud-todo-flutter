import 'package:flutter/material.dart';

import '../../core/db/app_database.dart' show TodoFolder, TodoTag, TodoTask;
import '../../state/providers.dart';
import 'saved_filter_mapping.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 标签条件内部的逻辑词，取值与服务端 `TodoFilterConditionsDO.LOGIC_AND/LOGIC_OR` 一致。
const String tagLogicAnd = 'and';
const String tagLogicOr = 'or';

/// 六个可命名条件的规范顺序，逐字对齐服务端 `TodoFilterConditionsDO.CONDITION_ORDER`
/// （zh-cloud-service `origin/develop@7bd493dd1265` 的 `:58-59`）。
/// 服务端那条注释就是理由：「『前后两个筛选条件』的『前/后』只能由这张表判定，
/// 服务端求值与客户端条件行必须同源，否则连接词会挂到另一条条件上」。
const List<String> conditionOrder = <String>[
  'listIds',
  'folderIds',
  'tagIds',
  'priorities',
  'statuses',
  'dateRange',
  'keyword',
];

/// 契约条件名的中文读法。未知键原样回显：面板不许把认不出的键伪装成没有这条条件。
String conditionKeyLabel(String key) => switch (key) {
  'listIds' => '清单',
  'folderIds' => '文件夹',
  'tagIds' => '标签',
  'priorities' => '优先级',
  'statuses' => '状态',
  'dateRange' => '日期',
  'keyword' => '关键词',
  _ => key,
};

/// 这份筛选态里「已启用」的契约条件，按 [conditionOrder] 排。
///
/// 面板用它决定哪些条件能挂连接词，映射层用它校验位置 —— 两处必须同源，
/// 否则「界面上允许的形状」和「服务端接受的形状」会分家（保存被整份拒绝）。
List<String> activeConditionKeys(TaskFilter filter) {
  final active = <String>[];
  if (filter.listId != null) active.add('listIds');
  if (filter.folderId != null) active.add('folderIds');
  if (filter.tagIds.isNotEmpty) active.add('tagIds');
  if (filter.priority != null) active.add('priorities');
  if (filter.completed != null) active.add('statuses');
  if (filter.dueRange != null ||
      filter.dueAtFrom != null ||
      filter.dueAtTo != null) {
    active.add('dateRange');
  }
  if (filter.keyword?.trim().isNotEmpty == true) active.add('keyword');
  return active;
}

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
    this.tagLogic = tagLogicAnd,
    this.conditionLogics = const {},
    this.priority,
    this.dueRange,
    this.completed,
    this.assigneeUserId,
    this.keyword,
    this.dueAtFrom,
    this.dueAtTo,
  });

  final String? listId;

  /// 本地文件夹主键（不是服务端 id）：`TodoFolders.serverId` 可空，离线建的文件夹用
  /// 服务端 id 就筛不了；与本类的 `listId`（同样是本地主键）保持一致口径。
  final String? folderId;
  final List<String> tagIds;

  /// 标签这一条条件内部的逻辑词：`and` = 全部命中，`or` = 任一命中。
  /// 词表与服务端同源（`TodoFilterConditionsDO.LOGIC_AND/LOGIC_OR`），缺省 and；
  /// 未知值一律按 and 求值（`tagsMatchAny`），不在求值层自创第三种口径。
  final String tagLogic;

  /// 跨条件的逻辑词（FL #524，嘀嗒《05-过滤器》:71 第一句）。
  /// 键取 [conditionOrder] 里的条件名，值取 `and`/`or`，说的是**这条条件相对前面累计结果**的连接方式 ——
  /// 不是「与紧挨着的前一条」两两判断：服务端把它拼成析取范式（带 `and` 的词会把这条追加进所有已有子句）。
  /// 空表 = 全部「且」，与本轮改动前的行为逐字节等价；不在 [conditionOrder] 里的键读不到 ⇒ 惰性，
  /// 所以存不下的维度（文件夹、负责人）不会被一份逻辑词翻成「或」。
  final Map<String, String> conditionLogics;
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
    String? folderId,
    bool clearFolderId = false,
    List<String>? tagIds,
    String? tagLogic,
    Map<String, String>? conditionLogics,
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
      folderId: clearFolderId ? null : folderId ?? this.folderId,
      tagIds: tagIds ?? this.tagIds,
      tagLogic: tagLogic ?? this.tagLogic,
      conditionLogics: conditionLogics ?? this.conditionLogics,
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

  /// 「或」档的判定口：大小写不敏感（服务端 `equalsIgnoreCase` 同口径），
  /// 非 `or` 的一切取值都落回「且」。
  ///
  /// 标签不足两个时也算「且」：单标签下 `containsAll` 与 `any` 命中集本就相同，
  /// 而界面上这个开关只在 ≥2 个标签时出现——留着 `or` 就是一份「存得下、看不见、改不动」的条件，
  /// `savedFilterOf` 也因此不会写出多余的 `tagLogic` 键。
  bool get tagsMatchAny =>
      tagLogic.toLowerCase() == tagLogicOr && tagIds.length > 1;

  /// 某条条件挂的是否「或」。与服务端 `isOrLogic` 同口径（`TodoFilterServiceImpl.java:322-325`）：
  /// 值忽略大小写等于 `or` 才算「或」，缺失、`and`、未知值一律算「且」。
  /// 键只认 [conditionOrder] 里那六个 —— 传进来的别的名字读不到，天然惰性。
  bool isConditionOr(String key) =>
      conditionLogics[key]?.toLowerCase() == tagLogicOr;

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
    final foldersAsync = ref.watch(foldersStreamProvider);
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
              final tagRepository = ref.read(tagRepositoryProvider);
              final next = await _pickAdvancedFilter(
                context,
                filter,
                assigneeOptions,
                tagsAsync.valueOrNull ?? const <TodoTag>[],
                tagsAsync.hasError,
                foldersAsync.valueOrNull ?? const <TodoFolder>[],
                foldersAsync.hasError,
                previewResolver,
                onCreateTag: tagRepository == null
                    ? null
                    : (name) => tagRepository.create(name: name),
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
                  tagLogic: next.tagLogic,
                  conditionLogics: next.conditionLogics,
                  folderId: next.folderId,
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
    required String tagLogic,
    required Map<String, String> conditionLogics,
    required String? folderId,
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
      tagLogic: tagLogic,
      conditionLogics: conditionLogics,
      folderId: folderId,
      clearFolderId: folderId == null,
    );
  }

  static Future<_AdvancedFilter?> _pickAdvancedFilter(
    BuildContext context,
    TaskFilter current,
    List<TaskAssigneeOption> assigneeOptions,
    List<TodoTag> tags,
    bool tagsUnavailable,
    List<TodoFolder> folders,
    bool foldersUnavailable,
    List<TodoTask> Function(TaskFilter draft)? previewResolver, {
    Future<TodoTag?> Function(String name)? onCreateTag,
  }) async {
    final keywordController = TextEditingController(
      text: current.keyword ?? '',
    );
    int? selectedAssigneeUserId = current.assigneeUserId;
    final selectedTagIds = current.tagIds.toSet();
    var selectedTagLogic = current.tagLogic;
    var selectedConditionLogics = Map<String, String>.from(
      current.conditionLogics,
    );
    String? selectedFolderId = current.folderId;
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
          // 草稿只算一次：预览命中数与「条件之间」小节列哪几条，必须来自同一份筛选态，
          // 否则小节会对着一个预览里已经不在的条件给开关。
          final draftFilter = _draftFilter(
            base: current,
            keyword: draftKeyword,
            dueAtFrom: draftDueAtFrom,
            dueAtTo: draftDueAtTo,
            assigneeUserId: selectedAssigneeUserId,
            tagIds: selectedTagIds.toList(),
            tagLogic: selectedTagLogic,
            conditionLogics: selectedConditionLogics,
            folderId: selectedFolderId,
          );
          final previewMatches =
              previewEnabled && previewResolver != null && draftDatesUsable
              ? previewResolver(draftFilter)
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
                    logic: selectedTagLogic,
                    onLogicChanged: (next) =>
                        setDialogState(() => selectedTagLogic = next),
                    unavailable: tagsUnavailable,
                    selected: selectedTagIds,
                    onCreateTag: onCreateTag,
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
                  _FolderConditionSection(
                    folders: folders,
                    unavailable: foldersUnavailable,
                    selectedId: selectedFolderId,
                    onSelect: (folderId) {
                      setDialogState(() {
                        // 单选：再点一次已选中的那个就是取消这条条件。
                        selectedFolderId = selectedFolderId == folderId
                            ? null
                            : folderId;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _ConditionLogicSection(
                    activeKeys: activeConditionKeys(draftFilter),
                    logics: selectedConditionLogics,
                    onChanged: (key, logic) => setDialogState(
                      () => selectedConditionLogics = {
                        ...selectedConditionLogics,
                        key: logic,
                      },
                    ),
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
                      tagLogic: selectedTagLogic,
                      conditionLogics: selectedConditionLogics,
                      folderId: selectedFolderId,
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
    // 文件夹条件要写成服务端 id，所以保存这一刻现取本地主键→服务端 id 的索引；
    // 索引没就绪（null）与「这个文件夹没服务端 id」是两种点名，映射层分开处理。
    final mapped = savedFilterOf(
      filter,
      folderServerIds: ref.read(folderServerIdIndexProvider),
    );
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
    this.tagLogic = tagLogicAnd,
    this.conditionLogics = const {},
    this.folderId,
  });

  final String? keyword;
  final DateTime? dueAtFrom;
  final DateTime? dueAtTo;
  final int? assigneeUserId;
  final List<String> tagIds;
  final String tagLogic;

  /// 条件之间的逻辑词，键是 [conditionOrder] 里的条件名。
  final Map<String, String> conditionLogics;

  /// 本地文件夹主键；null = 没有这条条件。
  final String? folderId;
}

bool _hasAdvancedFilter(TaskFilter filter) =>
    filter.keyword?.trim().isNotEmpty == true ||
    filter.dueAtFrom != null ||
    filter.dueAtTo != null ||
    filter.assigneeUserId != null ||
    filter.folderId != null ||
    filter.tagIds.isNotEmpty;

String _advancedFilterLabel(TaskFilter filter) {
  if (filter.tagIds.isNotEmpty) return '标签';
  if (filter.folderId != null) return '文件夹';
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

/// 「文件夹」这一条筛选条件：单选，值域来自文件夹列表（Issue #333）。
/// 读不出文件夹、或一个文件夹都没有时给可见提示，不静默退化成「什么都不列」。
class _FolderConditionSection extends StatelessWidget {
  const _FolderConditionSection({
    required this.folders,
    required this.unavailable,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TodoFolder> folders;
  final bool unavailable;
  final String? selectedId;
  final void Function(String folderId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        key: const Key('task-filter-folder-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('文件夹'),
          const SizedBox(height: 4),
          if (unavailable)
            const Text('现在读不到文件夹列表，稍后再试')
          else if (folders.isEmpty)
            const Text('还没有文件夹：先在侧栏新建一个文件夹，再回来按它筛')
          else
            Wrap(
              children: [
                for (final folder in folders)
                  Semantics(
                    selected: folder.id == selectedId,
                    child: _Choice(
                      label: folder.name,
                      selected: folder.id == selectedId,
                      onTap: () => onSelect(folder.id),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 「条件之间」这一条：给每条**可挂词**的已启用条件一个「且 / 或」开关。
///
/// 两个门槛都抄服务端 `TodoFilterServiceImpl.java:644-660` 的放置校验：
/// 只有已启用的条件能挂词，且第一条（按 `CONDITION_ORDER` 排）前面没有条件可连 ——
/// 摆一个服务端会整份拒绝的开关，等于给用户一个「按下去就存不进去」的按钮。
class _ConditionLogicSection extends StatelessWidget {
  const _ConditionLogicSection({
    required this.activeKeys,
    required this.logics,
    required this.onChanged,
  });

  final List<String> activeKeys;
  final Map<String, String> logics;
  final void Function(String key, String logic) onChanged;

  @override
  Widget build(BuildContext context) {
    if (activeKeys.length < 2) return const SizedBox.shrink();
    return Column(
      key: const Key('task-filter-condition-logic'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('条件之间', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final key in activeKeys.skip(1))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              key: Key('task-filter-condition-logic-$key'),
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('「${conditionKeyLabel(key)}」与前面'),
                for (final option in const <(String, String)>[
                  (tagLogicAnd, '且'),
                  (tagLogicOr, '或'),
                ])
                  Semantics(
                    key: Key('task-filter-condition-logic-$key-${option.$1}'),
                    label: '条件之间 ${conditionKeyLabel(key)} ${option.$2}',
                    selected:
                        (logics[key]?.toLowerCase() ?? tagLogicAnd) ==
                        option.$1,
                    button: true,
                    excludeSemantics: true,
                    child: ChoiceChip(
                      label: Text(option.$2),
                      selected:
                          (logics[key]?.toLowerCase() ?? tagLogicAnd) ==
                          option.$1,
                      onSelected: (_) => onChanged(key, option.$1),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 「标签」这一条筛选条件：多选，缺省按「且」（与 `applyTaskFilter` 的 `containsAll` 同口径）。
/// 读不出标签时不静默退化成"没有标签条件"，要给可见提示（四件套③）。
class _TagConditionSection extends StatefulWidget {
  const _TagConditionSection({
    required this.tags,
    required this.unavailable,
    required this.selected,
    required this.onToggle,
    required this.logic,
    required this.onLogicChanged,
    this.onCreateTag,
  });

  final List<TodoTag> tags;
  final bool unavailable;
  final Set<String> selected;
  final void Function(String tagId, bool selected) onToggle;

  /// 标签内部的逻辑词（`and` / `or`）。只在选了 ≥2 个标签时才画出来——
  /// 零个或一个标签时两档结果相同，摆一个没意义的开关还会让断言恒真。
  final String logic;
  final void Function(String logic) onLogicChanged;

  /// 就地建标签。高级筛选里零标签时，用户不必先去标签页建一条再回来选（FL #493）。
  /// 为 null 时保持旧行为：只给一句提示。
  final Future<TodoTag?> Function(String name)? onCreateTag;

  @override
  State<_TagConditionSection> createState() => _TagConditionSectionState();
}

class _TagConditionSectionState extends State<_TagConditionSection> {
  final _controller = TextEditingController();

  /// 本小节建出来的标签：标签流不一定立刻重发，光等 `widget.tags` 会出现「建了却看不见」。
  final List<TodoTag> _created = <TodoTag>[];
  String? _error;
  var _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TodoTag> get _available => [
    ...widget.tags,
    for (final tag in _created)
      if (!widget.tags.any((item) => item.id == tag.id)) tag,
  ];

  Future<void> _create() async {
    if (_creating) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先输入标签名');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final existing = _available.where((tag) => tag.name == name);
      final tag = existing.isNotEmpty
          ? existing.first
          : await widget.onCreateTag!(name);
      if (!mounted) return;
      if (tag == null) {
        setState(() {
          _creating = false;
          _error = '现在建不了标签，请稍后再试';
        });
        return;
      }
      setState(() {
        if (!_created.any((item) => item.id == tag.id)) _created.add(tag);
        _controller.clear();
        _creating = false;
      });
      // 建完即选中：复用 onToggle，标签条件走的是同一条写回路径。
      widget.onToggle(tag.id, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = '建标签没成功，请稍后再试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = _available;
    return Column(
      key: const Key('task-filter-tag-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('标签', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (widget.unavailable)
          const Text('标签暂不可用，其余条件仍可继续筛选')
        else ...[
          if (tags.isEmpty)
            Text(widget.onCreateTag == null ? '暂无可选择的标签' : '还没有标签，用下面一行建一个')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Semantics(
                    key: Key('task-filter-tag-semantics-${tag.id}'),
                    label: '标签 ${tag.name}，${_selectedLabel(tag.id)}',
                    selected: widget.selected.contains(tag.id),
                    button: true,
                    excludeSemantics: true,
                    child: FilterChip(
                      key: Key('task-filter-tag-${tag.id}'),
                      label: Text(tag.name),
                      selected: widget.selected.contains(tag.id),
                      onSelected: (next) => widget.onToggle(tag.id, next),
                    ),
                  ),
              ],
            ),
          if (widget.selected.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                key: const Key('task-filter-tag-logic'),
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('标签内逻辑'),
                  for (final option in const <(String, String)>[
                    (tagLogicAnd, '且'),
                    (tagLogicOr, '或'),
                  ])
                    Semantics(
                      key: Key('task-filter-tag-logic-${option.$1}'),
                      label: '标签逻辑 ${option.$2}',
                      selected: widget.logic == option.$1,
                      button: true,
                      excludeSemantics: true,
                      child: ChoiceChip(
                        label: Text(option.$2),
                        selected: widget.logic == option.$1,
                        onSelected: (_) => widget.onLogicChanged(option.$1),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.onCreateTag != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('task-filter-new-tag-input'),
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: '新建标签',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('task-filter-create-tag'),
                    onPressed: _creating ? null : _create,
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _selectedLabel(String tagId) =>
      widget.selected.contains(tagId) ? '已选中' : '未选中';
}

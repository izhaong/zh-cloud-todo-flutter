import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/repositories/summary_repository.dart';
import 'task_summary.dart';

/// 嘀嗒在移动端只有「笔记」支持添加摘要，因此入口只在笔记编辑器，返回用户确认的文本。
Future<String?> showNoteTaskSummarySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.82,
      child: const NoteTaskSummarySheet(),
    ),
  );
}

class NoteTaskSummarySheet extends ConsumerStatefulWidget {
  const NoteTaskSummarySheet({super.key});

  @override
  ConsumerState<NoteTaskSummarySheet> createState() =>
      _NoteTaskSummarySheetState();
}

class _NoteTaskSummarySheetState extends ConsumerState<NoteTaskSummarySheet> {
  TaskSummaryPreset _preset = TaskSummaryPreset.lastSevenDays;
  DateTimeRange? _customRange;
  Set<String> _listIds = const <String>{};
  bool? _completed;
  SummaryGroupMode _group = SummaryGroupMode.byList;
  SummarySortMode _sort = SummarySortMode.time;
  bool _showCompletedDate = true;
  bool _showProgress = true;

  List<SummaryTaskRow> _rows = const [];

  /// 与 [_rows] 成对记录「这批数据来自哪个区间」。失败保留旧数据时，
  /// 标题必须仍描述旧区间，也不能允许把它当新区间的结果插入。
  TaskSummaryRange? _loadedRange;
  bool _loading = true;
  bool _repositoryAvailable = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  TaskSummaryRange get _range => summaryRangeForPreset(
    _preset,
    ref.read(currentDateTimeProvider)(),
    customFrom: _customRange?.start,
    customTo: _customRange?.end,
  );

  /// 预览描述的是已取到的数据，因此区间取 `_loadedRange`；其余口径即时生效。
  TaskSummaryOptions get _options => TaskSummaryOptions(
    range: _loadedRange ?? _range,
    listIds: _listIds,
    completed: _completed,
    group: _group,
    sort: _sort,
    showCompletedDate: _showCompletedDate,
    showProgress: _showProgress,
  );

  bool get _rowsMatchSelectedRange {
    final loaded = _loadedRange;
    if (loaded == null) return false;
    final selected = _range;
    return loaded.from == selected.from && loaded.to == selected.to;
  }

  Future<void> _load() async {
    final repository = ref.read(summaryRepositoryProvider);
    final requestId = ++_requestId;
    final range = _range;
    if (repository == null) {
      if (!mounted) return;
      setState(() {
        _repositoryAvailable = false;
        _loading = false;
        _rows = const [];
        _loadedRange = null;
        _error = '未登录或本地任务库不可用，暂时无法生成摘要';
      });
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await repository.loadInRange(from: range.from, to: range.to);
      // 期间用户可能又换了区间；过期响应不得覆盖新响应。
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _rows = rows;
        _loadedRange = range;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      // 失败时保留上一次已加载数据，只追加提示。
      setState(() {
        _error = '刷新失败，已保留上一次摘要：$error';
        _loading = false;
      });
    }
  }

  Future<void> _setPreset(TaskSummaryPreset preset) async {
    if (preset == TaskSummaryPreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _customRange,
      );
      // 取消日期选择就停在原区间，不能把「自定义」悄悄当成今天。
      if (picked == null || !mounted) return;
      _customRange = picked;
    }
    if (!mounted) return;
    setState(() => _preset = preset);
    await _load();
  }

  /// 空集合等价「全部清单」。从全部起步点掉一个就变成其余全选，
  /// 逐个取消到空则回到全部，避免「一个都没选」这种无法呈现的状态。
  void _toggleList(String listId) {
    setState(() {
      if (_listIds.isEmpty) {
        _listIds = _availableLists.keys.where((id) => id != listId).toSet();
        if (_listIds.isEmpty) _listIds = const <String>{};
        return;
      }
      final next = {..._listIds};
      if (!next.remove(listId)) next.add(listId);
      _listIds = next.isEmpty ? const <String>{} : next;
    });
  }

  void _setCompleted(bool? completed) => setState(() => _completed = completed);

  void _setGroup(SummaryGroupMode group) => setState(() => _group = group);

  void _setSort(SummarySortMode sort) => setState(() => _sort = sort);

  @override
  Widget build(BuildContext context) {
    // 加载期间继续展示上一次取数的预览，只加进度条，不把控件和结果抹掉。
    final summary = buildTaskSummary(_options, _rows);
    final canInsert = summary != null && !_loading && _rowsMatchSelectedRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: const Key('note-summary-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text('摘要预览', style: TextStyle(fontSize: 18)),
              ),
              TextButton(
                key: const Key('note-summary-cancel'),
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
        _buildPreview(summary),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              key: const Key('note-summary-insert'),
              onPressed: canInsert
                  ? () => Navigator.pop(context, summary)
                  : null,
              child: const Text('插入'),
            ),
          ),
        ),
      ],
    );
  }

  /// 选项一律直接构建（不用 ListView 的懒加载）：调口径时预览必须立刻跟着变，
  /// 控件也不能因为滚出视口就不存在。
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('时间区间'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in TaskSummaryPreset.values)
                FilterChip(
                  key: ValueKey('note-summary-preset-${preset.name}'),
                  selected: _preset == preset,
                  label: Text(taskSummaryPresetLabel(preset)),
                  onSelected: (_) => _setPreset(preset),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            // 没有本地库时重试必然再失败，不给假希望。
            if (_repositoryAvailable)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('note-summary-retry'),
                  onPressed: _load,
                  child: const Text('重试'),
                ),
              ),
          ],
          if (_listIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('note-summary-clear-lists'),
                onPressed: () => setState(() => _listIds = const {}),
                child: const Text('显示全部清单'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _label('显示内容'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry
                  in _availableLists.entries.toList()
                    ..sort((left, right) => left.value.compareTo(right.value)))
                FilterChip(
                  key: ValueKey('note-summary-list-${entry.key}'),
                  selected: _listIds.isEmpty || _listIds.contains(entry.key),
                  label: Text(entry.value),
                  onSelected: (_) => _toggleList(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _choiceRow<bool?>(
            label: '状态',
            values: const [
              (value: null, label: '全部'),
              (value: true, label: '仅已完成'),
              (value: false, label: '仅未完成'),
            ],
            selected: _completed,
            keyPrefix: 'note-summary-status',
            names: const ['all', 'completed', 'uncompleted'],
            onSelected: _setCompleted,
          ),
          _choiceRow<SummaryGroupMode>(
            label: '分组',
            values: const [
              (value: SummaryGroupMode.none, label: '不分组'),
              (value: SummaryGroupMode.byList, label: '按清单'),
              (value: SummaryGroupMode.byStatus, label: '按完成状态'),
            ],
            selected: _group,
            keyPrefix: 'note-summary-group',
            names: const ['none', 'byList', 'byStatus'],
            onSelected: _setGroup,
          ),
          _choiceRow<SummarySortMode>(
            label: '排序',
            values: const [
              (value: SummarySortMode.time, label: '按时间'),
              (value: SummarySortMode.title, label: '按标题'),
            ],
            selected: _sort,
            keyPrefix: 'note-summary-sort',
            names: const ['time', 'title'],
            onSelected: _setSort,
          ),
          SwitchListTile(
            key: const Key('note-summary-show-completed-date'),
            contentPadding: EdgeInsets.zero,
            title: const Text('显示完成日期'),
            value: _showCompletedDate,
            onChanged: (value) => setState(() => _showCompletedDate = value),
          ),
          SwitchListTile(
            key: const Key('note-summary-show-progress'),
            contentPadding: EdgeInsets.zero,
            title: const Text('显示进度'),
            value: _showProgress,
            onChanged: (value) => setState(() => _showProgress = value),
          ),
        ],
      ),
    );
  }

  /// 预览固定在选项下方：调选项时要能立刻看到结果。
  /// 用 `SingleChildScrollView` 而不是 `ListView`，保证每一行都被构建、可断言。
  Widget _buildPreview(String? summary) {
    return SizedBox(
      height: 152,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('预览'),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: SingleChildScrollView(
                child: summary == null
                    ? Text(
                        _placeholder,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      )
                    : Column(
                        key: const Key('note-summary-preview'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 空行不渲染成 Text('')，否则读屏会念出一串空语义节点。
                          for (final line in summary.split('\n'))
                            if (line.isEmpty)
                              const SizedBox(height: 12)
                            else
                              Text(line),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _placeholder {
    if (_loading && _rows.isEmpty) return '正在读取任务…';
    if (_error != null) return '还没有可预览的摘要';
    return '该区间内没有任务';
  }

  Map<String, String> get _availableLists => {
    for (final row in _rows) row.listId: row.listName,
  };

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _choiceRow<T>({
    required String label,
    required List<({T value, String label})> values,
    required T selected,
    required String keyPrefix,
    required List<String> names,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < values.length; index++)
                FilterChip(
                  key: ValueKey('$keyPrefix-${names[index]}'),
                  selected: values[index].value == selected,
                  label: Text(values[index].label),
                  onSelected: (_) => onSelected(values[index].value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

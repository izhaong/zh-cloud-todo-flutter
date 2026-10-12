import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../state/repositories/task_query_repository.dart';

/// 搜索页专用的本地任务筛选选择器。
///
/// 它只生成 [TaskQueryFilter]，由调用方交给离线 Repository 查询；不会直接访问
/// 网络或写入同步队列。
class TaskSearchFilterSheet extends StatefulWidget {
  const TaskSearchFilterSheet({
    super.key,
    required this.initialFilter,
    required this.lists,
    required this.tags,
  });

  final TaskQueryFilter initialFilter;
  final List<TodoList> lists;
  final List<TodoTag> tags;

  @override
  State<TaskSearchFilterSheet> createState() => _TaskSearchFilterSheetState();
}

class _TaskSearchFilterSheetState extends State<TaskSearchFilterSheet> {
  late String? _listId = widget.initialFilter.listId;
  late final Set<String> _tagIds = widget.initialFilter.tagIds.toSet();
  late int? _priority = widget.initialFilter.priority;
  late DateTime? _dueAtFrom = widget.initialFilter.dueAtFrom;
  late DateTime? _dueAtTo = widget.initialFilter.dueAtTo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('筛选任务', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: const Key('task-search-filter-list'),
                initialValue: _listId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '清单',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('全部清单')),
                  // `listsStreamProvider` intentionally hides the synthetic
                  // inbox from ordinary list management, but it is still a
                  // valid task location and must remain searchable here.
                  const DropdownMenuItem<String?>(
                    value: 'inbox',
                    child: Text('收集箱'),
                  ),
                  for (final list in widget.lists)
                    DropdownMenuItem<String?>(
                      value: list.id,
                      child: Text(list.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _listId = value),
              ),
              const SizedBox(height: 16),
              Text('标签', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.tags)
                    FilterChip(
                      key: Key('task-search-filter-tag-${tag.id}'),
                      label: Text(tag.name),
                      selected: _tagIds.contains(tag.id),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _tagIds.add(tag.id);
                          } else {
                            _tagIds.remove(tag.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('优先级', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final priority in const [1, 2, 3])
                    ChoiceChip(
                      key: Key('task-search-filter-priority-$priority'),
                      label: Text('优先级 $priority'),
                      selected: _priority == priority,
                      onSelected: (_) => setState(() {
                        _priority = _priority == priority ? null : priority;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('task-search-filter-date-range'),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_dateRangeLabel()),
                onPressed: _pickDateRange,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('task-search-filter-apply'),
                onPressed: _apply,
                child: const Text('应用筛选'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateRangeLabel() {
    if (_dueAtFrom == null || _dueAtTo == null) return '选择日期范围';
    return '${_formatDate(_dueAtFrom!)} 至 ${_formatDate(_dueAtTo!)}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dueAtFrom == null || _dueAtTo == null
          ? null
          : DateTimeRange(start: _dueAtFrom!, end: _dueAtTo!),
      currentDate: now,
    );
    if (range == null || !mounted) return;
    setState(() {
      _dueAtFrom = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _dueAtTo = DateTime(range.end.year, range.end.month, range.end.day);
    });
  }

  void _apply() {
    final tagIds = _tagIds.toList()..sort();
    Navigator.of(context).pop(
      TaskQueryFilter(
        listId: _listId,
        tagIds: tagIds,
        priority: _priority,
        dueAtFrom: _dueAtFrom,
        dueAtTo: _dueAtTo,
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

Future<TaskQueryFilter?> showTaskSearchFilterSheet(
  BuildContext context, {
  required TaskQueryFilter initialFilter,
  required List<TodoList> lists,
  required List<TodoTag> tags,
}) {
  return showModalBottomSheet<TaskQueryFilter>(
    context: context,
    isScrollControlled: true,
    builder: (context) => TaskSearchFilterSheet(
      initialFilter: initialFilter,
      lists: lists,
      tags: tags,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';
import '../../state/repositories/task_query_repository.dart';
import 'task_search_filter_sheet.dart';

typedef TaskSearchPageLoader =
    Future<TaskSearchPageResult> Function(TaskSearchPageRequest request);

/// 离线全局搜索：只查询 Drift 本地聚合，不上传用户检索词。
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key, this.searchPage});

  /// Widget 回归可传入确定性查询；正常运行始终通过 [TaskQueryRepository] 查询 Drift。
  final TaskSearchPageLoader? searchPage;

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  TaskSearchScope _scope = TaskSearchScope.all;
  TaskQueryFilter _taskFilter = const TaskQueryFilter();
  List<TaskSearchResult> _results = const [];
  int _total = 0;
  int _request = 0;
  String _loadedFingerprint = '';
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taskQueryRepositoryProvider);
    final lists =
        ref.watch(listsStreamProvider).valueOrNull ?? const <TodoList>[];
    final tags = ref.watch(tagsStreamProvider).valueOrNull ?? const <TodoTag>[];
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('global-task-search'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: '搜索任务、清单或标签',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            if (_query.trim().isNotEmpty) ...[
              _buildScopeSelector(),
              if (_scope == TaskSearchScope.task)
                _buildTaskFilterActions(lists: lists, tags: tags),
              const SizedBox(height: 8),
            ],
            Expanded(child: _buildResults(repository)),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector() {
    return Semantics(
      label: '搜索范围',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final scope in TaskSearchScope.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('task-search-scope-${scope.name}'),
                  label: Text(_scopeLabel(scope)),
                  selected: _scope == scope,
                  onSelected: (_) => _selectScope(scope),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskFilterActions({
    required List<TodoList> lists,
    required List<TodoTag> tags,
  }) {
    final selectedCount = _taskFilterSelectedCount;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Semantics(
          label: selectedCount == 0 ? '筛选任务' : '筛选任务，已选 $selectedCount 项',
          button: true,
          child: TextButton.icon(
            key: const Key('task-search-filter'),
            icon: const Icon(Icons.tune_outlined),
            label: Text(selectedCount == 0 ? '筛选' : '筛选 $selectedCount'),
            onPressed: () => _openTaskFilter(lists: lists, tags: tags),
          ),
        ),
        if (selectedCount > 0)
          Semantics(
            label: '清除任务筛选',
            button: true,
            child: TextButton.icon(
              key: const Key('task-search-filter-clear'),
              icon: const Icon(Icons.clear),
              label: const Text('清除筛选'),
              onPressed: () {
                setState(() => _taskFilter = const TaskQueryFilter());
                _reload();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildResults(TaskQueryRepository? repository) {
    if (repository == null && widget.searchPage == null) {
      return const Center(child: Text('请先登录后再搜索'));
    }
    if (_query.trim().isEmpty) {
      return const Center(child: Text('输入关键词以搜索本地任务、清单和标签'));
    }
    if (_loading && _loadedFingerprint != _fingerprint) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('搜索失败，点击重试'),
        ),
      );
    }
    if (_results.isEmpty) return const Center(child: Text('未找到匹配结果'));
    return ListView(
      children: [
        for (final result in _results)
          ListTile(
            key: Key('global-search-result-${result.identity}'),
            leading: Icon(_iconFor(result.type)),
            title: Text('${_labelFor(result.type)} · ${result.title}'),
            onTap: () => _openResult(context, result),
          ),
        if (_results.length < _total)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Semantics(
                container: true,
                label: _loadingMore
                    ? '正在加载更多搜索结果'
                    : '加载更多 ${_total - _results.length} 条搜索结果',
                button: true,
                onTap: _loadingMore ? null : () => _reload(append: true),
                child: ExcludeSemantics(
                  child: FilledButton.tonal(
                    key: const Key('task-search-load-more'),
                    onPressed: _loadingMore
                        ? null
                        : () => _reload(append: true),
                    child: Text(
                      _loadingMore
                          ? '正在加载'
                          : '加载更多 ${_total - _results.length} 条',
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Center(
            child: TextButton.icon(
              onPressed: () => _reload(append: _results.isNotEmpty),
              icon: const Icon(Icons.refresh),
              label: const Text('加载更多失败，点击重试'),
            ),
          ),
      ],
    );
  }

  int get _taskFilterSelectedCount =>
      (_taskFilter.listId == null ? 0 : 1) +
      _taskFilter.tagIds.length +
      (_taskFilter.priority == null ? 0 : 1) +
      (_taskFilter.dueAtFrom == null || _taskFilter.dueAtTo == null ? 0 : 1);

  String get _fingerprint => [
    _query.trim(),
    _scope.name,
    _taskFilter.listId ?? '',
    ..._taskFilter.tagIds,
    _taskFilter.priority?.toString() ?? '',
    _taskFilter.dueAtFrom?.toIso8601String() ?? '',
    _taskFilter.dueAtTo?.toIso8601String() ?? '',
  ].join('|');

  String _scopeLabel(TaskSearchScope scope) => switch (scope) {
    TaskSearchScope.all => '全部',
    TaskSearchScope.task => '任务',
    TaskSearchScope.list => '清单',
    TaskSearchScope.tag => '标签',
  };

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _reload();
  }

  void _selectScope(TaskSearchScope scope) {
    if (_scope == scope) return;
    setState(() => _scope = scope);
    _reload();
  }

  Future<void> _openTaskFilter({
    required List<TodoList> lists,
    required List<TodoTag> tags,
  }) async {
    final next = await showTaskSearchFilterSheet(
      context,
      initialFilter: _taskFilter,
      lists: lists,
      tags: tags,
    );
    if (next == null || !mounted) return;
    setState(() => _taskFilter = next);
    _reload();
  }

  Future<void> _reload({bool append = false}) async {
    final repository = ref.read(taskQueryRepositoryProvider);
    if ((repository == null && widget.searchPage == null) ||
        _query.trim().isEmpty) {
      return;
    }
    if (append && (_loadingMore || _results.length >= _total)) return;

    final request = ++_request;
    final fingerprint = _fingerprint;
    setState(() {
      _error = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });
    try {
      final searchRequest = TaskSearchPageRequest(
        keyword: _query,
        scope: _scope,
        filter: _taskFilter,
        offset: append ? _results.length : 0,
      );
      final page = widget.searchPage == null
          ? await repository!.searchPage(searchRequest)
          : await widget.searchPage!(searchRequest);
      if (!mounted || request != _request || fingerprint != _fingerprint) {
        return;
      }
      setState(() {
        if (append) {
          final seen = _results.map((result) => result.identity).toSet();
          _results = [
            ..._results,
            ...page.results.where((result) => seen.add(result.identity)),
          ];
        } else {
          _results = page.results;
        }
        _total = page.total;
        _loadedFingerprint = fingerprint;
      });
    } catch (error) {
      if (mounted && request == _request && fingerprint == _fingerprint) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && request == _request && fingerprint == _fingerprint) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  IconData _iconFor(TaskSearchResultType type) => switch (type) {
    TaskSearchResultType.task => Icons.check_circle_outline,
    TaskSearchResultType.list => Icons.list_alt_outlined,
    TaskSearchResultType.tag => Icons.label_outline,
  };

  String _labelFor(TaskSearchResultType type) => switch (type) {
    TaskSearchResultType.task => '任务',
    TaskSearchResultType.list => '清单',
    TaskSearchResultType.tag => '标签',
  };

  void _openResult(BuildContext context, TaskSearchResult result) {
    Navigator.of(context).pop<TaskSearchResult>(result);
  }
}

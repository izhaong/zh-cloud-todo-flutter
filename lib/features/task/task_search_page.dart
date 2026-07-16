import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/repositories/task_query_repository.dart';
import 'task_detail_page.dart';

/// 离线全局搜索：只查询 Drift 本地聚合，不上传用户检索词。
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key});

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taskQueryRepositoryProvider);
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
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults(repository)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(TaskQueryRepository? repository) {
    if (repository == null) {
      return const Center(child: Text('请先登录后再搜索'));
    }
    if (_query.trim().isEmpty) {
      return const Center(child: Text('输入关键词以搜索本地任务、清单和标签'));
    }
    return FutureBuilder<List<TaskSearchResult>>(
      future: repository.search(_query),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? const <TaskSearchResult>[];
        if (results.isEmpty) return const Center(child: Text('未找到匹配结果'));
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            return ListTile(
              key: Key('global-search-result-${result.identity}'),
              leading: Icon(_iconFor(result.type)),
              title: Text('${_labelFor(result.type)} · ${result.title}'),
              onTap: () => _openResult(context, result),
            );
          },
        );
      },
    );
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
    if (result.type == TaskSearchResultType.task) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: result.id)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已定位${_labelFor(result.type)}：${result.title}')),
    );
  }
}

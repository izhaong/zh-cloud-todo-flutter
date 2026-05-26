import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoFlutterApp());
}

class TodoFlutterApp extends StatelessWidget {
  const TodoFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'zh-cloud todo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  static const _cacheKey = 'zh_cloud_todo_flutter_state_v1';

  bool _isLoading = true;
  bool _isSignedIn = false;
  String _activeTab = '任务';
  late List<_TodoListItem> _lists;
  late List<_TodoTaskItem> _tasks;
  late List<_SyncQueueItem> _syncQueue;

  @override
  void initState() {
    super.initState();
    _lists = [
      const _TodoListItem('工作', 12, 3),
      const _TodoListItem('个人', 8, 1),
      const _TodoListItem('共享清单', 5, 2),
    ];
    _tasks = [
      const _TodoTaskItem('补齐 Flutter 主壳路由', '工作', '进行中'),
      const _TodoTaskItem('接入任务列表和快速添加', '工作', '待办'),
      const _TodoTaskItem('同步队列与本地缓存回显', '共享清单', '待办'),
    ];
    _syncQueue = [
      const _SyncQueueItem('create task', '待重试'),
      const _SyncQueueItem('update list', '已排队'),
    ];
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _isSignedIn = data['signedIn'] as bool? ?? false;
      _activeTab = data['activeTab'] as String? ?? '任务';
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({'signedIn': _isSignedIn, 'activeTab': _activeTab}),
    );
  }

  Future<void> _toggleSignIn() async {
    setState(() {
      _isSignedIn = !_isSignedIn;
      if (_isSignedIn) {
        _syncQueue.insert(0, const _SyncQueueItem('login', '已同步'));
      } else {
        _syncQueue.insert(0, const _SyncQueueItem('logout', '已同步'));
      }
    });
    await _persistState();
  }

  Future<void> _addTask() async {
    setState(() {
      _tasks = [const _TodoTaskItem('新的快速添加任务', '工作', '待办'), ..._tasks];
      _syncQueue.insert(0, const _SyncQueueItem('create task', '待重试'));
    });
    await _persistState();
  }

  Future<void> _markFirstTaskDone() async {
    setState(() {
      if (_tasks.isEmpty) {
        return;
      }
      final first = _tasks.first;
      _tasks = [
        _TodoTaskItem(first.title, first.listName, '已完成'),
        ..._tasks.skip(1),
      ];
      _syncQueue.insert(0, const _SyncQueueItem('complete task', '已排队'));
    });
    await _persistState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('zh-cloud todo'),
        actions: [
          IconButton(
            tooltip: '同步',
            onPressed: () {
              setState(() {
                _syncQueue.insert(
                  0,
                  const _SyncQueueItem('manual sync', '已触发'),
                );
              });
              _persistState();
            },
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: _isSignedIn ? '退出登录' : '登录',
            onPressed: _toggleSignIn,
            icon: Icon(_isSignedIn ? Icons.logout : Icons.login),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('移动端核心闭环', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_isSignedIn ? '已登录，状态已恢复' : '未登录，等待接入 todo-member'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: '我的任务', value: '${_tasks.length}'),
              _MetricCard(label: '今日完成', value: '6'),
              _MetricCard(label: '同步队列', value: '${_syncQueue.length}'),
              const _MetricCard(label: '离线缓存', value: '已启用'),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('清单'),
          const SizedBox(height: 8),
          ..._lists.map((item) => _ListTileCard(item: item)),
          const SizedBox(height: 20),
          const _SectionTitle('任务'),
          const SizedBox(height: 8),
          ..._tasks.map((item) => _TaskTileCard(item: item)),
          const SizedBox(height: 20),
          const _SectionTitle('同步队列'),
          const SizedBox(height: 8),
          ..._syncQueue.map((item) => _QueueTileCard(item: item)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _addTask,
            icon: const Icon(Icons.playlist_add),
            label: const Text('快速添加任务'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _markFirstTaskDone,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('完成首个任务'),
          ),
          const SizedBox(height: 12),
          Text('当前页签：$_activeTab'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex(_activeTab),
        onDestinationSelected: (index) {
          setState(() {
            _activeTab = _tabName(index);
          });
          _persistState();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: '任务'),
          NavigationDestination(icon: Icon(Icons.view_list), label: '清单'),
          NavigationDestination(icon: Icon(Icons.sync), label: '同步'),
        ],
      ),
    );
  }

  int _navIndex(String value) {
    switch (value) {
      case '清单':
        return 1;
      case '同步':
        return 2;
      default:
        return 0;
    }
  }

  String _tabName(int index) {
    switch (index) {
      case 1:
        return '清单';
      case 2:
        return '同步';
      default:
        return '任务';
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({required this.item});

  final _TodoListItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: Text(item.name),
        subtitle: Text('${item.taskCount} 个任务 · ${item.completedCount} 已完成'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TaskTileCard extends StatelessWidget {
  const _TaskTileCard({required this.item});

  final _TodoTaskItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(item.title),
        subtitle: Text('${item.listName} · ${item.status}'),
        trailing: const Icon(Icons.more_horiz),
      ),
    );
  }
}

class _QueueTileCard extends StatelessWidget {
  const _QueueTileCard({required this.item});

  final _SyncQueueItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_sync_outlined),
        title: Text(item.action),
        subtitle: Text(item.state),
      ),
    );
  }
}

class _TodoListItem {
  const _TodoListItem(this.name, this.taskCount, this.completedCount);

  final String name;
  final int taskCount;
  final int completedCount;
}

class _TodoTaskItem {
  const _TodoTaskItem(this.title, this.listName, this.status);

  final String title;
  final String listName;
  final String status;
}

class _SyncQueueItem {
  const _SyncQueueItem(this.action, this.state);

  final String action;
  final String state;
}

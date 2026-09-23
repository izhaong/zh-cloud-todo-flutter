import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../state/providers.dart';

/// 嘀嗒《推荐任务》的四类分组，顺序与帮助中心一致。
const _recommendationGroups = <({String code, String title})>[
  (code: 'RECENTLY_ADDED', title: '最近添加'),
  (code: 'REPEATEDLY_RESCHEDULED', title: '多次修改时间'),
  (code: 'LONG_UNFINISHED', title: '长时间未完成'),
  (code: 'DUE_SOON', title: '即将到来'),
];

const _dueSoonCode = 'DUE_SOON';

/// 「即将到来」下唯一能由 `dueAt` 算出的两档，顺序写死：
/// 跟着候选数据（仓储按 `score` 降序）走的话，分数高的「后天」会排到「明天」前面。
const _dueSoonBucketOrder = <({String label, String keyName})>[
  (label: '明天', keyName: 'tomorrow'),
  (label: '后天', keyName: 'day-after'),
];

/// 嘀嗒《推荐任务》独立页：把工作区面板里只有前几条的推荐摊开成四类分组。
///
/// 分组依据是服务端给的 `reasonCode`，客户端不重新发明判据；
/// 只有「即将到来」的子档（明天 / 后天）能由 `dueAt` 算出来。
class RecommendationPage extends ConsumerStatefulWidget {
  const RecommendationPage({
    super.key,
    required this.onTaskSelected,
    required this.onAddToToday,
    this.now,
  });

  final ValueChanged<int> onTaskSelected;
  final Future<void> Function(int) onAddToToday;

  /// 「明天 / 后天」要有可比对的今天；测试注入固定时刻，默认走系统时间。
  final DateTime Function()? now;

  @override
  ConsumerState<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends ConsumerState<RecommendationPage> {
  var _refreshFailed = false;
  var _addToTodayFailed = false;
  Future<void>? _refreshInFlight;
  final _addingTaskIds = <int>{};

  /// 只在 `initState` 订一次：每次 build 现造一条流会让 `StreamBuilder`
  /// 逐帧退订再订阅，Drift 每次排一个 zero-delay 关闭定时器，页面就永远 settle 不下来。
  Stream<List<TodoRecommendation>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = ref.read(recommendationRepositoryProvider)?.watchAll();
  }

  DateTime get _today {
    final now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _addToToday(int taskServerId) async {
    // 禁用态只在**下一次 build 之后**生效；同一帧内连点两次，两次都命中
    // 上一次 build 里 onPressed 非 null 的按钮，所以要这道守卫兜住同帧。
    if (!_addingTaskIds.add(taskServerId)) return;
    setState(() => _addToTodayFailed = false);
    try {
      await widget.onAddToToday(taskServerId);
    } catch (_) {
      if (mounted) setState(() => _addToTodayFailed = true);
    } finally {
      _addingTaskIds.remove(taskServerId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() async {
    final repository = ref.read(recommendationRepositoryProvider);
    if (repository == null) return;
    try {
      await repository.refresh(limit: 50);
      if (mounted && _refreshFailed) setState(() => _refreshFailed = false);
    } catch (_) {
      // 保留 Drift 里上一次成功拉取的结果，页面不清空。
      if (mounted && !_refreshFailed) setState(() => _refreshFailed = true);
    }
  }

  Future<void> _requestRefresh() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final request = _refresh();
    _refreshInFlight = request;
    return request.whenComplete(() {
      if (identical(_refreshInFlight, request)) _refreshInFlight = null;
    });
  }

  String? _dueSoonBucketLabel(DateTime? dueAt) {
    if (dueAt == null) return null;
    final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final today = _today;
    if (due == today.add(const Duration(days: 1))) return '明天';
    if (due == today.add(const Duration(days: 2))) return '后天';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(recommendationRepositoryProvider);
    return Scaffold(
      key: const Key('recommendation-page'),
      appBar: AppBar(
        title: const Text('推荐任务'),
        actions: [
          IconButton(
            tooltip: '刷新推荐任务',
            onPressed: () => unawaited(_requestRefresh()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: repository == null
          ? const _RecommendationFeedback(message: '推荐暂不可用，请稍后重试')
          : StreamBuilder<List<TodoRecommendation>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // 快照报错时 `data` 是 null；不分支出去就会把失败念成「暂无推荐任务」。
                  return const _RecommendationFeedback(
                    message: '读取推荐任务失败',
                    subtitle: '可点右上角刷新重试。',
                  );
                }
                final all = snapshot.data ?? const <TodoRecommendation>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  children: [
                    if (_refreshFailed)
                      _LiveRegionBanner(
                        message: '刷新推荐任务失败，已保留上次结果',
                        color: Theme.of(context).colorScheme.error,
                      ),
                    if (_addToTodayFailed)
                      _LiveRegionBanner(
                        message: '添加到今天失败，请重试',
                        color: Theme.of(context).colorScheme.error,
                      ),
                    if (all.isEmpty)
                      const _RecommendationFeedback(message: '暂无推荐任务'),
                    for (final group in _recommendationGroups)
                      ..._buildGroup(group, all),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _buildGroup(
    ({String code, String title}) group,
    List<TodoRecommendation> all,
  ) {
    final members = all
        .where((item) => item.reasonCode == group.code)
        .toList(growable: false);
    if (members.isEmpty) return const [];
    final header = '${group.title}（${members.length} 条）';
    if (group.code != _dueSoonCode) {
      return [
        _GroupHeader(
          key: ValueKey('recommendation-group-${group.code}'),
          label: header,
        ),
        for (final item in members) _buildRow(item),
      ];
    }
    final sections =
        <({String label, String keyName}), List<TodoRecommendation>>{};
    for (final bucket in _dueSoonBucketOrder) {
      final items = members
          .where((item) => _dueSoonBucketLabel(item.dueAt) == bucket.label)
          .toList(growable: false);
      if (items.isNotEmpty) sections[bucket] = items;
    }
    final unbucketed = members
        .where((item) => _dueSoonBucketLabel(item.dueAt) == null)
        .toList(growable: false);
    return [
      _GroupHeader(
        key: ValueKey('recommendation-group-${group.code}'),
        label: header,
      ),
      for (final entry in sections.entries)
        Column(
          key: ValueKey('recommendation-bucket-${entry.key.keyName}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
              child: Text(
                entry.key.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final item in entry.value) _buildRow(item),
          ],
        ),
      for (final item in unbucketed) _buildRow(item),
    ];
  }

  Widget _buildRow(TodoRecommendation item) {
    final adding = _addingTaskIds.contains(item.taskServerId);
    return ListTile(
      key: ValueKey('recommendation-item-${item.taskServerId}'),
      leading: const Icon(Icons.auto_awesome_outlined, size: 20),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.reason, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Semantics(
        container: true,
        button: true,
        label: '添加到今天',
        onTap: adding ? null : () => unawaited(_addToToday(item.taskServerId)),
        child: ExcludeSemantics(
          child: IconButton(
            key: ValueKey('recommendation-add-${item.taskServerId}'),
            tooltip: '添加到今天',
            onPressed: adding
                ? null
                : () => unawaited(_addToToday(item.taskServerId)),
            icon: adding
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
        ),
      ),
      onTap: () => widget.onTaskSelected(item.taskServerId),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LiveRegionBanner extends StatelessWidget {
  const _LiveRegionBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Semantics(
        label: message,
        liveRegion: true,
        excludeSemantics: true,
        child: Text(message, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class _RecommendationFeedback extends StatelessWidget {
  const _RecommendationFeedback({required this.message, this.subtitle});

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

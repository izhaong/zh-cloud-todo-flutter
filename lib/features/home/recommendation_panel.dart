import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../state/providers.dart';

/// 仅消费 Repository 的推荐读取模型；不在 Widget 中直连后端。
///
/// 没有成功缓存时不占用工作区布局，因此不会改变既有固定视觉旅程。
class RecommendationPanel extends ConsumerStatefulWidget {
  const RecommendationPanel({super.key, required this.onTaskSelected});

  final ValueChanged<int> onTaskSelected;

  @override
  ConsumerState<RecommendationPanel> createState() =>
      _RecommendationPanelState();
}

class _RecommendationPanelState extends ConsumerState<RecommendationPanel> {
  var _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await ref.read(recommendationRepositoryProvider)?.refresh();
      if (mounted && _refreshFailed) {
        setState(() => _refreshFailed = false);
      }
    } catch (_) {
      // 保留 Drift 中上一次成功响应；同步恢复后会再次刷新。
      if (mounted && !_refreshFailed) {
        setState(() => _refreshFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(recommendationRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    return StreamBuilder<List<TodoRecommendation>>(
      stream: repository.watchAll(),
      builder: (context, snapshot) {
        final recommendations = snapshot.data ?? const <TodoRecommendation>[];
        if (recommendations.isEmpty) return const SizedBox.shrink();
        final colors = Theme.of(context).extension<AppThemeExtension>()?.colors;
        final accent = colors?.accent ?? Theme.of(context).colorScheme.primary;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: '推荐任务',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '推荐任务',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新推荐任务',
                          onPressed: () => unawaited(_refresh()),
                          icon: const Icon(Icons.refresh, size: 18),
                        ),
                      ],
                    ),
                  ),
                  if (_refreshFailed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Semantics(
                        label: '刷新推荐任务失败，已保留上次结果',
                        liveRegion: true,
                        excludeSemantics: true,
                        child: Text(
                          '刷新推荐任务失败，已保留上次结果',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  for (final item in recommendations.take(3))
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => widget.onTaskSelected(item.taskServerId),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

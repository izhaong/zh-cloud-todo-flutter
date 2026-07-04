import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/efficiency_providers.dart';

/// M11-B4 番茄专注页：开始/暂停/完成/取消 走真后端
class PomodoroPage extends ConsumerWidget {
  const PomodoroPage({super.key, this.taskId});

  final int? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activePomodoroIdProvider);
    final stats = ref.watch(pomodoroStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('番茄专注')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ModeSelector(),
            const SizedBox(height: 32),
            if (activeId == null)
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始专注'),
                onPressed: () async {
                  final api = ref.read(pomodoroApiProvider);
                  final session =
                      await api.start(taskId: taskId, mode: 'MODE_25_5');
                  ref.read(activePomodoroIdProvider.notifier).state = session.id;
                  ref.invalidate(pomodoroStatsProvider);
                },
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                    onPressed: () async {
                      await ref.read(pomodoroApiProvider).complete(activeId);
                      ref.read(activePomodoroIdProvider.notifier).state = null;
                      ref.invalidate(pomodoroStatsProvider);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                    onPressed: () async {
                      await ref.read(pomodoroApiProvider).cancel(activeId);
                      ref.read(activePomodoroIdProvider.notifier).state = null;
                      ref.invalidate(pomodoroStatsProvider);
                    },
                  ),
                ],
              ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            Text('最近 7 天统计',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载失败: $e'),
              data: (s) => Text(
                '总会话: ${s['totalSessions'] ?? 0} · '
                '总分钟: ${s['totalMinutes'] ?? 0}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatefulWidget {
  const _ModeSelector();
  @override
  State<_ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends State<_ModeSelector> {
  String _mode = 'MODE_25_5';

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'MODE_25_5', label: Text('25+5')),
        ButtonSegment(value: 'MODE_50_10', label: Text('50+10')),
        ButtonSegment(value: 'MODE_FREE', label: Text('自由')),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }
}
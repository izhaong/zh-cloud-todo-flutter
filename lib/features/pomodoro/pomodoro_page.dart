import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../state/efficiency_providers.dart';

/// M11-B4 番茄专注页：真实计时 + `/pomodoro` 会话上报 + 暂停/恢复/完成/取消。
///
/// 计时器走本地 [Timer.periodic]（每秒递减 plannedSeconds），与后端会话状态解耦
/// ——后端负责持久化会话与统计，前端负责流畅计时显示与即时按键响应。
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key, this.taskId});

  /// 任务的后端整数 id（可选；关联到任务的专注记录）。
  final int? taskId;

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  Timer? _ticker;
  int _secondsLeft = 0;
  bool _paused = false;
  PomodoroSessionDto? _session;

  static const _modes = [
    ('MODE_25_5', '25+5', 25),
    ('MODE_50_10', '50+10', 50),
    ('MODE_FREE', '自由', 25),
  ];

  String _mode = 'MODE_25_5';

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _plannedMinutes {
    for (final m in _modes) {
      if (m.$1 == _mode) return m.$3;
    }
    return 25;
  }

  Future<void> _start() async {
    final api = ref.read(pomodoroApiProvider);
    final session = await api.start(
      taskId: widget.taskId,
      mode: _mode,
      plannedMinutes: _plannedMinutes,
    );
    ref.invalidate(pomodoroStatsProvider);
    setState(() {
      _session = session;
      _paused = false;
      _secondsLeft = (_plannedMinutes) * 60;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (!_paused && _secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  Future<void> _pause() async {
    final s = _session;
    if (s == null) return;
    await ref.read(pomodoroApiProvider).pause(s.id);
    setState(() => _paused = true);
  }

  Future<void> _resume() async {
    final s = _session;
    if (s == null) return;
    await ref.read(pomodoroApiProvider).resume(s.id);
    setState(() => _paused = false);
  }

  Future<void> _finish({required bool complete}) async {
    final s = _session;
    if (s == null) return;
    final api = ref.read(pomodoroApiProvider);
    if (complete) {
      await api.complete(s.id);
    } else {
      await api.cancel(s.id);
    }
    _ticker?.cancel();
    ref.invalidate(pomodoroStatsProvider);
    ref.read(activePomodoroIdProvider.notifier).state = null;
    setState(() {
      _session = null;
      _secondsLeft = 0;
      _paused = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(activePomodoroIdProvider);
    final stats = ref.watch(pomodoroStatsProvider);
    final running = activeId != null && _session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('番茄专注')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeSelector(
              mode: _mode,
              enabled: !running,
              onChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                _format(_secondsLeft),
                style: Theme.of(context).textTheme.displayLarge,
              ),
            ),
            if (_paused) ...[
              const SizedBox(height: 8),
              const Center(child: Text('已暂停')),
            ],
            const SizedBox(height: 32),
            if (!running)
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始专注'),
                onPressed: _start,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_paused)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('恢复'),
                      onPressed: _resume,
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause),
                      label: const Text('暂停'),
                      onPressed: _pause,
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                    onPressed: () => _finish(complete: true),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                    onPressed: () => _finish(complete: false),
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

  static String _format(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final String mode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'MODE_25_5', label: Text('25+5')),
        ButtonSegment(value: 'MODE_50_10', label: Text('50+10')),
        ButtonSegment(value: 'MODE_FREE', label: Text('自由')),
      ],
      selected: {mode},
      onSelectionChanged: enabled
          ? (s) => onChanged(s.first)
          : (_) {}, /* 运行中禁止切换模式 */
    );
  }
}

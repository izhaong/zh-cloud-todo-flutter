import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/efficiency_api.dart';
import '../../core/db/app_database.dart';
import '../../state/efficiency_providers.dart';
import '../../state/providers.dart';

/// 番茄专注页：服务端预设、任务关联、专注笔记与跨设备会话收敛。
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key, this.taskId});

  /// 从任务详情进入时传入任务的服务端整数 ID。
  final int? taskId;

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage> {
  static const _syncInterval = Duration(seconds: 15);

  final _minutesController = TextEditingController(text: '25');
  final _remarkController = TextEditingController();
  Timer? _ticker;
  Timer? _syncTicker;
  PomodoroSessionDto? _session;
  List<PomodoroPresetDto> _presets = const [];
  String? _mode;
  int? _selectedTaskId;
  int _secondsLeft = 0;
  int _syncRequest = 0;
  bool _paused = false;
  bool _loadingPresets = true;
  bool _actionPending = false;
  bool _syncInFlight = false;
  String? _presetError;
  String? _actionError;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.taskId;
    Future<void>.microtask(() async {
      await Future.wait([_loadPresets(), _syncActiveSession()]);
      if (!mounted) return;
      _syncTicker = Timer.periodic(_syncInterval, (_) => _syncActiveSession());
    });
  }

  @override
  void dispose() {
    _syncRequest++;
    _ticker?.cancel();
    _syncTicker?.cancel();
    _minutesController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  PomodoroPresetDto? get _selectedPreset {
    for (final preset in _presets) {
      if (preset.mode == _mode) return preset;
    }
    return null;
  }

  int? get _plannedMinutes {
    final fixed = _selectedPreset?.focusMinutes;
    if (fixed != null) return fixed;
    final parsed = int.tryParse(_minutesController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 1440) return null;
    return parsed;
  }

  bool get _canStart =>
      !_loadingPresets &&
      _presetError == null &&
      _selectedPreset != null &&
      _plannedMinutes != null &&
      !_actionPending;

  Future<void> _loadPresets() async {
    if (mounted) {
      setState(() {
        _loadingPresets = true;
        _presetError = null;
      });
    }
    try {
      final presets = await ref.read(pomodoroApiProvider).presets();
      if (presets.isEmpty) {
        throw StateError('服务端没有可用专注模式');
      }
      if (!mounted) return;
      setState(() {
        _presets = presets;
        if (!presets.any((preset) => preset.mode == _mode)) {
          _mode = presets.first.mode;
        }
        _loadingPresets = false;
        _secondsLeft = (_plannedMinutes ?? 0) * 60;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPresets = false;
        _presetError = '专注模式加载失败：$error';
      });
    }
  }

  Future<void> _start() async {
    final mode = _mode;
    final plannedMinutes = _plannedMinutes;
    if (mode == null || plannedMinutes == null || _actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
    });
    try {
      _syncRequest++;
      final session = await ref
          .read(pomodoroApiProvider)
          .start(
            taskId: _selectedTaskId,
            mode: mode,
            plannedMinutes: plannedMinutes,
          );
      if (!mounted) return;
      ref.invalidate(pomodoroStatsProvider);
      _activateSession(session, secondsLeft: plannedMinutes * 60);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '开始失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _syncActiveSession() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    final request = ++_syncRequest;
    try {
      final session = await ref.read(pomodoroApiProvider).active();
      if (!mounted || request != _syncRequest) return;
      if (session == null) {
        _clearSession(clearRemark: true);
      } else {
        _activateSession(session, secondsLeft: _remainingSeconds(session));
      }
      setState(() => _syncError = null);
    } catch (error) {
      if (!mounted || request != _syncRequest) return;
      setState(() => _syncError = '会话同步失败：$error');
    } finally {
      _syncInFlight = false;
    }
  }

  int _remainingSeconds(PomodoroSessionDto session) {
    final plannedSeconds = (session.plannedMinutes ?? 25) * 60;
    final startedAt = session.startedAt;
    if (startedAt == null) return plannedSeconds;
    final effectiveEnd = session.status == 'PAUSED' && session.pausedAt != null
        ? session.pausedAt!
        : DateTime.now();
    final elapsed =
        effectiveEnd.difference(startedAt).inSeconds - session.pausedSeconds;
    return (plannedSeconds - elapsed).clamp(0, plannedSeconds);
  }

  void _activateSession(
    PomodoroSessionDto session, {
    required int secondsLeft,
  }) {
    if (!mounted) return;
    ref.read(activePomodoroIdProvider.notifier).state = session.id;
    setState(() {
      _session = session;
      _mode = session.mode;
      _selectedTaskId = session.taskId ?? _selectedTaskId;
      _paused = session.status == 'PAUSED';
      _secondsLeft = secondsLeft;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  void _clearSession({required bool clearRemark}) {
    _ticker?.cancel();
    ref.read(activePomodoroIdProvider.notifier).state = null;
    if (!mounted) return;
    setState(() {
      _session = null;
      _secondsLeft = (_plannedMinutes ?? 0) * 60;
      _paused = false;
      if (clearRemark) _remarkController.clear();
    });
  }

  Future<void> _pause() async {
    final session = _session;
    if (session == null || _actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
    });
    try {
      _syncRequest++;
      await ref.read(pomodoroApiProvider).pause(session.id);
      if (!mounted) return;
      setState(() => _paused = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '暂停失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _resume() async {
    final session = _session;
    if (session == null || _actionPending) return;
    setState(() {
      _actionPending = true;
      _actionError = null;
    });
    try {
      _syncRequest++;
      await ref.read(pomodoroApiProvider).resume(session.id);
      if (!mounted) return;
      setState(() => _paused = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '恢复失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _finish({required bool complete}) async {
    final session = _session;
    if (session == null || _actionPending) return;
    final remark = _remarkController.text.trim();
    if (remark.length > 512) {
      setState(() => _actionError = '专注笔记不能超过 512 个字符');
      return;
    }
    setState(() {
      _actionPending = true;
      _actionError = null;
    });
    try {
      _syncRequest++;
      final api = ref.read(pomodoroApiProvider);
      if (complete) {
        await api.complete(
          session.id,
          remark: remark,
          clientEndAt: DateTime.now(),
        );
      } else {
        await api.cancel(session.id);
      }
      if (!mounted) return;
      ref.invalidate(pomodoroStatsProvider);
      _clearSession(clearRemark: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = complete ? '完成失败：$error' : '取消失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  void _selectMode(String mode) {
    setState(() {
      _mode = mode;
      _actionError = null;
      _secondsLeft = (_plannedMinutes ?? 0) * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _session != null;
    final tasks = ref
        .watch(allTasksStreamProvider)
        .maybeWhen(
          data: (items) => items
              .where(
                (task) =>
                    task.serverId != null && !task.completed && !task.cancelled,
              )
              .toList(growable: false),
          orElse: () => const <TodoTask>[],
        );
    final taskIds = tasks.map((task) => task.serverId!).toSet();
    final selectedTaskId = _selectedTaskId;
    final selectedTaskMissing =
        selectedTaskId != null && !taskIds.contains(selectedTaskId);
    final durationRequired = _selectedPreset?.focusMinutes == null;

    return Scaffold(
      appBar: AppBar(title: const Text('番茄专注')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_loadingPresets)
              const Center(child: CircularProgressIndicator())
            else if (_presetError != null) ...[
              Text(_presetError!, key: const Key('pomodoro-preset-error')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadPresets,
                child: const Text('重试加载模式'),
              ),
            ] else
              _ModeSelector(
                presets: _presets,
                mode: _mode,
                enabled: !running && !_actionPending,
                onChanged: _selectMode,
              ),
            if (durationRequired) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('pomodoro-custom-minutes'),
                controller: _minutesController,
                enabled: !running,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _mode == 'FREE' ? '正计时目标分钟数' : '专注分钟数',
                  helperText: '请输入 1–1440 的整数',
                  errorText:
                      _minutesController.text.isNotEmpty &&
                          _plannedMinutes == null
                      ? '分钟数必须在 1–1440 之间'
                      : null,
                ),
                onChanged: (_) => setState(() {
                  _secondsLeft = (_plannedMinutes ?? 0) * 60;
                }),
              ),
            ],
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(labelText: '关联任务（可选）'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const Key('pomodoro-task'),
                  value:
                      selectedTaskId != null &&
                          (taskIds.contains(selectedTaskId) ||
                              selectedTaskMissing)
                      ? selectedTaskId
                      : null,
                  isExpanded: true,
                  hint: const Text('不关联任务'),
                  items: [
                    if (selectedTaskMissing)
                      DropdownMenuItem(
                        value: selectedTaskId,
                        child: Text('当前任务 #$selectedTaskId'),
                      ),
                    for (final task in tasks)
                      DropdownMenuItem(
                        value: task.serverId,
                        child: Text(
                          task.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: running || _actionPending
                      ? null
                      : (value) => setState(() => _selectedTaskId = value),
                ),
              ),
            ),
            if (_selectedTaskId != null && !running)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _selectedTaskId = null),
                  child: const Text('清除关联'),
                ),
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
            if (_syncError != null) ...[
              const SizedBox(height: 12),
              Text(
                _syncError!,
                key: const Key('pomodoro-sync-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              Text(
                _actionError!,
                key: const Key('pomodoro-action-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (running) ...[
              const SizedBox(height: 24),
              TextField(
                key: const Key('pomodoro-remark'),
                controller: _remarkController,
                enabled: !_actionPending,
                minLines: 2,
                maxLines: 4,
                maxLength: 512,
                decoration: const InputDecoration(
                  labelText: '专注笔记',
                  hintText: '记录本次专注的进展',
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!running)
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始专注'),
                onPressed: _canStart ? _start : null,
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_paused)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('恢复'),
                      onPressed: _actionPending ? null : _resume,
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause),
                      label: const Text('暂停'),
                      onPressed: _actionPending ? null : _pause,
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('完成'),
                    onPressed: _actionPending
                        ? null
                        : () => _finish(complete: true),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('取消'),
                    onPressed: _actionPending
                        ? null
                        : () => _finish(complete: false),
                  ),
                ],
              ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            Text('最近 7 天统计', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ref
                .watch(pomodoroStatsProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('加载失败: $error'),
                  data: (stats) => Text(
                    '总会话: ${stats['totalSessions'] ?? 0} · '
                    '总分钟: ${stats['totalMinutes'] ?? 0}',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _format(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.presets,
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final List<PomodoroPresetDto> presets;
  final String? mode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in presets)
          ChoiceChip(
            label: Text(preset.label),
            selected: preset.mode == mode,
            onSelected: enabled ? (_) => onChanged(preset.mode) : null,
          ),
      ],
    );
  }
}

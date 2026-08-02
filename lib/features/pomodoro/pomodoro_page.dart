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
  PomodoroStatsDto? _stats;
  List<PomodoroTimelineDto>? _timeline;
  List<PomodoroPresetDto> _presets = const [];
  List<PomodoroSessionDto> _records = const [];
  String? _mode;
  String _statsPeriod = 'week';
  String? _statsDataPeriod;
  late DateTime _timelineDate;
  DateTime? _timelineDataDate;
  int? _selectedTaskId;
  int _secondsLeft = 0;
  int _syncRequest = 0;
  int _recordsRequest = 0;
  int _statsRequest = 0;
  int _timelineRequest = 0;
  bool _paused = false;
  bool _loadingPresets = true;
  bool _actionPending = false;
  bool _syncInFlight = false;
  bool _loadingRecords = true;
  bool _loadingStats = true;
  bool _loadingTimeline = true;
  bool _recordActionPending = false;
  String? _presetError;
  String? _actionError;
  String? _syncError;
  String? _recordsError;
  String? _statsError;
  String? _timelineError;
  String? _recordActionError;

  @override
  void initState() {
    super.initState();
    _timelineDate = DateUtils.dateOnly(DateTime.now());
    _selectedTaskId = widget.taskId;
    Future<void>.microtask(() {
      unawaited(_loadPresets());
      unawaited(_syncActiveSession());
      unawaited(_loadRecords());
      unawaited(_loadStats());
      unawaited(_loadTimeline());
      if (!mounted) return;
      _syncTicker = Timer.periodic(_syncInterval, (_) => _syncActiveSession());
    });
  }

  @override
  void dispose() {
    _syncRequest++;
    _recordsRequest++;
    _statsRequest++;
    _timelineRequest++;
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
      _activateSession(session, secondsLeft: plannedMinutes * 60);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '开始失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _syncActiveSession() async {
    if (_syncInFlight || _actionPending) return;
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

  Future<void> _loadRecords() async {
    final request = ++_recordsRequest;
    if (mounted) {
      setState(() {
        _loadingRecords = true;
        _recordsError = null;
      });
    }
    try {
      final records = await ref.read(pomodoroApiProvider).page(pageSize: 20);
      if (!mounted || request != _recordsRequest) return;
      setState(() {
        _records = records;
        _loadingRecords = false;
      });
    } catch (error) {
      if (!mounted || request != _recordsRequest) return;
      setState(() {
        _loadingRecords = false;
        _recordsError = '记录加载失败：$error';
      });
    }
  }

  Future<void> _refreshRecordsAndStats() async {
    unawaited(_loadStats());
    unawaited(_loadTimeline());
    await _loadRecords();
  }

  Future<void> _loadStats() async {
    final request = ++_statsRequest;
    final period = _statsPeriod;
    if (mounted) {
      setState(() {
        _loadingStats = true;
        _statsError = null;
      });
    }
    try {
      final stats = await ref.read(pomodoroApiProvider).stats(period: period);
      if (!mounted || request != _statsRequest) return;
      setState(() {
        _stats = stats;
        _statsDataPeriod = period;
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted || request != _statsRequest) return;
      setState(() {
        _loadingStats = false;
        _statsError = '统计加载失败，请检查网络后重试';
      });
    }
  }

  void _selectStatsPeriod(Set<String> selection) {
    final period = selection.firstOrNull;
    if (period == null || period == _statsPeriod) return;
    setState(() => _statsPeriod = period);
    _loadStats();
  }

  Future<void> _loadTimeline() async {
    final request = ++_timelineRequest;
    final date = _timelineDate;
    if (mounted) {
      setState(() {
        _loadingTimeline = true;
        _timelineError = null;
      });
    }
    try {
      final timeline = await ref.read(pomodoroApiProvider).timeline(date: date);
      if (!mounted || request != _timelineRequest) return;
      setState(() {
        _timeline = timeline;
        _timelineDataDate = date;
        _loadingTimeline = false;
      });
    } catch (_) {
      if (!mounted || request != _timelineRequest) return;
      setState(() {
        _loadingTimeline = false;
        _timelineError = '时间轴加载失败，请检查网络后重试';
      });
    }
  }

  void _selectTimelineDate(DateTime value) {
    final date = DateUtils.dateOnly(value);
    if (DateUtils.isSameDay(date, _timelineDate) ||
        date.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return;
    }
    setState(() => _timelineDate = date);
    _loadTimeline();
  }

  Future<void> _pickTimelineDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _timelineDate,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: '选择专注时间轴日期',
    );
    if (!mounted || selected == null) return;
    _selectTimelineDate(selected);
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

  Future<void> _adjustDuration(int deltaMinutes) async {
    final session = _session;
    if (session == null || _actionPending) return;
    final previousPlanned = session.plannedMinutes ?? 25;
    setState(() {
      _actionPending = true;
      _actionError = null;
    });
    try {
      _syncRequest++;
      final adjusted = await ref
          .read(pomodoroApiProvider)
          .adjust(session.id, deltaMinutes: deltaMinutes);
      if (!mounted) return;
      final remaining = _secondsLeft + (adjusted - previousPlanned) * 60;
      setState(() {
        _session = session.copyWith(plannedMinutes: adjusted);
        _secondsLeft = remaining.clamp(0, adjusted * 60);
      });
      await _refreshRecordsAndStats();
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = '调整失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
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
      await _refreshRecordsAndStats();
      if (!mounted) return;
      _clearSession(clearRemark: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionError = complete ? '完成失败：$error' : '取消失败：$error');
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _showBackfillDialog(List<TodoTask> tasks) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _BackfillDialog(
        tasks: tasks,
        presets: _presets,
        onSubmit:
            ({
              int? taskId,
              required String mode,
              required int actualMinutes,
              required DateTime startedAt,
              required DateTime endedAt,
              String? remark,
            }) {
              return ref
                  .read(pomodoroApiProvider)
                  .backfill(
                    taskId: taskId,
                    mode: mode,
                    actualMinutes: actualMinutes,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    remark: remark,
                  );
            },
      ),
    );
    if (created == true && mounted) await _refreshRecordsAndStats();
  }

  Future<void> _editDuration(PomodoroSessionDto record) async {
    final actualMinutes = await showDialog<int>(
      context: context,
      builder: (context) =>
          _DurationDialog(initialMinutes: record.actualMinutes ?? 0),
    );
    if (actualMinutes == null || !mounted) return;
    await _updateDuration(record, actualMinutes);
  }

  Future<void> _updateDuration(
    PomodoroSessionDto record,
    int actualMinutes,
  ) async {
    if (_recordActionPending) return;
    setState(() {
      _recordActionPending = true;
      _recordActionError = null;
    });
    try {
      await ref
          .read(pomodoroApiProvider)
          .updateDuration(record.id, actualMinutes: actualMinutes);
      if (!mounted) return;
      await _refreshRecordsAndStats();
    } catch (error) {
      if (!mounted) return;
      setState(() => _recordActionError = '更新失败：$error');
    } finally {
      if (mounted) setState(() => _recordActionPending = false);
    }
  }

  Future<void> _deleteRecord(PomodoroSessionDto record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除专注记录？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _recordActionPending) return;
    setState(() {
      _recordActionPending = true;
      _recordActionError = null;
    });
    try {
      await ref.read(pomodoroApiProvider).deleteRecord(record.id);
      if (!mounted) return;
      await _refreshRecordsAndStats();
    } catch (error) {
      if (!mounted) return;
      setState(() => _recordActionError = '删除失败：$error');
    } finally {
      if (mounted) setState(() => _recordActionPending = false);
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
    final taskTitles = <int, String>{
      for (final task in tasks) task.serverId!: task.title,
    };
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
            if (running) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    key: const Key('pomodoro-adjust-minus'),
                    tooltip: '减少 5 分钟',
                    onPressed: _actionPending
                        ? null
                        : () => _adjustDuration(-5),
                    icon: const Icon(Icons.remove),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('调整专注时间'),
                  ),
                  IconButton.outlined(
                    key: const Key('pomodoro-adjust-plus'),
                    tooltip: '增加 5 分钟',
                    onPressed: _actionPending ? null : () => _adjustDuration(5),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
            if (_paused) ...[
              const SizedBox(height: 8),
              const Center(child: Text('已暂停')),
            ],
            if (running) ...[
              const SizedBox(height: 16),
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
              ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '专注记录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _recordActionPending
                      ? null
                      : () => _showBackfillDialog(tasks),
                  icon: const Icon(Icons.add),
                  label: const Text('新增记录'),
                ),
              ],
            ),
            if (_loadingRecords && _records.isEmpty) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ] else if (_records.isEmpty && _recordsError == null) ...[
              const SizedBox(height: 16),
              const Text('暂无专注记录'),
            ] else ...[
              const SizedBox(height: 8),
              for (final record in _records)
                _PomodoroRecordCard(
                  record: record,
                  taskTitle: taskTitles[record.taskId],
                  enabled: !_recordActionPending,
                  onEdit: () => _editDuration(record),
                  onAddFive: () {
                    final current = record.actualMinutes ?? 0;
                    if (current + 5 > 1440) {
                      setState(() => _recordActionError = '专注时长不能超过 1440 分钟');
                      return;
                    }
                    _updateDuration(record, current + 5);
                  },
                  onDelete: () => _deleteRecord(record),
                ),
            ],
            if (_recordActionError != null) ...[
              const SizedBox(height: 8),
              Text(
                _recordActionError!,
                key: const Key('pomodoro-record-action-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_recordsError != null) ...[
              const SizedBox(height: 8),
              Text(
                _recordsError!,
                key: const Key('pomodoro-records-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _loadingRecords ? null : _loadRecords,
                  child: const Text('重试加载记录'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _PomodoroStatsSection(
              key: const Key('pomodoro-stats-section'),
              period: _statsPeriod,
              dataPeriod: _statsDataPeriod,
              stats: _stats,
              loading: _loadingStats,
              error: _statsError,
              onPeriodChanged: _selectStatsPeriod,
              onRetry: _loadStats,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _PomodoroTimelineSection(
              key: const Key('pomodoro-timeline-section'),
              date: _timelineDate,
              dataDate: _timelineDataDate,
              items: _timeline,
              loading: _loadingTimeline,
              error: _timelineError,
              onPrevious: () => _selectTimelineDate(
                _timelineDate.subtract(const Duration(days: 1)),
              ),
              onNext:
                  DateUtils.isSameDay(
                    _timelineDate,
                    DateUtils.dateOnly(DateTime.now()),
                  )
                  ? null
                  : () => _selectTimelineDate(
                      _timelineDate.add(const Duration(days: 1)),
                    ),
              onPickDate: _pickTimelineDate,
              onToday: () => _selectTimelineDate(DateTime.now()),
              onRetry: _loadTimeline,
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

class _PomodoroStatsSection extends StatelessWidget {
  const _PomodoroStatsSection({
    super.key,
    required this.period,
    required this.dataPeriod,
    required this.stats,
    required this.loading,
    required this.error,
    required this.onPeriodChanged,
    required this.onRetry,
  });

  final String period;
  final String? dataPeriod;
  final PomodoroStatsDto? stats;
  final bool loading;
  final String? error;
  final ValueChanged<Set<String>> onPeriodChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '专注统计',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (loading && data != null)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            key: const Key('pomodoro-stats-period'),
            segments: const [
              ButtonSegment(value: 'day', label: Text('今天')),
              ButtonSegment(value: 'week', label: Text('7 天')),
              ButtonSegment(value: 'month', label: Text('30 天')),
              ButtonSegment(value: 'year', label: Text('12 个月')),
            ],
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: onPeriodChanged,
          ),
        ),
        if (data != null && dataPeriod != null && dataPeriod != period) ...[
          const SizedBox(height: 8),
          Text(
            loading
                ? '正在加载 ${_periodLabel(period)}，暂显示 ${_periodLabel(dataPeriod!)}结果'
                : '暂未更新到${_periodLabel(period)}，暂显示 ${_periodLabel(dataPeriod!)}结果',
            key: const Key('pomodoro-stats-data-period-note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const Key('pomodoro-stats-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loading ? null : onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试加载统计'),
          ),
        ],
        if (data == null) ...[
          const SizedBox(height: 24),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error == null)
            const Text('当前周期暂无统计数据'),
        ] else ...[
          const SizedBox(height: 16),
          _StatsMetrics(stats: data, period: dataPeriod ?? period),
          const SizedBox(height: 24),
          Text('专注节奏', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            dataPeriod == 'year' ? '按月查看实际专注分钟' : '按天查看实际专注分钟',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _FocusTrendChart(items: data.minutesTrend),
          if (dataPeriod != 'year') ...[
            const SizedBox(height: 24),
            Text('专注日历', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('颜色越深，专注时间越长', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            _FocusCalendar(items: data.minutesTrend),
          ],
          const SizedBox(height: 24),
          Text('任务分布', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('查看专注时间投入在哪些任务', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          _TaskDistribution(items: data.taskDistribution),
        ],
      ],
    );
  }

  static String _periodLabel(String period) {
    return switch (period) {
      'day' => '今天',
      'month' => '30 天',
      'year' => '12 个月',
      _ => '7 天',
    };
  }
}

class _StatsMetrics extends StatelessWidget {
  const _StatsMetrics({required this.stats, required this.period});

  final PomodoroStatsDto stats;
  final String period;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageMinutesPerDay;
    final averageLabel = average == average.roundToDouble()
        ? average.toStringAsFixed(0)
        : average.toStringAsFixed(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: width,
              child: _StatsMetric(
                key: const Key('pomodoro-stats-total-sessions'),
                label: '完成会话',
                value: '${stats.totalSessions}',
                unit: '次',
              ),
            ),
            SizedBox(
              width: width,
              child: _StatsMetric(
                key: const Key('pomodoro-stats-total-minutes'),
                label: '专注分钟',
                value: '${stats.totalMinutes}',
                unit: '分钟',
              ),
            ),
            SizedBox(
              width: width,
              child: _StatsMetric(
                key: const Key('pomodoro-stats-average-minutes'),
                label: period == 'year' ? '月均专注' : '日均专注',
                value: averageLabel,
                unit: '分钟',
              ),
            ),
            SizedBox(
              width: width,
              child: _StatsMetric(
                key: const Key('pomodoro-stats-best-hour'),
                label: '高效时段',
                value: stats.bestHour ?? '暂无',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsMetric extends StatelessWidget {
  const _StatsMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit!, style: Theme.of(context).textTheme.labelSmall),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusTrendChart extends StatelessWidget {
  const _FocusTrendChart({required this.items});

  final List<PomodoroDailyStatsDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('当前周期暂无专注趋势');
    final maxMinutes = items.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in items)
              Semantics(
                label: '${item.date} 专注 ${item.count} 分钟',
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 34,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${item.count}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 18,
                          height: maxMinutes == 0
                              ? 4
                              : 8 + 66 * item.count / maxMinutes,
                          decoration: BoxDecoration(
                            color: item.count == 0
                                ? colors.surfaceContainerHighest
                                : colors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _trendLabel(item.date),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _trendLabel(String value) {
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) {
      return '${value.substring(2, 4)}/${value.substring(5, 7)}';
    }
    return value.length >= 5 ? value.substring(value.length - 5) : value;
  }
}

class _TaskDistribution extends StatelessWidget {
  const _TaskDistribution({required this.items});

  final List<PomodoroTaskDistributionDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('当前周期暂无任务分布');
    final totalMinutes = items.fold<int>(0, (sum, item) => sum + item.minutes);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              key: ValueKey(
                'pomodoro-task-distribution-semantics-${item.taskId ?? 'uncategorized'}',
              ),
              container: true,
              label:
                  '${item.taskTitle}，专注 ${item.minutes} 分钟，${item.sessions} 次会话',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.taskTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${item.minutes} 分钟 · ${item.sessions} 次'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        key: ValueKey(
                          'pomodoro-task-distribution-${item.taskId ?? 'uncategorized'}',
                        ),
                        value: totalMinutes == 0
                            ? 0
                            : item.minutes / totalMinutes,
                        minHeight: 8,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FocusCalendar extends StatelessWidget {
  const _FocusCalendar({required this.items});

  final List<PomodoroDailyStatsDto> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('当前周期暂无专注日历');
    final maxMinutes = items.fold<int>(
      0,
      (max, item) => item.count > max ? item.count : max,
    );
    final colors = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final item in items)
          Semantics(
            label: '${item.date} 专注日历 ${item.count} 分钟',
            child: ExcludeSemantics(
              child: Tooltip(
                message: '${item.date} · ${item.count} 分钟',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      colors.surfaceContainerHighest,
                      colors.primary,
                      maxMinutes == 0 ? 0 : item.count / maxMinutes,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PomodoroTimelineSection extends StatelessWidget {
  const _PomodoroTimelineSection({
    super.key,
    required this.date,
    required this.dataDate,
    required this.items,
    required this.loading,
    required this.error,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onToday,
    required this.onRetry,
  });

  final DateTime date;
  final DateTime? dataDate;
  final List<PomodoroTimelineDto>? items;
  final bool loading;
  final String? error;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;
  final VoidCallback onToday;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final data = items;
    final sourceDate = dataDate;
    final showingAnotherDate =
        data != null &&
        sourceDate != null &&
        !DateUtils.isSameDay(sourceDate, date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '每日专注时间轴',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (loading && data != null)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.outlined(
              key: const Key('pomodoro-timeline-previous'),
              tooltip: '前一天',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('pomodoro-timeline-date'),
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  _dateLabel(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              key: const Key('pomodoro-timeline-next'),
              tooltip: '后一天',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!DateUtils.isSameDay(date, DateUtils.dateOnly(DateTime.now())))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onToday, child: const Text('回到今天')),
          ),
        if (showingAnotherDate) ...[
          const SizedBox(height: 8),
          Text(
            loading
                ? '正在加载 ${_dateLabel(date)}，暂显示 ${_dateLabel(sourceDate)}记录'
                : '暂未更新到 ${_dateLabel(date)}，暂显示 ${_dateLabel(sourceDate)}记录',
            key: const Key('pomodoro-timeline-data-date-note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            key: const Key('pomodoro-timeline-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loading ? null : onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试加载时间轴'),
          ),
        ],
        if (data == null) ...[
          const SizedBox(height: 24),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error == null)
            const Text('当天暂无专注记录'),
        ] else if (data.isEmpty) ...[
          const SizedBox(height: 16),
          const Text('当天暂无专注记录'),
        ] else ...[
          const SizedBox(height: 12),
          for (final item in data) _PomodoroTimelineCard(item: item),
        ],
      ],
    );
  }

  static String _dateLabel(DateTime value) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(value);
    final suffix = DateUtils.isSameDay(day, today)
        ? ' · 今天'
        : DateUtils.isSameDay(day, today.subtract(const Duration(days: 1)))
        ? ' · 昨天'
        : '';
    return '${value.month}月${value.day}日$suffix';
  }
}

class _PomodoroTimelineCard extends StatelessWidget {
  const _PomodoroTimelineCard({required this.item});

  final PomodoroTimelineDto item;

  @override
  Widget build(BuildContext context) {
    final range = _clockRange(item.startedAt, item.endedAt);
    final semanticsRange = range ?? '时间未知';
    return Semantics(
      container: true,
      label:
          '$semanticsRange，${item.taskTitle}，专注 ${item.actualMinutes} 分钟，${_pomodoroModeLabel(item.mode)}',
      child: ExcludeSemantics(
        child: Card(
          key: ValueKey('pomodoro-timeline-${item.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.actualMinutes} 分钟'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    ?_clockRange(item.startedAt, item.endedAt),
                    _pomodoroModeLabel(item.mode),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.remark?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(item.remark!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _clockRange(DateTime? start, DateTime? end) {
    if (start == null) return null;
    String two(int value) => value.toString().padLeft(2, '0');
    final startLabel = '${two(start.hour)}:${two(start.minute)}';
    if (end == null) return startLabel;
    return '$startLabel–${two(end.hour)}:${two(end.minute)}';
  }
}

String _pomodoroModeLabel(String mode) => switch (mode) {
  'MODE_25_5' => '经典 25/5',
  'MODE_50_10' => '长专注 50/10',
  'FREE' => '自由专注',
  'CUSTOM' => '自定义专注',
  _ => mode,
};

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

class _PomodoroRecordCard extends StatelessWidget {
  const _PomodoroRecordCard({
    required this.record,
    required this.taskTitle,
    required this.enabled,
    required this.onEdit,
    required this.onAddFive,
    required this.onDelete,
  });

  final PomodoroSessionDto record;
  final String? taskTitle;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onAddFive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = record.status == 'COMPLETED';
    final timeRange = _timeRange(record.startedAt, record.endedAt);
    final detail = <String>[
      _modeLabel(record.mode),
      '${record.actualMinutes ?? 0} 分钟',
      ?timeRange,
    ].join(' · ');
    return Card(
      key: ValueKey('pomodoro-record-${record.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail, style: Theme.of(context).textTheme.titleSmall),
            if (taskTitle != null || record.taskId != null) ...[
              const SizedBox(height: 4),
              Text('关联任务：${taskTitle ?? '#${record.taskId}'}'),
            ],
            if (record.remark?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(record.remark!),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: Key('pomodoro-record-edit-${record.id}'),
                    onPressed: enabled ? onEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑时长'),
                  ),
                  TextButton.icon(
                    key: Key('pomodoro-record-add-${record.id}'),
                    onPressed: enabled ? onAddFive : null,
                    icon: const Icon(Icons.add),
                    label: const Text('追加 5 分钟'),
                  ),
                  TextButton.icon(
                    key: Key('pomodoro-record-delete-${record.id}'),
                    onPressed: enabled ? onDelete : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _modeLabel(String mode) => switch (mode) {
    'MODE_25_5' => '经典 25/5',
    'MODE_50_10' => '长专注 50/10',
    'FREE' => '自由专注',
    'CUSTOM' => '自定义专注',
    _ => mode,
  };

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.month}月${value.day}日 '
        '${two(value.hour)}:${two(value.minute)}';
  }

  static String? _timeRange(DateTime? startedAt, DateTime? endedAt) {
    if (startedAt == null) return null;
    final start = _formatDateTime(startedAt);
    if (endedAt == null) return start;
    final end = _formatDateTime(endedAt);
    return '$start – $end';
  }
}

typedef _BackfillSubmit =
    Future<int> Function({
      int? taskId,
      required String mode,
      required int actualMinutes,
      required DateTime startedAt,
      required DateTime endedAt,
      String? remark,
    });

class _BackfillDialog extends StatefulWidget {
  const _BackfillDialog({
    required this.tasks,
    required this.presets,
    required this.onSubmit,
  });

  final List<TodoTask> tasks;
  final List<PomodoroPresetDto> presets;
  final _BackfillSubmit onSubmit;

  @override
  State<_BackfillDialog> createState() => _BackfillDialogState();
}

class _BackfillDialogState extends State<_BackfillDialog> {
  final _minutesController = TextEditingController(text: '25');
  final _remarkController = TextEditingController();
  late DateTime _startedAt;
  late DateTime _endedAt;
  late String _mode;
  int? _taskId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _endedAt = DateTime.now();
    _startedAt = _endedAt.subtract(const Duration(minutes: 25));
    _mode = widget.presets.isEmpty ? 'CUSTOM' : widget.presets.first.mode;
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  int? get _actualMinutes {
    final value = int.tryParse(_minutesController.text.trim());
    if (value == null || value < 0 || value > 1440) return null;
    return value;
  }

  Future<void> _pickDateTime({required bool started}) async {
    final current = started ? _startedAt : _endedAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (started) {
        _startedAt = selected;
      } else {
        _endedAt = selected;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    final actualMinutes = _actualMinutes;
    final remark = _remarkController.text.trim();
    if (actualMinutes == null) {
      setState(() => _error = '分钟数必须在 0–1440 之间');
      return;
    }
    if (_endedAt.isBefore(_startedAt)) {
      setState(() => _error = '结束时间不能早于开始时间');
      return;
    }
    if (remark.length > 512) {
      setState(() => _error = '备注不能超过 512 个字符');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        taskId: _taskId,
        mode: _mode,
        actualMinutes: actualMinutes,
        startedAt: _startedAt,
        endedAt: _endedAt,
        remark: remark,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增专注记录'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: '专注模式'),
                items: [
                  if (widget.presets.isEmpty)
                    const DropdownMenuItem(value: 'CUSTOM', child: Text('自定义'))
                  else
                    for (final preset in widget.presets)
                      DropdownMenuItem(
                        value: preset.mode,
                        child: Text(preset.label),
                      ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _mode = value ?? _mode),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pomodoro-backfill-minutes'),
                controller: _minutesController,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '实际分钟',
                  helperText: '0–1440',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _taskId,
                decoration: const InputDecoration(labelText: '关联任务（可选）'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('不关联任务'),
                  ),
                  for (final task in widget.tasks)
                    DropdownMenuItem<int?>(
                      value: task.serverId,
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _taskId = value),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('pomodoro-backfill-started-at'),
                onPressed: _submitting
                    ? null
                    : () => _pickDateTime(started: true),
                icon: const Icon(Icons.schedule),
                label: Text('开始：${_formatDateTime(_startedAt)}'),
              ),
              OutlinedButton.icon(
                key: const Key('pomodoro-backfill-ended-at'),
                onPressed: _submitting
                    ? null
                    : () => _pickDateTime(started: false),
                icon: const Icon(Icons.schedule),
                label: Text('结束：${_formatDateTime(_endedAt)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pomodoro-backfill-remark'),
                controller: _remarkController,
                enabled: !_submitting,
                minLines: 2,
                maxLines: 4,
                maxLength: 512,
                decoration: const InputDecoration(labelText: '备注（可选）'),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('pomodoro-backfill-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('保存记录'),
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialMinutes}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > 1440) {
      setState(() => _error = '分钟数必须在 0–1440 之间');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑实际时长'),
      content: TextField(
        key: const Key('pomodoro-record-duration'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: '实际分钟',
          helperText: '0–1440',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

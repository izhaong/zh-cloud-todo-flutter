import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/efficiency_api.dart';

class PomodoroTimerDraft {
  const PomodoroTimerDraft({
    required this.name,
    required this.mode,
    required this.focusMinutes,
    required this.taskId,
    required this.habitId,
    required this.sortOrder,
  });

  final String name;
  final String mode;
  final int? focusMinutes;
  final int? taskId;
  final int? habitId;
  final int sortOrder;

  factory PomodoroTimerDraft.fromTimer(PomodoroTimerDto timer) {
    return PomodoroTimerDraft(
      name: timer.name,
      mode: timer.mode,
      focusMinutes: timer.focusMinutes,
      taskId: timer.taskId,
      habitId: timer.habitId,
      sortOrder: timer.sortOrder,
    );
  }
}

Future<PomodoroTimerDraft?> showPomodoroTimerEditor({
  required BuildContext context,
  required Map<int, String> taskTitles,
  required Map<int, String> habitTitles,
  PomodoroTimerDto? initial,
}) {
  return showDialog<PomodoroTimerDraft>(
    context: context,
    builder: (context) => _PomodoroTimerEditorDialog(
      initial: initial,
      taskTitles: taskTitles,
      habitTitles: habitTitles,
    ),
  );
}

class _PomodoroTimerEditorDialog extends StatefulWidget {
  const _PomodoroTimerEditorDialog({
    required this.taskTitles,
    required this.habitTitles,
    this.initial,
  });

  final PomodoroTimerDto? initial;
  final Map<int, String> taskTitles;
  final Map<int, String> habitTitles;

  @override
  State<_PomodoroTimerEditorDialog> createState() =>
      _PomodoroTimerEditorDialogState();
}

class _PomodoroTimerEditorDialogState
    extends State<_PomodoroTimerEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _minutesController;
  late final TextEditingController _sortController;
  late String _mode;
  String _association = 'none';
  String? _nameError;
  String? _minutesError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _mode = initial?.mode ?? 'FREE';
    _minutesController = TextEditingController(
      text: initial?.focusMinutes?.toString() ?? '25',
    );
    _sortController = TextEditingController(
      text: (initial?.sortOrder ?? 0).toString(),
    );
    if (initial?.taskId != null) {
      _association = 'task:${initial!.taskId}';
    } else if (initial?.habitId != null) {
      _association = 'habit:${initial!.habitId}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  int? get _focusMinutes => switch (_mode) {
    'FREE' => null,
    'MODE_25_5' => 25,
    'MODE_50_10' => 50,
    _ => int.tryParse(_minutesController.text.trim()),
  };

  void _save() {
    final name = _nameController.text.trim();
    final minutes = _focusMinutes;
    final invalidName = name.isEmpty || name.length > 64;
    final invalidMinutes =
        _mode != 'FREE' && (minutes == null || minutes < 1 || minutes > 1440);
    if (invalidName || invalidMinutes) {
      setState(() {
        _nameError = invalidName ? '名称需为 1–64 个字符' : null;
        _minutesError = invalidMinutes ? '分钟数必须在 1–1440 之间' : null;
      });
      return;
    }
    final association = _association.split(':');
    final associationId = association.length != 2
        ? null
        : int.tryParse(association[1]);
    Navigator.of(context).pop(
      PomodoroTimerDraft(
        name: name,
        mode: _mode,
        focusMinutes: minutes,
        taskId: association.first == 'task' ? associationId : null,
        habitId: association.first == 'habit' ? associationId : null,
        sortOrder: int.tryParse(_sortController.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增常用专注' : '编辑常用专注'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('pomodoro-timer-name'),
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '名称',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('pomodoro-timer-mode'),
              initialValue: _mode,
              decoration: const InputDecoration(labelText: '计时方式'),
              items: const [
                DropdownMenuItem(value: 'FREE', child: Text('正计时')),
                DropdownMenuItem(value: 'MODE_25_5', child: Text('经典 25/5')),
                DropdownMenuItem(value: 'MODE_50_10', child: Text('长专注 50/10')),
                DropdownMenuItem(value: 'CUSTOM', child: Text('自定义番茄')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _mode = value;
                  _minutesError = null;
                });
              },
            ),
            if (_mode == 'CUSTOM') ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('pomodoro-timer-minutes'),
                controller: _minutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '专注分钟数',
                  helperText: '1–1440 分钟',
                  errorText: _minutesError,
                ),
                onChanged: (_) {
                  if (_minutesError != null) {
                    setState(() => _minutesError = null);
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('pomodoro-timer-association'),
              initialValue: _association,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '关联任务或习惯（可选）'),
              items: [
                const DropdownMenuItem<String>(
                  value: 'none',
                  child: Text('无关联'),
                ),
                for (final entry in widget.taskTitles.entries)
                  DropdownMenuItem(
                    value: 'task:${entry.key}',
                    child: Text('任务：${entry.value}'),
                  ),
                for (final entry in widget.habitTitles.entries)
                  DropdownMenuItem(
                    value: 'habit:${entry.key}',
                    child: Text('习惯：${entry.value}'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _association = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('pomodoro-timer-sort'),
              controller: _sortController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
              ],
              decoration: const InputDecoration(labelText: '排序值'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存计时器')),
      ],
    );
  }
}

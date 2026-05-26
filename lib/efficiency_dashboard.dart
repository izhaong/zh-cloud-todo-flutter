import 'package:flutter/material.dart';

class EfficiencyQuadrantItem {
  const EfficiencyQuadrantItem({
    required this.title,
    required this.quadrant,
    required this.done,
  });

  final String title;
  final String quadrant;
  final bool done;

  EfficiencyQuadrantItem copyWith({
    String? title,
    String? quadrant,
    bool? done,
  }) {
    return EfficiencyQuadrantItem(
      title: title ?? this.title,
      quadrant: quadrant ?? this.quadrant,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'quadrant': quadrant,
    'done': done,
  };

  factory EfficiencyQuadrantItem.fromJson(Map<String, dynamic> json) {
    return EfficiencyQuadrantItem(
      title: json['title'] as String? ?? '',
      quadrant: json['quadrant'] as String? ?? '',
      done: json['done'] as bool? ?? false,
    );
  }
}

class EfficiencyHabitItem {
  const EfficiencyHabitItem({
    required this.title,
    required this.target,
    required this.doneToday,
    required this.streak,
  });

  final String title;
  final String target;
  final bool doneToday;
  final int streak;

  EfficiencyHabitItem copyWith({
    String? title,
    String? target,
    bool? doneToday,
    int? streak,
  }) {
    return EfficiencyHabitItem(
      title: title ?? this.title,
      target: target ?? this.target,
      doneToday: doneToday ?? this.doneToday,
      streak: streak ?? this.streak,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'target': target,
    'doneToday': doneToday,
    'streak': streak,
  };

  factory EfficiencyHabitItem.fromJson(Map<String, dynamic> json) {
    return EfficiencyHabitItem(
      title: json['title'] as String? ?? '',
      target: json['target'] as String? ?? '',
      doneToday: json['doneToday'] as bool? ?? false,
      streak: json['streak'] as int? ?? 0,
    );
  }
}

class EfficiencyCountdownItem {
  const EfficiencyCountdownItem({
    required this.title,
    required this.targetDateIso,
  });

  final String title;
  final String targetDateIso;

  DateTime get targetDate => DateTime.parse(targetDateIso);

  EfficiencyCountdownItem copyWith({String? title, String? targetDateIso}) {
    return EfficiencyCountdownItem(
      title: title ?? this.title,
      targetDateIso: targetDateIso ?? this.targetDateIso,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'targetDateIso': targetDateIso,
  };

  factory EfficiencyCountdownItem.fromJson(Map<String, dynamic> json) {
    return EfficiencyCountdownItem(
      title: json['title'] as String? ?? '',
      targetDateIso:
          json['targetDateIso'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}

class EfficiencyTabView extends StatelessWidget {
  const EfficiencyTabView({
    super.key,
    required this.isSignedIn,
    required this.taskCount,
    required this.completedTaskCount,
    required this.calendarEventCount,
    required this.syncQueueCount,
    required this.quadrantItems,
    required this.pomodoroSecondsRemaining,
    required this.pomodoroCompletedRounds,
    required this.pomodoroRunning,
    required this.habits,
    required this.countdowns,
    required this.onQuadrantAction,
    required this.onPomodoroStart,
    required this.onPomodoroPause,
    required this.onPomodoroReset,
    required this.onHabitToggle,
    required this.onCountdownShift,
  });

  final bool isSignedIn;
  final int taskCount;
  final int completedTaskCount;
  final int calendarEventCount;
  final int syncQueueCount;
  final List<EfficiencyQuadrantItem> quadrantItems;
  final int pomodoroSecondsRemaining;
  final int pomodoroCompletedRounds;
  final bool pomodoroRunning;
  final List<EfficiencyHabitItem> habits;
  final List<EfficiencyCountdownItem> countdowns;
  final ValueChanged<int> onQuadrantAction;
  final VoidCallback onPomodoroStart;
  final VoidCallback onPomodoroPause;
  final VoidCallback onPomodoroReset;
  final ValueChanged<int> onHabitToggle;
  final void Function(int index, int daysDelta) onCountdownShift;

  static const List<String> _quadrants = <String>[
    '紧急且重要',
    '重要不紧急',
    '紧急不重要',
    '不紧急不重要',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuadrantItems = quadrantItems.length;
    final completedQuadrantItems = quadrantItems
        .where((item) => item.done)
        .length;
    final completedHabits = habits.where((item) => item.doneToday).length;
    final nearestCountdown = countdowns.isEmpty
        ? 0
        : countdowns
              .map((item) => item.targetDate.difference(DateTime.now()).inDays)
              .reduce((value, next) => value < next ? value : next);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('效率工具', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(isSignedIn ? '已登录，效率状态直接落在本地缓存里' : '未登录也可先演示本地效率闭环'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _EntryChip(label: '四象限'),
            _EntryChip(label: '番茄'),
            _EntryChip(label: '习惯'),
            _EntryChip(label: '倒数纪念日'),
            _EntryChip(label: '基础统计'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: pomodoroRunning ? onPomodoroPause : onPomodoroStart,
              icon: Icon(pomodoroRunning ? Icons.pause : Icons.play_arrow),
              label: Text(pomodoroRunning ? '暂停专注' : '开始专注'),
            ),
            OutlinedButton.icon(
              onPressed: onPomodoroReset,
              icon: const Icon(Icons.refresh),
              label: const Text('重置番茄'),
            ),
            FilledButton.tonalIcon(
              onPressed: habits.isEmpty ? null : () => onHabitToggle(0),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                habits.isNotEmpty && habits.first.doneToday ? '撤销首习惯' : '打卡首习惯',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(label: '任务总数', value: '$taskCount'),
            _MetricCard(label: '任务完成', value: '$completedTaskCount'),
            _MetricCard(label: '日历事件', value: '$calendarEventCount'),
            _MetricCard(label: '同步队列', value: '$syncQueueCount'),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('四象限'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            for (var i = 0; i < _quadrants.length; i++)
              _QuadrantCard(
                label: _quadrants[i],
                items: quadrantItems
                    .where((item) => item.quadrant == _quadrants[i])
                    .toList(),
                onAction: () => onQuadrantAction(i),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('番茄'),
        const SizedBox(height: 8),
        _PomodoroCard(
          secondsRemaining: pomodoroSecondsRemaining,
          completedRounds: pomodoroCompletedRounds,
          running: pomodoroRunning,
          onStart: onPomodoroStart,
          onPause: onPomodoroPause,
          onReset: onPomodoroReset,
        ),
        const SizedBox(height: 20),
        const _SectionTitle('习惯'),
        const SizedBox(height: 8),
        ...List.generate(
          habits.length,
          (index) => _HabitTile(
            item: habits[index],
            onChanged: (_) => onHabitToggle(index),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('倒数纪念日'),
        const SizedBox(height: 8),
        ...List.generate(
          countdowns.length,
          (index) => _CountdownTile(
            item: countdowns[index],
            onAddDay: () => onCountdownShift(index, 1),
            onSubtractDay: () => onCountdownShift(index, -1),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionTitle('基础统计'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: '四象限完成',
              value: '$completedQuadrantItems/$totalQuadrantItems',
            ),
            _MetricCard(
              label: '习惯打卡',
              value: '$completedHabits/${habits.length}',
            ),
            _MetricCard(label: '番茄轮次', value: '$pomodoroCompletedRounds'),
            _MetricCard(
              label: '最近倒数',
              value: nearestCountdown >= 0
                  ? '$nearestCountdown 天'
                  : '超期 ${-nearestCountdown} 天',
            ),
          ],
        ),
      ],
    );
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

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
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

class _QuadrantCard extends StatelessWidget {
  const _QuadrantCard({
    required this.label,
    required this.items,
    required this.onAction,
  });

  final String label;
  final List<EfficiencyQuadrantItem> items;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) => !item.done).toList();
    final theme = Theme.of(context);
    final preview = items.isEmpty ? '暂无示例任务' : items.first.title;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${items.where((item) => item.done).length}/${items.length} 已完成',
            ),
            const SizedBox(height: 8),
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(pending.isEmpty ? Icons.add_task : Icons.check),
                label: Text(pending.isEmpty ? '添加示例' : '完成首项'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PomodoroCard extends StatelessWidget {
  const _PomodoroCard({
    required this.secondsRemaining,
    required this.completedRounds,
    required this.running,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  final int secondsRemaining;
  final int completedRounds;
  final bool running;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (secondsRemaining / (25 * 60));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    running ? '专注中' : '待开始',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('已完成 $completedRounds 轮'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            const SizedBox(height: 12),
            Text(
              _formatDuration(secondsRemaining),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            const Text('25 分钟番茄钟的本地演示回合'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: running ? onPause : onStart,
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(running ? '暂停专注' : '开始专注'),
                ),
                OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.item, required this.onChanged});

  final EfficiencyHabitItem item;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: item.doneToday,
        onChanged: (value) => onChanged(value ?? false),
        title: Text(item.title),
        subtitle: Text('${item.target} · 连续 ${item.streak} 天'),
        secondary: const Icon(Icons.self_improvement),
      ),
    );
  }
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile({
    required this.item,
    required this.onAddDay,
    required this.onSubtractDay,
  });

  final EfficiencyCountdownItem item;
  final VoidCallback onAddDay;
  final VoidCallback onSubtractDay;

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.targetDate.difference(DateTime.now()).inDays;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.celebration_outlined),
        title: Text(item.title),
        subtitle: Text(daysLeft >= 0 ? '还有 $daysLeft 天' : '已超期 ${-daysLeft} 天'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: '提前一天',
              onPressed: onSubtractDay,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: '延后一天',
              onPressed: onAddDay,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

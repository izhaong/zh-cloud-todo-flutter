import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/time/task_time_formatter.dart';
import '../../native/native_intents.dart';
import '../../state/providers.dart';

class NativeTaskProjection {
  const NativeTaskProjection({
    required this.todayTasks,
    required this.importantTasks,
    required this.lockScreenServerIds,
    required this.unsyncedImportantCount,
    required this.shareText,
    required this.stickyNoteText,
  });

  final List<TodoTask> todayTasks;
  final List<TodoTask> importantTasks;
  final List<int> lockScreenServerIds;
  final int unsyncedImportantCount;
  final String shareText;
  final String stickyNoteText;

  factory NativeTaskProjection.fromTasks(
    Iterable<TodoTask> tasks, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final active = tasks
        .where((task) => !task.completed && !task.cancelled)
        .toList();
    final todayTasks = active.where((task) {
      final display = _taskDisplayDate(task);
      return display != null &&
          display.year == today.year &&
          display.month == today.month &&
          display.day == today.day;
    }).toList()..sort(_compareBySchedule);
    final importantTasks =
        active.where((task) => task.priority >= 2 || task.isPinned).toList()
          ..sort((left, right) {
            final priority = right.priority.compareTo(left.priority);
            if (priority != 0) return priority;
            return _compareBySchedule(left, right);
          });
    final lockScreenServerIds = importantTasks
        .map((task) => task.serverId)
        .whereType<int>()
        .toList(growable: false);
    final unsyncedImportantCount = importantTasks
        .where((task) => task.serverId == null)
        .length;
    final dateLabel = '${today.month}月${today.day}日';
    final shareText = todayTasks.isEmpty
        ? '$dateLabel 今日暂无待办任务'
        : [
            '$dateLabel 今日任务',
            for (var index = 0; index < todayTasks.length; index++)
              '${index + 1}. ${todayTasks[index].title}',
          ].join('\n');
    final stickyNoteText = todayTasks.isEmpty
        ? ''
        : [
            '今日重点',
            for (final task in todayTasks.take(5)) '☐ ${task.title}',
          ].join('\n');
    return NativeTaskProjection(
      todayTasks: List.unmodifiable(todayTasks),
      importantTasks: List.unmodifiable(importantTasks),
      lockScreenServerIds: List.unmodifiable(lockScreenServerIds),
      unsyncedImportantCount: unsyncedImportantCount,
      shareText: shareText,
      stickyNoteText: stickyNoteText,
    );
  }

  static DateTime? _taskDisplayDate(TodoTask task) {
    final instant = task.dueAt ?? task.endAt ?? task.startAt;
    if (instant == null) return null;
    return taskWallClockDateTime(
      instant,
      allDay: task.allDay,
      fixedTimezone: task.fixedTimezone,
      timeZone: task.timeZone,
    );
  }

  static int _compareBySchedule(TodoTask left, TodoTask right) {
    final leftDate = _taskDisplayDate(left);
    final rightDate = _taskDisplayDate(right);
    if (leftDate == null && rightDate != null) return 1;
    if (leftDate != null && rightDate == null) return -1;
    if (leftDate != null && rightDate != null) {
      final byDate = leftDate.compareTo(rightDate);
      if (byDate != 0) return byDate;
    }
    return left.id.compareTo(right.id);
  }
}

/// 原生增强入口页。页面只消费当前账号的 Drift 任务投影；平台通道仅接收
/// 已同步的服务端任务 ID，不会为离线任务伪造 ID。
class NativeEntryPage extends ConsumerStatefulWidget {
  const NativeEntryPage({
    super.key,
    this.taskStream,
    this.incomingUriStream,
    this.initialUriLoader,
  });

  final Stream<List<TodoTask>>? taskStream;
  final Stream<Uri>? incomingUriStream;
  final Future<Uri?> Function()? initialUriLoader;

  @override
  ConsumerState<NativeEntryPage> createState() => _NativeEntryPageState();
}

class _NativeEntryPageState extends ConsumerState<NativeEntryPage> {
  final TextEditingController _noteCtl = TextEditingController();
  StreamSubscription<Uri>? _incomingUriSubscription;
  int _warmUriVersion = 0;
  String _lastResult = '';

  @override
  void initState() {
    super.initState();
    _incomingUriSubscription =
        (widget.incomingUriStream ?? NativeIntents.incomingUris()).listen(
          _recordWarmUri,
          onError: (Object _) {},
        );
    _bootstrapUri();
  }

  @override
  void dispose() {
    unawaited(_incomingUriSubscription?.cancel());
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapUri() async {
    final warmUriVersion = _warmUriVersion;
    final uri =
        await (widget.initialUriLoader ?? NativeIntents.handleIncomingUri)();
    if (uri != null && warmUriVersion == _warmUriVersion) _recordUri(uri);
  }

  void _recordWarmUri(Uri uri) {
    _warmUriVersion++;
    _recordUri(uri);
  }

  void _recordUri(Uri uri) {
    if (!mounted) return;
    setState(() => _lastResult = 'URI 入参: $uri');
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taskRepositoryProvider);
    final taskStream =
        widget.taskStream ??
        repository?.watchAll() ??
        const Stream<List<TodoTask>>.empty();
    final now = ref.watch(currentDateTimeProvider)();
    return StreamBuilder<List<TodoTask>>(
      stream: taskStream,
      initialData: const [],
      builder: (context, snapshot) {
        final projection = NativeTaskProjection.fromTasks(
          snapshot.data ?? const [],
          now: now,
        );
        return Scaffold(
          appBar: AppBar(title: const Text('原生增强')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_lastResult.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_lastResult),
                  ),
                ),
              const SizedBox(height: 16),
              _SectionTitle('桌面便签'),
              TextField(
                controller: _noteCtl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '输入要显示在桌面便签的内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('填入今日任务'),
                    onPressed: projection.stickyNoteText.isEmpty
                        ? null
                        : () => _noteCtl.text = projection.stickyNoteText,
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.sticky_note_2),
                    label: const Text('写入桌面便签'),
                    onPressed: () async {
                      final content = _noteCtl.text.trim();
                      if (content.isEmpty) {
                        _toast('请先输入便签内容');
                        return;
                      }
                      final ok = await NativeIntents.setStickyNote(content);
                      _toast(ok ? '已写入桌面便签' : '不支持当前平台');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle('快捷指令 / URL Scheme'),
              const Text('zhcloudtodo://task/add?title=任务标题&due=2026-07-30'),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('复制 Scheme'),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(
                      text: 'zhcloudtodo://task/add?title=任务标题',
                    ),
                  );
                  _toast('已复制到剪贴板');
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle('系统分享'),
              FilledButton.icon(
                icon: const Icon(Icons.share),
                label: Text('分享今日任务（${projection.todayTasks.length}）'),
                onPressed: () async {
                  final ok = await NativeIntents.shareText(
                    projection.shareText,
                    subject: 'ZH-CLOUD Todo',
                  );
                  _toast(ok ? '已打开系统分享面板' : '分享失败');
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle('锁屏重要任务'),
              Text(
                projection.unsyncedImportantCount == 0
                    ? '仅推送已同步的重要或置顶任务'
                    : '另有 ${projection.unsyncedImportantCount} 项重要任务尚未同步，不会伪造任务 ID',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  '推送 ${projection.lockScreenServerIds.length} 项重要任务',
                ),
                onPressed: projection.lockScreenServerIds.isEmpty
                    ? null
                    : () async {
                        final ok = await NativeIntents.pushLockScreenTasks(
                          projection.lockScreenServerIds,
                        );
                        _toast(ok ? '已推送' : '不支持当前平台');
                      },
              ),
              const SizedBox(height: 24),
              _SectionTitle('桌面小组件数据预览'),
              if (projection.todayTasks.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('今天暂无任务'))
              else
                for (final task in projection.todayTasks)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.task_alt),
                    title: Text(task.title),
                    subtitle: Text(
                      NativeTaskProjection._taskDisplayDate(
                            task,
                          )?.toIso8601String() ??
                          '',
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

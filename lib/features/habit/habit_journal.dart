import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/brand_colors.dart';
import '../../state/efficiency_providers.dart';
import '../../state/providers.dart';

/// 嘀嗒《02-更好地完成习惯.md》:55-:60 五档心情（specs/131，矩阵 #45 面 ④）。
const habitMoodChoices = ['😊', '😐', '😞', '🤩', '😤'];

/// 打卡弹层（specs/131，矩阵 #45 面 ④）：心情五档 + 日志文本，
/// 拼进既有 check-in 的 note 字段（首行 emoji、其余正文）。
/// [onDone] 在打卡成功后回调（调用方刷新数据）。
Future<void> showHabitCheckInSheet(
  BuildContext context, {
  required int habitId,
  int? amount,
  VoidCallback? onDone,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _HabitCheckInSheet(habitId: habitId, amount: amount),
  );
  if (saved == true) onDone?.call();
}

class _HabitCheckInSheet extends ConsumerStatefulWidget {
  const _HabitCheckInSheet({required this.habitId, this.amount});

  final int habitId;
  final int? amount;

  @override
  ConsumerState<_HabitCheckInSheet> createState() => _HabitCheckInSheetState();
}

class _HabitCheckInSheetState extends ConsumerState<_HabitCheckInSheet> {
  String? _mood;
  final _journalController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final journalText = _journalController.text.trim();
    final String? note;
    if (_mood == null) {
      note = journalText.isEmpty ? null : journalText;
    } else {
      note = journalText.isEmpty ? _mood : '$_mood\n$journalText';
    }
    try {
      await ref
          .read(habitRepositoryProvider)
          .checkIn(widget.habitId, amount: widget.amount, note: note);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('打卡失败：${error.toString()}')),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '打卡',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('心情', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final (index, mood) in habitMoodChoices.indexed)
                    Expanded(
                      child: IconButton(
                        key: Key('habit-mood-$index'),
                        icon: Text(
                          mood,
                          style: TextStyle(fontSize: _mood == mood ? 28 : 22),
                        ),
                        onPressed: () =>
                            setState(() => _mood = _mood == mood ? null : mood),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _journalController,
                key: const Key('habit-journal-input'),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '日志',
                  hintText: '记录今天的完成情况…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('habit-checkin-save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '打卡'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 习惯详情页的「打卡日志」时间轴段（specs/131，矩阵 #45 面 ④）。
class HabitJournalSection extends ConsumerWidget {
  const HabitJournalSection({super.key, required this.habitId});

  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalFuture = ref.watch(habitJournalFutureProvider(habitId));
    return journalFuture.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final colors = brandColors(context);
        return Column(
          key: const Key('habit-journal-section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                '打卡日志',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.foreground,
                ),
              ),
            ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        DateFormat('MM-dd HH:mm').format(entry.checkedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    if (entry.moodAndJournal != null) ...[
                      Text(entry.moodAndJournal!.$1 ?? ''),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        entry.moodAndJournal?.$2 ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

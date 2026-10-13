import 'dart:math' as math;

import '../../core/db/app_database.dart';
import '../../state/repositories/reminder_repository.dart';
import 'default_reminder_fire_at.dart';

/// 批量快速添加里「识别到时间」的那一半。
///
/// 判据源《03-特色功能/05-智能识别.md》:5「你可以在“快速添加”中直接输入日期文本，
/// 滴答清单会自动识别并为您创建日期和提醒。」单条弹窗已按这句话落提醒；
/// 多行批量走 `TaskRepository.createBatch` 的 `dueAtResolver`，此前只写 `dueAt` 不建提醒。
///
/// [defaultReminderMinutes] 是「新任务默认值-默认提醒」那档
/// （specs/105，矩阵 #9 面 ⑥）：非空且 >0 时提醒时刻 = 识别时刻 − 提前分钟数，
/// 与单条弹窗同一套换算（[reminderFireAtFor]）；换算后落在过去的行不建提醒、
/// 不计失败——那是「默认提醒」的语义，不是写入出错。
///
/// 失败语义照 `TaskQuickAddSheet._save` 的先例：提醒写不成不回滚已建任务，
/// 也不能静默早退 —— 返回值就是该给用户看的那句话，null 表示无需报告。
Future<String?> attachResolvedReminders({
  required List<TodoTask> created,
  required ReminderRepository? reminders,
  int? defaultReminderMinutes,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  final resolved = created.where((task) => task.dueAt != null).toList();
  if (resolved.isEmpty) return null;
  if (reminders == null) {
    return '任务已建，但提醒没建成：提醒功能当前不可用';
  }
  var failed = 0;
  var skipped = 0;
  for (final task in resolved) {
    final fireAt = reminderFireAtFor(
      task.dueAt!,
      defaultReminderMinutes: defaultReminderMinutes,
      now: clock,
    );
    if (fireAt == null) {
      skipped += 1;
      continue;
    }
    try {
      await reminders.create(taskId: task.id, fireAt: fireAt);
    } catch (_) {
      failed += 1;
    }
  }
  if (failed == 0) return null;
  final attempted = resolved.length - skipped;
  final done = math.max(0, attempted - failed);
  return '已建 $done 条提醒，另有 $failed 条没建成，请稍后在任务里添加提醒';
}

import '../../core/db/app_database.dart';
import '../../state/repositories/reminder_repository.dart';

/// 批量快速添加里「识别到时间」的那一半。
///
/// 判据源《03-特色功能/05-智能识别.md》:5「你可以在“快速添加”中直接输入日期文本，
/// 滴答清单会自动识别并为您创建日期和提醒。」单条弹窗已按这句话落提醒；
/// 多行批量走 `TaskRepository.createBatch` 的 `dueAtResolver`，此前只写 `dueAt` 不建提醒。
///
/// 失败语义照 `TaskQuickAddSheet._save` 的先例：提醒写不成不回滚已建任务，
/// 也不能静默早退 —— 返回值就是该给用户看的那句话，null 表示无需报告。
Future<String?> attachResolvedReminders({
  required List<TodoTask> created,
  required ReminderRepository? reminders,
}) async {
  final resolved = created.where((task) => task.dueAt != null).toList();
  if (resolved.isEmpty) return null;
  if (reminders == null) {
    return '任务已建，但提醒没建成：提醒功能当前不可用';
  }
  var failed = 0;
  for (final task in resolved) {
    try {
      await reminders.create(taskId: task.id, fireAt: task.dueAt!);
    } catch (_) {
      failed += 1;
    }
  }
  if (failed == 0) return null;
  final done = resolved.length - failed;
  return '已建 $done 条提醒，另有 $failed 条没建成，请稍后在任务里添加提醒';
}
